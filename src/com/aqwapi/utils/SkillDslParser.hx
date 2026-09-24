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

                if (currentClass != "" && currentMode != "") {
                    var classObj:Dynamic = Reflect.field(result, currentClass);
                    if (classObj == null) {
                        classObj = {};
                        Reflect.setField(result, currentClass, classObj);
                    }
                    currentData = {
                        skillUseMode: "WaitForCooldown",
                        skillTimeout: 100,
                        skills: []
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
                    currentData.skillTimeout = AqwUtils.parseInt(val, 100);

                case "combo", "skills", "rotation":
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
                var sid:Int = AqwUtils.parseInt(sidStr, 1);

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
                skills.push({ skillId: AqwUtils.parseInt(part, 1) });
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
            return {
                type: "Wait",
                timeout: AqwUtils.parseInt(numBuf.toString(), 0)
            };
        }

        // 2. Health: hp > 70% or hp < 50
        if (StringTools.startsWith(lower, "hp")) {
            return parseStatRule("Health", StringTools.trim(r.substring(2)));
        }

        // 3. Mana: mp < 70% or mp > 30%
        if (StringTools.startsWith(lower, "mp")) {
            return parseStatRule("Mana", StringTools.trim(r.substring(2)));
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
                        val = AqwUtils.parseFloat(StringTools.trim(after.substring(2)), 0);
                    } else if (StringTools.startsWith(after, "<=")) {
                        comp = "less";
                        val = AqwUtils.parseFloat(StringTools.trim(after.substring(2)), 0);
                    } else if (StringTools.startsWith(after, ">")) {
                        comp = "greater";
                        val = AqwUtils.parseFloat(StringTools.trim(after.substring(1)), 0);
                    } else if (StringTools.startsWith(after, "<")) {
                        comp = "less";
                        val = AqwUtils.parseFloat(StringTools.trim(after.substring(1)), 0);
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
        }

        var isPercentage:Bool = (valStr.indexOf("%") != -1);
        if (isPercentage) {
            valStr = StringTools.replace(valStr, "%", "");
        }

        var val:Float = AqwUtils.parseFloat(StringTools.trim(valStr), 0);

        return {
            type: type,
            comparison: comp,
            value: val,
            isPercentage: isPercentage
        };
    }
}
