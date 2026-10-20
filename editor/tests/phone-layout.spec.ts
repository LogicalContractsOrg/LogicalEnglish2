import { test, expect } from '@playwright/test';

// On a phone (a narrow screen) the editor's page scrolls and its panels stack:
// the program, the query controls, the answers, the explanation. With the
// desktop layout the query controls filled the bottom panel, the answers and
// the explanation had no height below the screen, and the page could not
// scroll to them (the examples' QR codes open on phones).
test.use({ viewport: { width: 390, height: 664 }, hasTouch: true, isMobile: true });

test.describe('Phone layout', () => {
    test('an answer and its explanation can be scrolled to', async ({ page }) => {
        await page.goto('index.html?example=citizenship&scenario=harry&query=one');
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        await expect(page.locator('#query-select')).not.toHaveValue('', { timeout: 30000 });
        await page.locator('#btn-query').click();
        await expect(page.locator('#answers-panel')).toContainText('John acquires British citizenship', { timeout: 30000 });
        const sizes = await page.evaluate(() => ({
            page: document.documentElement.scrollHeight, screen: innerHeight,
            explanation: document.getElementById('explanation-panel')!.getBoundingClientRect().height,
        }));
        expect(sizes.page).toBeGreaterThan(sizes.screen);
        expect(sizes.explanation).toBeGreaterThan(100);
        await page.locator('#explanation-panel').scrollIntoViewIfNeeded();
        expect(await page.evaluate(() => scrollY)).toBeGreaterThan(0);
        await expect(page.locator('#explanation-panel')).toContainText('Harry is the father of John');
        await expect(page.locator('#explanation-panel')).toBeInViewport();
    });
});
