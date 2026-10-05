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

                case "autoattack", "auto":
                    var lowerVal:String = val.toLowerCase();
                    if (lowerVal == "true" || lowerVal == "1" || lowerVal == "yes") currentData.autoattack = true;
                    else if (lowerVal == "false" || lowerVal == "0" || lowerVal == "no") currentData.autoattack = false;

                case "combo", "skills", "rotation":
                    currentData.combo = val;
                    currentData.skills = parseCombo(val);
            }
        }

        return result;
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

    /** True for digits with at most one decimal point. Keeps words out of the counter window parse. */
    private static function isAllDigits(s:String):Bool {
        if (s == null || s.length == 0) return false;
        var seenDot:Bool = false;
        for (i in 0...s.length) {
            var c:Int = s.charCodeAt(i);
            if (c == 46) {
                if (seenDot) return false;
                seenDot = true;
            } else if (c < 48 || c > 57) {
                return false;
            }
        }
        return true;
    }

    /**
     * The resolution types the server actually sends in `sar`/`sars` (`World.as:10009-10074`), plus
     * the two aliases meaning "don't filter".
     */
    private static function isResolutionType(t:String):Bool {
        return (t == "hit" || t == "crit" || t == "critical" || t == "miss" || t == "dodge" ||
            t == "parry" || t == "block" || t == "none" || t == "any" || t == "all");
    }

    /** `critical` aliases to `crit`; `any`/`all` mean no filter, which is null. */
    private static function normalizeResolutionType(t:String):String {
        if (t == "critical") return "crit";
        if (t == "any" || t == "all") return null;
        return t;
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

        // 2. Counter: [counter], [counter <= 1500], [counter <= 1.5s], [hit], [attacked], [mobattack]
        //    Opens when the target resolved an attack against us. The value is a freshness window: a
        //    plain number is milliseconds (like `[wait(500ms)]`), an `s` suffix is seconds.
        //
        //    An `=type` suffix narrows to one resolution type, taken from the packet's own enum:
        //    hit, crit, miss, dodge, parry, block, none. `[counter=miss]` only opens on a swing that
        //    missed us, `[counter=dodge <= 2s]` on a dodge inside a 2s window. Plain `[counter]` takes
        //    every type, which is what a riposte wants - the reaction has to be available on the
        //    swings that miss as well as the ones that land.
        var cPrefix:Int = -1;
        if (lower.indexOf("counter") == 0) cPrefix = 7;
        else if (lower.indexOf("mobattack") == 0) cPrefix = 9;
        else if (lower.indexOf("attacked") == 0) cPrefix = 8;
        else if (lower.indexOf("hit") == 0) cPrefix = 3;
        if (cPrefix > 0) {
            var out:Dynamic = {type: "Counter"};

            // Normalize the comparison/wrapping noise into plain spaces so the remainder can be
            // tokenized: `counter=miss <= 1.5s`, `counter: 1500` and `hit(1500)` all reduce to words
            // and one number.
            var norm:String = r.substring(cPrefix).toLowerCase();
            norm = StringTools.replace(norm, "<=", " ");
            norm = StringTools.replace(norm, "=", " ");
            norm = StringTools.replace(norm, ">", " ");
            norm = StringTools.replace(norm, "(", " ");
            norm = StringTools.replace(norm, ")", " ");
            norm = StringTools.replace(norm, ":", " ");

            // Scan tokens rather than slicing on `=`. Slicing cannot tell `[counter=miss <= 1500]`
            // apart from `[counter=1500]`, and reading the `s` in `miss` as a seconds suffix turned
            // 1500ms into 1500000ms. A token is a type only when it is letters-only and names a real
            // resolution, so the `s` in `miss` can never reach the seconds check.
            var tokens:Array<String> = norm.split(" ");
            for (tok in tokens) {
                var t:String = StringTools.trim(tok);
                if (t == "") continue;

                if (isResolutionType(t)) {
                    out.actionType = normalizeResolutionType(t);
                    continue;
                }

                // `xN` counts how many resolved attacks must land before the rule opens.
                // Deliberately NOT `=N`: `=` followed by digits has always meant a millisecond window
                // (`[counter=1500]`), so letting `=` also mean a count would silently turn every
                // existing window into "wait for 1500 hits". `x` cannot collide - no resolution type
                // or alias begins with it.
                if (t.charAt(0) == "x") {
                    var digitsN:String = t.substr(1);
                    if (isAllDigits(digitsN)) {
                        var n:Int = ApiUtils.parseInt(digitsN, 0);
                        if (n > 0) out.count = n;
                        continue;
                    }
                }

                // A numeric token is the window. Only a trailing `s` counts as seconds, and only when
                // what precedes it is a number.
                var num:String = t;
                var isSeconds:Bool = false;
                if (num.charAt(num.length - 1) == "s") {
                    var head:String = num.substr(0, num.length - 1);
                    if (head != "" && isAllDigits(head)) {
                        num = head;
                        isSeconds = true;
                    }
                }
                if (!isAllDigits(num)) continue;
                var amount:Float = ApiUtils.parseFloat(num, 0);
                if (amount <= 0) continue;
                out.value = isSeconds ? amount * 1000 : amount;
            }
            return out;
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
