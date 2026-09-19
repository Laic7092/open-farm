#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""tools/check_docs.py — 体检 GDScript 的 `##` 文档注释。

Godot 自己不校验 doc comment 里的 BBCode：未知标签、没闭合的 [b]、引用到
不存在的类 / 方法 / 参数，`--check-only` 与 `--doctool` 都不吭声，渲染出来
才发现是乱码。这个脚本补这一刀。

用法：
  python3 tools/check_docs.py               # 扫 src/ tests/ tools/
  python3 tools/check_docs.py src/ui/       # 只扫指定路径
  python3 tools/check_docs.py --json        # 机器可读
  python3 tools/check_docs.py --strict      # 警告也当失败（CI 用）
  python3 tools/check_docs.py --no-engine   # 不调 Godot，只查项目内部引用
  python3 tools/check_docs.py --quiet       # 只回统计

查三类：
  错误  成对标签未闭合 / 多余闭合 / 嵌套错位；未知标签；空的 [param] [method] 等
  警告  引用到不存在的类 / 成员；[param x] 的 x 不在所属函数 / 信号签名里
  警告  行内 `#` 普通注释里写了文档标记（不会渲染，等于白写）

引擎类名单由 `godot --dump-extension-api` 生成（约 0.5 秒），缓存进
.tmp/check/；找不到 Godot 时自动跳过引擎侧校验，只查项目内部。
约定见 AGENTS.md。
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

SKIP_DIRS = {".git", ".godot", ".tmp", "reports", "addons", "__pycache__"}
DEFAULT_ROOTS = ["src", "tests", "tools"]
CACHE = Path(".tmp/check/extension_api.json")

# Godot 文档注释支持的 BBCode 标签（官方《GDScript documentation comments》）。
# 成对：必须 [/x] 收尾，允许带参数（[color=red] [/color]）。
PAIRED = {
    "b", "i", "u", "s", "code", "codeblock", "codeblocks", "kbd", "center",
    "url", "color", "font", "font_size", "bgcolor", "fgcolor",
    "gdscript", "csharp",
}
VOID = {"br", "lb", "rb", "p"}                 # 自闭合 / 无内容
RAW = {"code", "codeblock"}                    # 内部不解析其它标签
REF = {                                        # 引用标签，必须带参数
    "param", "method", "member", "constant", "signal", "enum",
    "annotation", "constructor", "operator", "theme_item", "class",
}
TAG_RE = re.compile(r"\[(/?)([A-Za-z_]\w*)((?:[ =][^\[\]\n]*)?)\]")
REF_KIND_SET = {
    "method": "methods", "member": "members", "constant": "constants",
    "signal": "signals", "enum": "enums", "class": "classes",
}


# ---------------------------------------------------------------- 数据结构

@dataclass
class Issue:
    level: str          # "error" | "warning"
    path: str
    line: int
    code: str
    message: str


@dataclass
class Decl:
    kind: str           # func / signal / var / const / enum / class / class_name
    name: str
    line: int
    indent: int = 0
    params: list = field(default_factory=list)


@dataclass
class Block:
    """一段（或一行行内的）`##` 文档注释。"""
    line: int
    indent: int
    text: str
    span: int = 1       # 占几行（行首块）
    inline: bool = False


@dataclass
class ClassInfo:
    name: str = ""
    path: str = ""
    extends: str = ""
    members: dict = field(default_factory=dict)   # kind -> set(name)

    def add(self, kind, name):
        self.members.setdefault(kind, set()).add(name)


# ---------------------------------------------------------------- 文本抽取

def strip_strings(line):
    """抠掉字符串字面量内容，免得代码里的引号 / ## 干扰判断。"""
    out, quote, i = [], "", 0
    while i < len(line):
        ch = line[i]
        if quote:
            if ch == "\\":
                out.append(" ")
                i += 2
                continue
            if ch == quote:
                quote = ""
            out.append(" ")
        elif ch in "\"'":
            quote = ch
            out.append(" ")
        else:
            out.append(ch)
        i += 1
    return "".join(out)


