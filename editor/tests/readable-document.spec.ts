import { test, expect } from '@playwright/test';

// File > Save as a Readable Document (le_readable.pl): the program as a
// document for a person who reads it without the editor. Open shows the web
// page in a new tab; Save downloads the file; /readable/<example> gives the
// same document to a signed-in visitor, and sends anybody else to sign in.

async function signIn(page: any) {
    await page.request.post('/login', { form: {
        email: 'support@logicalcontracts.com', password: 'LE2rocks', return: '/' } });
}

async function openDialog(page: any) {
    await page.goto('index.html?example=citizenship');
    await page.waitForSelector('.monaco-editor', { timeout: 30000 });
    await expect.poll(() => page.evaluate(() =>
        ((window as any).monaco?.editor?.getModels?.() || []).map((m: any) => m.getValue()).join('')),
        { timeout: 30000 }).toContain('the knowledge base citizenship includes');
    await page.evaluate(() => (document.getElementById('menu-readable') as HTMLElement).click());
    await expect(page.locator('#readable-dialog')).toBeVisible();
}

test.describe('Readable document', () => {
    test('opens as a web page whose sentences link to their definitions', async ({ page }) => {
        await openDialog(page);
        await page.locator('#readable-dialog select').nth(1).selectOption('legal');
        const [doc] = await Promise.all([
            page.waitForEvent('popup'),
            page.locator('#readable-dialog button', { hasText: 'Open' }).click(),
        ]);
        await doc.waitForURL(/^blob:/, { timeout: 30000 });
        await expect(doc.locator('h1')).toHaveText('citizenship');
        await expect(doc.locator('body')).toHaveClass(/style-legal/);
        // "is the father of" in the first rule goes to the rule that defines it
        const link = doc.locator('#s11 a.t', { hasText: 'is the father of' });
        await expect(link).toHaveAttribute('href', '#s12');
        await expect(doc.locator('#s12 .h')).toContainText('is the father of');
        // the comment at the top of the program is not in the document
        await expect(doc.locator('body')).not.toContainText('Do NOT remove');
        // the style menu changes the style
        await doc.locator('#rd-style-btn').click();
        await doc.locator('#rd-style-menu li[data-style="cute"]').click();
        await expect(doc.locator('body')).toHaveClass(/style-cute/);
        await expect(doc.locator('.index dt')).toHaveCount(9);
    });

    test('saves a Word document', async ({ page }) => {
        await openDialog(page);
        await page.locator('#readable-dialog select').first().selectOption('docx');
        const [download] = await Promise.all([
            page.waitForEvent('download'),
            page.locator('#readable-dialog button', { hasText: 'Save' }).click(),
        ]);
        expect(download.suggestedFilename()).toBe('citizenship.docx');
    });

    test('a server that does not answer gives a message, not a wait for ever', async ({ page }) => {
        await openDialog(page);
        await page.locator('#readable-dialog select').first().selectOption('md');
        await page.route('**/leapi', route => {
            const body = route.request().postData() || '';
            return body.includes('readableDocument') ? route.abort('connectionreset') : route.continue();
        });
        await page.locator('#readable-dialog button', { hasText: 'Save' }).click();
        await expect(page.locator('#readable-dialog')).toContainText('The server did not answer');
        await expect(page.locator('#readable-dialog button', { hasText: 'Save' })).toBeEnabled();
        expect(await page.evaluate(() => document.body.style.cursor)).toBe('');
    });

    test('the address of an example is for signed-in visitors', async ({ page, request }) => {
        if (process.env.NO_RESTRICTIONS !== 'true') {
            const anon = await request.get('/readable/citizenship?format=html', { maxRedirects: 0 });
            expect(anon.status()).toBe(302);
            expect(anon.headers()['location']).toContain('/login?return=');
        }
        await signIn(page);
        const r = await page.request.get('/readable/citizenship?format=md');
        expect(r.status()).toBe(200);
        expect(await r.text()).toContain('# citizenship');
        await page.goto('/readable/citizenship?format=html&style=compact');
        await expect(page.locator('body')).toHaveClass(/style-compact/);
    });
});
