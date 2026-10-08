import { test, expect } from '@playwright/test';

// Smoke tests for the LE Contract Assistant web app (web_extras/contract_assistant).
// A job started with a nonexistent model fails in seconds but still emits log
// lines, stage changes and a config summary — enough to exercise the whole
// Run-screen poll loop without any LLM.

const TOKEN = 'myToken123';

<<<<<<< HEAD
=======
// The Contract Assistant belongs to the licence "Logical English Translators"
// (lpsPlus accounts/, capability contract_assistant): the tests sign in first,
// with the account the auth tests use. page.request shares the page's cookies.
async function signIn(page: any) {
    await page.request.post('/login', { form: {
        email: 'support@logicalcontracts.com', password: 'LE2rocks', return: '/' } });
}

>>>>>>> 92331814ad247a300fe820fd74fe6908f2b1611f
async function startFailingJob(request: any): Promise<string> {
    const resp = await request.post('/leapi', {
        data: {
            token: TOKEN,
            operation: 'contract_start',
            wording: { name: 'c.md', text: '# Tiny\n\nA tiny contract.\n' },
            model: 'nonexistent-model',
            budget: { preset: 'draft', minutes: 1 }
        }
    });
    const data = await resp.json();
    expect(data.job).toBeTruthy();
    return data.job;
}

