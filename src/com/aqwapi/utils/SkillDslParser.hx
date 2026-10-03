package com.aqwapi.utils;

class SkillDslParser {
    /**
     * Parses the 1-liner combo DSL text format into the exact structure
     * expected by CombatEngine (_skillsData).
     *
     * Format:
     *   [ClassName : ModeName]
     *   mode = WaitForCooldown | UseIfAvailable
     *   timeout = 100
     *   combo = 1 > 2[hp < 50%] > 3[!aura(self:Buff)] > 4[mp < 10%]
     */
    public static function parse(txt:String):Dynamic {
        if (txt == null || txt.length == 0) return {};

        var result:Dynamic = {};
        var currentClass:String = null;
        var currentMode:String = "Base";
        var currentData:Dynamic = null;

        var lines:Array<String> = txt.split("\n");
        for (rawLine in lines) {
            var line:String = StringTools.trim(rawLine);
            if (line.length == 0 || StringTools.startsWith(line, "#") || StringTools.startsWith(line, "//")) {
                continue;
            }

            // Section header: [ClassName : ModeName] or [ClassName]
            if (StringTools.startsWith(line, "[") && StringTools.endsWith(line, "]")) {
                var inner:String = line.substring(1, line.length - 1);
                var colonIdx:Int = inner.indexOf(":");
                if (colonIdx != -1) {
                    currentClass = StringTools.trim(inner.substring(0, colonIdx));
                    currentMode = StringTools.trim(inner.substring(colonIdx + 1));
                } else {
                    currentClass = StringTools.trim(inner);
                    currentMode = "Base";
                }

                currentData = null;
                if (currentClass != "" && currentMode != "") {
                    var classObj:Dynamic = Reflect.field(result, currentClass);
                    if (classObj == null) {
                        classObj = {};
                        Reflect.setField(result, currentClass, classObj);
                    }
                    currentData = {
                        skillUseMode: "WaitForCooldown",
                        skillTimeout: 0,
                        skills: [],
                        combo: ""
                    };
                    Reflect.setField(classObj, currentMode, currentData);
                }
                continue;
            }

            if (currentData == null) continue;

            // Key = Value
            var eqIdx:Int = line.indexOf("=");
            if (eqIdx == -1) continue;

            var key:String = StringTools.trim(line.substring(0, eqIdx)).toLowerCase();
            var val:String = StringTools.trim(line.substring(eqIdx + 1));

            switch (key) {
                case "mode", "skillusemode":
                    var lowerVal:String = val.toLowerCase();
                    if (lowerVal == "useifavailable" || lowerVal == "priority" || lowerVal == "avail") {
                        currentData.skillUseMode = "UseIfAvailable";
                    } else {
                        currentData.skillUseMode = "WaitForCooldown";
                    }

                case "timeout", "skilltimeout":
                    var pTo:Null<Int> = Std.parseInt(val);
                    // 0 (or an unparseable value) means "wait indefinitely", matching the
                    // runtime gate in CombatEngine.runWaitForCooldown.
                    currentData.skillTimeout = (pTo != null) ? pTo : 0;

                case "stopontargetauras", "stop_on_target_auras", "stopauras":
                    currentData.stopOnTargetAuras = val;

                case "resetcomboontargetchange", "resetontarget":
                    var lowerVal:String = val.toLowerCase();
                    currentData.resetComboOnTargetChange = (lowerVal == "true" || lowerVal == "1" || lowerVal == "yes");

                case "combo", "skills", "rotation":
                    currentData.combo = val;
                    currentData.skills = parseCombo(val);
            }
        }

        return result;
    }

    /**
     * Every distinct aura name a combo already references, in first-seen order.
     *
     * The editor's aura picker offers the auras that are active RIGHT NOW, which cannot express
     * the common case of `aura(self:Tracer Rounds)` written while the buff is down. Feeding these
     * back into the picker keeps a name selectable once it has been used.
     */
    public static function collectAuraNames(comboStr:String):Array<String> {
        var out:Array<String> = [];
        if (comboStr == null || comboStr.length == 0) return out;

        var steps:Array<Dynamic> = parseCombo(comboStr);
        for (step in steps) {
            var rules:Array<Dynamic> = (step != null && step.rules != null) ? cast step.rules : [];
            for (rule in rules) {
                if (rule == null) continue;
                var type:String = Std.string(rule.type);
                if (type != "Aura" && type != "MultiAura" && type != "AuraTime"
                    && type != "AuraRemaining" && type != "AuraTimer") continue;
                var name:String = (rule.auraName != null) ? Std.string(rule.auraName) : "";
                if (name == "" || name.toLowerCase() == "name") continue;
                var exists = false;
                for (e in out) {
                    if (e == name) {
                        exists = true;
                        break;
                    }
                }
                if (!exists) out.push(name);
            }
        }
        return out;
    }

