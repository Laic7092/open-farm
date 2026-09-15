#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""tools/outline.py — 不整读大文件，也能看懂结构。

给 Agent（和人）用的"廉价阅读器"：只打印结构——用途、段落、常量、
函数签名与行号——不打印函数体。要看细节时用 sym 只取那一个函数。

用法：
  python3 tools/outline.py outline tools/smoke_test.gd      # 结构大纲
  python3 tools/outline.py outline tools/ src/              # 批量
  python3 tools/outline.py sym tools/smoke_test.gd _ready   # 只看一个函数体
  python3 tools/outline.py sym tools/smoke_test.gd 'flora.*'# 名字支持正则
  python3 tools/outline.py grep EventBus tools/             # 带行号搜，不整读
  python3 tools/outline.py refs tools/smoke_test.gd _check_mine   # 谁调用它 / 它调用谁
  python3 tools/outline.py callers clear src/ tools/ tests/        # 跨文件查调用方（改共享契约前必查）
  python3 tools/outline.py lint                                    # 大文件规范体检
  python3 tools/outline.py map                              # 全仓索引：行数 + 用途
  python3 tools/outline.py map tools/                       # 只索引某个目录

通用开关：
  --all   连 addons/ .godot/ 一起扫（默认跳过）
  --json  输出 JSON，方便再加工

支持 .gd / .tscn / .tres / .sh / .py / .md。默认扫描 tools/ 与 src/。
约定见 docs/big_files.md。
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
from pathlib import Path

SKIP_DIRS = {".git", ".godot", "target", ".tmp", "reports", "addons"}
DEFAULT_ROOTS = ["tools", "src"]
EXTS = (".gd", ".tscn", ".tres", ".sh", ".py", ".md")
BIG_FILE = 400      # 超过这个行数就提示别整读
BIG_FUNC = 80       # 超过这个行数的单个函数会单独点名


# ---------------------------------------------------------------- 文件收集

def expand(paths, all_dirs=False):
    out = []
    for p in paths:
        if any(ch in p for ch in "*?["):
            out.extend(sorted(g for g in glob.glob(p, recursive=True) if os.path.isfile(g)))
            continue
        pp = Path(p)
        if pp.is_dir():
            for root, dirs, files in os.walk(pp):
                dirs[:] = sorted(d for d in dirs if all_dirs or d not in SKIP_DIRS)
                for f in sorted(files):
                    if f.endswith(EXTS):
                        out.append(os.path.join(root, f))
        elif pp.is_file():
            out.append(str(pp))
        else:
            print("⚠ 找不到：%s" % p, file=sys.stderr)
    seen, res = set(), []
    for f in out:
        f = f.replace(os.sep, "/")
        if f not in seen:
            seen.add(f)
            res.append(f)
    return res


# ---------------------------------------------------------------- GDScript


def _balance(text):
    d = 0
    for ch in text:
        if ch in "([{":
            d += 1
        elif ch in ")]}":
            d -= 1
    return d


def _doc_above(lines, i):
    j, buf = i - 1, []
    while j >= 0 and lines[j].startswith("##"):
        buf.append(lines[j][2:].strip())
        j -= 1
    return list(reversed(buf))


def _read_sig(lines, i):
    """从 func 所在行开始拼出完整签名（可能跨多行），返回 (签名, 结束行号)。"""
    n = len(lines)
    buf = [lines[i].rstrip()]
    k = i
    while k - i < 30:
        joined = " ".join(x.strip() for x in buf)
        if joined.endswith(":") and _balance(joined) <= 0:
            break
        if k + 1 >= n:
            break
        k += 1
        buf.append(lines[k].rstrip())
    return " ".join(x.strip() for x in buf), k


def _body_end(lines, sig_end):
    j, last = sig_end + 1, sig_end
    while j < len(lines):
        s = lines[j]
        if s.strip() == "":
            j += 1
            continue
        if s[0] in " \t":
            last = j
            j += 1
            continue
        break
    return last


