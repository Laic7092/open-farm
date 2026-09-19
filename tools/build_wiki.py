#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""tools/build_wiki.py — 把导出的数据渲染成静态 HTML wiki，用于审阅游戏内容。

数据来源是 [code]tools/wiki_dump.tscn[/code] 导出的 [code].tmp/wiki/data.json[/code]
（引擎侧保证引用已解析、切图常量已对齐），本脚本只做三件事：
[br]1. 读取 data.json + [code]assets/i18n/*.csv[/code]
[br]2. 把用到的贴图复制进 [code].tmp/wiki/sprites/[/code]
[br]3. 输出单页 [code].tmp/wiki/index.html[/code]（内联 CSS/JS，浏览器直接打开）

用法：
  python3 tools/build_wiki.py              # 生成后打印路径
  python3 tools/build_wiki.py --open       # 顺手用浏览器打开
  python3 tools/build_wiki.py --serve 8000 # 起一个本地静态服务
"""
from __future__ import annotations

import argparse
import os
import sys
import webbrowser

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "wiki"))

import render  # noqa: E402
from content import KINDS, Context, REF_FIELDS, REF_LIST_FIELDS, esc  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSS = """
:root{--bg:#12141a;--panel:#1c1f28;--panel2:#232733;--line:#2f3542;--fg:#e6e9f0;
--dim:#8a93a6;--accent:#ffd166;--good:#7ddc9b;--bad:#ff7b7b;--link:#8fd3ff}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:13px/1.6 "Segoe UI",system-ui,"Microsoft YaHei",sans-serif}
a{color:var(--link);text-decoration:none}a:hover{text-decoration:underline}
.layout{display:grid;grid-template-columns:230px 1fr;min-height:100vh}
nav{position:sticky;top:0;height:100vh;overflow:auto;padding:16px;background:var(--panel);border-right:1px solid var(--line)}
nav h1{font-size:15px;margin:0 0 4px}nav .ver{color:var(--dim);font-size:11px;margin-bottom:10px}
nav input{width:100%;padding:6px 8px;margin-bottom:10px;background:var(--panel2);border:1px solid var(--line);color:var(--fg);border-radius:4px}
nav ol{list-style:none;margin:0;padding:0}nav li a{display:flex;justify-content:space-between;padding:3px 6px;border-radius:4px;color:var(--fg)}
nav li a:hover{background:var(--panel2);text-decoration:none}
nav .count{color:var(--dim);font-size:11px}
main{padding:20px 28px;max-width:1400px}
section{margin-bottom:34px}section h2{font-size:18px;border-bottom:1px solid var(--line);padding-bottom:6px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:12px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:12px;overflow:hidden}
.card-head{display:flex;gap:10px;align-items:center;margin-bottom:8px}
.card-head h3{margin:0;font-size:14px}.cid{color:var(--dim);font-weight:400;font-size:11px}
.kindtag{color:var(--dim);font-size:11px}
.thumb,.icon{image-rendering:pixelated;vertical-align:middle;background:#0c0d11;border-radius:3px}
table.fields{width:100%;border-collapse:collapse;margin:4px 0}
table.fields th{text-align:left;color:var(--dim);font-weight:400;width:34%;vertical-align:top;padding:2px 6px 2px 0}
table.fields td{padding:2px 0;vertical-align:top}
table.fields.nested{background:var(--panel2);border-radius:4px;padding:2px 6px;margin:2px 0}
details.more{margin-top:6px}details.more summary{cursor:pointer;color:var(--dim);font-size:12px}
.block{margin:8px 0;padding:8px;background:var(--panel2);border-radius:5px}
.block h4{margin:0 0 6px;font-size:12px;color:var(--accent)}
.frames{display:flex;flex-wrap:wrap;gap:8px;margin:6px 0}
.frame{margin:0;text-align:center}.frame figcaption{font-size:10px;color:var(--dim)}
.sheet{display:inline-block;image-rendering:pixelated;background-image:var(--img);background-repeat:no-repeat;
width:calc(var(--cw)*var(--scale));height:calc(var(--ch)*var(--scale));
background-size:calc(var(--sw)*var(--scale)) calc(var(--sh)*var(--scale));
background-position:calc(var(--x)*var(--scale)*-1) calc(var(--y)*var(--scale)*-1)}
.chip{display:inline-block;background:var(--panel2);border:1px solid var(--line);border-radius:10px;padding:0 7px;margin:1px 2px 1px 0;font-size:12px}
.chip .cid{font-size:10px;margin-left:5px}
.badge{display:inline-block;background:#2b3140;border-radius:4px;padding:0 6px;margin:1px 2px 1px 0;font-size:12px}
.flag{font-family:ui-monospace,monospace;font-size:11px;background:#2b3140;border-radius:3px;padding:0 4px}
.money{color:var(--accent)}.time{font-family:ui-monospace,monospace}
.dim{color:var(--dim)}.en{color:var(--dim);font-size:11px}
.bad{color:var(--bad)}.yes{color:var(--good)}.no{color:var(--bad)}
.refs{margin-top:8px;padding-top:6px;border-top:1px solid var(--line);color:var(--dim);font-size:11px}
.dialogue .line{padding:4px 0;border-bottom:1px dashed var(--line)}
.dialogue .idx,.dialogue .speaker{font-size:11px;color:var(--accent);margin-right:6px}
.dialogue .text{margin:2px 0 2px 24px}
.choices{margin:2px 0 2px 40px;padding:0 0 0 14px}.choices li{margin:2px 0}
.overview table{border-collapse:collapse}.overview td,.overview th{padding:3px 12px 3px 0;text-align:left;border-bottom:1px solid var(--line)}
.wall{display:grid;grid-template-columns:repeat(auto-fill,minmax(110px,1fr));gap:8px}
.wall figure{margin:0;background:var(--panel);border:1px solid var(--line);border-radius:5px;padding:6px;text-align:center}
.wall img{image-rendering:pixelated;max-width:100%;background:#0c0d11}
.wall figcaption{font-size:10px;color:var(--dim);word-break:break-all}
.badges{display:flex;gap:14px;flex-wrap:wrap;margin:8px 0}
.badges div{background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:6px 12px}
.badges b{color:var(--accent);font-size:18px}
.sec.hidden,.card.hidden{display:none}
"""

JS = """
const q=document.getElementById('q');
q.addEventListener('input',()=>{const t=q.value.trim().toLowerCase();
 const show=el=>el.classList.toggle('hidden',!!t&&!el.textContent.toLowerCase().includes(t));
 document.querySelectorAll('article.card, tr.i18n-row').forEach(show);
 for(const s of document.querySelectorAll('section.sec')){
   const n=s.querySelectorAll('article.card:not(.hidden), tr.i18n-row:not(.hidden)').length;
   s.classList.toggle('hidden',!!t&&n===0);}
});
document.addEventListener('keydown',e=>{if(e.key==='/'&&document.activeElement!==q){e.preventDefault();q.focus();}});
"""


def overview(ctx: Context) -> str:
    counts = "".join(
        f'<tr><td><a href="#{ctx.slug(kind)}">{ctx.label(kind)}</a></td>'
        f'<td>{len(ctx.items(kind))}</td></tr>'
        for kind in KINDS
    )
    problems = problems_of(ctx)
    listing = (
        "<ul>" + "".join(f"<li class='bad'>{esc(p)}</li>" for p in problems) + "</ul>"
        if problems else '<span class="yes">validate_all() 与引用检查全部通过</span>'
    )
    return (
        '<section id="overview" class="sec overview"><h2>概览</h2>'
        f'<div class="badges"><div><b>{sum(len(ctx.items(k)) for k in KINDS)}</b> 条静态数据</div>'
        f'<div><b>{len(ctx.i18n)}</b> 条文案</div>'
        f'<div><b>{len(problems)}</b> 个待查</div></div>'
        f'<table><tr><th>分类</th><th>数量</th></tr>{counts}</table>'
        f'<div class="block"><h4>数据体检</h4>{listing}</div>'
        "</section>"
    )


def problems_of(ctx: Context) -> list[str]:
    """引擎自检 + 缺译 + 悬空引用；空列表表示干净。"""
    found: list[str] = [f'validate: {p}' for p in ctx.validation]
    for kind, bucket in ctx.resources.items():
        for rid, res in bucket.items():
            for field, value in res.items():
                if field.endswith("_key") and value and value not in ctx.i18n:
                    found.append(f'{ctx.label(kind)} {rid} 的 {field} 缺译：{value}')
            for field, target in REF_FIELDS.items():
                if res.get(field) and ctx.get(target, res[field]) is None:
                    found.append(f'{ctx.label(kind)} {rid} 的 {field} 悬空：{res[field]}')
            for field, target in REF_LIST_FIELDS.items():
                for item in res.get(field) or []:
                    if ctx.get(target, item) is None:
                        found.append(f'{ctx.label(kind)} {rid} 的 {field} 悬空：{item}')
            for field, value in res.items():
                if isinstance(value, dict) and "$ref" in value and ctx.get(value["$ref"], value["id"]) is None:
                    found.append(f'{ctx.label(kind)} {rid} 的 {field} 悬空：{value["id"]}')
    return found


def i18n_section(ctx: Context) -> str:
    used: dict[str, set[str]] = {}
    for kind, bucket in ctx.resources.items():
        for rid, res in bucket.items():
            for field, value in res.items():
                if field.endswith("_key") and isinstance(value, str) and value:
                    used.setdefault(value, set()).add((kind, rid))
    rows = []
    for key, entry in sorted(ctx.i18n.items(), key=lambda kv: (kv[1]["src"], kv[0])):
        who = used.get(key)
        refs = (
            " ".join(
                f'<a class="chip ref" href="{ctx.url(k, r)}">{esc(ctx.label(k))}·{esc(r)}</a>'
                for k, r in sorted(who)[:4]
            )
            if who else '<span class="dim">未见数据引用</span>'
        )
        if len(who or []) > 4:
            refs += f' <span class="dim">+{len(who) - 4}</span>'
        en = esc(entry["en"]) if entry["en"] else '<span class="bad">缺英文</span>'
        zh = esc(entry["zh"]) if entry["zh"] else '<span class="bad">缺中文</span>'
        rows.append(
            f'<tr class="i18n-row"><td><span class="flag">{esc(key)}</span></td><td>{zh}</td><td>{en}</td>'
            f'<td class="dim">{esc(entry["src"])}</td><td>{refs}</td></tr>'
        )
    return (
        '<section id="i18n" class="sec"><h2>文案 <span class="count">%d</span></h2>'
        '<table class="fields"><tr><th>键</th><th>中文</th><th>English</th><th>来源</th><th>数据引用</th></tr>'
        '%s</table></section>' % (len(ctx.i18n), "".join(rows))
    )


def sprites_section(ctx: Context) -> str:
    base = os.path.join(ctx.assets.root, "assets", "sprites")
    groups: dict[str, list[str]] = {}
    for current, _dirs, files in os.walk(base):
        for name in sorted(files):
            if name.endswith(".png"):
                rel = os.path.relpath(os.path.join(current, name), base).replace(os.sep, "/")
                groups.setdefault(os.path.dirname(rel) or ".", []).append(rel)
    if not groups:
        return ""
    blocks = []
    for directory in sorted(groups):
        figures = []
        for rel in groups[directory]:
            url = ctx.assets.url("res://assets/sprites/" + rel)
            figures.append(
                f'<figure><img src="{url}"><figcaption>{esc(rel)}</figcaption></figure>'
            )
        blocks.append(f'<div class="block"><h4>{esc(directory)} <span class="dim">{len(groups[directory])}</span></h4>'
                      f'<div class="wall">{"".join(figures)}</div></div>')
    return f'<section id="sprites" class="sec"><h2>图片墙</h2>{"".join(blocks)}</section>'


def build(root: str, out_dir: str) -> tuple[str, list[str]]:
    ctx = Context(root, out_dir)
    sections = [overview(ctx)]
    sections += [render.section(ctx, kind) for kind in KINDS]
    sections += [i18n_section(ctx), sprites_section(ctx)]
    nav = "".join(
        f'<li><a href="#{ctx.slug(kind)}">{ctx.label(kind)}<span class="count">{len(ctx.items(kind))}</span></a></li>'
        for kind in KINDS
    )
    page = (
        "<!doctype html><html lang=\"zh-CN\"><head><meta charset=\"utf-8\">"
        f"<title>open-farm wiki v{esc(ctx.version)}</title><style>{CSS}</style></head><body>"
        '<div class="layout"><nav><h1>open-farm wiki</h1>'
        f'<div class="ver">v{esc(ctx.version)} · {sum(len(ctx.items(k)) for k in KINDS)} 条数据</div>'
        '<input id="q" placeholder="搜索（/ 聚焦）">'
        f'<ol><li><a href="#overview">概览</a></li>{nav}'
        '<li><a href="#i18n">文案</a></li><li><a href="#sprites">图片墙</a></li></ol></nav>'
        f'<main>{"".join(sections)}</main></div><script>{JS}</script></body></html>'
    )
    path = os.path.join(out_dir, "index.html")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(page)
    return path, problems_of(ctx)


def main() -> int:
    parser = argparse.ArgumentParser(description="生成 open-farm 内容 wiki（静态 HTML）")
    parser.add_argument("--root", default=ROOT, help="仓库根目录")
    parser.add_argument("--out", default=os.path.join(ROOT, ".tmp", "wiki"), help="输出目录")
    parser.add_argument("--open", action="store_true", help="生成后用浏览器打开")
    parser.add_argument("--strict", action="store_true", help="有缺译 / 悬空引用时以非零码退出")
    parser.add_argument("--serve", type=int, metavar="PORT", help="生成后起本地静态服务")
    args = parser.parse_args()

    path, problems = build(args.root, args.out)
    print(f"wiki 已生成：{path}（{len(problems)} 个待查）")
    for problem in problems:
        print(f"  ! {problem}")
    if args.open:
        webbrowser.open("file://" + path)
    if args.serve:
        import functools
        import http.server

        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=args.out)
        print(f"服务地址：http://localhost:{args.serve}/")
        http.server.ThreadingHTTPServer(("127.0.0.1", args.serve), handler).serve_forever()
    return 1 if problems and args.strict else 0


if __name__ == "__main__":
    raise SystemExit(main())