    /**
     * Checks a combo string WITHOUT saving it, reporting everything that would be silently
     * mangled by parseCombo.
     *
     * This exists because the parser's failure mode is silence: an unrecognised condition is
     * dropped, a non-numeric step becomes skill 1, and an empty rule list means the step fires
     * unconditionally. All three used to surface as a green "Saved" toast and then simply never
     * work.
     *
     * Only `Diagnostic.ERROR` blocks a save. Warnings describe configs that parse but almost
     * certainly do not mean what the author intended.
     */
    public static function validate(comboStr:String):Array<Diagnostic> {
        var out:Array<Diagnostic> = [];

        if (comboStr == null || StringTools.trim(comboStr).length == 0) {
            out.push(new Diagnostic(Diagnostic.ERROR, "Combo is empty.", -1, ""));
            return out;
        }

        // `|` is only meaningful INSIDE brackets, where it means OR. Outside them it is not a
        // step separator - the step delimiter is `>`. Catch the common mistake of writing
        // "1[...] | 2[...]", which parseCombo folds into a single malformed step.
        var outsidePipe = findOutsideBrackets(comboStr, "|");
        if (outsidePipe != null) {
            out.push(new Diagnostic(Diagnostic.ERROR,
                "'|' does not separate steps - use '>'. Steps are joined with '>' (a '|' inside brackets is OR).",
                -1, outsidePipe));
        }

        var tokens:Array<String> = splitCombo(comboStr);
        var stepCount = 0;
        for (i in 0...tokens.length) {
            var part:String = StringTools.trim(tokens[i]);
            if (part.length == 0) continue;
            stepCount++;
            validateStep(part, i, out);
        }

        if (stepCount == 0) {
            out.push(new Diagnostic(Diagnostic.ERROR, "No skill steps found.", -1, comboStr));
        }

        return out;
    }

    /** First occurrence of `needle` outside any `[...]`, or null. */
    private static function findOutsideBrackets(text:String, needle:String):Null<String> {
        var depth = 0;
        for (i in 0...text.length) {
            var c = text.charAt(i);
            if (c == "[") depth++;
            else if (c == "]") { if (depth > 0) depth--; }
            else if (depth == 0 && c == needle) return StringTools.trim(text.substr(0, i + 1));
        }
        return null;
    }

    private static function validateStep(part:String, index:Int, out:Array<Diagnostic>):Void {
        var bracketStart:Int = part.indexOf("[");
        var bracketEnd:Int = part.lastIndexOf("]");

        if (bracketStart == -1 || bracketEnd <= bracketStart) {
            if (bracketStart != -1 || bracketEnd != -1) {
                out.push(new Diagnostic(Diagnostic.ERROR, "Unbalanced brackets.", index, part));
                return;
            }
            // Bare step: parseCombo silently substitutes skill 1 for anything non-numeric.
            if (Std.parseInt(part) == null) {
                out.push(new Diagnostic(Diagnostic.ERROR,
                    "'" + part + "' is not a skill id - it would be saved as skill 1.", index, part));
            }
            return;
        }

        var sidStr:String = StringTools.trim(part.substring(0, bracketStart));
        if (sidStr.length == 0) {
            out.push(new Diagnostic(Diagnostic.ERROR, "Missing skill id before '['.", index, part));
        } else if (Std.parseInt(sidStr) == null) {
            out.push(new Diagnostic(Diagnostic.ERROR,
                "'" + sidStr + "' is not a skill id - it would be saved as skill 1.", index, part));
        }

        var inner:String = part.substring(bracketStart + 1, bracketEnd);
        if (StringTools.trim(inner).length == 0) {
            out.push(new Diagnostic(Diagnostic.ERROR,
                "Empty brackets - this step will fire unconditionally.", index, part));
            return;
        }

        // Trailing junk after the closing bracket is dropped by parseCombo without complaint.
        var trailing:String = StringTools.trim(part.substring(bracketEnd + 1));
        if (trailing.length > 0) {
            out.push(new Diagnostic(Diagnostic.WARNING,
                "Ignoring text after the closing bracket: '" + trailing + "'", index, part));
        }

        var isOr = inner.indexOf("|") != -1;
        var rawRules:Array<String> = inner.split(isOr ? "|" : "&");
        var recognised = 0;
        for (rr in rawRules) {
            var raw:String = StringTools.trim(rr);
            if (raw.length == 0) continue;

            var rule:Dynamic = parseRule(raw);
            if (rule == null) {
                out.push(new Diagnostic(Diagnostic.ERROR,
                    "Unrecognised condition '" + raw + "' - it would be ignored.", index, part));
                continue;
            }
            recognised++;
            validateRule(rule, raw, index, out);
        }

        if (recognised == 0) {
            out.push(new Diagnostic(Diagnostic.ERROR,
                "Every condition was dropped - this step will fire UNCONDITIONALLY.", index, part));
        } else if (rawRules.length > 1 && recognised == 1) {
            out.push(new Diagnostic(Diagnostic.WARNING,
                (isOr ? "Only one of the OR-ed conditions is valid - the others were dropped, "
                      : "Only one of the AND-ed conditions is valid - the others were dropped, ")
                    + "so this step behaves as if it had a single condition.", index, part));
        }
    }