def parse_gd(path):
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    n = len(lines)
    res = {
        "path": path, "kind": "gd", "lines": n, "extends": "", "class_name": "",
        "tool": False, "doc": [], "sections": [], "consts": [], "vars": [],
        "signals": [], "enums": [], "funcs": [], "inner_classes": [],
    }
    doc_done = False
    i = 0
    while i < n:
        s = lines[i].rstrip()
        if not doc_done and s.startswith("##"):
            j = i
            while j < n and lines[j].startswith("##"):
                j += 1
            res["doc"] = [lines[k][2:].strip() for k in range(i, j)]
            doc_done = True
            i = j
            continue
        if not s or s[0] in " \t":
            i += 1
            continue

        m = re.match(r"^#\s*[-=~#]{4,}\s*(.*)$", s)
        if m:
            if m.group(1).strip():
                res["sections"].append({"name": m.group(1).strip(), "line": i + 1})
            i += 1
            continue
        if s.startswith("#"):
            i += 1
            continue

        m = re.match(r"^extends\s+([^\s#]+)", s)
        if m:
            res["extends"] = m.group(1)
            i += 1
            continue
        m = re.match(r"^class_name\s+([A-Za-z_]\w*)", s)
        if m:
            res["class_name"] = m.group(1)
            i += 1
            continue
        if re.match(r"^@tool\b", s):
            res["tool"] = True
            i += 1
            continue
        m = re.match(r"^signal\s+([A-Za-z_]\w*)\s*(.*)$", s)
        if m:
            res["signals"].append({"name": m.group(1), "line": i + 1, "sig": m.group(2).strip()})
            i += 1
            continue
        m = re.match(r"^enum\s+([A-Za-z_]\w*)", s)
        if m:
            res["enums"].append({"name": m.group(1), "line": i + 1})
            i += 1
            continue
        m = re.match(r"^class\s+([A-Za-z_]\w*)", s)
        if m:
            res["inner_classes"].append({"name": m.group(1), "line": i + 1})
            i += 1
            continue
        m = re.match(r"^(static\s+)?func\s+([A-Za-z_]\w*)", s)
        if m:
            sig, sig_end = _read_sig(lines, i)
            end = _body_end(lines, sig_end) + 1
            res["funcs"].append({
                "name": m.group(2), "static": bool(m.group(1)), "line": i + 1,
                "end": end, "length": end - i, "sig": sig, "doc": _doc_above(lines, i),
            })
            i = sig_end + 1
            continue

        core = re.sub(r"^(@[A-Za-z_]\w*(\([^()]*\))?\s+)+", "", s)
        m = re.match(r"^const\s+([A-Za-z_]\w*)\s*(?::\s*[^=]+)?=\s*(.*)$", core)
        if m:
            res["consts"].append({"name": m.group(1), "line": i + 1,
                                  "value": m.group(2).strip()[:60], "doc": _doc_above(lines, i)})
            i += 1
            continue
        m = re.match(r"^var\s+([A-Za-z_]\w*)\s*(?::\s*([^=]+?))?\s*(?:=\s*(.*))?$", core)
        if m:
            res["vars"].append({"name": m.group(1), "line": i + 1,
                                "type": (m.group(2) or "").strip(),
                                "value": (m.group(3) or "").strip()[:40],
                                "doc": _doc_above(lines, i)})
            i += 1
            continue
        i += 1
    names = {f["name"] for f in res["funcs"]}
    callers = {}
    for f in res["funcs"]:
        for ln in lines[f["line"]: f["end"]]:
            if ln.lstrip().startswith("#"):
                continue
            for m in re.finditer(r"\b([A-Za-z_]\w*)\s*\(", ln):
                n = m.group(1)
                if n in names and n != f["name"]:
                    callers.setdefault(n, []).append(f["name"])
    res["callers"] = {k: sorted(set(v)) for k, v in callers.items()}
    return res


# ---------------------------------------------------------------- 场景 / 资源

NODE_RE = re.compile(r'^\[node\s+name="([^"]*)"(?:\s+type="([^"]*)")?(?:\s+parent="([^"]*)")?')
EXT_RE = re.compile(r'^\[(?:ext|sub)_resource\s+type="([^"]*)"[^\]]*path="([^"]*)"')