def parse_params(raw):
    """从签名括号里切出参数名：跳过默认值里的逗号 / 括号 / 字符串。"""
    names, depth, cur, quote = [], 0, "", ""
    for ch in raw:
        if quote:
            if ch == quote:
                quote = ""
            cur += ch
            continue
        if ch in "\"'":
            quote = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            names.append(cur)
            cur = ""
            continue
        cur += ch
    names.append(cur)
    out = []
    for item in names:
        item = item.strip().lstrip("*")          # 去掉 *args / **kwargs 的星号
        if not item:
            continue
        out.append(item.split("=")[0].split(":")[0].strip())
    return [n for n in out if n]


FUNC_RE = re.compile(r"^(\s*)(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(([^)]*)")
SIGNAL_RE = re.compile(r"^(\s*)signal\s+([A-Za-z_]\w*)\s*\(?([^)]*)")
VAR_RE = re.compile(r"^(\s*)(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?var\s+([A-Za-z_]\w*)")
CONST_RE = re.compile(r"^(\s*)const\s+([A-Za-z_]\w*)")
ENUM_RE = re.compile(r"^(\s*)enum\s*([A-Za-z_]\w*)")
CLASS_NAME_RE = re.compile(r"^(\s*)class_name\s+([A-Za-z_]\w*)")
INNER_RE = re.compile(r"^(\s*)class\s+([A-Za-z_]\w*)\s*(?:extends|:)")
EXTENDS_RE = re.compile(r"^(\s*)extends\s+([\w\"./]+)")
ENUM_DEF_RE = re.compile(r"^(\s*)enum\s+([A-Za-z_]\w*)")
ENUM_VALUE_RE = re.compile(r"\b([A-Z][A-Z0-9_]*)\b")
AUTOLOAD_RE = re.compile(r'^([A-Za-z_]\w*)\s*=\s*"\*?(res://[^"]+)"')


def parse_decl(code):
    """一行代码 → Decl；不是声明返回 None。"""
    for regex, kind, has_params in (
        (FUNC_RE, "func", True),
        (SIGNAL_RE, "signal", True),
        (CLASS_NAME_RE, "class_name", False),
        (CONST_RE, "const", False),
        (ENUM_RE, "enum", False),
        (VAR_RE, "var", False),
        (INNER_RE, "class", False),
    ):
        m = regex.match(code)
        if m:
            params = parse_params(m.group(3)) if has_params else []
            return Decl(kind, m.group(2), 0, len(m.group(1)), params)
    return None


def extract(lines):
    """返回 (blocks, decls)：文档块 + 全部声明（行号 → Decl）。"""
    blocks, decls = [], {}
    for idx, line in enumerate(lines):
        code = strip_strings(line)
        decl = parse_decl(code)
        if decl:
            decl.line = idx + 1
            decls[idx + 1] = decl
        m = re.match(r"^(\s*)##(?!#)\s?(.*)$", code)
        if m:
            if blocks and not blocks[-1].inline and blocks[-1].indent == len(m.group(1)) \
                    and blocks[-1].line + blocks[-1].span == idx + 1:
                blocks[-1].text += "\n" + m.group(2)
                blocks[-1].span += 1
            else:
                blocks.append(Block(idx + 1, len(m.group(1)), m.group(2)))
            continue
        pos = code.find("##")
        if pos > 0 and "#" not in code[pos + 2:pos + 3]:
            content = code[pos + 2:].lstrip()
            if content:
                blocks.append(Block(idx + 1, 0, content, inline=True))
    return blocks, decls


def bind(blocks, decls):
    """文档块 → 它注释的那个声明。

    只有紧邻（中间没有空行）才算挂在该成员上；`##` 块后隔了空行的是类级 /
    独立段落文档——Godot 就是这么分的，这里跟着走，别自己发明规则。
    """
    return {id(b): (decls.get(b.line) if b.inline else decls.get(b.line + b.span))
            for b in blocks}


