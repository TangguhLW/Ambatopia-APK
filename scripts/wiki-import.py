"""Cache public category listings and bounded factual infobox metadata, then publish a sidecar."""
import argparse
import hashlib
import html
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOST = 'https://growtopiawiki.com'
CACHE = ROOT / 'research/external-sources/wiki-cache'
STAGE = ROOT / 'research/external-sources/wiki-staging.json'


def text(value):
    return ' '.join(html.unescape(re.sub('<[^>]+>', ' ', value)).split())


def parse_listing(body, url):
    if 'id="mw-pages"' not in body:
        raise ValueError('Category page list missing')
    section = body.split('id="mw-pages"', 1)[1].split('id="catlinks"', 1)[0]
    entries = {}
    for href, title in re.findall(r'<a\s+href="([^"]+)"\s+title="([^"]+)"', section):
        if href.startswith('/w/') and not re.match(r'(Category|File|Template|Help|Special):', html.unescape(title)):
            destination = urllib.parse.urljoin(url, html.unescape(href))
            entries[destination] = {'name': html.unescape(title), 'url': destination}
    following = re.search(r'<a\s+href="([^"]+)"[^>]*>next page</a>', section)
    total = re.search(r'out of ([\d,]+) total', text(section))
    return {'entries': list(entries.values()), 'next': urllib.parse.urljoin(url, html.unescape(following[1])) if following else None,
            'reported_total': int(total[1].replace(',', '')) if total else None}


def parse_detail(body, url):
    title = re.search(r'<h1[^>]*>(.*?)</h1>', body, re.S)
    image = re.search(r'<meta property="og:image" content="([^"]+)"', body)
    sprite = html.unescape(image[1]) if image else None
    sprite_id = re.search(r'/sprites/(\d+)\.png(?:\?|$)', sprite or '')
    revision = re.search(r'"wgRevisionId":(\d+)', body)
    rows = {}
    for row in re.findall(r'<tr[^>]*>(.*?)</tr>', body, re.S):
        cells = re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row, re.S)
        if len(cells) >= 2 and text(cells[0]) in ['Type', 'Render Type', 'Collision Type', 'Hardness', 'Clothing Type', 'Gems Drop']:
            rows[text(cells[0])] = text(cells[1])[:240]
    categories = sorted(set(html.unescape(v) for v in re.findall(r'title="Category:([^"]+)"', body)))
    return {'name': text(title[1]) if title else '', 'url': url, 'sprite_url': sprite,
            'sprite_kind': 'wiki inventory preview; worn animation not established',
            'sprite_id_candidate': int(sprite_id[1]) if sprite_id else None,
            'revision': int(revision[1]) if revision else None, 'fields': rows, 'categories': categories,
            'license': 'CC BY-NC-SA unless individually noted; file license not independently verified'}


def fetch(url, kind):
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != 'https' or parsed.netloc != 'growtopiawiki.com':
        raise ValueError('Out-of-scope URL')
    if not (parsed.path.startswith('/w/') or parsed.path == '/index.php' and parsed.query.startswith('title=Category:')):
        raise ValueError('Disallowed robots path')
    if any(key+'=' in parsed.query for key in ['action', 'oldid', 'diff', 'veaction']):
        raise ValueError('Disallowed query')
    clean = urllib.parse.urldefrag(url)[0]
    path = CACHE / (hashlib.sha256(clean.encode()).hexdigest()+'.json')
    if path.exists():
        cached = json.loads(path.read_text(encoding='utf-8'))
        if cached['url'] != clean or cached['kind'] != kind:
            raise ValueError('Cache identity mismatch')
        return cached['data']
    for attempt in range(3):
        try:
            request = urllib.request.Request(clean, headers={'User-Agent':'AmbatopiaResourceResearch/0.11 (public metadata, cached; single request)'})
            with urllib.request.urlopen(request, timeout=20) as response:
                if response.geturl().split('/')[2] != 'growtopiawiki.com':
                    raise ValueError('Unexpected redirect origin')
                body = response.read(2_000_001)
                if len(body)>2_000_000:
                    raise ValueError('Response too large')
                data = (parse_listing if kind=='listing' else parse_detail)(body.decode('utf-8'),clean)
            atomic(path,{'url':clean,'kind':kind,'fetched_at':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'sha256':hashlib.sha256(body).hexdigest(),'data':data})
            time.sleep(0.8)
            return data
        except urllib.error.HTTPError as error:
            if error.code not in [429,500,502,503,504] or attempt==2:
                raise
            time.sleep(min(60,max(2**attempt,float(error.headers.get('Retry-After','2')))))
        except (TimeoutError, urllib.error.URLError):
            if attempt==2:
                raise
            time.sleep(2**attempt)


