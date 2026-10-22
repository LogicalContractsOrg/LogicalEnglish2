import { test, expect } from '@playwright/test';

// Case searches (docs/user/reference/language.md §17.11): "which cases make it
// the case that …" lists every case in which the goal holds, each with the
// scenarios that cover it; "is there a case in which …" finds a case that
// breaks a property. A case no scenario covers offers "Add as scenario",
// which writes a ready-made scenario that meets it into the program.
test.describe('Case search', () => {
    test('lists the cases and adds a scenario for an uncovered one', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('index.html?example=regulatory/case_search&scenario=ana&query=both%20eligible%20and%20excluded');
        await expect(page.locator('#query-select')).toHaveValue('both eligible and excluded', { timeout: 90000 });
        await page.click('#btn-query');
        const cases = page.locator('#answers-list .answer-item.case-item');
        await expect(cases).toHaveCount(2, { timeout: 90000 });
        await expect(cases.nth(0).locator('.case-badge')).toHaveText(/case 1 of 2/i);
        await expect(cases.nth(0).locator('.case-coverage')).toHaveText('covered by scenario ben');
        const gap = cases.nth(1);
        await expect(gap).toContainText('the amount is greater than 15000 and the amount is less than 20000');
        await expect(gap.locator('.case-coverage.uncovered')).toBeVisible();

        await gap.locator('.case-add-scenario').click();
        const source = await page.evaluate(() => (window as any).monaco?.editor?.getEditors?.()[0]?.getValue());
        expect(source).toContain('scenario case_2 is:');
        expect(source).toContain('person_1 has an income of 17500.');
        // run again: the new scenario now covers the case
        await page.click('#btn-query');
        await expect(page.locator('#answers-list .answer-item.case-item').nth(1).locator('.case-coverage'))
            .toHaveText('covered by scenario case_2', { timeout: 90000 });
    });

    test('says when a property holds in every case', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('index.html?example=regulatory/case_search&scenario=ana&query=support%20for%20a%20student');
        await expect(page.locator('#query-select')).toHaveValue('support for a student', { timeout: 90000 });
        await page.click('#btn-query');
        await expect(page.locator('#answers-list .answer-item').first())
            .toHaveText('there is no such case: the search covered every case', { timeout: 90000 });
    });

    test('Misc > Find Cases asks both searches about the selected query', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('index.html?example=regulatory/case_search&scenario=ana&query=support');
        await expect(page.locator('#query-select')).toHaveValue('support', { timeout: 90000 });
        // "which cases make it the case that …", from the selected query
        await page.locator('.menu-item', { hasText: 'Misc' }).first().hover();
        await page.locator('#menu-find-cases').hover();
        await page.locator('#menu-find-cases-all').click();
        await expect(page.locator('#cases-modal')).toBeVisible();
        await expect(page.locator('#cases-opener')).toHaveText('which cases make it the case that …');
        await expect(page.locator('#cases-goal')).toHaveValue('which person gets rent support');
        await page.click('#cases-run');
        await expect(page.locator('#query-select')).toHaveValue('___custom___');
        await expect(page.locator('#custom-query-text')).toHaveValue('which cases make it the case that which person gets rent support');
        await expect(page.locator('#answers-list .answer-item.case-item')).toHaveCount(1, { timeout: 90000 });
        await expect(page.locator('#answers-list .case-coverage').first()).toHaveText('covered by scenario ana');

        // "is there a case in which …": the custom query's goal, without its opener
        await page.locator('.menu-item', { hasText: 'Misc' }).first().hover();
        await page.locator('#menu-find-cases').hover();
        await page.locator('#menu-find-cases-one').click();
        await expect(page.locator('#cases-opener')).toHaveText('is there a case in which …');
        await expect(page.locator('#cases-goal')).toHaveValue('which person gets rent support');
        await page.fill('#cases-goal', 'a person gets rent support and the person is a student.');
        await page.click('#cases-run');
        await expect(page.locator('#custom-query-text')).toHaveValue('is there a case in which a person gets rent support and the person is a student');
        await expect(page.locator('#answers-list .answer-item').first())
            .toHaveText('there is no such case: the search covered every case', { timeout: 90000 });
    });
});
