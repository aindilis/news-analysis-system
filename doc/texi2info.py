#!/usr/bin/env python3
"""Minimal Texinfo-to-Info converter for doc/news-analysis.texi.

makeinfo is the real tool; use it when available:
    makeinfo news-analysis.texi
This script handles only the subset that tutorial uses, so the .info
can be built where Texinfo is not installed.
Usage: python3 texi2info.py IN.texi OUT.info
"""
import re
import sys
import textwrap

WIDTH = 72


def inline(s):
    s = s.replace('@@', '\x00AT\x00')
    s = s.replace('@dots{}', '...').replace('@copyright{}', '(C)')
    rules = {
        'code': lambda x: "'" + x + "'", 'samp': lambda x: "'" + x + "'",
        'option': lambda x: "'" + x + "'", 'env': lambda x: "'" + x + "'",
        'file': lambda x: "'" + x + "'", 'command': lambda x: "'" + x + "'",
        'kbd': lambda x: "'" + x + "'", 'var': lambda x: x.upper(),
        'emph': lambda x: '_' + x + '_', 'strong': lambda x: '*' + x + '*',
        'dfn': lambda x: '"' + x + '"', 'url': lambda x: '<' + x + '>',
        'xref': lambda x: '*Note ' + x + '::', 'pxref': lambda x: '*note ' + x + '::',
    }
    pat = re.compile(r'@(\w+)\{([^{}]*)\}')
    while True:
        m = pat.search(s)
        if not m:
            break
        cmd, arg = m.group(1), m.group(2)
        if cmd not in rules:
            raise SystemExit(f'unsupported inline command @{cmd}')
        s = s[:m.start()] + rules[cmd](arg) + s[m.end():]
    s = s.replace('``', '"').replace("''", '"')
    s = s.replace('\x00AT\x00', '@')
    if '@' in s:
        raise SystemExit(f'unconverted @ in: {s!r}')
    return s


def fill(text, indent, first=None):
    first = indent if first is None else first
    w = textwrap.TextWrapper(width=WIDTH, initial_indent=first,
                             subsequent_indent=indent,
                             break_long_words=False, break_on_hyphens=False)
    return w.fill(inline(' '.join(text.split())))


def parse(lines):
    """Split into header info and a list of nodes: (name, [body lines])."""
    nodes, cur, direntry, skip = [], None, [], None
    for raw in lines:
        line = raw.rstrip('\n')
        if skip:
            if line.strip() == '@end ' + skip:
                skip = None
            elif skip == 'direntry':
                direntry.append(line)
            continue
        if line.startswith(('\\input', '@setfilename', '@settitle',
                            '@dircategory', '@bye')):
            continue
        m = re.match(r'@(copying|titlepage|direntry)\s*$', line)
        if m:
            skip = m.group(1)
            continue
        if line.startswith('@node '):
            cur = [line[6:].strip(), []]
            nodes.append(cur)
            continue
        if cur is not None:
            cur[1].append(line)
    return direntry, nodes