def atomic(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    temporary = path.with_suffix(path.suffix+'.tmp')
    temporary.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
    temporary.replace(path)


def validate(rows):
    if not rows or len({r['id'] for r in rows}) != len(rows):
        raise ValueError('Empty or duplicate-ID publication rejected')
    if any(not isinstance(r['id'],int) or not r.get('name') or not r.get('source_url','').startswith(HOST+'/w/') for r in rows):
        raise ValueError('Invalid publication')


def run(args):
    CACHE.mkdir(parents=True,exist_ok=True)
    state={'pages':[],'entries':{},'details':{},'errors':[],'reported_total':None,'listing_complete':False}
    if STAGE.exists():
        state=json.loads(STAGE.read_text(encoding='utf-8'))
    url=HOST+'/w/Category:Item'
    visited=set()
    while url:
        url=urllib.parse.urldefrag(url)[0]
        if url in visited:
            raise ValueError('Repeated category cursor')
        visited.add(url)
        page=fetch(url,'listing')
        if page['reported_total'] is not None:
            state['reported_total']=page['reported_total']
        for row in page['entries']:
            state['entries'][row['url']]=row
        if url not in state['pages']:
            state['pages'].append(url)
        atomic(STAGE,state)
        print('Listing',len(visited),len(state['entries']),flush=True)
        if len(visited)>200:
            raise ValueError('Unexpected pagination budget')
        url=page['next']
    state['listing_complete']=len(state['entries'])==state['reported_total']
    index=json.loads((ROOT/'data/catalog-index.json').read_text(encoding='utf-8'))
    native={int(r['id']):r for r in index['entries']}
    priority=['Dirt','Rock','Cave Background','Main Door','Bedrock','World Lock','Baseball Cap','Shades','Green Shirt','Jeans','Brown Shoes','Fairy Wings']
    details=sorted(state['entries'].values(),key=lambda r:(r['name'] not in priority,r['name']))
    limit=len(details) if args.details=='all' else int(args.details)
    for row in details[:limit]:
        if row['url'] in state['details']:
            continue
        try:
            state['details'][row['url']]=fetch(row['url'],'detail')
        except Exception as error:
            state['errors'].append({'url':row['url'],'error':str(error)})
        atomic(STAGE,state)
        if len(state['details'])%25==0:
            print('Details',len(state['details']),flush=True)
    verified=[]
    conflicts=[]
    for row in state['details'].values():
        original=row['sprite_id_candidate']
        local=native.get(original)
        if local and local['name'].casefold()==row['name'].casefold():
            verified.append({'id':original,'name':local['name'],'source_url':row['url'],'revision':row['revision'],
                             'wiki_categories':row['categories'],'wiki_fields':row['fields'],'sprite_url':row['sprite_url'],
                             'local_asset':local['asset'],'verification':'ID from sprite URL + exact native ID/name agreement; sprite mapping remains local',
                             'license':row['license']})
        else:
            conflicts.append({'wiki':row['name'],'id_candidate':original,'local':local['name'] if local else None,'url':row['url']})
    coverage={'category_pages':len(visited),'unique_listed':len(state['entries']),'reported_total':state['reported_total'],
              'listing_complete':state['listing_complete'],'detail_success':len(state['details']),'failures':len(state['errors']),
              'verified_native_matches':len(verified),'conflicts':conflicts,'canonical_catalog_replaced':False}
    atomic(ROOT/'research/external-sources/coverage.json',coverage)
    if args.publish:
        validate(verified)
        destination=ROOT/'data/source-enrichment.json'
        if destination.exists():
            atomic(destination.with_suffix('.previous.json'),json.loads(destination.read_text(encoding='utf-8')))
        atomic(destination,{'schema_version':1,'native_generation':index['generation'],'entries':sorted(verified,key=lambda r:r['id'])})
    print(json.dumps(coverage,ensure_ascii=False),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--details',default='64')
    parser.add_argument('--publish',action='store_true')
    run(parser.parse_args())