def parse_tscn(path):
    lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
    nodes, exts, subs, root_script, depths = [], [], 0, "", {}
    for idx, line in enumerate(lines):
        m = NODE_RE.match(line)
        if m:
            name, typ, parent = m.group(1), m.group(2) or "", m.group(3) or ""
            if not parent:
                depth, node_path = 0, "."
            elif parent == ".":
                depth, node_path = 1, name
            else:
                depth, node_path = depths.get(parent, 0) + 1, parent + "/" + name
            depths[node_path] = depth
            nodes.append({"name": name, "type": typ, "parent": parent,
                          "line": idx + 1, "depth": depth})
            continue
        m = EXT_RE.match(line)
        if m:
            kind, res_path = m.group(1), m.group(2)
            if kind == "Script" and not root_script:
                root_script = res_path
            exts.append({"type": kind, "path": res_path, "line": idx + 1})
            continue
        if line.startswith("[sub_resource"):
            subs += 1
    return {"path": path, "kind": "tscn", "lines": len(lines),
            "root_type": nodes[0]["type"] if nodes else "", "root_script": root_script,
            "nodes": nodes, "ext": exts, "sub_count": subs}


def parse_tres(path):
    lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
    head, exts, subs = {}, [], 0
    for idx, line in enumerate(lines):
        if line.startswith("[gd_resource") or line.startswith("[resource"):
            for k, v in re.findall(r'(\w+)="([^"]*)"', line):
                head[k] = v
        elif line.startswith("[ext_resource"):
            m = EXT_RE.match(line)
            exts.append({"line": idx + 1, "type": m.group(1) if m else "?",
                         "path": m.group(2) if m else line})
        elif line.startswith("[sub_resource"):
            subs += 1
    return {"path": path, "kind": "tres", "lines": len(lines), "head": head,
            "ext": exts, "sub_count": subs}


def parse_text(path):
    lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
    res = {"path": path, "kind": "text", "lines": len(lines), "doc": [], "funcs": []}
    for line in lines[:40]:
        if line.startswith("#!") or line.startswith("# -*-"):
            continue
        if line.startswith("##"):
            res["doc"].append(line[2:].strip())
        elif line.startswith("#"):
            body = line.lstrip("#").strip()
            if body:
                res["doc"].append(body)
    if not res["doc"]:
        q3 = '"' * 3
        p3 = "'" * 3
        in_doc = False
        for line in lines[:60]:
            st = line.strip()
            if not in_doc and (st.startswith(q3) or st.startswith(p3)):
                in_doc = True
                body = st.replace('"', "").replace("'", "").strip()
                if body:
                    res["doc"].append(body)
                if st.count(q3) >= 2 or st.count(p3) >= 2:
                    in_doc = False
                continue
            if in_doc:
                if st.endswith(q3) or st.endswith(p3):
                    in_doc = False
                    continue
                if st:
                    res["doc"].append(st)
    for i, line in enumerate(lines):
        m = re.match(r"^(?:function\s+|def\s+)?([A-Za-z_][\w-]*)\s*\(\s*\)\s*\{?$", line)
        if m:
            res["funcs"].append({"name": m.group(1), "line": i + 1, "sig": line.strip()})
    return res


def parse_any(path):
    if path.endswith(".gd"):
        return parse_gd(path)
    if path.endswith((".tscn", ".scn")):
        return parse_tscn(path)
    if path.endswith((".tres", ".res")):
        return parse_tres(path)
    return parse_text(path)


# ---------------------------------------------------------------- 渲染


BB_RE = re.compile(r"\[(?:br|/?b|/?i|/?u|/?s|/?code|/?codeblock|/?center|url(?::[^\]]*)?)\]")
REF_RE = re.compile(r"\[(?:method|param|constant|member|signal|enum|class|theme_item)\s+([^\]]+)\]")


def doc_lines_of(doc):
    """顶部说明的可读行：去掉空行与 [codeblock] 代码块。"""
    out, skip = [], False
    for x in doc:
        t = x.strip()
        if "[codeblock]" in t:
            skip = True
            continue
        if "[/codeblock]" in t:
            skip = False
            continue
        if not skip and t:
            out.append(x)
    return out


def plain(text):
    """去掉 Godot 文档 BBCode 标签，便于终端阅读。"""
    text = REF_RE.sub(r"\1", text)
    text = BB_RE.sub(" ", text)
    return " ".join(text.split())


def short(text, width):
    text = " ".join(text.split())
    return text if len(text) <= width else text[: width - 1] + "…"