    private static function validateRule(rule:Dynamic, raw:String, index:Int, out:Array<Diagnostic>):Void {
        var type:String = Std.string(rule.type);

        switch (type) {
            case "Aura", "MultiAura", "AuraTime", "AuraRemaining", "AuraTimer":
                var auraName:String = (rule.auraName != null) ? Std.string(rule.auraName) : "";
                if (auraName.length == 0) {
                    out.push(new Diagnostic(Diagnostic.ERROR, "Aura condition has no aura name.", index, raw));
                } else if (auraName.toLowerCase() == "name") {
                    // The editor's macro buttons literally insert "aura(self:Name)".
                    out.push(new Diagnostic(Diagnostic.WARNING,
                        "'Name' is a placeholder, not a real aura - it will never match.", index, raw));
                }
                if (type == "Aura" || type == "MultiAura") {
                    var thr:Float = ApiUtils.parseFloat(rule.value, 0);
                    var comp:String = (rule.comparison != null) ? Std.string(rule.comparison) : "greater";
                    if (thr < 0) {
                        out.push(new Diagnostic(Diagnostic.WARNING,
                            "Stack threshold " + thr + " can never be satisfied.", index, raw));
                    }
                }

            case "Health", "Mana", "TargetHealth", "PartyHealth":
                var value:Float = ApiUtils.parseFloat(rule.value, 0);
                var comp2:String = (rule.comparison != null) ? Std.string(rule.comparison) : "greater";
                var isPct:Bool = (rule.isPercentage == true);

                // The parser refuses to treat anything over 100 as a percentage, even when the
                // author wrote a '%'. Worth saying out loud, because "hp > 150%" silently
                // becomes raw "hp > 150".
                if (isPct) {
                    if (comp2 == "greater" && value > 100) {
                        out.push(new Diagnostic(Diagnostic.WARNING,
                            "A percentage above 100 can never be reached.", index, raw));
                    } else if (comp2 == "less" && value < 0) {
                        out.push(new Diagnostic(Diagnostic.WARNING,
                            "A negative threshold can never be reached.", index, raw));
                    }
                } else if (value < 0) {
                    out.push(new Diagnostic(Diagnostic.WARNING,
                        "A negative threshold can never be reached.", index, raw));
                }

                if (raw.indexOf("%") != -1 && value > 100) {
                    out.push(new Diagnostic(Diagnostic.WARNING,
                        "'" + raw + "' was read as a RAW value (" + value + "), not a percentage - "
                        + "values over 100 are never treated as percentages.", index, raw));
                }

            case "Wait":
                if (ApiUtils.parseFloat(rule.timeout, 0) <= 0) {
                    out.push(new Diagnostic(Diagnostic.WARNING,
                        "wait(0) imposes no delay.", index, raw));
                }

            case "MobAtkIn":
                if (ApiUtils.parseFloat(rule.window, 500) < 100) {
                    out.push(new Diagnostic(Diagnostic.WARNING,
                        "A window under 100ms will almost never line up with an attack.", index, raw));
                }

            case "AfterMobAtk":
                if (ApiUtils.parseFloat(rule.window, 1000) <= 0) {
                    out.push(new Diagnostic(Diagnostic.WARNING,
                        "A zero-length window can never match a fresh attack.", index, raw));
                }
        }
    }

