import { test, expect } from '@playwright/test';

// Misc ▸ Run the Program's Tests: every expectation of the program with its
// outcome. A passed test shows what it expected and what it got, as a failed
// one does; a test that expects no answers says so.
test.describe('Test report', () => {
    test('shows Expected and Got for passed tests', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('index.html?example=migration/dmn/clients/traffic_violation/traffic_violation&scenario=readme&query=q_d_amount_of_the_fine');
        await expect(page.locator('#query-select')).toHaveValue('q_d_amount_of_the_fine', { timeout: 90000 });
        await page.evaluate(() => (document.getElementById('menu-test-report') as HTMLElement).click());
        const report = page.locator('#test-report');
        await expect(report).toContainText('21 passed', { timeout: 90000 });

        const readme = report.locator('tr', { hasText: 'readme' }).filter({ hasText: 'q_d_amount_of_the_fine' });
        await expect(readme.locator('td').nth(3)).toHaveText('the amount of the fine is 500');
        await expect(readme.locator('td').nth(4)).toHaveText('the amount of the fine is 500');

        const none = report.locator('tr', { hasText: 'slightly_fast' }).filter({ hasText: 'q_d_amount_of_the_fine' });
        await expect(none.locator('td').nth(3)).toHaveText('(no answers)');
        await expect(none.locator('td').nth(4)).toHaveText('(no answers)');
    });
});
