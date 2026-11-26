import { test, expect } from '@playwright/test';

// The LOMO door (migration/lomo/): File > Open of a LOMO description in
// Turtle opens its register (one fact for each statement), and File > Export
// to Another System > LOMO writes the register back as Turtle.

const editorText = (page: any) => page.evaluate(() => {
    const ms = (window as any).monaco?.editor?.getModels?.() || [];
    return ms.map((m: any) => m.getValue()).join('\n=====\n');
});

async function openFile(page: any, name: string, content: string) {
    await page.evaluate(() => { delete (window as any).showOpenFilePicker; });
    const [chooser] = await Promise.all([
        page.waitForEvent('filechooser'),
        page.evaluate(() => (document.getElementById('menu-open') as HTMLElement).click()),
    ]);
    await chooser.setFiles({ name, mimeType: 'text/plain', buffer: Buffer.from(content) });
}

async function signIn(page: any) {
    await page.request.post('/login', { form: {
        email: 'support@logicalcontracts.com', password: 'LE2rocks', return: '/' } });
}

const TTL = `@prefix ex: <http://example.org/e2e#> .
@prefix lomo: <http://data.europa.eu/leg/lomo#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

ex:Norm_Report a lomo:SubstantiveRule ;
    rdfs:label "Report every year"@en ;
    lomo:hasDeonticModality <http://data.europa.eu/leg/deontic-modality/Obligation> ;
    lomo:establishedIn <http://data.europa.eu/eli/reg/2016/679/art_33/par_1/oj> ;
    lomo:produces ex:SendReport .
ex:SendReport a lomo:Action ;
    rdfs:label "send the report"@en ;
    lomo:hasAgentRole ex:Role_Sender ;
    lomo:atTime [ a lomo:TemporalSpecification ;
        lomo:hasFunction <http://data.europa.eu/leg/temporal-function/deadline> ;
        lomo:frequency "P1Y"^^xsd:duration ] .
ex:Role_Sender a lomo:AgentRole ;
    lomo:forAgent ex:MemberStates ;
    lomo:withRole <http://publications.europa.eu/resource/authority/role/ADDRESSER> .
ex:MemberStates a lomo:AgentType ; rdfs:label "Member States"@en .
`;

test.describe('LOMO descriptions', () => {
    test('a description opens as its register, and goes back to Turtle', async ({ page }) => {
        await signIn(page);
        const formats = await (await page.request.post('/leapi', {
            data: { token: 'myToken123', operation: 'importFormats' } })).json();
        test.skip(!(formats.formats || []).some((f: any) => f.id === 'lomo'),
                  'no LOMO translator on this server (no migration/ folder)');
        await page.goto('index.html');
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        await openFile(page, 'report.ttl', TTL);
        await expect.poll(() => editorText(page), { timeout: 60000 }).toContain('norm report has the modality obligation');
        const text = await editorText(page);
        expect(text).toContain('norm report is established in "http://data.europa.eu/eli/reg/2016/679/art_33/par_1/oj"');
        expect(text).toContain('send report has the time specification send report time');
        expect(text).toContain('query obligations is:');
        await page.locator('#import-report span').click();
        await page.evaluate(() => (document.getElementById('menu-export') as HTMLElement).click());
        await expect(page.locator('#export-list, #export-result').first()).toBeVisible({ timeout: 60000 });
        if (await page.locator('#export-list').count()) {
            await page.locator('#export-list div', { hasText: /^LOMO description/ }).click();
        }
        await expect(page.locator('#export-result')).toBeVisible({ timeout: 60000 });
        await expect(page.locator('#export-text')).toContainText('lomo:SubstantiveRule');
        await expect(page.locator('#export-text')).toContainText('"P1Y"^^<http://www.w3.org/2001/XMLSchema#duration>');
    });
});