    public static function parseCombo(comboStr:String):Array<Dynamic> {
        var skills:Array<Dynamic> = [];
        if (comboStr == null || comboStr.length == 0) return skills;

        var tokens:Array<String> = splitCombo(comboStr);

        for (token in tokens) {
            var part:String = StringTools.trim(token);
            if (part.length == 0) continue;

            var bracketStart:Int = part.indexOf("[");
            var bracketEnd:Int = part.lastIndexOf("]");

            if (bracketStart != -1 && bracketEnd > bracketStart) {
                var sidStr:String = StringTools.trim(part.substring(0, bracketStart));
                var rulesStr:String = StringTools.trim(part.substring(bracketStart + 1, bracketEnd));
                var pSid:Null<Int> = Std.parseInt(sidStr);
                var sid:Int = (pSid != null) ? pSid : 1;

                var isOr:Bool = (rulesStr.indexOf("|") != -1);
                var ruleSep:String = isOr ? "|" : "&";
                var rawRules:Array<String> = rulesStr.split(ruleSep);

                var ruleObjs:Array<Dynamic> = [];
                for (rr in rawRules) {
                    var rTrimmed:String = StringTools.trim(rr);
                    if (rTrimmed.length == 0) continue;
                    var rObj:Dynamic = parseRule(rTrimmed);
                    if (rObj != null) {
                        ruleObjs.push(rObj);
                    } else {
                        // parseRule returns null for anything it does not recognise. Dropping
                        // it silently made a typo'd condition vanish and the surrounding
                        // bracket fire far more often than it was written to.
                        ApiLogger.warn("Skills", "Unrecognised condition '" + rTrimmed
                            + "' in combo '" + comboStr + "' - ignored.");
                    }
                }

                var skillObj:Dynamic = { skillId: sid };
                if (ruleObjs.length > 0) {
                    skillObj.rules = ruleObjs;
                    if (ruleObjs.length > 1) {
                        skillObj.isMultiAura = true;
                        skillObj.multiAuraOperator = isOr ? "OR" : "AND";
                    }
                }
                skills.push(skillObj);
            } else {
                var pPart:Null<Int> = Std.parseInt(part);
                skills.push({ skillId: (pPart != null) ? pPart : 1 });
            }
        }

        return skills;
    }

    /**
     * Splits a combo string on '>' delimiters, ignoring any '>' inside square brackets '[...]'.
     */
    private static function splitCombo(comboStr:String):Array<String> {
        var tokens:Array<String> = [];
        var cur:StringBuf = new StringBuf();
        var depth:Int = 0;

        for (i in 0...comboStr.length) {
            var c:String = comboStr.charAt(i);
            if (c == "[") {
                depth++;
                cur.add(c);
            } else if (c == "]") {
                if (depth > 0) depth--;
                cur.add(c);
            } else if (c == ">" && depth == 0) {
                var s:String = StringTools.trim(cur.toString());
                if (s.length > 0) tokens.push(s);
                cur = new StringBuf();
            } else {
                cur.add(c);
            }
        }

        var remaining:String = StringTools.trim(cur.toString());
        if (remaining.length > 0) tokens.push(remaining);

        return tokens;
    }