# ---------------------------------------------------------------- 标签扫描

@dataclass
class Token:
    line: int
    name: str
    closing: bool
    arg: str = ""
    dangling: bool = False    # RAW 标签没找到闭合


def scan(text, start_line):
    toks, i, line = [], 0, start_line
    while i < len(text):
        ch = text[i]
        if ch == "\n":
            line += 1
            i += 1
            continue
        m = TAG_RE.match(text, i)
        if not m:
            i += 1
            continue
        closing, name, arg = bool(m.group(1)), m.group(2), m.group(3)
        toks.append(Token(line, name, closing, arg.strip()))
        i = m.end()
        if not closing and name in RAW:
            stop = text.find("[/%s]" % name, i)
            if stop < 0:
                toks[-1].dangling = True
                break
            line += text.count("\n", i, stop)
            i = stop
    return toks


# ---------------------------------------------------------------- 项目索引

def collect_files(roots, all_dirs=False):
    out, seen = [], set()
    for root in roots:
        p = Path(root)
        if p.is_file() and p.suffix == ".gd":
            files = [p]
        elif p.is_dir():
            files = [f for f in sorted(p.rglob("*.gd"))
                     if all_dirs or not any(part in SKIP_DIRS for part in f.parts)]
        else:
            print("⚠ 找不到：%s" % root, file=sys.stderr)
            continue
        for f in files:
            key = str(f).replace("\\", "/")
            if key not in seen:
                seen.add(key)
                out.append(f)
    return out


def load_autoloads(project_file="project.godot"):
    """project.godot 的 [autoload] 段：名字 → res:// 脚本。

    Autoload 名（EventBus / SaveManager…）就是 `##` 里引用的名字，得当类看。
    """
    try:
        text = Path(project_file).read_text(encoding="utf-8")
    except OSError:
        return {}
    out, inside = {}, False
    for line in text.splitlines():
        if line.startswith("["):
            inside = line.strip() == "[autoload]"
            continue
        if inside:
            m = AUTOLOAD_RE.match(line.strip())
            if m:
                out[m.group(1)] = m.group(2).replace("res://", "")
    return out


def scan_project(files, autoloads=None):
    """扫出所有 class_name / enum / autoload 及其成员，供引用校验用。"""
    index, by_path = {}, {}
    for path in files:
        key = str(path).replace("\\", "/")
        info = ClassInfo(path=key)
        by_path[key] = info
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except OSError:
            continue
        pending_enum = None
        for line in lines:
            code = strip_strings(line)
            m = EXTENDS_RE.match(code)
            if m and not info.extends:
                info.extends = m.group(2).strip('"')
            enum_def = ENUM_DEF_RE.match(code)
            if enum_def:                      # enum Name { A, B } 也是一种可引用名字
                pending_enum = ClassInfo(name=enum_def.group(2), path=key)
            if pending_enum is not None:
                for value in ENUM_VALUE_RE.findall(code.split("{", 1)[-1]):
                    pending_enum.add("constants", value)
                    pending_enum.add("enums", value)
                if "}" in code:
                    index.setdefault(pending_enum.name, pending_enum)
                    pending_enum = None
            decl = parse_decl(code)
            if decl:
                if decl.kind == "class_name":
                    info.name = decl.name
                else:
                    info.add({"func": "methods", "signal": "signals",
                              "const": "constants", "var": "members",
                              "enum": "enums", "class": "classes"}[decl.kind],
                             decl.name)
                    if decl.kind == "class":      # 内部类也能被 [Inner] 引用
                        index.setdefault(decl.name, info)
        if info.name:
            index[info.name] = info
    for name, rel in (autoloads or {}).items():
        if rel in by_path:
            index.setdefault(name, by_path[rel])
    return index


# ---------------------------------------------------------------- 引擎索引

