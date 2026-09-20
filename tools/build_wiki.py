#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""tools/build_wiki.py — 把导出的数据渲染成手机优先的多页静态 wiki，用于审阅游戏内容。

数据来源是 [code]tools/wiki_dump.tscn[/code] 导出的 [code].tmp/wiki/data.json[/code]
（引擎侧保证引用已解析、切图常量已对齐）。本脚本只做四件事：
[br]1. 读 data.json + [code]assets/i18n/*.csv[/code]，算出体检问题（缺译 / 悬空引用）
[br]2. 用 Jinja2 模板（[code]tools/wiki/templates[/code]）铺页面
[br]3. 复制静态资源（[code]tools/wiki/static[/code] 的 app.css / app.js）与贴图到输出目录
[br]4. 生成全局搜索索引 [code]search-index.js[/code]

输出结构（扁平文件名，本地 [code]file://[/code] 与 GitHub Pages 通用）：
[br]- [code]index.html[/code] 概览：体检 + 分类入口
[br]- [code]<slug>.html[/code] 每类列表（列表 / 表格视图切换）
[br]- [code]d_<slug>_<id>.html[/code] 每条资源的详情页
[br]- [code]i18n.html[/code] / [code]sprites.html[/code]
[br]- [code]app.css[/code] / [code]app.js[/code] / [code]search-index.js[/code] / [code]sprites/**[/code]

用法：
  ./tools/build_wiki.sh                     # 推荐：外壳脚本负责先导出数据
  python3 tools/build_wiki.py --open        # 生成后用浏览器打开
  python3 tools/build_wiki.py --serve 8000  # 起一个本地静态服务
  python3 tools/build_wiki.py --strict      # 有缺译 / 悬空引用时非零退出
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import webbrowser
from collections import Counter

from jinja2 import Environment, FileSystemLoader

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "wiki"))

import render  # noqa: E402
from content import KINDS, Context, esc  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TEMPLATES = os.path.join(HERE, "wiki", "templates")
STATIC = os.path.join(HERE, "wiki", "static")
STATIC_FILES = ("app.css", "app.js")


# ---------------------------------------------------------------- 体检

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
            for field, target in render.REF_FIELDS.items():
                if res.get(field) and ctx.get(target, res[field]) is None:
                    found.append((kind, rid, f"{field} 悬空：{res[field]}"))
            for field, target in render.REF_LIST_FIELDS.items():
                for item in res.get(field) or []:
                    if ctx.get(target, item) is None:
                        found.append((kind, rid, f"{field} 悬空：{item}"))
            for field, value in res.items():
                if isinstance(value, dict) and "$ref" in value and ctx.get(value["$ref"], value["id"]) is None:
                    found.append((kind, rid, f"{field} 悬空：{value['id']}"))
    return found


def problem_line(ctx: Context, kind: str, rid: str, message: str) -> str:
    if kind and rid:
        where = f'<a href="{ctx.url(kind, rid)}">{esc(ctx.label(kind))}·{esc(ctx.name(kind, rid))}</a>'
    else:
        where = '<span class="dim">全局</span>'
    return f"{where} {esc(message)}"


# ---------------------------------------------------------------- 页面数据

def nav_items(ctx: Context, warnings: Counter) -> list[dict]:
    items = []
    for kind in KINDS:
        bucket = ctx.items(kind)
        if not bucket:
            continue
        items.append({
            "slug": ctx.slug(kind), "label": ctx.label(kind),
            "count": len(bucket), "warn": warnings.get(kind, 0),
        })
    return items


def categories(ctx: Context, warnings: Counter) -> list[dict]:
    cats = []
    for kind in KINDS:
        bucket = ctx.items(kind)
        if not bucket:
            continue
        first = next(iter(bucket.values()))
        cats.append({
            "slug": ctx.slug(kind), "label": ctx.label(kind), "cls": kind,
            "count": len(bucket), "warn": warnings.get(kind, 0),
            "icon": render.icon_url(ctx, kind, first),
        })
    return cats


def i18n_rows(ctx: Context) -> list[dict]:
    """文案表：每条翻译 + 引用它的数据条目（最多 4 个）。"""
    used: dict[str, set[tuple[str, str]]] = {}
    for kind, bucket in ctx.resources.items():
        for rid, res in bucket.items():
            for field, value in res.items():
                if field.endswith("_key") and isinstance(value, str) and value:
                    used.setdefault(value, set()).add((kind, rid))
    rows = []
    for key, entry in sorted(ctx.i18n.items(), key=lambda kv: (kv[1]["src"], kv[0])):
        who = used.get(key)
        if who:
            refs = " ".join(
                f'<a class="chip" href="{ctx.url(k, r)}">{esc(ctx.label(k))}·{esc(r)}</a>'
                for k, r in sorted(who)[:4]
            )
            if len(who) > 4:
                refs += f' <span class="dim">+{len(who) - 4}</span>'
        else:
            refs = '<span class="dim">未见数据引用</span>'
        rows.append({
            "key": key,
            "zh": esc(entry["zh"]) if entry["zh"] else '<span class="bad">缺中文</span>',
            "en": esc(entry["en"]) if entry["en"] else '<span class="bad">缺英文</span>',
            "refs": refs,
        })
    return rows


def sprite_groups(ctx: Context) -> list[tuple[str, list[str]]]:
    base = os.path.join(ctx.assets.root, "assets", "sprites")
    groups: dict[str, list[str]] = {}
    for current, _dirs, files in os.walk(base):
        for name in sorted(files):
            if name.endswith(".png"):
                rel = os.path.relpath(os.path.join(current, name), base).replace(os.sep, "/")
                groups.setdefault(os.path.dirname(rel) or ".", []).append(rel)
    return sorted(groups.items())


# ---------------------------------------------------------------- 渲染

def _write(out_dir: str, name: str, text: str) -> None:
    with open(os.path.join(out_dir, name), "w", encoding="utf-8") as handle:
        handle.write(text)


def _search_index(ctx: Context) -> str:
    entries = [
        {"n": ctx.name(kind, rid), "k": ctx.slug(kind), "i": rid}
        for kind in KINDS for rid in ctx.items(kind)
    ]
    kinds = {ctx.slug(kind): ctx.label(kind) for kind in KINDS}
    return (
        "window.WIKI_INDEX=" + json.dumps(entries, ensure_ascii=False, separators=(",", ":")) + ";\n"
        "window.WIKI_KINDS=" + json.dumps(kinds, ensure_ascii=False, separators=(",", ":")) + ";\n"
    )


def render_pages(out_dir: str, ctx: Context, problems: list[tuple[str, str, str]],
                 warnings: Counter) -> int:
    env = Environment(loader=FileSystemLoader(TEMPLATES), autoescape=True,
                      trim_blocks=True, lstrip_blocks=True)
    groups_all = sprite_groups(ctx)
    common = {
        "version": ctx.version,
        "total": sum(len(ctx.items(k)) for k in KINDS),
        "i18n_count": len(ctx.i18n),
        "sprite_count": sum(len(files) for _d, files in groups_all),
        "nav": nav_items(ctx, warnings),
        "cats": categories(ctx, warnings),
    }

    def page(template: str, out_name: str, **kw) -> None:
        data = dict(common)
        data.update(kw)
        _write(out_dir, out_name, env.get_template(template).render(**data))

    count = 0
    page("index.html.j2", "index.html", title="概览", tab="home", current="home",
         problems=[problem_line(ctx, k, r, m) for k, r, m in problems])
    page("categories.html.j2", "categories.html", title="全部分类",
         tab="categories", current="categories")
    count += 2

    for kind in KINDS:
        items = ctx.items(kind)
        if not items:
            continue
        slug = ctx.slug(kind)
        rows = [render.list_row(ctx, kind, rid, res) for rid, res in items.items()]
        groups = None
        if kind == "DialogueData":
            groups = [
                {"label": label, "rows": [render.list_row(ctx, kind, rid, items[rid]) for rid in rids]}
                for label, rids in render.dialogue_groups(ctx, items)
            ]
        table = render.data_table(ctx, kind)
        page("list.html.j2", f"{slug}.html", title=ctx.label(kind), tab="categories",
             current=slug, label=ctx.label(kind), slug=slug, count=len(items),
             rows=rows, groups=groups, has_table=bool(table), table=table)
        count += 1
        for rid, res in items.items():
            subtitle, stat, stat_label = render.summary(ctx, kind, rid, res)
            cells = [{"value": stat, "label": stat_label}] if stat else []
            if subtitle:
                cells.append({"value": subtitle, "label": "概要"})
            page("detail.html.j2", f"d_{slug}_{rid}.html", title=ctx.name(kind, rid),
                 tab="categories", current=slug, back=True, back_url=f"{slug}.html",
                 kind_label=ctx.label(kind), rid=rid, name=ctx.name(kind, rid),
                 icon=render.icon_url(ctx, kind, res), cells=cells,
                 body=render.detail_body(ctx, kind, rid))
            count += 1

    page("i18n.html.j2", "i18n.html", title="文案", tab="i18n", current="i18n",
         count=len(ctx.i18n), rows=i18n_rows(ctx))
    groups = [
        {"directory": directory if directory != "." else "根目录", "files": [
            {"rel": rel, "url": ctx.assets.url("res://assets/sprites/" + rel)} for rel in files
        ]}
        for directory, files in groups_all
    ]
    page("sprites.html.j2", "sprites.html", title="图片墙", tab="sprites", current="sprites",
         count=common["sprite_count"], groups=groups)
    count += 2

    _write(out_dir, "search-index.js", _search_index(ctx))
    return count


# ---------------------------------------------------------------- 主流程

def build(root: str, out_dir: str, data_path: str | None = None) -> tuple[str, list[tuple[str, str, str]], int]:
    os.makedirs(out_dir, exist_ok=True)
    ctx = Context(root, out_dir, data_path)
    for name in STATIC_FILES:
        shutil.copyfile(os.path.join(STATIC, name), os.path.join(out_dir, name))
    problems = problems_of(ctx)
    warnings = Counter(kind for kind, _rid, _message in problems if kind)
    pages = render_pages(out_dir, ctx, problems, warnings)
    return os.path.join(out_dir, "index.html"), problems, pages


def _lan_ip() -> str:
    """取本机在局域网里的地址，供手机同网访问时提示。"""
    import socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        sock.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="生成 open-farm 内容 wiki（多页静态 HTML）")
    parser.add_argument("--root", default=ROOT, help="仓库根目录")
    parser.add_argument("--out", default=os.path.join(ROOT, ".tmp", "wiki"), help="输出目录")
    parser.add_argument("--data", default=None, help="data.json 路径（默认 <输出目录>/data.json）")
    parser.add_argument("--open", action="store_true", help="生成后用浏览器打开")
    parser.add_argument("--strict", action="store_true", help="有缺译 / 悬空引用时以非零码退出")
    parser.add_argument("--serve", type=int, metavar="PORT", help="生成后起本地静态服务")
    parser.add_argument("--host", default="127.0.0.1",
                        help="--serve 的绑定地址（手机同网访问用 0.0.0.0）")
    args = parser.parse_args()

    path, problems, pages = build(args.root, args.out, args.data)
    print(f"wiki 已生成：{args.out}（{pages} 页，{len(problems)} 个待查），入口 {path}")
    for kind, rid, message in problems:
        print(f"  ! {kind + ' ' + rid if kind else '全局'}：{message}")
    if args.open:
        webbrowser.open("file://" + path)
    if args.serve:
        import functools
        import http.server

        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=args.out)
        if args.host == "0.0.0.0":
            print(f"服务地址：http://{_lan_ip()}:{args.serve}/（手机同网可直接打开）")
        else:
            print(f"服务地址：http://{args.host}:{args.serve}/")
        http.server.ThreadingHTTPServer((args.host, args.serve), handler).serve_forever()
    return 1 if problems and args.strict else 0


if __name__ == "__main__":
    raise SystemExit(main())