    private static function parseRule(r:String):Dynamic {
        if (r == null || r.length == 0) return null;

        var lower:String = r.toLowerCase();

        // 1. Wait: wait(5000ms) or wait(5000)
        if (StringTools.startsWith(lower, "wait(") && StringTools.endsWith(lower, ")")) {
            var inside:String = r.substring(5, r.length - 1);
            var numBuf:StringBuf = new StringBuf();
            for (i in 0...inside.length) {
                var code:Int = inside.charCodeAt(i);
                if (code >= 48 && code <= 57) numBuf.addChar(code);
            }
            var pTo:Null<Int> = Std.parseInt(numBuf.toString());
            return {
                type: "Wait",
                timeout: (pTo != null) ? pTo : 0
            };
        }

        // 2. Target crowd control: targetCC / targetcc / mobCC, optionally negated with !
        // True while the CURRENT target is hard-CC'd (stun/stone/paralyze/disable).
        if (lower == "targetcc" || lower == "targetstun" || lower == "mobcc") {
            return { type: "TargetCC", negate: false };
        }
        if (lower == "!targetcc" || lower == "!targetstun" || lower == "!mobcc") {
            return { type: "TargetCC", negate: true };
        }

        // 3. Predictive counter: mobAtkIn:500 / mobAtkIn(500)
        // True when the monster's LEARNED attack cadence says a swing is due within the
        // window. Suppressed (treated as false) until the predictor has enough samples and
        // a tight enough spread, so this silently degrades to normal priority execution
        // rather than committing a dodge weave to an unreliable rhythm.
        if (StringTools.startsWith(lower, "mobatkin")) {
            var cleanIn:String = StringTools.replace(lower, "(", ":");
            cleanIn = StringTools.replace(cleanIn, ")", "");
            var inParts:Array<String> = cleanIn.split(":");
            var inWin:Int = 500;
            if (inParts.length > 1) inWin = ApiUtils.parseInt(StringTools.trim(inParts[1]), 500);
            return { type: "MobAtkIn", window: inWin };
        }

        // 4. Reactive counter, against the server's own action resolution:
        //   afterMobAtk:<windowMs>[:any|evaded][:<minDamage>]
        //   afterMobAtk(<windowMs>, any, <minDamage>)
        // Default requires an EVADED outcome (miss/dodge/parry). ":any" also accepts hits,
        // and a trailing number only reacts when the hit did at least that much damage.
        // Only meaningful in UseIfAvailable - in WaitForCooldown a failing rule advances
        // the combo index and skips the step entirely.
        if (StringTools.startsWith(lower, "aftermobatk") || StringTools.startsWith(lower, "mobatk")) {
            // Normalise every accepted separator to a colon so a single split handles both
            // forms: "aftermobatk(2000, any, 200)" and "aftermobatk:2000:any:200".
            var cleanRule:String = lower;
            for (sep in ["(", ")", ","]) cleanRule = StringTools.replace(cleanRule, sep, ":");
            var parts:Array<String> = cleanRule.split(":");

            var windowMs:Int = 1000;
            var evadedOnly:Bool = true;
            var minDmg:Int = 0;

            if (parts.length > 1) windowMs = ApiUtils.parseInt(StringTools.trim(parts[1]), 1000);
            if (parts.length > 2) evadedOnly = (StringTools.trim(parts[2]) != "any");
            if (parts.length > 3) minDmg = ApiUtils.parseInt(StringTools.trim(parts[3]), 0);

            return {
                type: "AfterMobAtk",
                window: windowMs,
                evadedOnly: evadedOnly,
                minDmg: minDmg
            };
        }

        // 3. Target Health: target:hp, tgt:hp, target_hp, target.hp, mon:hp, target:health
        if (StringTools.startsWith(lower, "target:hp") || StringTools.startsWith(lower, "tgt:hp") ||
            StringTools.startsWith(lower, "target_hp") || StringTools.startsWith(lower, "target.hp") ||
            StringTools.startsWith(lower, "tgt_hp") || StringTools.startsWith(lower, "mon:hp") ||
            StringTools.startsWith(lower, "mon_hp")) {
            var hpIdx:Int = lower.indexOf("hp");
            var sub:String = StringTools.trim(r.substring(hpIdx + 2));
            if (StringTools.startsWith(sub, ":")) sub = StringTools.trim(sub.substring(1));
            return parseStatRule("TargetHealth", sub);
        } else if (StringTools.startsWith(lower, "target:health") || StringTools.startsWith(lower, "tgt:health") || StringTools.startsWith(lower, "mon:health")) {
            var hIdx:Int = lower.indexOf("health");
            var sub:String = StringTools.trim(r.substring(hIdx + 6));
            if (StringTools.startsWith(sub, ":")) sub = StringTools.trim(sub.substring(1));
            return parseStatRule("TargetHealth", sub);
        }

        // 3. Party Health: party:hp, party_hp, party.hp, party:health
        if (StringTools.startsWith(lower, "party:hp") || StringTools.startsWith(lower, "party_hp") || StringTools.startsWith(lower, "party.hp")) {
            var sub:String = StringTools.trim(r.substring(8));
            if (StringTools.startsWith(sub, ":")) sub = StringTools.trim(sub.substring(1));
            return parseStatRule("PartyHealth", sub);
        } else if (StringTools.startsWith(lower, "party:health")) {
            var sub:String = StringTools.trim(r.substring(12));
            if (StringTools.startsWith(sub, ":")) sub = StringTools.trim(sub.substring(1));
            return parseStatRule("PartyHealth", sub);
        }

        // 4. Health: hp > 70%, hp < 2000, health < 50%
        if (StringTools.startsWith(lower, "health")) {
            var sub:String = StringTools.trim(r.substring(6));
            if (StringTools.startsWith(sub, ":")) sub = StringTools.trim(sub.substring(1));
            return parseStatRule("Health", sub);
        }
        if (StringTools.startsWith(lower, "hp")) {
            var sub:String = StringTools.trim(r.substring(2));
            if (StringTools.startsWith(sub, ":")) sub = StringTools.trim(sub.substring(1));
            return parseStatRule("Health", sub);
        }

        // 5. Mana: mp < 70%, mp > 30, mana < 20%
        if (StringTools.startsWith(lower, "mana")) {
            var sub:String = StringTools.trim(r.substring(4));
            if (StringTools.startsWith(sub, ":")) sub = StringTools.trim(sub.substring(1));
            return parseStatRule("Mana", sub);
        }
        if (StringTools.startsWith(lower, "mp")) {
            var sub:String = StringTools.trim(r.substring(2));
            if (StringTools.startsWith(sub, ":")) sub = StringTools.trim(sub.substring(1));
            return parseStatRule("Mana", sub);
        }

        // 6. Aura Timer / Remaining: auraTime(self:Name) <= 1.5s, auraRemaining(target:Name) < 2s
        var atIdx:Int = -1;
        var atPrefixLen:Int = 0;
        if (lower.indexOf("auratime(") != -1) {
            atIdx = lower.indexOf("auratime(");
            atPrefixLen = 9;
        } else if (lower.indexOf("aura_time(") != -1) {
            atIdx = lower.indexOf("aura_time(");
            atPrefixLen = 10;
        } else if (lower.indexOf("auratimer(") != -1) {
            atIdx = lower.indexOf("auratimer(");
            atPrefixLen = 10;
        } else if (lower.indexOf("auraremaining(") != -1) {
            atIdx = lower.indexOf("auraremaining(");
            atPrefixLen = 14;
        }

        if (atIdx != -1) {
            var openParen:Int = atIdx + atPrefixLen;
            var closeParen:Int = r.indexOf(")", openParen);
            if (closeParen != -1) {
                var inside:String = r.substring(openParen, closeParen);
                var after:String = StringTools.trim(r.substring(closeParen + 1));

                var target:String = "self";
                var name:String = inside;

                var colonIdx:Int = inside.indexOf(":");
                if (colonIdx != -1) {
                    target = StringTools.trim(inside.substring(0, colonIdx)).toLowerCase();
                    name = StringTools.trim(inside.substring(colonIdx + 1));
                }

                var comp:String = "less";
                var valStr:String = "";

                if (StringTools.startsWith(after, ">=")) {
                    comp = "greater";
                    valStr = StringTools.trim(after.substring(2));
                } else if (StringTools.startsWith(after, "<=")) {
                    comp = "less";
                    valStr = StringTools.trim(after.substring(2));
                } else if (StringTools.startsWith(after, ">")) {
                    comp = "greater";
                    valStr = StringTools.trim(after.substring(1));
                } else if (StringTools.startsWith(after, "<")) {
                    comp = "less";
                    valStr = StringTools.trim(after.substring(1));
                } else if (StringTools.startsWith(after, "==")) {
                    comp = "equal";
                    valStr = StringTools.trim(after.substring(2));
                } else if (StringTools.startsWith(after, "=")) {
                    comp = "equal";
                    valStr = StringTools.trim(after.substring(1));
                } else {
                    valStr = after;
                }

                var afterLower = valStr.toLowerCase();
                var isMs:Bool = (afterLower.indexOf("ms") != -1);
                var numStr = StringTools.replace(afterLower, "ms", "");
                numStr = StringTools.replace(numStr, "s", "");
                var parsedVal:Float = ApiUtils.parseFloat(StringTools.trim(numStr), 0.0);
                if (isMs) {
                    parsedVal = parsedVal / 1000.0;
                } else if (parsedVal > 60 && afterLower.indexOf("s") == -1) {
                    parsedVal = parsedVal / 1000.0;
                }

                return {
                    type: "AuraTime",
                    auraName: name,
                    auraTarget: target,
                    comparison: comp,
                    value: parsedVal
                };
            }
        }

        // 7. Aura: !aura(self:Name) or aura(target:Name) >= 22 or aura(Name)
        var auraIdx:Int = lower.indexOf("aura(");
        if (auraIdx != -1) {
            var isNeg:Bool = (auraIdx > 0 && r.charAt(auraIdx - 1) == "!");
            var openParen:Int = auraIdx + 5;
            var closeParen:Int = r.indexOf(")", openParen);
            if (closeParen != -1) {
                var inside:String = r.substring(openParen, closeParen);
                var after:String = StringTools.trim(r.substring(closeParen + 1));

                var target:String = "self";
                var name:String = inside;

                var colonIdx:Int = inside.indexOf(":");
                if (colonIdx != -1) {
                    target = StringTools.trim(inside.substring(0, colonIdx)).toLowerCase();
                    name = StringTools.trim(inside.substring(colonIdx + 1));
                }

                var comp:String = isNeg ? "less" : "greater";
                var val:Float = 0.0;

                if (after.length > 0) {
                    if (StringTools.startsWith(after, ">=")) {
                        comp = "greater";
                        val = ApiUtils.parseFloat(StringTools.trim(after.substring(2)), 0.0);
                    } else if (StringTools.startsWith(after, "<=")) {
                        comp = "less";
                        val = ApiUtils.parseFloat(StringTools.trim(after.substring(2)), 0.0);
                    } else if (StringTools.startsWith(after, ">")) {
                        comp = "greater";
                        val = ApiUtils.parseFloat(StringTools.trim(after.substring(1)), 0.0);
                    } else if (StringTools.startsWith(after, "<")) {
                        comp = "less";
                        val = ApiUtils.parseFloat(StringTools.trim(after.substring(1)), 0.0);
                    }
                }

                return {
                    type: "Aura",
                    auraName: name,
                    auraTarget: target,
                    comparison: comp,
                    value: val
                };
            }
        }

        return null;
    }

