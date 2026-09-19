#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""tools/build_wiki.py — 把导出的数据渲染成静态 HTML wiki，用于审阅游戏内容。

数据来源是 [code]tools/wiki_dump.tscn[/code] 导出的 [code].tmp/wiki/data.json[/code]
（引擎侧保证引用已解析、切图常量已对齐），本脚本只做三件事：
[br]1. 读取 data.json + [code]assets/i18n/*.csv[/code]
[br]2. 把用到的贴图复制进 [code].tmp/wiki/sprites/[/code]
[br]3. 输出单页 [code].tmp/wiki/index.html[/code]（内联 CSS/JS，浏览器直接打开）

页面围绕「审阅」这条主线组织：
[br]- 概览：先把体检问题顶到最前，再给可点击的分类入口
[br]- 卡片 / 表格两种视图：卡片看单条细节，表格可排序、横向比数值
[br]- 搜索：一个输入框同时过滤卡片、表格、文案与图片墙（[code]/[/code] 聚焦，[code]Esc[/code] 清空）

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
from collections import Counter

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "wiki"))

import render  # noqa: E402
from content import KINDS, Context, REF_FIELDS, REF_LIST_FIELDS, esc  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSS = """
:root{--bg:#12141a;--panel:#1c1f28;--panel2:#232733;--panel3:#2b3140;--line:#2f3542;--fg:#e6e9f0;
--dim:#8a93a6;--accent:#ffd166;--good:#7ddc9b;--bad:#ff7b7b;--link:#8fd3ff}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--fg);font:13px/1.6 "Segoe UI",system-ui,"Microsoft YaHei",sans-serif}
a{color:var(--link);text-decoration:none}a:hover{text-decoration:underline}
code{font-family:ui-monospace,monospace;font-size:.92em}
.layout{display:grid;grid-template-columns:236px minmax(0,1fr);min-height:100vh}
nav{position:sticky;top:0;height:100vh;overflow:auto;padding:14px;background:var(--panel);border-right:1px solid var(--line)}
nav h1{font-size:15px;margin:0 0 4px}
nav .ver{color:var(--dim);font-size:11px;margin-bottom:10px}
.navtoggle{display:none;width:100%;margin-bottom:8px;padding:7px;background:var(--panel2);border:1px solid var(--line);color:var(--fg);border-radius:5px;cursor:pointer}
.navtoggle:hover{border-color:var(--accent)}
.searchbox{position:relative;margin-bottom:4px}
nav input{width:100%;padding:6px 26px 6px 8px;background:var(--panel2);border:1px solid var(--line);color:var(--fg);border-radius:5px}
nav input:focus{outline:none;border-color:var(--accent)}
.searchbox button{position:absolute;right:4px;top:4px;background:none;border:0;color:var(--dim);cursor:pointer;font-size:15px;line-height:1}
.hits{font-size:11px;min-height:16px;margin:2px 0 8px}
nav ol{list-style:none;margin:0;padding:0}
nav li a{display:flex;align-items:center;gap:6px;padding:3px 7px;border-radius:5px;color:var(--fg)}
nav li a:hover{background:var(--panel2);text-decoration:none}
nav li a.active{background:var(--panel3);color:var(--accent);font-weight:600}
nav li a.zero{opacity:.35}
nav .count{margin-left:auto;color:var(--dim);font-size:11px;font-variant-numeric:tabular-nums}
nav .warn{color:var(--bad);font-size:11px;font-weight:600}
nav .navfoot{margin-top:14px;border-top:1px solid var(--line);padding-top:10px;display:grid;gap:6px}
nav button{width:100%;padding:6px;background:var(--panel2);border:1px solid var(--line);color:var(--fg);border-radius:5px;cursor:pointer}
nav button:hover{border-color:var(--accent)}
main{padding:20px 28px 120px;max-width:1500px;min-width:0}
section{margin-bottom:38px;scroll-margin-top:12px}
.sec-head{display:flex;align-items:center;gap:12px;border-bottom:1px solid var(--line);padding-bottom:6px;margin-bottom:12px;position:sticky;top:0;background:var(--bg);z-index:5}
.sec-head h2{font-size:18px;margin:0}
.viewtoggle{margin-left:auto;display:flex;border:1px solid var(--line);border-radius:6px;overflow:hidden}
.viewtoggle button{background:var(--panel);border:0;color:var(--dim);padding:3px 12px;font-size:12px;cursor:pointer}
.viewtoggle button.on{background:var(--panel3);color:var(--accent)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:12px}
.dgroup{margin-bottom:18px}
.dgroup-head{font-size:13px;color:var(--accent);margin:12px 0 8px;border-left:3px solid var(--accent);padding-left:8px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:7px;padding:12px;overflow:hidden;scroll-margin-top:70px}
.card:target,.card.flash{border-color:var(--accent);box-shadow:0 0 0 2px rgba(255,209,102,.25)}
.card-head{display:flex;gap:10px;align-items:center;margin-bottom:8px}
.card-head h3{margin:0;font-size:14px}.cid{color:var(--dim);font-weight:400;font-size:11px}
.kindtag{color:var(--dim);font-size:11px}
.thumb,.icon{image-rendering:pixelated;vertical-align:middle;background:#0c0d11;border-radius:3px}
table.fields{width:100%;border-collapse:collapse;margin:4px 0}
table.fields th{text-align:left;color:var(--dim);font-weight:400;width:34%;vertical-align:top;padding:2px 6px 2px 0}
table.fields td{padding:2px 0;vertical-align:top}
table.fields.nested{background:var(--panel2);border-radius:4px;padding:2px 6px;margin:2px 0}
details.more{margin-top:6px}details.more summary{cursor:pointer;color:var(--dim);font-size:12px}
details.more summary:hover{color:var(--accent)}
.block{margin:8px 0;padding:8px;background:var(--panel2);border-radius:5px}
.block h4{margin:0 0 6px;font-size:12px;color:var(--accent)}
.frames{display:flex;flex-wrap:wrap;gap:8px;margin:6px 0}
.frame{margin:0;text-align:center}.frame figcaption{font-size:10px;color:var(--dim)}
.sheet{display:inline-block;image-rendering:pixelated;background-image:var(--img);background-repeat:no-repeat;
width:calc(var(--cw)*var(--scale));height:calc(var(--ch)*var(--scale));
background-size:calc(var(--sw)*var(--scale)) calc(var(--sh)*var(--scale));
background-position:calc(var(--x)*var(--scale)*-1) calc(var(--y)*var(--scale)*-1)}
.chip{display:inline-block;background:var(--panel2);border:1px solid var(--line);border-radius:10px;padding:0 7px;margin:1px 2px 1px 0;font-size:12px}
.chip:hover{border-color:var(--link)}
.chip .cid{font-size:10px;margin-left:5px}
.badge{display:inline-block;background:var(--panel3);border-radius:4px;padding:0 6px;margin:1px 2px 1px 0;font-size:12px}
.flag{font-family:ui-monospace,monospace;font-size:11px;background:var(--panel3);border-radius:3px;padding:0 4px}
.swatch{display:inline-block;width:14px;height:14px;border-radius:3px;border:1px solid var(--line);vertical-align:-2px;margin-right:5px}
.money{color:var(--accent)}.time{font-family:ui-monospace,monospace}
.dim{color:var(--dim)}.en{color:var(--dim);font-size:11px}
.bad{color:var(--bad)}.yes{color:var(--good)}.no{color:var(--bad)}
.refs{margin-top:8px;padding-top:6px;border-top:1px solid var(--line);color:var(--dim);font-size:11px}
.refs-n{color:var(--accent);margin-right:6px}
.dialogue .line{padding:4px 0;border-bottom:1px dashed var(--line)}
.dialogue .idx,.dialogue .speaker{font-size:11px;color:var(--accent);margin-right:6px}
.dialogue .text{margin:2px 0 2px 24px}
.choices{margin:2px 0 2px 40px;padding:0 0 0 14px}.choices li{margin:2px 0}
.badges{display:flex;gap:12px;flex-wrap:wrap;margin:10px 0}
.badges a{background:var(--panel);border:1px solid var(--line);border-radius:7px;padding:8px 14px;color:var(--fg);display:block;min-width:110px}
.badges a:hover{border-color:var(--accent);text-decoration:none}
.badges b{color:var(--accent);font-size:20px;display:block;line-height:1.3}
.badges span{color:var(--dim);font-size:11px}
.badges a.warn b{color:var(--bad)}
table.overview-table{border-collapse:collapse}table.overview-table td,table.overview-table th{padding:3px 16px 3px 0;text-align:left;border-bottom:1px solid var(--line)}
.problems{background:var(--panel);border:1px solid var(--line);border-radius:7px;padding:4px 14px}
.problems.ok{border-color:#2f5c46}
.problems ul{margin:6px 0;padding-left:20px}
.data-table{width:100%;border-collapse:collapse;font-size:12px}
.data-table th{position:sticky;top:44px;background:var(--panel3);color:var(--fg);text-align:left;padding:6px 8px;cursor:pointer;white-space:nowrap;border-bottom:1px solid var(--line);z-index:4}
.data-table th:hover{color:var(--accent)}
.data-table th.sorted-asc::after{content:" ▲";color:var(--accent)}
.data-table th.sorted-desc::after{content:" ▼";color:var(--accent)}
.data-table td{padding:4px 8px;border-bottom:1px solid var(--line);vertical-align:top}
.data-table tbody tr:nth-child(even){background:rgba(255,255,255,.02)}
.data-table tbody tr:hover{background:var(--panel2)}
.data-table td.name{white-space:nowrap}
.wall{display:grid;grid-template-columns:repeat(auto-fill,minmax(110px,1fr));gap:8px}
.wall figure{margin:0;background:var(--panel);border:1px solid var(--line);border-radius:5px;padding:6px;text-align:center}
.wall img{image-rendering:pixelated;max-width:100%;background:#0c0d11}
.wall figcaption{font-size:10px;color:var(--dim);word-break:break-all}
.view.hidden{display:none}
.view-table{overflow-x:auto;-webkit-overflow-scrolling:touch}
@media (max-width:900px){
.layout{grid-template-columns:minmax(0,1fr)}
nav{position:sticky;top:0;height:auto;max-height:86vh;padding:10px 12px;border-right:0;border-bottom:1px solid var(--line);z-index:30}
nav ol,nav .navfoot{display:none}
nav.open ol,nav.open .navfoot{display:block}
.navtoggle{display:block}
main{padding:14px 14px 110px;max-width:none}
.grid{grid-template-columns:1fr}
.sec-head{position:static}
.data-table{min-width:600px}
.data-table th{position:static}
.card{scroll-margin-top:12px}
}
@media (max-width:560px){
main{padding:12px 12px 100px}
.badges a{min-width:0;flex:1 1 0}
.badges b{font-size:17px}
.viewtoggle button{padding:3px 9px}
table.fields th{width:40%}
}
.card.no-match,tr.i18n-row.no-match,figure.wall-fig.no-match{display:none}
#totop{position:fixed;right:20px;bottom:20px;width:40px;height:40px;border-radius:50%;border:1px solid var(--line);
background:var(--panel3);color:var(--fg);font-size:18px;cursor:pointer;display:none;z-index:20}
#totop.show{display:block}
"""

JS = """
const q=document.getElementById('q');
const hits=document.getElementById('hits');
const clearBtn=document.getElementById('clearq');
const navLinks=[...document.querySelectorAll('nav a[data-target]')];
const sections=[...document.querySelectorAll('main section.sec')];
document.getElementById('totop').addEventListener('click',()=>window.scrollTo({top:0}));
const navEl=document.querySelector('nav');
const navToggle=document.getElementById('navtoggle');
if(navToggle)navToggle.addEventListener('click',()=>navEl.classList.toggle('open'));
navLinks.forEach(a=>a.addEventListener('click',()=>{if(innerWidth<=900)navEl.classList.remove('open');}));

function textOf(el){return ((el.dataset.search||'')+' '+el.textContent).toLowerCase();}

function apply(){
  const t=q.value.trim().toLowerCase();
  let total=0;
  for(const sec of sections){
    let n=0;
    for(const el of sec.querySelectorAll('.card,tr.i18n-row,figure.wall-fig')){
      const hit=!t||textOf(el).includes(t);
      el.classList.toggle('no-match',!hit);
      if(hit)n++;
    }
    for(const row of sec.querySelectorAll('tr.data-row')){
      row.classList.toggle('no-match',!!t&&!textOf(row).includes(t));
    }
    for(const g of sec.querySelectorAll('.dgroup')){
      g.classList.toggle('hidden',!!t&&!g.querySelector('.card:not(.no-match)'));
    }
    for(const b of sec.querySelectorAll('.wall-block')){
      b.classList.toggle('hidden',!!t&&!b.querySelector('figure.wall-fig:not(.no-match)'));
    }
    const overview=sec.id==='overview';
    sec.classList.toggle('hidden',!!t&&!overview&&n===0);
    if(!overview)total+=n;
    const link=navLinks.find(a=>a.dataset.target===sec.id);
    if(link){
      const c=link.querySelector('.count');
      c.textContent=t?String(n):c.dataset.total;
      link.classList.toggle('zero',!!t&&n===0);
    }
  }
  hits.textContent=t?(total?('匹配 '+total+' 条'):'没有匹配'):'';
  hits.classList.toggle('bad',!!t&&total===0);
  clearBtn.hidden=!t;
}
q.addEventListener('input',apply);
clearBtn.addEventListener('click',()=>{q.value='';apply();q.focus();});
document.addEventListener('keydown',e=>{
  if(e.key==='/'&&document.activeElement!==q){e.preventDefault();q.focus();}
  else if(e.key==='Escape'&&document.activeElement===q){q.value='';apply();q.blur();}
});

// 侧栏高亮：跟随滚动所在的分类。
const visible=new Map();
const spy=new IntersectionObserver(es=>{
  for(const e of es){if(e.isIntersecting)visible.set(e.target.id,e.boundingClientRect.top);else visible.delete(e.target.id);}
  if(!visible.size)return;
  const id=[...visible.entries()].sort((a,b)=>Math.abs(a[1])-Math.abs(b[1]))[0][0];
  navLinks.forEach(a=>a.classList.toggle('active',a.dataset.target===id));
},{rootMargin:'-70px 0px -65% 0px'});
sections.forEach(s=>spy.observe(s));

// 卡片 / 表格视图切换（按分类记忆）。
function setView(sec,view){
  sec.querySelector('.view-cards')?.classList.toggle('hidden',view!=='cards');
  sec.querySelector('.view-table')?.classList.toggle('hidden',view!=='table');
  sec.querySelectorAll('.viewtoggle button').forEach(b=>b.classList.toggle('on',b.dataset.view===view));
  try{localStorage.setItem('wiki-view-'+sec.dataset.kind,view);}catch(e){}
}
document.querySelectorAll('.viewtoggle').forEach(t=>t.addEventListener('click',e=>{
  const b=e.target.closest('button');if(b)setView(t.closest('section'),b.dataset.view);
}));
document.querySelectorAll('section.sec[data-kind]').forEach(sec=>{
  if(!sec.querySelector('.view-table'))return;
  try{const v=localStorage.getItem('wiki-view-'+sec.dataset.kind);if(v)setView(sec,v);}catch(e){}
});
const allBtn=document.getElementById('allviews');
if(allBtn){
  const target=()=>{const s=document.querySelector('section.sec .view-table.hidden');return s?'table':'cards';};
  allBtn.addEventListener('click',()=>{
    const v=target();
    document.querySelectorAll('section.sec[data-kind]').forEach(s=>{if(s.querySelector('.view-table'))setView(s,v);});
    allBtn.textContent=v==='table'?'全部切换回卡片':'全部切换为表格';
  });
}

// 表头点击排序（数值列按数值，其余按中文）。
function sortVal(a,b){
  const na=parseFloat(a.replace(/[^\\d.\\-]/g,'')),nb=parseFloat(b.replace(/[^\\d.\\-]/g,''));
  if(!isNaN(na)&&!isNaN(nb))return na-nb;
  return a.localeCompare(b,'zh');
}
document.querySelectorAll('.data-table').forEach(table=>{
  table.querySelectorAll('th').forEach((th,idx)=>{
    th.addEventListener('click',()=>{
      const dir=th.dataset.dir==='asc'?-1:1;
      table.querySelectorAll('th').forEach(o=>{delete o.dataset.dir;o.classList.remove('sorted-asc','sorted-desc');});
      th.dataset.dir=dir===1?'asc':'desc';
      th.classList.add(dir===1?'sorted-asc':'sorted-desc');
      const body=table.tBodies[0];
      [...body.rows].sort((a,b)=>dir*sortVal(a.cells[idx].textContent,b.cells[idx].textContent))
        .forEach(r=>body.appendChild(r));
    });
  });
});

// 深链接：跳到某张卡片时闪一下边框。
function flashTarget(){
  if(!location.hash)return;
  const el=document.getElementById(location.hash.slice(1));
  if(!el)return;
  el.classList.add('flash');
  setTimeout(()=>el.classList.remove('flash'),1600);
}
window.addEventListener('hashchange',flashTarget);
addEventListener('scroll',()=>document.getElementById('totop').classList.toggle('show',scrollY>500));
flashTarget();
"""


def problems_of(ctx: Context) -> list[tuple[str, str, str]]:
    """引擎自检 + 缺译 + 悬空引用，返回 (类名, id, 说明)；空列表表示干净。"""
    found: list[tuple[str, str, str]] = [
        ("", "", f"validate: {p}") for p in ctx.validation
    ]
    for kind, bucket in ctx.resources.items():
        for rid, res in bucket.items():
            for field, value in res.items():
                if field.endswith("_key") and value and value not in ctx.i18n:
                    found.append((kind, rid, f"{field} 缺译：{value}"))
            for field, target in REF_FIELDS.items():
                if res.get(field) and ctx.get(target, res[field]) is None:
                    found.append((kind, rid, f"{field} 悬空：{res[field]}"))
            for field, target in REF_LIST_FIELDS.items():
                for item in res.get(field) or []:
                    if ctx.get(target, item) is None:
                        found.append((kind, rid, f"{field} 悬空：{item}"))
            for field, value in res.items():
                if isinstance(value, dict) and "$ref" in value and ctx.get(value["$ref"], value["id"]) is None:
                    found.append((kind, rid, f"{field} 悬空：{value['id']}"))
    return found


def overview(ctx: Context, problems: list[tuple[str, str, str]]) -> str:
    counts = "".join(
        f'<tr><td><a href="#{ctx.slug(kind)}">{esc(ctx.label(kind))}</a></td>'
        f'<td>{len(ctx.items(kind))}</td></tr>'
        for kind in KINDS if ctx.items(kind)
    )
    total = sum(len(ctx.items(kind)) for kind in KINDS)
    if problems:
        items = "".join(_problem_line(ctx, kind, rid, msg) for kind, rid, msg in problems)
        health = f'<div class="problems"><h4 class="bad">数据体检 · {len(problems)} 个待查</h4><ul>{items}</ul></div>'
    else:
        health = '<div class="problems ok"><h4 class="yes">数据体检 · 全部通过</h4>' \
                 '<div class="dim">validate_all()、缺译检查与引用检查均无问题。</div></div>'
    tiles = [
        f'<a href="#items"><b>{total}</b><span>条静态数据</span></a>',
        f'<a href="#i18n"><b>{len(ctx.i18n)}</b><span>条文案</span></a>',
        f'<a href="#sprites"><b>{sum(len(files) for _d, files in _sprites(ctx))}</b><span>张图片</span></a>',
        f'<a href="#overview" class="{"warn" if problems else ""}"><b>{len(problems)}</b><span>个待查</span></a>',
    ]
    return (
        '<section id="overview" class="sec overview"><header class="sec-head"><h2>概览</h2></header>'
        f'<div class="badges">{"".join(tiles)}</div>'
        f'{health}'
        '<div class="block"><h4>分类</h4>'
        f'<table class="overview-table"><tr><th>分类</th><th>数量</th></tr>{counts}</table></div>'
        '<div class="dim">提示：<code>/</code> 聚焦搜索，<code>Esc</code> 清空；点表头可排序，右下角可回顶部。</div>'
        "</section>"
    )


def _problem_line(ctx: Context, kind: str, rid: str, msg: str) -> str:
    if kind and rid:
        where = f'<a href="#{ctx.slug(kind)}-{rid}">{esc(ctx.label(kind))}·{esc(ctx.name(kind, rid))}</a>'
    else:
        where = '<span class="dim">全局</span>'
    return f'<li>{where} {esc(msg)}</li>'


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
        search = esc(f'{key} {entry["zh"]} {entry["en"]}'.lower())
        rows.append(
            f'<tr class="i18n-row" data-search="{search}"><td><span class="flag">{esc(key)}</span></td>'
            f'<td>{zh}</td><td>{en}</td><td class="dim">{esc(entry["src"])}</td><td>{refs}</td></tr>'
        )
    return (
        '<section id="i18n" class="sec"><header class="sec-head"><h2>文案'
        f' <span class="count">{len(ctx.i18n)}</span></h2></header>'
        '<table class="fields"><tr><th>键</th><th>中文</th><th>English</th><th>来源</th><th>数据引用</th></tr>'
        '%s</table></section>' % "".join(rows)
    )


def _sprites(ctx: Context) -> list[tuple[str, list[str]]]:
    base = os.path.join(ctx.assets.root, "assets", "sprites")
    groups: dict[str, list[str]] = {}
    for current, _dirs, files in os.walk(base):
        for name in sorted(files):
            if name.endswith(".png"):
                rel = os.path.relpath(os.path.join(current, name), base).replace(os.sep, "/")
                groups.setdefault(os.path.dirname(rel) or ".", []).append(rel)
    return sorted(groups.items())


def sprites_section(ctx: Context) -> str:
    groups = _sprites(ctx)
    if not groups:
        return ""
    blocks = []
    for directory, files in groups:
        figures = []
        for rel in files:
            url = ctx.assets.url("res://assets/sprites/" + rel)
            figures.append(
                f'<figure class="wall-fig" data-search="{esc(rel.lower())}"><img src="{url}">'
                f'<figcaption>{esc(rel)}</figcaption></figure>'
            )
        blocks.append(
            f'<div class="block wall-block"><h4>{esc(directory)} <span class="dim">{len(files)}</span></h4>'
            f'<div class="wall">{"".join(figures)}</div></div>'
        )
    return f'<section id="sprites" class="sec"><header class="sec-head"><h2>图片墙</h2></header>{"".join(blocks)}</section>'


def build(root: str, out_dir: str) -> tuple[str, list[tuple[str, str, str]]]:
    ctx = Context(root, out_dir)
    problems = problems_of(ctx)
    warnings = Counter(kind for kind, _rid, _msg in problems if kind)

    sections = [overview(ctx, problems)]
    sections += [render.section(ctx, kind) for kind in KINDS]
    sections += [i18n_section(ctx), sprites_section(ctx)]

    nav_items = []
    for kind in KINDS:
        if not ctx.items(kind):
            continue
        badge = f'<span class="warn">⚠{warnings[kind]}</span>' if warnings.get(kind) else ""
        nav_items.append(
            f'<li><a href="#{ctx.slug(kind)}" data-target="{ctx.slug(kind)}">{esc(ctx.label(kind))}'
            f'{badge}<span class="count" data-total="{len(ctx.items(kind))}">{len(ctx.items(kind))}</span></a></li>'
        )
    nav = "".join(nav_items)
    sprite_count = sum(len(files) for _directory, files in _sprites(ctx))
    all_views = any(kind in render.TABLE_COLUMNS for kind in KINDS)
    page = (
        "<!doctype html><html lang=\"zh-CN\"><head><meta charset=\"utf-8\">"
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
        f"<title>open-farm wiki v{esc(ctx.version)}</title><style>{CSS}</style></head><body>"
        '<div class="layout"><nav><h1>open-farm wiki</h1>'
        f'<div class="ver">v{esc(ctx.version)} · {sum(len(ctx.items(k)) for k in KINDS)} 条数据</div>'
        '<button id="navtoggle" class="navtoggle" aria-label="展开目录">☰ 分类目录</button>'
        '<div class="searchbox"><input id="q" placeholder="搜索名称 / id / 文案（/）" autocomplete="off">'
        '<button id="clearq" hidden title="清空">×</button></div>'
        '<div id="hits" class="hits dim"></div>'
        f'<ol><li><a href="#overview" data-target="overview">概览'
        '<span class="count"></span></a></li>'
        + nav
        + '<li><a href="#i18n" data-target="i18n">文案'
        f'<span class="count" data-total="{len(ctx.i18n)}">{len(ctx.i18n)}</span></a></li>'
        '<li><a href="#sprites" data-target="sprites">图片墙'
        f'<span class="count" data-total="{sprite_count}">{sprite_count}</span></a></li></ol>'
        '<div class="navfoot">'
        + ('<button id="allviews">全部切换为表格</button>' if all_views else '')
        + '</div>'
        '</nav>'
        f'<main>{"".join(s for s in sections if s)}</main></div>'
        '<button id="totop" title="回到顶部">↑</button>'
        f'<script>{JS}</script></body></html>'
    )
    path = os.path.join(out_dir, "index.html")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(page)
    return path, problems


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
    for kind, rid, message in problems:
        print(f"  ! {kind + ' ' + rid if kind else '全局'}：{message}")
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
