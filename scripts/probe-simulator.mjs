import { chromium } from 'file:///C:/Users/user/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs';
import fs from 'node:fs/promises';
const browser=await chromium.launch({channel:'msedge',headless:true});const page=await browser.newPage();const requests=[];page.on('pageerror',e=>console.log('PAGE ERROR',e.message));page.on('console',m=>console.log('CONSOLE',m.text().slice(0,300)));
page.on('response',async r=>{if(r.url().startsWith('https://growtopiasimulator.com/'))requests.push({url:r.url(),status:r.status()});});
await page.goto('https://growtopiasimulator.com/edit/',{waitUntil:'networkidle',timeout:60000});
await page.waitForTimeout(12000);console.log((await page.locator('body').innerText()).slice(0,5500));
console.log(await page.evaluate(()=>({globals:Object.keys(window).filter(k=>/GW|item|weather/i.test(k)),gw:typeof GW==='undefined'?null:Object.keys(GW)})));
await fs.writeFile('research/simulator-current/requests.json',JSON.stringify(requests,null,2));
await page.screenshot({path:'research/simulator-current/edit.png'});await browser.close();