def fmt_outline(d, doc_lines=12, funcs_mode="auto", nodes_mode="top"):
    out = []
    name = d["path"]
    if d["kind"] == "gd":
        head = "extends %s" % (d["extends"] or "?")
        if d["class_name"]:
            head += " / class_name %s" % d["class_name"]
        out.append("=== %s · %d 行 · %s ===" % (name, d["lines"], head))
        if d["doc"]:
            out.append("用途: " + short(plain(d["doc"][0]), 150))
            rest = doc_lines_of(d["doc"][1:])
            shown = rest if doc_lines <= 0 else rest[: max(0, doc_lines - 1)]
            for line in shown:
                out.append("      " + short(plain(line), 140))
            if len(shown) < len(rest):
                out.append("      …（说明还有 %d 段；--full 看全）" % (len(rest) - len(shown)))
        if d["lines"] >= BIG_FILE:
            out.append("⚠ %d 行：别整读；细节用 sym，定位用 grep / refs。" % d["lines"])
        secs = d["sections"]
        if secs:
            parts = []
            for i, sc in enumerate(secs):
                stop = secs[i + 1]["line"] if i + 1 < len(secs) else 10 ** 9
                cnt = sum(1 for f in d["funcs"] if sc["line"] <= f["line"] < stop)
                parts.append("L%d %s(%d)" % (sc["line"], sc["name"], cnt))
            out.append("段: " + " · ".join(parts))
        if d["enums"]:
            out.append("枚举: " + ", ".join("%s L%d" % (e["name"], e["line"]) for e in d["enums"]))
        if d["signals"]:
            out.append("信号: " + ", ".join(x["name"] for x in d["signals"]))
        if d["consts"]:
            out.append("常量 %d: " % len(d["consts"]) + " | ".join(
                "%s L%d" % (c["name"], c["line"]) for c in d["consts"]))
        if d["vars"]:
            out.append("变量 %d: " % len(d["vars"]) + short(
                ", ".join(v["name"] for v in d["vars"]), 150))
        if d["inner_classes"]:
            out.append("内部类: " + ", ".join(c["name"] for c in d["inner_classes"]))
        funcs = d["funcs"]
        total = sum(f["length"] for f in funcs)
        callers = d.get("callers", {})
        if funcs_mode == "none":
            out.append("函数 %d 个（占 %d/%d 行）；--funcs all 列全部" % (len(funcs), total, d["lines"]))
        else:
            if funcs_mode == "all":
                listed, more = funcs, 0
            else:
                seen, listed = set(), []
                bucket = ([x for x in funcs if not callers.get(x["name"])]
                          + [x for x in funcs if x["length"] >= BIG_FUNC])
                for f in bucket:
                    if f["name"] not in seen:
                        seen.add(f["name"])
                        listed.append(f)
                listed.sort(key=lambda x: x["line"])
                more = max(0, len(listed) - 12)
                listed = listed[:12]
            out.append("函数 %d 个（占 %d/%d 行）:" % (len(funcs), total, d["lines"]))
            for f in listed:
                out.append("  L%-5d %-6s %-50s %4d 行" % (
                    f["line"], "static" if f["static"] else "", short(f["sig"], 50), f["length"]))
            if funcs_mode == "auto":
                tail = ("  …还有 %d 个未列（先入口 + >=%d 行）" % (more, BIG_FUNC)) if more else (
                    "  （自动只列入口 + >=%d 行的函数）" % BIG_FUNC)
                out.append(tail + "；--funcs all 展开，--funcs none 只看数量。")
    elif d["kind"] == "tscn":
        out.append("=== %s · %d 行 · 场景 root=%s%s ===" % (
            name, d["lines"], d["root_type"] or "?",
            " script=%s" % d["root_script"] if d["root_script"] else ""))
        out.append("节点 %d · ext_resource %d · sub_resource %d" % (
            len(d["nodes"]), len(d["ext"]), d["sub_count"]))
        scripts = " ".join(e["path"].rsplit("/", 1)[-1] for e in d["ext"] if e["type"] == "Script")
        if scripts:
            out.append("脚本: " + short(scripts, 150))
        nodes = d["nodes"]
        if nodes_mode == "all":
            shown, more = nodes, 0
        else:
            shown = [nd for nd in nodes if nd["depth"] <= 1]
            more = len(nodes) - len(shown)
        for nd in shown:
            out.append("  %sL%-5d %-28s %s" % ("  " * nd["depth"], nd["line"], nd["name"], nd["type"]))
        if more:
            out.append("  …还有 %d 个深层节点；--nodes all / --full 展开。" % more)
    elif d["kind"] == "tres":
        out.append("=== %s · %d 行 · %s ===" % (name, d["lines"], d["head"].get("type", "resource")))
        out.append("sub_resource %d · ext_resource %d" % (d["sub_count"], len(d["ext"])))
        for e in d["ext"][:12]:
            out.append("  L%-5d %-10s %s" % (e["line"], e["type"], e["path"]))
    else:
        out.append("=== %s · %d 行 · %s ===" % (name, d["lines"], d["kind"]))
        if d["doc"]:
            out.append("用途: " + short(plain(d["doc"][0]), 150))
            rest = doc_lines_of(d["doc"][1:])
            shown = rest if doc_lines <= 0 else rest[: max(0, doc_lines - 1)]
            for line in shown:
                out.append("      " + short(plain(line), 140))
        for f in d["funcs"]:
            out.append("  L%-5d %s" % (f["line"], f["sig"]))
    return "\n".join(out)


