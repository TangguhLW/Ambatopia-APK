import importlib.util
import tempfile
import unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('wiki_import',Path(__file__).resolve().parents[1]/'scripts/wiki-import.py')
pipeline=importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)


class WikiImportTests(unittest.TestCase):
    def test_listing_and_cursor(self):
        html='<div id="mw-pages"><p>200 pages, out of 201 total</p><a href="/w/Dirt" title="Dirt">Dirt</a><a href="/w/Dirt" title="Dirt">Dirt</a><a href="/index.php?title=Category:Item&amp;pagefrom=Rock">next page</a><div id="catlinks">'
        row=pipeline.parse_listing(html,pipeline.HOST+'/w/Category:Item')
        self.assertEqual(len(row['entries']),1)
        self.assertEqual(row['reported_total'],201)
        self.assertIn('&pagefrom=Rock',row['next'])

    def test_changed_or_broken_response(self):
        with self.assertRaises(ValueError):pipeline.parse_listing('<p>challenge</p>',pipeline.HOST)
        row=pipeline.parse_detail('<h1>No item</h1>',pipeline.HOST+'/w/No_item')
        self.assertIsNone(row['sprite_id_candidate'])

    def test_detail_identity_and_fields(self):
        row=pipeline.parse_detail('<h1>Dirt</h1><meta property="og:image" content="https://cdn.growtopiawiki.com/sprites/2.png?v=1"><table><tr><th>Hardness</th><td>3 Hits</td></tr></table>',pipeline.HOST+'/w/Dirt')
        self.assertEqual(row['sprite_id_candidate'],2)
        self.assertEqual(row['fields']['Hardness'],'3 Hits')

    def test_publication_rejects_empty_duplicates_and_invalid_origin(self):
        for rows in [[],[{'id':2},{'id':2}],[{'id':2,'name':'Dirt','source_url':'https://invalid.example/'}]]:
            with self.assertRaises(ValueError):pipeline.validate(rows)

    def test_atomic_idempotent_cache_preserves_last_good(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'active.json'
            row={'entries':[{'id':2,'name':'Dirt'}]}
            pipeline.atomic(p,row)
            before=p.read_bytes()
            pipeline.atomic(p,row)
            self.assertEqual(p.read_bytes(),before)
            try:pipeline.validate([])
            except ValueError:pass
            self.assertEqual(p.read_bytes(),before)

    def test_network_scope_fails_before_request(self):
        for url in ['https://growtopiawiki.com/api.php?action=query','https://example.com/w/Dirt','https://growtopiawiki.com/index.php?title=Category:Item&action=edit']:
            with self.assertRaises(ValueError):pipeline.fetch(url,'listing')


if __name__=='__main__':unittest.main()