<<<<<<< HEAD
test.describe('Contract Assistant UI', () => {
=======
// The Contract Assistant lives in the private lpsPlus repository: on an
// installation without it, the operations answer `not_installed` and these
// tests do not apply.
async function installed(request: any): Promise<boolean> {
    const data = await (await request.post('/leapi', {
        data: { token: TOKEN, operation: 'contract_status', job: 'caj_none' } })).json();
    return !data.not_installed;
}

test.beforeEach(async ({ request }) => {
    test.skip(!(await installed(request)), 'the Contract Assistant (lpsPlus) is not installed here');
});

test.describe('Contract Assistant licence', () => {
    test('an anonymous visitor is refused, and told which licence', async ({ page, request }) => {
        const data = await (await request.post('/leapi', {
            data: { token: TOKEN, operation: 'contract_status', job: 'caj_none' } })).json();
        expect(data.unlicensed).toBe(true);
        expect(data.error).toContain('Logical English Translators');
        await page.goto('/web_extras/contract_assistant/index.html');
        await expect(page.locator('h1')).toContainText('LE Contract Assistant');
        await expect(page.locator('body')).toContainText('Logical English Translators');
        await expect(page.locator('a[href^="/login?return="]')).toBeVisible();
    });
});

test.describe('Contract Assistant UI', () => {
    test.beforeEach(async ({ page }) => { await signIn(page); });

    test('a web address can stand for the wording, and a second model for branches', async ({ page }) => {
        await page.goto('/web_extras/contract_assistant/index.html');
        await expect(async () => {
            expect(await page.locator('#branch-model option').count()).toBeGreaterThan(1);
        }).toPass({ timeout: 15000 });
        await expect(page.locator('#btn-start')).toBeDisabled();
        await page.locator('#wording-url').fill('https://example.org/policy.pdf');
        await expect(page.locator('#btn-start')).toBeEnabled();
    });
>>>>>>> 92331814ad247a300fe820fd74fe6908f2b1611f
    test('setup screen loads with models and uploads', async ({ page }) => {
        await page.goto('/web_extras/contract_assistant/index.html');
        await expect(page.locator('#file-wording')).toBeAttached();
        // The model picker fills from list_models.
        await expect(async () => {
            expect(await page.locator('#model option').count()).toBeGreaterThan(0);
        }).toPass({ timeout: 15000 });
        // Start stays disabled until a wording file is chosen.
        await expect(page.locator('#btn-start')).toBeDisabled();
    });

    // The optional "Existing LE code" box (group 2) counts what was pasted and
    // triggers a cost estimate; the cost line lives with the effort budget.
    test('existing LE code box and cost estimate render', async ({ page }) => {
        await page.goto('/web_extras/contract_assistant/index.html');
        const area = page.locator('#existing-code');
        await expect(area).toBeVisible();
        await expect(page.locator('#existing-note')).toHaveText('');
        await area.fill('the templates are:\n    *a person* is happy.\n% a comment line\n');
        await expect(page.locator('#existing-note')).toContainText('2 significant line(s)');

        // The cost line is present and says something (an unpriced model or a
        // price table that could not be fetched still produces a message).
        await expect(page.locator('#cost')).toBeVisible();
        await expect(page.locator('#cost-value')).not.toBeEmpty();
    });

    // Regression: the Run screen must keep showing the scrolling log, the elapsed
    // time and the choices summary on every poll (a title rewrite once destroyed
    // the elapsed span, and the resulting render error killed the log updates).
<<<<<<< HEAD
    test('run screen shows log, elapsed time and config summary', async ({ page, request }) => {
        test.setTimeout(60000);
        const job = await startFailingJob(request);
=======
    test('run screen shows log, elapsed time and config summary', async ({ page }) => {
        test.setTimeout(60000);
        const job = await startFailingJob(page.request);
>>>>>>> 92331814ad247a300fe820fd74fe6908f2b1611f
        // Reattach by URL hash, as a reloaded tab would.
        await page.goto('/web_extras/contract_assistant/index.html#' + job);

        // The log accumulates lines (stage headers at minimum).
        await expect(page.locator('#log')).toContainText('Stage', { timeout: 20000 });
        // The choices summary and the elapsed clock render.
        await expect(page.locator('#run-summary')).toContainText('nonexistent-model');
        await expect(page.locator('#run-summary')).toContainText('K=1 W=1');
        await expect(page.locator('#run-elapsed')).toContainText('elapsed');

        // The job fails fast (unknown model): terminal state disables Cancel and
        // offers the way back.
        await expect(page.locator('#run-title-text')).toHaveText('Failed', { timeout: 30000 });
        await expect(page.locator('#log')).toContainText('Job failed');
        await expect(page.locator('#btn-cancel')).toBeDisabled();
        await expect(page.locator('#btn-run-back')).toBeVisible();

        // ... and the log survived the terminal transition (regression guard).
        await expect(page.locator('#log')).toContainText('Vocabulary sample');
    });

    // A job outlives the tab that started it, so the Setup screen lists the
    // jobs this browser started: closing the window must not lose a run.
<<<<<<< HEAD
    test('recent runs list recovers a job after the tab is closed', async ({ page, request }) => {
        test.setTimeout(60000);
        const job = await startFailingJob(request);
=======
    test('recent runs list recovers a job after the tab is closed', async ({ page }) => {
        test.setTimeout(60000);
        const job = await startFailingJob(page.request);
>>>>>>> 92331814ad247a300fe820fd74fe6908f2b1611f
        await page.goto('/web_extras/contract_assistant/index.html#' + job);
        await expect(page.locator('#run-title-text')).toHaveText('Failed', { timeout: 30000 });

        // Back to Setup: the job is listed with its state.
        await page.locator('#btn-run-back').click();
        const row = page.locator('.recent-row').first();
        await expect(page.locator('#recent-card')).toBeVisible();
        await expect(row).toContainText('failed');

        // A brand-new page load (no hash — the tab was closed) still lists it,
        // and opening it from there reattaches to the same job.
        await page.goto('/web_extras/contract_assistant/index.html');
        await expect(page.locator('#recent-card')).toBeVisible();
        await page.locator('.recent-row .recent-open').first().click();
        await expect(page).toHaveURL(new RegExp('#' + job + '$'));
        await expect(page.locator('#log')).toContainText('Stage', { timeout: 20000 });

        // Forget removes it from the list (the list is this browser's only).
        await page.locator('#btn-run-back').click();
        await page.locator('.recent-row .recent-forget').first().click();
        await expect(page.locator('#recent-card')).toBeHidden();
    });
});
