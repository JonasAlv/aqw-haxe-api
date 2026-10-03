#!/usr/bin/env python3
"""
Audit skills.json against the real SkillDslParser semantics.

This is a faithful Python port of the branching in
aqw-haxe-api/src/com/aqwapi/utils/SkillDslParser.hx (parseCombo/splitCombo/
parseRule/parseStatRule) and the Aura branch of
aqw-haxe-api/src/com/aqwapi/combat/SkillRules.hx, so it reports what the
engine will *actually* do rather than what the text looks like.

Usage:  python3 tools/audit_skills.py [path/to/skills.json]
Exit code 1 if any ERROR-severity finding is present.
"""

import json
import os
import re
import sys

DEFAULT = os.path.join(
    os.path.dirname(__file__), "..", "..",
    "aqw-mobile-mod", "loader", "assets", "skills.json",
)

# Punctuation the parser keeps as part of an aura name. getStacks() does an
# exact lowercased compare, so any of these makes the lookup miss.
NAME_NOISE = re.compile(r"[!.]+$")


def split_combo(s):
    """Port of SkillDslParser.splitCombo - bracket aware."""
    toks, cur, depth = [], [], 0
    for ch in s:
        if ch == "[":
            depth += 1
            cur.append(ch)
        elif ch == "]":
            if depth > 0:
                depth -= 1
            cur.append(ch)
        elif ch == ">" and depth == 0:
            t = "".join(cur).strip()
            if t:
                toks.append(t)
            cur = []
        else:
            cur.append(ch)
    t = "".join(cur).strip()
    if t:
        toks.append(t)
    return toks


def _cmp(after):
    """Port of the comparator ladder -> (comparison, value_string)."""
    for op, comp, n in ((">=", "greater", 2), ("<=", "less", 2),
                        (">", "greater", 1), ("<", "less", 1),
                        ("==", "equal", 2), ("=", "equal", 1)):
        if after.startswith(op):
            return comp, after[n:].strip()
    return None, after


def _num(text):
    return float(re.sub(r"[^0-9.\-]", "", text) or 0)


