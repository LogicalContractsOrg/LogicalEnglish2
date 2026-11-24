#!/usr/bin/env node
/*  Opens each twin's "the policy in Minsc" link in a headless browser and
    reports what Minsc makes of it: the Miniscript descriptor and the address,
    or its error. The Try-in-Minsc door of the twins, checked.

        node check_minsc.cjs <twins-dir>        (e.g. LogicalEnglish2/examples/migration/miniscript)

    Needs Playwright's chromium (PLAYWRIGHT_CHROMIUM=path, else Playwright's own). */
'use strict';
const fs = require('fs');
const path = require('path');
let chromium;
for (const m of ['playwright', require('path').join(__dirname, '../../../editor/node_modules/playwright')]) { try { chromium = require(m).chromium; break; } catch {} }
if (!chromium) { console.error('no playwright'); process.exit(2); }
const dir = process.argv[2];
const twins = fs.readdirSync(dir).filter((d) => fs.existsSync(path.join(dir, d, d + '.le')));
(async () => {
    const opts = process.env.PLAYWRIGHT_CHROMIUM ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM } : {};
    const browser = await chromium.launch(opts);
    let bad = 0;
    for (const t of twins) {
        const text = fs.readFileSync(path.join(dir, t, t + '.le'), 'utf8');
        const m = text.match(/the policy in Minsc is published at "([^"]+)"/);
        if (!m) { console.log(JSON.stringify({ twin: t, error: 'no Minsc link' })); bad++; continue; }
        const page = await browser.newPage();
        await page.goto(m[1], { waitUntil: 'load' });
        await page.waitForFunction(() => document.querySelector('#loading') && getComputedStyle(document.querySelector('#loading')).display === 'none', null, { timeout: 30000 }).catch(() => {});
        await page.waitForTimeout(1500);
        const error = await page.$eval('#error', (e) => (getComputedStyle(e).display !== 'none' ? e.innerText.trim() : ''));
        const descriptor = await page.$eval('#output-miniscript .codeview', (e) => e.innerText.trim()).catch(() => '');
        const address = await page.$eval('#output-address span', (e) => e.innerText.trim()).catch(() => '');
        //  Minsc's compiler (rust-miniscript) refuses a policy with a spending
        //  path that needs no signature: a verdict on the policy, not a bad link
        const refusal = /not safe|malleable/i.test(error);
        if ((error && !refusal) || (!address && !refusal)) bad++;
        console.log(JSON.stringify({ twin: t, error, refusal, descriptor: descriptor.replace(/^x+/, '').slice(0, 120), address }));
        await page.close();
    }
    await browser.close();
    process.exit(bad ? 1 : 0);
})();
