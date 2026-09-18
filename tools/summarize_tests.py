#!/usr/bin/env python3
"""把 gdUnit4 的 JUnit XML 报告压成几行摘要。

用法：
    python3 tools/summarize_tests.py <.tmp/check/reports/report_N/results.xml>

gdUnit4 控制台默认逐条打印每个用例，一次全量跑会刷出上千行；`tools/check.sh`
把它重定向到日志，再用本脚本只打印统计与失败明细。退出码与测试结果一致
（0 通过 / 1 有失败 / 2 报告不可读）。
"""
import sys
import xml.etree.ElementTree as ET

CDATA_ANSI = None


def _detail(node):
    """取 failure / error 里的断言信息（去掉堆栈、折成一行）。"""
    text = (node.text or "").strip()
    text = text.split("\n\tat ")[0].split("\nat ")[0]
    return " ".join(text.split())


def main(argv):
    if len(argv) != 1:
        print("用法：python3 tools/summarize_tests.py <results.xml>", file=sys.stderr)
        return 2
    try:
        root = ET.parse(argv[0]).getroot()
    except (OSError, ET.ParseError) as exc:
        print("无法解析测试报告 %s：%s" % (argv[0], exc), file=sys.stderr)
        return 2

    suites = root.findall("testsuite")
    total = int(root.get("tests", 0))
    failures = int(root.get("failures", 0))
    skipped = int(root.get("skipped", 0))
    flaky = int(root.get("flaky", 0))
    errors = sum(int(s.get("errors", 0)) for s in suites)
    seconds = sum(float(s.get("time", 0) or 0) for s in suites)

    failed = []
    for suite in suites:
        for case in suite.findall("testcase"):
            for tag in ("failure", "error"):
                node = case.find(tag)
                if node is None:
                    continue
                failed.append((case.get("classname", "?"), case.get("name", "?"),
                               node.get("message", ""), _detail(node)))

    passed = total - failures - errors - skipped
    if not failed:
        print("单元测试：%d/%d 套件，%d/%d 用例通过（%.1fs）"
              % (len(suites), len(suites), passed, total, seconds))
        if flaky or skipped:
            print("  （flaky %d / skipped %d）" % (flaky, skipped))
        return 0

    print("单元测试：%d 用例，%d 失败 / %d 错误（%.1fs）"
          % (total, failures, errors, seconds))
    for classname, name, message, detail in failed:
        location = message.split(": ", 1)[-1] if message else ""
        print("  ✗ %s::%s  %s" % (classname, name, location))
        if detail:
            print("      %s" % detail[:200])
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
