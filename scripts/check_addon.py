"""Static checks for the addon, runnable without WoW or Lua.

Usage: python scripts/check_addon.py [addon_folder]

1. Every file referenced from the .toc and from <Script>/<Include> in XML exists,
   with exact case (WoW on macOS is case-sensitive).
2. No packager-only markers (@do-not-package@, @debug@, @non-debug@) remain in
   our own Lua/XML/TOC files. Code inside those blocks behaves differently in a
   git clone than in a packaged build (see docs/decisions.md, C1).
3. Our Lua files have balanced blocks (function/if/do/repeat vs end/until) and
   brackets. Not a parser, but it catches most broken edits without Lua installed.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MARKERS = re.compile(r"@(do-not-package|end-do-not-package|debug|end-debug|non-debug|end-non-debug)@")
XML_REF = re.compile(r'<(?:Script|Include)\s+file="([^"]+)"')
XML_COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
# Packager markers inside third-party libraries are not ours to remove.
SKIP_MARKER_DIRS = {"Libs"}


def rel(path: Path):
    return path.relative_to(ROOT) if path.is_relative_to(ROOT) else path


def exists_exact_case(path: Path) -> bool:
    """Path.exists() is case-insensitive on Windows; walk each part instead."""
    current = Path(path.anchor) if path.is_absolute() else Path(".")
    for part in path.parts[1:] if path.is_absolute() else path.parts:
        if part in ("..", "."):
            current = current / part
            continue
        try:
            names = {p.name for p in current.iterdir()}
        except (FileNotFoundError, NotADirectoryError):
            return False
        if part not in names:
            return False
        current = current / part
    return True


def check_refs(addon: Path) -> list[str]:
    errors = []
    seen = set()

    def visit(file: Path, referrer: str):
        key = file.resolve()
        if key in seen:
            return
        seen.add(key)
        if not exists_exact_case(file.resolve()):
            errors.append(f"missing: {rel(file)} (from {referrer})")
            return
        if file.suffix.lower() == ".xml":
            text = XML_COMMENT.sub("", file.read_text(encoding="utf-8", errors="replace"))
            for ref in XML_REF.findall(text):
                visit(file.parent / ref.replace("\\", "/"), file.name)

    for toc in sorted(addon.glob("*.toc")):
        for line in toc.read_text(encoding="utf-8-sig", errors="replace").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            visit(addon / line.replace("\\", "/"), toc.name)
    return errors


def check_markers(addon: Path) -> list[str]:
    errors = []
    for file in addon.rglob("*"):
        if file.suffix.lower() not in (".lua", ".xml", ".toc"):
            continue
        if SKIP_MARKER_DIRS & set(file.relative_to(addon).parts):
            continue
        for n, line in enumerate(file.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if MARKERS.search(line):
                errors.append(f"packager marker: {rel(file)}:{n}: {line.strip()}")
    return errors


LUA_TOKEN = re.compile(
    r"""--\[(?P<cl>=*)\[.*?\](?P=cl)\]"""   # long comment
    r"""|--[^\n]*"""                         # line comment
    r"""|\[(?P<sl>=*)\[.*?\](?P=sl)\]"""     # long string
    r"""|"(?:\\.|[^"\\\n])*\""""            # "string"
    r"""|'(?:\\.|[^'\\\n])*'"""              # 'string'
    r"""|(?P<word>[A-Za-z_][A-Za-z0-9_]*)"""
    r"""|(?P<br>[(){}\[\]])""",
    re.DOTALL,
)
OPENERS = {"function", "if", "do", "repeat"}
CLOSERS = {"end", "until"}
PAIRS = {")": "(", "}": "{", "]": "["}


def check_lua_balance(addon: Path) -> list[str]:
    """Cheap syntax guard without a Lua interpreter: block keywords and brackets must balance.
    `for`/`while` are counted through their `do`."""
    errors = []
    for file in addon.rglob("*.lua"):
        if "Libs" in file.relative_to(addon).parts and "LibEventSourcing" not in file.parts:
            continue
        text = file.read_text(encoding="utf-8", errors="replace")
        depth, stack, problem = 0, [], None
        for m in LUA_TOKEN.finditer(text):
            line = text.count("\n", 0, m.start()) + 1
            word, br = m.group("word"), m.group("br")
            if word in OPENERS:
                depth += 1
            elif word in CLOSERS:
                depth -= 1
                if depth < 0:
                    problem = f"unexpected '{word}' at line {line}"
                    break
            elif br and br in "({[":
                stack.append((br, line))
            elif br:
                if not stack or stack[-1][0] != PAIRS[br]:
                    problem = f"unmatched '{br}' at line {line}"
                    break
                stack.pop()
        if problem is None and depth != 0:
            problem = f"{depth} block(s) not closed with 'end'"
        if problem is None and stack:
            problem = f"'{stack[-1][0]}' from line {stack[-1][1]} not closed"
        if problem:
            errors.append(f"lua balance: {rel(file)}: {problem}")
    return errors


def main() -> int:
    addons = [Path(a).resolve() for a in sys.argv[1:]] or sorted(
        p.parent for p in ROOT.glob("*/*.toc") if p.parent.name == p.stem
    )
    errors = []
    for addon in addons:
        errors += check_refs(addon)
        errors += check_markers(addon)
        errors += check_lua_balance(addon)
    for e in errors:
        print(e)
    print(f"{len(errors)} problem(s) in {', '.join(a.name for a in addons)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
