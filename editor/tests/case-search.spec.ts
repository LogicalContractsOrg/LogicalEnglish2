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
});
