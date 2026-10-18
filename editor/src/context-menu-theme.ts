/*
 * context-menu-theme.ts — the editor's context menu keeps its colours on iOS.
 *
 * Monaco draws its context menu in a shadow DOM inside the editor, except on
 * iOS, where it does not (Monaco issue #122035) and appends the menu to the
 * page's <body> instead. The menu takes its background and text colours from
 * CSS variables (`--vscode-menu-background`, …) that the theme defines only on
 * `.monaco-editor, .monaco-diff-editor, .monaco-component`. Under <body> the
 * menu is inside none of them, so on an iPad it showed with no background,
 * its items mixed with the text being edited.
 *
 * The fix: every context view Monaco puts outside an editor gets the class
 * `monaco-component`, which brings it the theme's variables (and follows a
 * change of theme, since the variables stay the theme's). Nothing changes
 * where the menu is drawn inside the editor.
 */

let installed = false;

function tag(el: Element): void {
    if (el.classList.contains('context-view') && !el.closest('.monaco-editor, .monaco-diff-editor, .monaco-component')) {
        el.classList.add('monaco-component');
    }
}

export function installContextMenuTheme(): void {
    if (installed || typeof document === 'undefined' || !document.body) return;
    installed = true;
    document.querySelectorAll('.context-view').forEach(tag);
    new MutationObserver((mutations) => {
        for (const m of mutations) {
            m.addedNodes.forEach((n) => {
                if (!(n instanceof Element)) return;
                tag(n);
                n.querySelectorAll('.context-view').forEach(tag);
            });
        }
    }).observe(document.body, { childList: true, subtree: true });
}