def fmt_map(entries, top=0):
    out, warn = [], []
    entries = sorted(entries, key=lambda x: -x["lines"])
    width = max([len(e["path"]) for e in entries] + [4])
    out.append("%-5s %-*s %s" % ("行数", width, "文件", "用途（首段文档）"))
    for e in (entries[:top] if top else entries):
        purpose = short(plain(e["purpose"]) or "（无顶部说明，建议补 ## 注释）", 70)
        flag = "⚠" if e["lines"] >= BIG_FILE else " "
        out.append("%s%-5d %-*s %s" % (flag, e["lines"], width, e["path"], purpose))
        if e["lines"] >= BIG_FILE:
            warn.append(e["path"])
    total = sum(e["lines"] for e in entries)
    out.append("")
    out.append("共 %d 个文件、%d 行%s；>=%d 行的 %d 个：读之前先 outline / sym，别整读。" % (
        len(entries), total, "（只列了前 %d 个）" % top if top else "", BIG_FILE, len(warn)))
    for w in warn:
        out.append("  ⚠ %s" % w)
    return "\n".join(out)


# ---------------------------------------------------------------- 子命令


def cmd_outline(args):
    if not args.paths:
        print("给个文件或目录，例如：python3 tools/outline.py outline tools/smoke_test.gd", file=sys.stderr)
        return 2
    files = expand(args.paths, args.all)
    if not files:
        print("没有匹配到文件", file=sys.stderr)
        return 1
    data = [parse_any(f) for f in files]
    if args.json:
        print(json.dumps(data, ensure_ascii=False, indent=1))
    else:
        print("\n\n".join(fmt_outline(
            d,
            0 if args.full else args.doc,
            "all" if args.full else args.funcs,
            "all" if args.full else args.nodes,
        ) for d in data))
    return 0


def cmd_map(args):
    files = [f for f in expand(args.paths, args.all) if f.endswith((".gd", ".sh", ".py"))]
    entries = []
    for f in files:
        d = parse_gd(f) if f.endswith(".gd") else parse_text(f)
        doc = doc_lines_of(d["doc"])
        entries.append({"path": f, "lines": d["lines"],
                        "purpose": plain(doc[0]).strip() if doc else "",
                        "extends": d.get("extends", ""), "funcs": len(d.get("funcs", []))})
    entries.sort(key=lambda x: -x["lines"])
    if args.json:
        print(json.dumps(entries, ensure_ascii=False, indent=1))
    else:
        print(fmt_map(entries, 0 if args.full else getattr(args, "top", 25)))
    return 0


def cmd_sym(args):
    path = args.file.replace(os.sep, "/")
    if not os.path.isfile(path):
        print("找不到文件：%s" % path, file=sys.stderr)
        return 1
    d = parse_gd(path) if path.endswith(".gd") else parse_text(path)
    pat = re.compile(args.name)
    hits = [f for f in d["funcs"] if pat.search(f["name"])]
    if not hits:
        print("没匹配到函数 %r，候选：" % args.name, file=sys.stderr)
        for f in d["funcs"]:
            print("  L%-5d %s" % (f["line"], f["name"]), file=sys.stderr)
        return 1
    lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
    for f in hits:
        start = max(f["line"] - len(f.get("doc", [])) - 1, 0)
        j = f.get("end", f["line"])
        while j < len(lines) and (not lines[j].strip() or lines[j][0] in " \t"):
            j += 1
        while j > f["line"] and not lines[j - 1].strip():
            j -= 1
        print("--- %s L%d-%d（%d 行）---" % (path, f["line"], j, j - start))
        for k in range(start, j):
            print("%5d| %s" % (k + 1, lines[k]))
        print()
    return 0