def parse_rule(r):
    """Port of parseRule. Returns (rule_or_None, branch_label, note)."""
    low = r.lower()

    # 1. Wait
    if low.startswith("wait("):
        return {"type": "Wait", "timeout": _num(r[5:-1])}, "Wait", None

    # 2/3. Target HP / health
    for pfx, kind in (("target:hp", "TargetHealth"), ("tgt:hp", "TargetHealth"),
                      ("target_hp", "TargetHealth"), ("target.hp", "TargetHealth"),
                      ("mon:hp", "TargetHealth"), ("target_hp", "TargetHealth"),
                      ("target:health", "TargetHealth"), ("tgt:health", "TargetHealth"),
                      ("mon:health", "TargetHealth")):
        if low.startswith(pfx):
            i = low.index("hp") if "hp" in pfx else low.index("health")
            key = "hp" if pfx.endswith("hp") else "health"
            sub = r[i + len(key) + 2:].lstrip()
            if sub.startswith(":"):
                sub = sub[1:]
            comp, val = _cmp(sub.strip())
            v = _num(val)
            return ({"type": kind, "comparison": comp or "greater", "value": v,
                     "isPercentage": "%" in (val or "") or (v <= 100 and "%" in sub)},
                    kind, None)

    # 4. Party
    for pfx, key in (("party:hp", "hp"), ("party_hp", "hp"), ("party.hp", "hp"),
                     ("party:health", "health")):
        if low.startswith(pfx):
            sub = r[len(pfx):].lstrip()
            if sub.startswith(":"):
                sub = sub[1:]
            comp, val = _cmp(sub.strip())
            v = _num(val)
            return ({"type": "PartyHealth", "comparison": comp or "greater", "value": v,
                     "isPercentage": "%" in (val or "")},
                    "PartyHealth", None)

    # 5. Health / HP
    for pfx in ("health", "hp"):
        if low.startswith(pfx):
            sub = r[len(pfx) + 2:] if pfx == "health" else r[len(pfx) + 2:]
            sub = sub.lstrip()
            if sub.startswith(":"):
                sub = sub[1:]
            comp, val = _cmp(sub.strip())
            v = _num(val)
            return ({"type": "Health", "comparison": comp or "greater", "value": v,
                     "isPercentage": "%" in (val or "")},
                    "Health", None)

    # 6. Mana / MP
    for pfx in ("mana", "mp"):
        if low.startswith(pfx):
            sub = r[len(pfx) + 2:].lstrip()
            if sub.startswith(":"):
                sub = sub[1:]
            comp, val = _cmp(sub.strip())
            v = _num(val)
            return ({"type": "Mana", "comparison": comp or "greater", "value": v,
                     "isPercentage": "%" in (val or "")},
                    "Mana", None)

    # 7. Aura timer
    for pfx, lbl in (("auratime(", "AuraTime"), ("aura_time(", "AuraTime"),
                     ("auratimer(", "AuraTime"), ("auraremaining(", "AuraTime")):
        if pfx in low:
            ai = low.index(pfx)
            op = ai + len(pfx)
            cl = r.find(")", op)
            if cl != -1:
                inside = r[op:cl]
                after = r[cl + 1:].strip()
                target, name = "self", inside
                if ":" in inside:
                    target, name = (x.strip() for x in inside.split(":", 1))
                comp, val = _cmp(after)
                v = _num(val)
                afterl = (val or "").lower()
                is_ms = "ms" in afterl
                clean = afterl.replace("ms", "").replace("s", "")
                pv = _num(clean)
                if is_ms:
                    pv /= 1000.0
                elif pv > 60 and "s" not in afterl:
                    pv /= 1000.0
                return ({"type": "AuraTime", "auraName": name, "auraTarget": target.lower(),
                         "comparison": comp or "less", "value": pv}, "AuraTime", None)

    # 8. Aura
    if "aura(" in low:
        ai = low.index("aura(")
        neg = ai > 0 and r[ai - 1] == "!"
        cl = r.find(")", ai + 5)
        if cl != -1:
            inside = r[ai + 5:cl]
            after = r[cl + 1:].strip()
            target, name = "self", inside
            if ":" in inside:
                target, name = (x.strip() for x in inside.split(":", 1))
            comp, val = _cmp(after)
            comp = comp or ("less" if neg else "greater")
            v = _num(val) if comp is not None else 0.0
            note = None
            if target.startswith("!"):
                note = "negation written INSIDE the parens - corrupt target %r" % target
            elif NAME_NOISE.search(name):
                note = "aura name ends in %r - getStacks compares exactly, so this never matches" \
                       % NAME_NOISE.search(name).group(0)
            elif not neg and ai > 0 and r[ai - 1] != "!":
                note = None
            return ({"type": "Aura", "auraName": name, "auraTarget": target.lower(),
                     "comparison": comp, "value": v, "negated": neg}, "Aura", note)

    return None, None, "no parser branch matches - rule is SILENTLY DROPPED"


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    data = json.load(open(path))
    errors, warns, info = [], [], []

    for cls, modes in data.items():
        for mode, cfg in modes.items():
            where = f"{cls} / {mode}"
            combo = cfg.get("combo", "") or ""
            timeout = cfg.get("timeout", 0)
            mode_kind = cfg.get("mode", "WaitForCooldown")

            if not combo:
                errors.append((where, "mode has no combo - CombatEngine falls back to runSimpleRotation"))
                continue

            steps = split_combo(combo)
            if len(steps) == 1 and ">" not in combo:
                pass

            slots = []
            for step in steps:
                if step.count("[") != step.count("]"):
                    errors.append((where, f"unbalanced brackets in step {step!r}"))
                    continue
                sid_txt = step.split("[")[0].strip()
                try:
                    sid = int(sid_txt)
                except ValueError:
                    errors.append((where, f"slot id {sid_txt!r} is not an integer (step {step!r})"))
                    continue
                slots.append(sid)
                if sid < 0 or sid > 5:
                    errors.append((where, f"slot id {sid} out of range 0-5 - engine rejects and advances (step {step!r})"))

                if "[" not in step:
                    continue
                rules_txt = step[step.index("[") + 1:step.rindex("]")]
                sep = "|" if "|" in rules_txt else "&"
                for rtxt in [x.strip() for x in rules_txt.split(sep)]:
                    if not rtxt:
                        continue
                    rule, branch, note = parse_rule(rtxt)
                    if rule is None:
                        errors.append((where, f"rule {rtxt!r}: {note}"))
                        continue
                    if note:
                        errors.append((where, f"rule {rtxt!r}: {note}"))
                    if rule["type"] in ("Aura", "AuraTime"):
                        nm = rule["auraName"]
                        if nm != nm.strip():
                            warns.append((where, f"aura name {nm!r} has stray whitespace"))
                    if rule["type"] in ("Health", "Mana", "TargetHealth"):
                        # parseStatRule: value > 100 forces isPercentage=false
                        pct = rule.get("isPercentage")
                        v = rule.get("value", 0)
                        if pct is False and 0 < v <= 100:
                            warns.append((where, f"{rule['type']} rule {rtxt!r}: {v:g} without '%' "
                                                 f"-> compared as an ABSOLUTE value, not a percentage"))

            if mode_kind == "WaitForCooldown":
                if not isinstance(timeout, (int, float)) or timeout <= 0:
                    warns.append((where, f"timeout={timeout!r} -> waits INDEFINITELY (can trap)"))
                run = 1
                best = None
                for a, b in zip(slots, slots[1:]):
                    run = run + 1 if a == b else 1
                    if best is None or run > best[0]:
                        best = (run, a)
                if best and best[0] > 1:
                    budget = 1500 + (timeout if isinstance(timeout, (int, float)) else 0)
                    stall = best[0] * budget
                    if stall > 5000:
                        warns.append((where, f"slot {best[1]} repeats {best[0]}x consecutively -> "
                                             f"worst-case stall ~{stall/1000:.1f}s"))
            else:
                info.append((where, "UseIfAvailable - no cursor, cannot stall"))

    print(f"  {os.path.basename(path)}: {len(data)} classes\n")

    for title, rows in (("ERRORS", errors), ("WARNINGS", warns)):
        if not rows:
            continue
        print(f"  {title} ({len(rows)}):")
        seen = {}
        for where, msg in rows:
            seen.setdefault(msg.split(":")[0][:70], []).append((where, msg))
        for _, group in seen.items():
            for where, msg in group[:4]:
                print(f"    {where}")
                print(f"        {msg}")
            if len(group) > 4:
                print(f"    ... and {len(group)-4} more like these")
        print()

    print(f"  summary: {len(errors)} error(s), {len(warns)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())