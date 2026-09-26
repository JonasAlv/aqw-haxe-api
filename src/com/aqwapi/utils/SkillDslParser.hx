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
                        skillTimeout: 100,
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
                    currentData.skillTimeout = (pTo != null) ? pTo : 100;

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
                    if (rObj != null) ruleObjs.push(rObj);
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

        // 2. Party Health: party:hp, party_hp, party.hp, party:health
        if (StringTools.startsWith(lower, "party:hp") || StringTools.startsWith(lower, "party_hp") || StringTools.startsWith(lower, "party.hp")) {
            var sub:String = StringTools.trim(r.substring(8));
            if (StringTools.startsWith(sub, ":")) sub = StringTools.trim(sub.substring(1));
            return parseStatRule("PartyHealth", sub);
        } else if (StringTools.startsWith(lower, "party:health")) {
            var sub:String = StringTools.trim(r.substring(12));
            if (StringTools.startsWith(sub, ":")) sub = StringTools.trim(sub.substring(1));
            return parseStatRule("PartyHealth", sub);
        }

        // 3. Health: hp > 70%, hp < 2000, health < 50%
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

        // 4. Mana: mp < 70%, mp > 30, mana < 20%
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

        // 4. Aura: !aura(self:Name) or aura(target:Name) >= 22 or aura(Name)
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
                        var pVal:Float = Std.parseFloat(StringTools.trim(after.substring(2)));
                        val = Math.isNaN(pVal) ? 0.0 : pVal;
                    } else if (StringTools.startsWith(after, "<=")) {
                        comp = "less";
                        var pVal:Float = Std.parseFloat(StringTools.trim(after.substring(2)));
                        val = Math.isNaN(pVal) ? 0.0 : pVal;
                    } else if (StringTools.startsWith(after, ">")) {
                        comp = "greater";
                        var pVal:Float = Std.parseFloat(StringTools.trim(after.substring(1)));
                        val = Math.isNaN(pVal) ? 0.0 : pVal;
                    } else if (StringTools.startsWith(after, "<")) {
                        comp = "less";
                        var pVal:Float = Std.parseFloat(StringTools.trim(after.substring(1)));
                        val = Math.isNaN(pVal) ? 0.0 : pVal;
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

        var pVal:Float = Std.parseFloat(StringTools.trim(cleanStr));
        var val:Float = Math.isNaN(pVal) ? 0.0 : pVal;

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
        var sid:Int = 1;
        if (s.skillId != null) {
            if (Std.isOfType(s.skillId, Int)) {
                sid = cast s.skillId;
            } else {
                var pSid:Null<Int> = Std.parseInt(Std.string(s.skillId));
                if (pSid != null) sid = pSid;
            }
        }
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
            var to:Int = 0;
            if (r.timeout != null) {
                if (Std.isOfType(r.timeout, Int)) {
                    to = cast r.timeout;
                } else {
                    var pTo:Null<Int> = Std.parseInt(Std.string(r.timeout));
                    if (pTo != null) to = pTo;
                }
            }
            return "wait(" + to + "ms)";
        }
        if (rtype == "PartyHealth") {
            var val:Float = 0.0;
            if (r.value != null) {
                if (Std.isOfType(r.value, Float) || Std.isOfType(r.value, Int)) {
                    val = cast r.value;
                } else {
                    var pVal:Float = Std.parseFloat(Std.string(r.value));
                    if (!Math.isNaN(pVal)) val = pVal;
                }
            }
            var isPct:Bool = (r.isPercentage == true);
            var comp:String = (r.comparison == "greater") ? ">" : (r.comparison == "equal" ? "=" : "<");
            var unit:String = isPct ? "%" : "";
            var valStr:String = (val == Std.int(val)) ? Std.string(Std.int(val)) : Std.string(val);
            return "party:hp " + comp + " " + valStr + unit;
        }
        if (rtype == "Health" || rtype == "Mana") {
            var stat:String = (rtype == "Health") ? "hp" : "mp";
            var val:Float = 0.0;
            if (r.value != null) {
                if (Std.isOfType(r.value, Float) || Std.isOfType(r.value, Int)) {
                    val = cast r.value;
                } else {
                    var pVal:Float = Std.parseFloat(Std.string(r.value));
                    if (!Math.isNaN(pVal)) val = pVal;
                }
            }
            var isPct:Bool = (r.isPercentage == true);
            var comp:String = (r.comparison == "greater") ? ">" : (r.comparison == "equal" ? "=" : "<");
            var unit:String = isPct ? "%" : "";
            var valStr:String = (val == Std.int(val)) ? Std.string(Std.int(val)) : Std.string(val);
            return stat + " " + comp + " " + valStr + unit;
        }
        if (rtype == "Aura" || rtype == "MultiAura") {
            var target:String = (r.auraTarget != null && r.auraTarget != "") ? Std.string(r.auraTarget) : "self";
            var name:String = (r.auraName != null) ? Std.string(r.auraName) : "";
            var val:Float = 0.0;
            if (r.value != null) {
                if (Std.isOfType(r.value, Float) || Std.isOfType(r.value, Int)) {
                    val = cast r.value;
                } else {
                    var pVal:Float = Std.parseFloat(Std.string(r.value));
                    if (!Math.isNaN(pVal)) val = pVal;
                }
            }
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