def cmd_refs(args):
    path = args.file.replace(os.sep, "/")
    if not os.path.isfile(path):
        print("找不到文件：%s" % path, file=sys.stderr)
        return 1
    d = parse_gd(path)
    funcs = d["funcs"]
    lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
    names = {f["name"]: f for f in funcs}
    for f in funcs:
        found = set()
        for ln in lines[f["line"]: f["end"]]:
            if ln.lstrip().startswith("#"):
                continue
            for m in re.finditer(r"\b([A-Za-z_]\w*)\s*\(", ln):
                n = m.group(1)
                if n in names and n != f["name"]:
                    found.add(n)
        f["_calls"] = found
    pat = re.compile(args.name)
    hits = [f for f in funcs if pat.search(f["name"])]
    if not hits:
        print("没匹配到函数 %r，候选：" % args.name, file=sys.stderr)
        for f in funcs:
            print("  L%-5d %s" % (f["line"], f["name"]), file=sys.stderr)
        return 1
    for f in hits:
        callers = [g for g in funcs if f["name"] in g.get("_calls", set())]
        print("=== %s :: %s (L%d-%d，%d 行) ===" % (
            path, f["name"], f["line"], f["end"], f["end"] - f["line"] + 1))
        print("调用者 %d:" % len(callers))
        for g in sorted(callers, key=lambda x: x["line"]):
            print("  L%-5d %s" % (g["line"], g["name"]))
        if not callers:
            print("  （本文件内没有调用者：入口 / 信号回调 / 只在别处用）")
        called = sorted(f.get("_calls", ()), key=lambda x: names[x]["line"])
        print("被调用 %d（本文件内）: %s" % (len(called), ", ".join(called)))
        print()
    return 0


def cmd_callers(args):
    files = [f for f in expand(args.paths) if f.endswith(".gd")]
    pat = re.compile(r"\b" + re.escape(args.name) + r"\s*\(")
    defs, hits = [], []
    for path in files:
        d = parse_gd(path)
        lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
        for f in d["funcs"]:
            if f["name"] == args.name:
                defs.append((path, f["line"], f["end"] - f["line"] + 1))
                continue
            for k in range(f["line"], min(f["end"], len(lines))):
                if lines[k].lstrip().startswith("#"):
                    continue
                if pat.search(lines[k]):
                    hits.append((path, k + 1, f["name"]))
                    break
    print("=== callers %s（扫 %d 个 .gd）===" % (args.name, len(files)))
    print("定义 %d:" % len(defs))
    for p2, ln, size in defs:
        print("  %s:%d（%d 行）" % (p2, ln, size))
    if not defs:
        print("  （仓库里没有同名函数定义）")
    elif len(defs) > 1:
        print("  ⚠ 同名定义多（含 Array / Dictionary 等内置方法），调用点请按路径甄别")
    print("跨文件调用点 %d:" % len(hits))
    for p2, ln, fname in hits[: args.max]:
        print("  %s:%d  in %s" % (p2, ln, fname))
    if len(hits) > args.max:
        print("  … 其余 %d 处省略（--max 调整）" % (len(hits) - args.max))
    return 0


def cmd_lint(args):
    roots = args.paths or ["tools", "src", "tests"]
    files = expand(roots)
    red, yellow, nodoc, longf, hugef = [], [], [], [], []
    for path in files:
        d = parse_any(path)
        if d["lines"] >= 800:
            red.append((path, d["lines"]))
        elif d["lines"] >= 400:
            yellow.append((path, d["lines"]))
        if path.endswith(".gd"):
            if d["lines"] >= 200 and not d["doc"]:
                nodoc.append((path, d["lines"]))
            for f in d["funcs"]:
                if f["length"] >= 120:
                    hugef.append((path, f["name"], f["line"], f["length"]))
                elif f["length"] >= 80:
                    longf.append((path, f["name"], f["line"], f["length"]))
    print("大文件体检 · 阈值：文件 400（黄）/ 800（红）行，函数 80（黄）/ 120（红）行")
    print("范围：%s（默认跳过 addons/ .godot/ reports/）" % ", ".join(roots))
    print()
    print("红线文件 >=800 行：%d" % len(red))
    for path, ln in sorted(red, key=lambda x: -x[1]):
        print("  ⛔ %-46s %d 行" % (path, ln))
    print("黄线文件 400-799 行：%d" % len(yellow))
    for path, ln in sorted(yellow, key=lambda x: -x[1]):
        print("  ⚠  %-46s %d 行" % (path, ln))
    print("缺顶部 ## 说明（>=200 行的 .gd）：%d" % len(nodoc))
    for path, ln in sorted(nodoc, key=lambda x: -x[1]):
        print("  ⚠  %-46s %d 行" % (path, ln))
    print("超长函数 80-119 行：%d" % len(longf))
    for path, name, ln, size in sorted(longf, key=lambda x: -x[3]):
        print("  ⚠  %s:%d  %s（%d 行）" % (path, ln, name, size))
    print("红线函数 >=120 行：%d" % len(hugef))
    for path, name, ln, size in sorted(hugef, key=lambda x: -x[3]):
        print("  ⛔ %s:%d  %s（%d 行）" % (path, ln, name, size))
    print()
    print("处理办法：黄线先 outline / sym；红线禁止整读，改前 callers+refs 查调用方。")
    if args.strict and (red or hugef):
        return 1
    return 0


