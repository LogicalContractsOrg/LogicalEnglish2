import { test, expect } from '@playwright/test';

// Misc > Smart editing: off by default (Monaco's own word completion only),
// remembered in localStorage; on, the rest of a sentence from the templates.

const PROG = `the target language is: prolog.
the templates are:
    *a person* is a parent of *a child*.
    *a person* is happy.
the knowledge base t includes:
    a person is happy if the person is a parent of a child.
scenario s is:
    alice is a parent of bob.
query q is:
    which person is happy.`;

async function typeAtEndOfScenario(page: any, text: string) {
    // the end of "    alice is a parent of bob." (line 8), then a new line
    await page.locator('.monaco-editor').first().click();
    await page.keyboard.press('ControlOrMeta+Home');
    for (let i = 0; i < 7; i++) await page.keyboard.press('ArrowDown');
    await page.keyboard.press('End');
    await page.keyboard.press('Enter');
    await page.keyboard.type(text, { delay: 30 });
}

const suggestion = (page: any, text: string) =>
    page.locator('.suggest-widget .monaco-list-row', { hasText: text });

test('Smart editing is off by default, and offers the rest of a sentence when on', async ({ page }) => {
    await page.goto('index.html?text=' + encodeURIComponent(PROG));
    await page.waitForSelector('.monaco-editor');
    await expect(page.locator('#smart-editing-check')).toHaveCSS('visibility', 'hidden');

    await typeAtEndOfScenario(page, 'carol is a pa');
    await page.waitForTimeout(800);
    await expect(suggestion(page, 'is a parent of')).toHaveCount(0);
    await page.keyboard.press('Escape');

    await page.evaluate(() => (document.getElementById('menu-smart-editing') as HTMLElement).click());
    await expect(page.locator('#smart-editing-check')).toHaveCSS('visibility', 'visible');
    expect(await page.evaluate(() => localStorage.getItem('le-smart-editing'))).toBe('true');

    await page.keyboard.type('r', { delay: 30 });
    await expect(suggestion(page, 'is a parent of')).toHaveCount(1);
    await page.keyboard.press('Enter');
    await expect(page.locator('.monaco-editor .view-lines')).toContainText('carol is a parent of a child');
});
