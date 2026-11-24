"""The example policies of the Miniscript page, as plain text: the title of
each demo link of the page, followed by the policy that the link loads.

The page states no licence, so only these short lines are kept in the
repository, as quotations with attribution; the page itself is not. To run
this script, save https://bitcoin.sipa.be/miniscript/ and give the file as
the argument (fetch it into ../.cache/, which git ignores):

    python3 extract_sipa.py ../.cache/sipa_miniscript.html > sipa_miniscript.txt
"""
import re, sys
from html.parser import HTMLParser

BLOCK = {'p', 'ul', 'li', 'div', 'h3', 'h4', 'form', 'label', 'textarea', 'br', 'small', 'button'}

class X(HTMLParser):
    def __init__(self):
        super().__init__()
        self.out = []      # finished lines
        self.cur = []      # current block's text
        self.prefix = ''
        self.skip = 0
        self.link = None
    def flush(self):
        t = re.sub(r'\s+', ' ', ''.join(self.cur)).strip()
        if t:
            self.out.append(self.prefix + t)
        self.cur = []
        self.prefix = ''
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag in ('script', 'style', 'button'):
            self.skip += 1
            return
        if tag in BLOCK:
            self.flush()
            if tag == 'h3':
                self.out.append('')
            if tag == 'li':
                self.prefix = '- '
            if tag == 'p':
                self.out.append('')
        if tag == 'a':
            href = a.get('href', '')
            m = re.match(r'javascript:load_policy\("(.*)"\)', href)
            self.link = m.group(1) if m else None
            self.url = None if m else href
    def handle_endtag(self, tag):
        if tag in ('script', 'style', 'button'):
            self.skip -= 1
            return
        if tag == 'a' and self.link:
            self.cur.append(': ' + self.link)
            self.link = None
        elif tag == 'a' and getattr(self, 'url', None):
            self.cur.append(' <' + self.url + '>')
            self.url = None
        if tag in BLOCK:
            self.flush()
    def handle_data(self, d):
        if not self.skip:
            self.cur.append(d)

html = open(sys.argv[1], encoding='utf8').read()
start = html.index('<h3 class="card-header">Introduction</h3>')
end = html.index('<h3 class="card-header">Analyze a Miniscript</h3>')
x = X()
x.feed(html[start:end])
x.flush()
lines = []
for l in x.out:
    if l == '' and (not lines or lines[-1] == ''):
        continue
    lines.append(l)
text = '\n'.join(lines).strip() + '\n'
text = text.replace('\nPolicy\nand(pk(A)', '\nPolicy (the input box, pre-filled): and(pk(A)')
text = text.replace('Fill field with:', 'Example policies (the page\'s demo links: each title, then the policy it loads):')
keep = text[text.index('Example policies'):]
hdr = ("Quoted from https://bitcoin.sipa.be/miniscript/ (Pieter Wuille, Andrew Poelstra, Sanket Kanjalkar), retrieved 2026-09-13.\n"
       "The page states no licence: its authors keep all rights. Only the example policies of the page are quoted here,\n"
       "each as the title of the page's example link followed by the policy that the link loads.\n\n")
sys.stdout.write(hdr + keep)