def cmd_grep(args):
    files = expand(args.paths, args.all)
    pat = re.compile(args.pattern, re.I if args.ignore_case else 0)
    shown, total = 0, 0
    for f in files:
        try:
            lines = Path(f).read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for idx, line in enumerate(lines):
            if pat.search(line):
                total += 1
                if shown < args.max:
                    print("%s:%d: %s" % (f, idx + 1, short(line, 200)))
                    shown += 1
    if total > shown:
        print("… 共 %d 处匹配，只显示前 %d 处（用 --max 调整）" % (total, shown))
    elif total == 0:
        print("没有匹配", file=sys.stderr)
        return 1
    return 0


def main(argv):
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--all", action="store_true", help="连 addons/.godot 一起扫")
    common.add_argument("--json", action="store_true", help="输出 JSON")
    common.add_argument("--full", action="store_true", help="展开全部（函数 / 节点 / 说明 / 索引）")

    p = argparse.ArgumentParser(prog="outline.py", description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("outline", parents=[common], help="打印文件结构大纲")
    s.add_argument("paths", nargs="*", default=[])
    s.add_argument("--doc", type=int, default=12, help="顶部说明最多打印几段（0=全部）")
    s.add_argument("--funcs", choices=["auto", "all", "none"], default="auto",
                   help="函数清单详略（auto=入口 + 大函数，默认）")
    s.add_argument("--nodes", choices=["top", "all"], default="top",
                   help="场景节点树：top=根 + 直接子节点（默认）")
    s.set_defaults(fn=cmd_outline)

    s = sub.add_parser("map", parents=[common], help="全仓索引：行数 + 用途")
    s.add_argument("paths", nargs="*", default=DEFAULT_ROOTS)
    s.add_argument("--top", type=int, default=25, help="只列最大的 N 个（0=全部）")
    s.set_defaults(fn=cmd_map)

    s = sub.add_parser("sym", parents=[common], help="只打印匹配的函数体")
    s.add_argument("file")
    s.add_argument("name")
    s.set_defaults(fn=cmd_sym)

    s = sub.add_parser("refs", parents=[common], help="谁调用了它 / 它调用了谁")
    s.add_argument("file")
    s.add_argument("name")
    s.set_defaults(fn=cmd_refs)

    s = sub.add_parser("callers", parents=[common], help="全仓查谁调用了它（跨文件）")
    s.add_argument("name")
    s.add_argument("paths", nargs="*", default=["src", "tools", "tests"])
    s.add_argument("--max", type=int, default=20, help="最多显示多少调用点")
    s.set_defaults(fn=cmd_callers)

    s = sub.add_parser("lint", parents=[common], help="大文件规范体检")
    s.add_argument("paths", nargs="*", default=["tools", "src", "tests"])
    s.add_argument("--strict", action="store_true", help="有红线时退出码非 0")
    s.set_defaults(fn=cmd_lint)

    s = sub.add_parser("grep", parents=[common], help="带行号搜索，不整读")
    s.add_argument("pattern")
    s.add_argument("paths", nargs="*", default=DEFAULT_ROOTS)
    s.add_argument("--max", type=int, default=40)
    s.add_argument("-i", "--ignore-case", action="store_true")
    s.set_defaults(fn=cmd_grep)

    args = p.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

