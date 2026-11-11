import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

// The Radial Tree of a query (radial-tree.html): opened from Misc > Radial
// Tree with the query selected in the Query panel, or from the editor's
// context menu with the selection on a query. The program is the fixture of
// testing/test_graph.pl (radial_tree).
const PROGRAM = fs.readFileSync(
    path.join(__dirname, '..', '..', 'testing', 'fixtures', 'le', 'radial_tree_claims.le'), 'utf8');

async function openEditor(page: any) {
    await page.goto('index.html?text=' + encodeURIComponent(PROGRAM));
    await page.waitForTimeout(800);
    await page.locator('#scenario-select').hover();   // triggers the module load
    await expect.poll(() => page.locator('#query-select option').count(), { timeout: 30000 }).toBeGreaterThan(1);
    await page.evaluate(() => localStorage.setItem('le_graph_test', '1'));
}

async function waitForTree(popup: any) {
    await popup.waitForLoadState();
    await expect.poll(() => popup.evaluate(() => !!(window as any).__radialTest), { timeout: 30000 }).toBe(true);
    await expect.poll(() => popup.evaluate(() =>
        (window as any).__radialTest.labels().length), { timeout: 60000 }).toBeGreaterThan(0);
}

test.describe('Radial Tree', () => {
    test('Misc > Radial Tree asks for a query, then shows its tree and tests', async ({ page }) => {
        test.setTimeout(120000);
        await openEditor(page);

        // No query selected: a message, no window.
        let message = '';
        page.once('dialog', async (d: any) => { message = d.message(); await d.accept(); });
        await page.click('text=Misc');
        await page.click('#menu-radial-tree');
        await expect.poll(() => message).toContain('Select a query');

        await page.selectOption('#query-select', 'covered');
        await page.click('text=Misc');
        const [popup] = await Promise.all([
            page.waitForEvent('popup'),
            page.click('#menu-radial-tree'),
        ]);
        await waitForTree(popup);

        const labels: string[] = await popup.evaluate(() => (window as any).__radialTest.labels());
        expect(labels).toContain('covered');
        expect(labels).toContain('a claim is under the buildings section');
        expect(labels).toContain('a claim concerns gradual wear');

        // The tests panel: three scenarios, all passed.
        await expect(popup.locator('#tests-table tbody tr')).toHaveCount(3);
        await expect(popup.locator('#tests-summary')).toContainText('3/3');

        // A scenario selected: the root shows whether the query holds in it.
        await popup.locator('#tests-table tbody tr').nth(1).click();   // wear: not covered
        await expect(popup.locator('.verdict-text')).toHaveText('NO');
        await popup.locator('#tests-table tbody tr').nth(0).click();   // pipe: covered
        await expect(popup.locator('.verdict-text')).toHaveText('YES');
        await expect(popup.locator('.status-no').first()).toBeVisible();   // NOT gradual wear... holds; something else does not
    });

    test('the context menu item checks that the selection is a query', async ({ page }) => {
        test.setTimeout(120000);
        await openEditor(page);

        const runAt = async (needle: string) => page.evaluate((n: string) => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            const model = ed.getModel();
            const pos = model.getPositionAt(model.getValue().indexOf(n) + 2);
            ed.setPosition(pos);
            return ed.getAction('open-radial-tree').run(ed);
        }, needle);

        // In a rule: not a query.
        let message = '';
        page.once('dialog', async (d: any) => { message = d.message(); await d.accept(); });
        await runAt('a claim is under the contents section\n    if');
        await expect.poll(() => message).toContain('not a query');

        // In the query: the tree opens.
        const [popup] = await Promise.all([
            page.waitForEvent('popup'),
            runAt('which claim is covered'),
        ]);
        await waitForTree(popup);
        expect(await popup.evaluate(() => (window as any).__radialTest.reply().query)).toBe('covered');
    });
});
