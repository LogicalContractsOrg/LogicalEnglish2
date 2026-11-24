// The clipboard, for tests that check what a "Copy" button copied.
//
// The system clipboard is one for the whole machine, and the tests run in
// several workers at the same time. Two tests that copy in the same moment
// read each other's text: for months two tests of the Query Editor failed in
// turn for this reason. So each page also keeps what it copied itself, and the
// tests read that, after they have waited for the copy to be made. The page's own code is not changed: it still writes to the
// real clipboard.

import type { BrowserContext, Page } from '@playwright/test';

// Call before the first page.goto of the test, in place of
// context.grantPermissions(['clipboard-read', 'clipboard-write']).
export async function ownClipboard(context: BrowserContext): Promise<void> {
    await context.grantPermissions(['clipboard-read', 'clipboard-write']);
    await context.addInitScript(() => {
        const w = window as any;
        const cb = navigator.clipboard as any;
        if (!cb || w.__leClipboardKept) return;
        w.__leClipboardKept = true;
        const writeText = cb.writeText.bind(cb);
        cb.writeText = (text: string) => { w.__leCopied = String(text); return writeText(text); };
        const write = cb.write.bind(cb);
        cb.write = async (items: any[]) => {
            for (const item of items) {
                if (item.types.includes('text/plain')) {
                    w.__leCopied = await (await item.getType('text/plain')).text();
                }
            }
            return write(items);
        };
    });
}

// What this page copied since the last call. A "Copy" button answers the
// click before its text is on the clipboard (the handler waits for other things
// first), so this waits for the copy: a test that read at once got the text of
// the copy before, or of another test. For a page that copies nothing itself
// (the copy was made by another window), the system clipboard is read.
export async function copiedText(page: Page): Promise<string> {
    try {
        await page.waitForFunction(() => (window as any).__leCopied !== undefined, undefined, { timeout: 10000 });
    } catch {
        return page.evaluate(() => navigator.clipboard.readText());
    }
    return page.evaluate(() => {
        const w = window as any;
        const text = w.__leCopied;
        w.__leCopied = undefined;      // the next call waits for the next copy
        return text;
    });
}