    private static function parseStatRule(type:String, expr:String):Dynamic {
        var trimmed:String = StringTools.trim(expr);
        var comp:String = "greater";
        var valStr:String = "";

        if (StringTools.startsWith(trimmed, ">=")) {
            comp = "greater";
            valStr = StringTools.trim(trimmed.substring(2));
        } else if (StringTools.startsWith(trimmed, "<=")) {
            comp = "less";
            valStr = StringTools.trim(trimmed.substring(2));
        } else if (StringTools.startsWith(trimmed, ">")) {
            comp = "greater";
            valStr = StringTools.trim(trimmed.substring(1));
        } else if (StringTools.startsWith(trimmed, "<")) {
            comp = "less";
            valStr = StringTools.trim(trimmed.substring(1));
        } else if (StringTools.startsWith(trimmed, "==")) {
            comp = "equal";
            valStr = StringTools.trim(trimmed.substring(2));
        } else if (StringTools.startsWith(trimmed, "=")) {
            comp = "equal";
            valStr = StringTools.trim(trimmed.substring(1));
        }

        var isPercentage:Bool = (valStr.indexOf("%") != -1);
        var cleanStr:String = StringTools.replace(valStr, "%", "");
        cleanStr = StringTools.replace(cleanStr.toLowerCase(), "hp", "");
        cleanStr = StringTools.replace(cleanStr.toLowerCase(), "mp", "");

        var val:Float = ApiUtils.parseFloat(StringTools.trim(cleanStr), 0.0);

        // Values over 100 cannot be percentages (e.g. hp < 2500)
        if (val > 100) {
            isPercentage = false;
        }

        return {
            type: type,
            comparison: comp,
            value: val,
            isPercentage: isPercentage
        };
    }