def load_engine(bin_path, refresh=False):
    """引擎类名单：`godot --dump-extension-api` 生成，缓存到 .tmp/check/。"""
    if not bin_path or not Path(bin_path).exists():
        return None
    if refresh or not CACHE.exists():
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        try:
            subprocess.run([str(bin_path), "--headless", "--dump-extension-api"],
                           cwd=str(CACHE.parent), stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=120, check=True)
        except (OSError, subprocess.SubprocessError):
            return None
    try:
        raw = json.loads(CACHE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    classes = {}
    for cls in raw.get("classes", []):
        classes[cls["name"]] = {
            "inherits": cls.get("inherits", ""),
            "methods": {m["name"] for m in cls.get("methods", [])},
            "members": {p["name"] for p in cls.get("properties", [])},
            "constants": {c["name"] for c in cls.get("constants", [])},
            "signals": {s["name"] for s in cls.get("signals", [])},
            "enums": {e["name"] for e in cls.get("enums", [])},
            "classes": set(),
        }
        # 枚举值也当常量引用：[constant Control.MOUSE_FILTER_IGNORE]
        classes[cls["name"]]["constants"].update(
            v["name"] for e in cls.get("enums", []) for v in e.get("values", []))
    builtins = {b["name"] for b in raw.get("builtin_classes", [])}
    return {"classes": classes, "builtins": builtins}


def engine_lookup(engine, cls, kind, name, depth=0):
    """在引擎类（含继承链）里找成员。None = 链走到名单外，判不了。"""
    if not engine or depth > 32:
        return None
    info = engine["classes"].get(cls)
    if info is None:
        return None
    if name in info.get(kind, ()):
        return True
    parent = info.get("inherits", "")
    if not parent:
        return False
    return engine_lookup(engine, parent, kind, name, depth + 1)


def project_lookup(index, cls, kind, name, depth=0):
    """在项目类（含继承链）里找成员。None = 父类在项目外，判不了。"""
    if depth > 32:
        return None
    info = index.get(cls)
    if info is None:
        return None
    if name in info.members.get(kind, ()) or name in info.members.get("classes", ()):
        return True
    parent = info.extends
    if not parent:
        return False
    if parent not in index:
        # 父类是引擎类 / 外部脚本：交给引擎侧继续查
        return None
    return project_lookup(index, parent, kind, name, depth + 1)


def resolve(index, engine, cls, kind, name):
    """True 存在 / False 确定不存在 / None 无从判断。"""
    if cls in index:
        return project_lookup(index, cls, kind, name)
    if engine and cls in engine["classes"]:
        return engine_lookup(engine, cls, kind, name)
    return None


# ---------------------------------------------------------------- 校验

def check_ref_tag(tok, ctx, owner, index, engine, path, issues):
    """带参数的引用标签：[param x] / [method Class.m] / [member m] …"""
    arg = tok.arg
    if tok.name == "param":
        if not arg:
            issues.append(Issue("error", path, tok.line, "E-EMPTY",
                                "[param] 后面缺参数名"))
        elif ctx and ctx.kind in ("func", "signal") and ctx.params and arg not in ctx.params:
            issues.append(Issue("warning", path, tok.line, "W-PARAM",
                                "[param %s] 不在 %s %s 的参数表（%s）"
                                % (arg, ctx.kind, ctx.name, ", ".join(ctx.params))))
        return
    if not arg or "=" in arg:
        issues.append(Issue("error", path, tok.line, "E-EMPTY",
                            "[%s] 的参数不合法：%s" % (tok.name, arg or "空")))
        return
    kind = REF_KIND_SET.get(tok.name)
    parts = arg.split(".")
    if len(parts) > 2:
        # 链式路径（[signal EventBus.player.changed] / [constant A.B.C]）：
        # 静态查不下去，只确认最外层那个类存在
        root = parts[0]
        if root not in index and not (engine and root in engine["classes"]):
            issues.append(Issue("warning", path, tok.line, "W-CLASS",
                                "[%s %s] 的类 %s 不存在" % (tok.name, arg, root)))
        return
    if kind and len(parts) == 1:
        # 裸成员名：只能在所属类里找，类不明（如类级文档）就不判
        if owner and resolve(index, engine, owner, kind, parts[0]) is False:
            issues.append(Issue("warning", path, tok.line, "W-MEMBER",
                                "[%s %s] 在 %s 里找不到" % (tok.name, arg, owner)))
        return
    cls, member = ".".join(parts[:-1]), parts[-1]
    if kind and (cls in index or (engine and cls in engine["classes"])):
        if resolve(index, engine, cls, kind, member) is False:
            issues.append(Issue("warning", path, tok.line, "W-MEMBER",
                                "[%s %s]：%s 里没有 %s" % (tok.name, arg, cls, member)))
        return
    if engine and cls not in engine["builtins"] and cls not in index \
            and cls not in engine["classes"]:
        issues.append(Issue("warning", path, tok.line, "W-CLASS",
                            "[%s %s] 的类 %s 不存在" % (tok.name, arg, cls)))


def check_bare_ref(tok, index, engine, path, issues):
    """裸引用：[Node] / [WaterKind.Kind] / [Vector2i]。"""
    target = tok.name
    parts = target.split(".")
    head = parts[0]
    if len(parts) > 2:              # 链式路径：只确认识别得出最外层
        if head not in index and not (engine and head in engine["classes"]):
            if engine:
                issues.append(Issue("warning", path, tok.line, "W-CLASS",
                                    "[%s] 不是已知的类或枚举" % target))
        return
    if not head[:1].isupper():
        issues.append(Issue("error", path, tok.line, "E-TAG",
                            "未知标签 [%s]" % target))
        return
    if engine and head in engine["builtins"]:
        return
    if head not in index and not (engine and head in engine["classes"]):
        if engine:      # 没有引擎名单时不判，免得满屏误报
            issues.append(Issue("warning", path, tok.line, "W-CLASS",
                                "[%s] 不是已知的类或枚举" % target))
        return
    if len(parts) > 1:
        tail = parts[1]
        hits = [resolve(index, engine, head, kind, tail)
                for kind in ("enums", "members", "constants", "methods", "classes")]
        if hits and all(h is False for h in hits):
            issues.append(Issue("warning", path, tok.line, "W-MEMBER",
                                "[%s]：%s 里没有 %s" % (target, head, tail)))


def check_block(block, ctx, owner, index, engine, path, issues):
    toks = scan(block.text, block.line)
    stack = []
    for tok in toks:
        if tok.dangling:
            issues.append(Issue("error", path, tok.line, "E-UNCLOSED",
                                "[%s] 没有闭合" % tok.name))
            continue
        if tok.closing:
            if not stack:
                issues.append(Issue("error", path, tok.line, "E-STRAY",
                                    "多余的 [/%s]，前面没有对应的 [%s]" % (tok.name, tok.name)))
            elif stack[-1].name != tok.name:
                issues.append(Issue("error", path, tok.line, "E-NEST",
                                    "[/%s] 对不上，最近打开的是 [%s]"
                                    % (tok.name, stack[-1].name)))
                stack.pop()
            else:
                stack.pop()
            continue
        if tok.name in PAIRED:
            stack.append(tok)
        elif tok.name in VOID:
            if tok.arg:
                issues.append(Issue("error", path, tok.line, "E-ARG",
                                    "[%s] 不接受参数：%s" % (tok.name, tok.arg)))
        elif tok.name in REF:
            check_ref_tag(tok, ctx, owner, index, engine, path, issues)
        else:                          # 裸类名 / 枚举引用
            check_bare_ref(tok, index, engine, path, issues)
    for tok in stack:
        issues.append(Issue("error", path, tok.line, "E-UNCLOSED",
                            "[%s] 没有闭合（缺 [/%s]）" % (tok.name, tok.name)))


def check_plain_comments(lines, path, issues):
    """`#` 普通注释里写文档标记 —— 不会渲染，等于白写（提示级）。"""
    paired = re.compile(r"\[(/?)(b|i|code|kbd|br|center|u|s)\]")
    with_arg = re.compile(r"\[(param|method|member|constant|signal|enum|class) [^\]]+\]")
    for idx, line in enumerate(lines):
        code = strip_strings(line)
        if not re.match(r"^\s*#(?!#)", code):
            continue
        m = paired.search(code) or with_arg.search(code)
        if m:
            issues.append(Issue("note", path, idx + 1, "N-PLAIN",
                                "普通注释里写了文档标记 %s，Godot 不会渲染" % m.group(0)))


def check_file(path, index, engine, issues):
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return 0
    blocks, decls = extract(lines)
    bound = bind(blocks, decls)
    owner = next((d.name for d in decls.values() if d.kind == "class_name"), "")
    for block in blocks:
        check_block(block, bound.get(id(block)), owner, index, engine, str(path), issues)
    check_plain_comments(lines, str(path), issues)
    return len(blocks)


def main(argv=None):
    ap = argparse.ArgumentParser(description="校验 GDScript 的 ## 文档注释")
    ap.add_argument("paths", nargs="*", default=None, help="要扫的目录 / 文件（默认 %s）"
                                                          % " ".join(DEFAULT_ROOTS))
    ap.add_argument("--json", action="store_true", help="输出 JSON")
    ap.add_argument("--strict", action="store_true", help="警告也算失败")
    ap.add_argument("--quiet", action="store_true", help="只回统计")
    ap.add_argument("--no-engine", action="store_true", help="不加载引擎类名单")
    ap.add_argument("--refresh-engine", action="store_true", help="重建引擎类名单缓存")
    ap.add_argument("--godot", default="./godot", help="Godot 可执行文件（默认 ./godot）")
    ap.add_argument("--all", action="store_true", help="连 addons/ .godot/ 一起扫")
    args = ap.parse_args(argv)

    files = collect_files(args.paths or DEFAULT_ROOTS, args.all)
    if not files:
        print("没有找到 .gd 文件", file=sys.stderr)
        return 2

    index = scan_project(files, load_autoloads())
    engine = None if args.no_engine else load_engine(args.godot, args.refresh_engine)

    issues, total_blocks = [], 0
    for path in files:
        total_blocks += check_file(path, index, engine, issues)

    errors = [i for i in issues if i.level == "error"]
    warnings = [i for i in issues if i.level == "warning"]
    notes = [i for i in issues if i.level == "note"]
    if args.json:
        print(json.dumps({
            "files": len(files), "blocks": total_blocks,
            "errors": len(errors), "warnings": len(warnings), "notes": len(notes),
            "issues": [vars(i) for i in issues],
        }, ensure_ascii=False, indent=2))
    else:
        by_line = {}
        for path in files:
            try:
                by_line[str(path)] = path.read_text(encoding="utf-8").splitlines()
            except OSError:
                by_line[str(path)] = []
        if not args.quiet:
            order = {"error": 0, "warning": 1, "note": 2}
            marks = {"error": "✗", "warning": "⚠", "note": "·"}
            for issue in sorted(issues, key=lambda i: (order[i.level], i.path, i.line)):
                print("%s %s:%d  %s  %s" % (marks[issue.level], issue.path, issue.line,
                                            issue.code, issue.message))
                src = by_line.get(issue.path, [])
                if 0 < issue.line <= len(src):
                    print("    %d | %s" % (issue.line, src[issue.line - 1].strip()))
        engine_note = "引擎类名单已加载" if engine else "未加载引擎类名单"
        print("统计：%d 个文件 / %d 个文档块；错误 %d，警告 %d，提示 %d（%s）"
              % (len(files), total_blocks, len(errors), len(warnings), len(notes), engine_note))

    if errors:
        return 1
    return 1 if (args.strict and warnings) else 0


if __name__ == "__main__":
    sys.exit(main())