def render_body(body, chap_no, out):
    para, stack, sec_no = [], [], 0   # stack of (kind, counter, indent)
    in_example, in_menu = False, False

    def indent():
        return ' ' * sum(i for _, _, i in stack)

    def flush():
        if para:
            out.append(fill(' '.join(para), indent()))
            out.append('')
            para.clear()

    for line in body:
        s = line.strip()
        if in_example:
            if s == '@end example':
                in_example = False
                out.append('')
            else:
                out.append(indent() + '     ' + inline(line) if line else '')
            continue
        if in_menu:
            if s == '@end menu':
                in_menu = False
                out.append('')
            elif s.startswith('* '):
                m = re.match(r'\* (.+?)::\s*(.*)', s)
                name, desc = m.group(1), m.group(2)
                out.append(f'* {name + "::":<22}{desc}')
            continue
        if s == '@example':
            flush(); in_example = True; continue
        if s == '@menu':
            flush(); in_menu = True; out.append('* Menu:'); out.append(''); continue
        m = re.match(r'@(top|chapter|section)\s+(.*)', s)
        if m:
            flush()
            kind, title = m.group(1), inline(m.group(2))
            if kind == 'top':
                head, ch = title, '*'
            elif kind == 'chapter':
                head, ch = f'{chap_no} {title}', '*'
            else:
                sec_no += 1
                head, ch = f'{chap_no}.{sec_no} {title}', '='
            out.extend([head, ch * len(head), ''])
            continue
        m = re.match(r'@(itemize|enumerate|table)\b\s*(.*)', s)
        if m:
            flush()
            stack.append((m.group(1) if m.group(1) != 'table' else 'table:' + m.group(2), 0, 0))
            continue
        if s in ('@end itemize', '@end enumerate', '@end table'):
            flush(); stack.pop(); continue
        if s.startswith('@item'):
            flush()
            kind, n, _ = stack[-1]
            base = ' ' * sum(i for _, _, i in stack[:-1])
            if kind == 'itemize':
                stack[-1] = (kind, n, 5)
                para.append('\x01BULLET\x01')
            elif kind == 'enumerate':
                stack[-1] = (kind, n + 1, 5)
                para.append(f'\x01NUM{n + 1}\x01')
            else:
                term = s[5:].strip()
                fmt = kind.split(':', 1)[1].strip()
                t = inline(term)
                if fmt == '@code':
                    t = "'" + t + "'"
                stack[-1] = (kind, n, 5)
                out.append(base + t)
            continue
        if s == '':
            flush(); continue
        para.append(s)
        if len(para) == 2 and para[0].startswith('\x01'):
            pass
    flush()


def fix_markers(out):
    """Replace list markers placed at the start of a filled paragraph."""
    res = []
    for block in out:
        m = re.match(r'^(\s*)\x01(BULLET|NUM(\d+))\x01 ?(.*)$', block, re.S)
        if m:
            ind = m.group(1)                     # already includes +5
            base = ind[:-5]
            lead = (base + '   * ') if m.group(2) == 'BULLET' else (base + f'  {m.group(3)}. ')
            text = m.group(4)
            block = textwrap.TextWrapper(width=WIDTH, initial_indent=lead,
                                         subsequent_indent=ind,
                                         break_long_words=False,
                                         break_on_hyphens=False).fill(' '.join(text.split()))
        res.append(block)
    return res


def main(src, dst):
    direntry, nodes = parse(open(src, encoding='ascii').readlines())
    names = [n for n, _ in nodes]
    fname = dst.rsplit('/', 1)[-1]
    header = [f'This is {fname}, produced by texi2info.py from news-analysis.texi.', '',
              'INFO-DIR-SECTION Science', 'START-INFO-DIR-ENTRY']
    header += [d for d in direntry if d.strip()] + ['END-INFO-DIR-ENTRY', '']
    text = '\n'.join(header) + '\n'
    tags = []
    chap = 0
    for i, (name, body) in enumerate(nodes):
        if name == 'Top':
            nav = f'Node: Top,  Next: {names[1]},  Up: (dir)'
        else:
            chap += 1
            prev = names[i - 1]
            nxt = names[i + 1] if i + 1 < len(names) else None
            nav = f'Node: {name},  ' + (f'Next: {nxt},  ' if nxt else '') + f'Prev: {prev},  Up: Top'
        out = []
        render_body(body, chap, out)
        out = fix_markers(out)
        tags.append((name, len(text.encode('ascii'))))
        text += '\x1f\n' + f'File: {fname},  {nav}\n\n' + '\n'.join(out).rstrip() + '\n\n'
    text += '\x1f\nTag Table:\n' + ''.join(f'Node: {n}\x7f{o}\n' for n, o in tags) + '\x1f\nEnd Tag Table\n'
    open(dst, 'w', encoding='ascii').write(text)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
