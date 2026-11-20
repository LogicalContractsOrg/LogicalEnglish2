import { test, expect } from '@playwright/test';

// The facts background (language reference §14.5) in the Scenario Editor:
// the review list of "Write it in English" and "Apply the facts background".
// The backend is mocked: the background step itself is tested in
// testing/test_facts_background.pl.

const SOURCE = [
    'the target language is: prolog.',
    '',
    'the facts background includes these resources:',
    '    background/garments, background/presumptions.',
    '',
    'the templates are:',
    '    the kind of *a good* is *a kind*; undefined.',
    '    the fabric of *a garment* is lightweight; undefined.',
].join('\n');

const BACKGROUND = {
    lines: [
        'the kind of tee is T-shirt, according to garments background, because "kind_by_name", confer "Men Tee Shirt".',
        'the fabric of tee is lightweight, according to customs presumptions, because "tshirt_fabric", confer "Men Tee Shirt".',
    ],
    derived: [
        { fact: 'the kind of tee is T-shirt', line: 'the kind of tee is T-shirt, according to garments background, because "kind_by_name", confer "Men Tee Shirt".',
          program: 'garments background', rule: 'kind_by_name', passage: 'Men Tee Shirt', from: [] },
        { fact: 'the fabric of tee is lightweight', line: 'the fabric of tee is lightweight, according to customs presumptions, because "tshirt_fabric", confer "Men Tee Shirt".',
          program: 'customs presumptions', rule: 'tshirt_fabric', passage: 'Men Tee Shirt', from: [] },
    ],
    noted: [{ fact: 'tee is called "tee shirt", confer "Men Tee Shirt".', produced: ['the kind of tee is T-shirt'] }],
    unused: ['tee is called "boyshorts", confer "Boyshorts".'],
    notes: [],
    questions: [],
    programs: [],
};

async function open(page: any) {
    await page.goto('index.html');
    await page.evaluate((s: string) => {
        localStorage.setItem('le_scenario_editor_data', JSON.stringify({ source: s }));
        localStorage.setItem('le-assistant-model', 'openai/gpt-oss-120b');
    }, SOURCE);
}

test.describe('Facts background', () => {
    test('Write it in English shows the derived facts with their program, and inserts the ticked ones', async ({ page }) => {
        await open(page);
        await page.route('**/leapi*', async (route: any) => {
            const body = JSON.parse(route.request().postData() || '{}');
            if (body.operation === 'nl_to_le') {
                await route.fulfill({ status: 200, contentType: 'application/json',
                    body: JSON.stringify({ result: 'ok', le: BACKGROUND.lines.join('\n'), warnings: [], background: BACKGROUND }) });
            } else { await route.continue(); }
        });
        await page.goto('scenario-editor.html');
        await page.fill('#scenario-name', 'listing');
        await page.selectOption('#add-template', '__write_in_english__');
        await page.click('#btn-add');
        await page.fill('.nl-dialog textarea', 'Men Tee Shirt');
        await page.click('.nl-dialog button.primary');

        // the review list: one row per fact, each with the badge of its program
        await expect(page.locator('.nl-bg-row')).toHaveCount(2);
        await expect(page.locator('.nl-bg-badge').nth(0)).toHaveText('garments background');
        await expect(page.locator('.nl-bg-badge').nth(1)).toHaveText('customs presumptions');
        await expect(page.locator('.nl-bg-badge').nth(1)).toHaveAttribute('title', /tshirt_fabric/);
        await expect(page.locator('.nl-bg')).toContainText('boyshorts');

        // untick the presumption, then insert
        await page.locator('.nl-bg-row input[type=checkbox]').nth(1).uncheck();
        await page.click('.nl-dialog button.primary');
        await expect(page.locator('.nl-dialog')).toHaveCount(0);
        await expect(page.locator('.fact-row')).toHaveCount(1);
        await expect(page.locator('.fact-row').nth(0).locator('input.field').nth(1)).toHaveValue('T-shirt');
    });

    test('Apply the facts background adds the facts that follow from the rows', async ({ page }) => {
        await open(page);
        let sent: any = null;
        await page.route('**/leapi*', async (route: any) => {
            const body = JSON.parse(route.request().postData() || '{}');
            if (body.operation === 'applyFactsBackground') {
                sent = body;
                await route.fulfill({ status: 200, contentType: 'application/json',
                    body: JSON.stringify({ result: 'ok', background: { ...BACKGROUND, lines: [BACKGROUND.lines[1]], derived: [BACKGROUND.derived[1]] } }) });
            } else { await route.continue(); }
        });
        await page.goto('scenario-editor.html');
        await expect(page.locator('#btn-apply-background')).toBeVisible();
        const kindOption = await page.locator('#add-template option', { hasText: 'kind of' }).first().getAttribute('value');
        await page.selectOption('#add-template', kindOption!);
        await page.click('#btn-add');
        await page.locator('.fact-row input.field').first().fill('tee');
        await page.locator('.fact-row input.field').nth(1).fill('T-shirt');
        await page.click('#btn-apply-background');
        await expect(page.locator('.fact-row')).toHaveCount(2);
        await expect(page.locator('.fact-row').nth(1)).toContainText('lightweight');
        await expect(page.locator('#status')).toContainText('1');
        expect(sent.facts[0]).toContain('the kind of tee is T-shirt');
    });

    test('the button is hidden without a facts background', async ({ page }) => {
        await page.goto('index.html');
        await page.evaluate(() => {
            localStorage.setItem('le_scenario_editor_data', JSON.stringify({ source: 'the templates are:\n    *a person* is happy.\n' }));
        });
        await page.goto('scenario-editor.html');
        await expect(page.locator('#btn-apply-background')).toBeHidden();
    });
});