    public static function formatCombo(skills:Array<Dynamic>):String {
        if (skills == null || skills.length == 0) return "";
        var parts:Array<String> = [];
        for (s in skills) {
            parts.push(formatSkill(s));
        }
        return parts.join(" > ");
    }

    public static function formatSkill(s:Dynamic):String {
        if (s == null) return "1";
        var sid:Int = (s.skillId != null) ? ApiUtils.parseInt(s.skillId, 1) : 1;
        var rules:Array<Dynamic> = (s.rules != null && Std.isOfType(s.rules, Array)) ? cast s.rules : [];
        if (rules.length == 0) return Std.string(sid);

        var ruleStrs:Array<String> = [];
        for (r in rules) {
            var formatted = formatRule(r);
            if (formatted != null && formatted.length > 0) ruleStrs.push(formatted);
        }
        if (ruleStrs.length == 0) return Std.string(sid);

        var op:String = (s.multiAuraOperator == "OR") ? " | " : " & ";
        return sid + "[" + ruleStrs.join(op) + "]";
    }

    public static function formatRule(r:Dynamic):String {
        if (r == null) return "";
        var rtype:String = (r.type != null) ? Std.string(r.type) : "";
        if (rtype == "None" || rtype == "") return "";
        if (rtype == "Wait") {
            var to:Int = (r.timeout != null) ? ApiUtils.parseInt(r.timeout, 0) : 0;
            return "wait(" + to + "ms)";
        }
        if (rtype == "TargetHealth") {
            var val:Float = (r.value != null) ? ApiUtils.parseFloat(r.value, 0.0) : 0.0;
            var isPct:Bool = (r.isPercentage == true);
            var comp:String = (r.comparison == "greater") ? ">" : (r.comparison == "equal" ? "=" : "<");
            var unit:String = isPct ? "%" : "";
            var valStr:String = (val == Std.int(val)) ? Std.string(Std.int(val)) : Std.string(val);
            return "tgt:hp " + comp + " " + valStr + unit;
        }
        if (rtype == "PartyHealth") {
            var val:Float = (r.value != null) ? ApiUtils.parseFloat(r.value, 0.0) : 0.0;
            var isPct:Bool = (r.isPercentage == true);
            var comp:String = (r.comparison == "greater") ? ">" : (r.comparison == "equal" ? "=" : "<");
            var unit:String = isPct ? "%" : "";
            var valStr:String = (val == Std.int(val)) ? Std.string(Std.int(val)) : Std.string(val);
            return "party:hp " + comp + " " + valStr + unit;
        }
        if (rtype == "Health" || rtype == "Mana") {
            var stat:String = (rtype == "Health") ? "hp" : "mp";
            var val:Float = (r.value != null) ? ApiUtils.parseFloat(r.value, 0.0) : 0.0;
            var isPct:Bool = (r.isPercentage == true);
            var comp:String = (r.comparison == "greater") ? ">" : (r.comparison == "equal" ? "=" : "<");
            var unit:String = isPct ? "%" : "";
            var valStr:String = (val == Std.int(val)) ? Std.string(Std.int(val)) : Std.string(val);
            return stat + " " + comp + " " + valStr + unit;
        }
        if (rtype == "AuraTime" || rtype == "AuraRemaining" || rtype == "AuraTimer") {
            var target:String = (r.auraTarget != null && r.auraTarget != "") ? Std.string(r.auraTarget) : "self";
            var name:String = (r.auraName != null) ? Std.string(r.auraName) : "";
            var val:Float = (r.value != null) ? ApiUtils.parseFloat(r.value, 0.0) : 0.0;
            var comp:String = (r.comparison == "greater") ? ">" : (r.comparison == "equal" ? "=" : "<=");
            var valStr:String = (val == Std.int(val)) ? Std.string(Std.int(val)) : Std.string(Math.round(val * 10) / 10);
            return "auraTime(" + target + ":" + name + ") " + comp + " " + valStr + "s";
        }
        if (rtype == "Aura" || rtype == "MultiAura") {
            var target:String = (r.auraTarget != null && r.auraTarget != "") ? Std.string(r.auraTarget) : "self";
            var name:String = (r.auraName != null) ? Std.string(r.auraName) : "";
            var val:Float = (r.value != null) ? ApiUtils.parseFloat(r.value, 0.0) : 0.0;
            var comp:String = (r.comparison != null) ? Std.string(r.comparison) : "greater";
            if (comp == "less" && val <= 0.5) {
                return "!aura(" + target + ":" + name + ")";
            } else if (comp == "greater" && val <= 0.5) {
                return "aura(" + target + ":" + name + ")";
            } else {
                var c:String = (comp == "greater") ? ">=" : "<=";
                return "aura(" + target + ":" + name + ") " + c + " " + val;
            }
        }
        return "";
    }
}
