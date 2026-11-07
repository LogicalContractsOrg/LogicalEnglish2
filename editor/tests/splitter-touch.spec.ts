import { test, expect } from '@playwright/test';

// The splitter between the program and the query panel, and the one between
// the answers and the explanation, can be dragged with a finger. They listened
// to mouse events only, and an iPad sends none while a finger drags (it
// scrolls the page instead), so on an iPad neither splitter moved.
test.use({ viewport: { width: 1024, height: 768 }, hasTouch: true });

//  A finger drag from (x, y) to (x + dx, y + dy), sent as touch input
//  (Chromium's DevTools protocol: a touch, not a mouse, event stream).
async function fingerDrag(page: any, x: number, y: number, dx: number, dy: number) {
    const cdp = await page.context().newCDPSession(page);
    const point = (px: number, py: number) => [{ x: px, y: py, id: 1 }];
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: point(x, y) });
    for (let i = 1; i <= 5; i++) {
        await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: point(x + dx * i / 5, y + dy * i / 5) });
    }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}

async function centre(page: any, selector: string) {
    const box = (await page.locator(selector).boundingBox())!;
    return { x: box.x + box.width / 2, y: box.y + box.height / 2 };
}

test.describe('Splitters on a touch screen', () => {
    test.beforeEach(async ({ page }) => {
        await page.goto('index.html?example=citizenship');
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
    });

    test('a finger drags the splitter under the program', async ({ page }) => {
        const before = await page.locator('#bottom-panel').evaluate((e: HTMLElement) => e.getBoundingClientRect().height);
        const c = await centre(page, '#resizer');
        await fingerDrag(page, c.x, c.y, 0, -120);
        const after = await page.locator('#bottom-panel').evaluate((e: HTMLElement) => e.getBoundingClientRect().height);
        expect(after - before).toBeGreaterThan(100);
    });

    test('a finger drags the splitter between the answers and the explanation', async ({ page }) => {
        const before = await page.locator('#answers-panel').evaluate((e: HTMLElement) => e.getBoundingClientRect().width);
        const c = await centre(page, '#results-resizer');
        await fingerDrag(page, c.x, c.y, 150, 0);
        const after = await page.locator('#answers-panel').evaluate((e: HTMLElement) => e.getBoundingClientRect().width);
        expect(after - before).toBeGreaterThan(100);
    });

    test('the mouse still drags the splitter under the program', async ({ page }) => {
        const before = await page.locator('#bottom-panel').evaluate((e: HTMLElement) => e.getBoundingClientRect().height);
        const c = await centre(page, '#resizer');
        await page.mouse.move(c.x, c.y);
        await page.mouse.down();
        await page.mouse.move(c.x, c.y - 120, { steps: 5 });
        await page.mouse.up();
        const after = await page.locator('#bottom-panel').evaluate((e: HTMLElement) => e.getBoundingClientRect().height);
        expect(after - before).toBeGreaterThan(100);
    });
});
