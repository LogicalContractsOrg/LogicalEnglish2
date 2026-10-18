import { test, expect } from '@playwright/test';

// A query stopped by its time limit replies with the answers it found, marked
// `incomplete` (le_api.pl, run_interruptible_query/5): the answers panel shows
// them, says there may be more, and its "Keep going" button asks again with
// twice the time. The first reply is made up here (no program is slow enough
// to be stopped in a test's time); the second is the server's own.

const PROGRAM = `the target language is: prolog.
the templates are:
*a creature* is happy.
the knowledge base h includes:
alice is happy.
bob is happy.
query happy is:
which creature is happy.
`;

test('answers of a stopped query come with Keep going, which asks for more time', async ({ page }) => {
  test.setTimeout(60000);
  const asked: any[] = [];
  await page.route('**/leapi', async (route) => {
    const body = route.request().postDataJSON();
    if (body?.operation !== 'answeringQuery') return route.continue();
    asked.push(body);
    if (asked.length > 1) return route.continue();
    await route.fulfill({
      contentType: 'application/json',
      body: JSON.stringify({
        result: 'ok', timedOut: true, incomplete: true, timeLimit: 240, checklist: [],
        results: [{ answer: 'alice is happy', goal: 'alice is happy', unknowns: [], strongestReason: '', strongestReasonPath: '',
                    why: [{ type: 'success', literal: 'alice is happy', naf: false, children: [] }] }],
      }),
    });
  });

  await page.goto('index.html?text=' + encodeURIComponent(PROGRAM));
  await page.waitForTimeout(800);
  await page.locator('#scenario-select').hover();   // triggers the module load
  await expect.poll(() => page.locator('#query-select option').count(), { timeout: 20000 }).toBeGreaterThan(1);
  await page.selectOption('#query-select', 'happy');
  await page.click('#btn-query');

  const notice = page.locator('#answers-list .answers-incomplete');
  await expect(notice).toContainText('within 240 seconds');
  await expect(page.locator('#answers-list .answer-item')).toHaveCount(1);

  await notice.locator('.btn-keep-going').click();
  await expect.poll(() => asked.length).toBe(2);
  expect(asked[0].timeLimit).toBeUndefined();
  expect(asked[1].timeLimit).toBe(480);
  // the server's own reply: both answers, and no notice
  await expect(page.locator('#answers-list .answer-item')).toHaveCount(2);
  await expect(page.locator('#answers-list .answers-incomplete')).toHaveCount(0);
});
