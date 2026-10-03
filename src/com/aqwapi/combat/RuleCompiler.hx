package com.aqwapi.combat;

import com.aqwapi.utils.ApiUtils;

/**
 * Turns the parsed `Dynamic` rule objects emitted by SkillDslParser into typed RuleGroups.
 *
 * The Dynamic form stays the interchange format on purpose: `SkillDslParser.formatRule` reads it
 * back to render combos in the UI, and skills.json stores it verbatim. Compiling to Conditions is
 * therefore additive - it sits behind the parser rather than replacing it, so the UI round-trip
 * keeps working untouched.
 *
 * Every mapping here is a 1:1 transcription of the matching branch in `SkillRules.evaluateRule`.
 * Where the legacy branch depended on a value that is fixed at parse time (the `isPercentage`
 * inference, the `greater`/`less` -> `>=`/`<=` operator mapping, default windows) the decision is
 * made once here instead of on every tick.
 */
class RuleCompiler {

    static inline var CACHE_GROUP:String = "__aqwRuleGroup";
    static inline var CACHE_SRC:String = "__aqwRuleSrc";
    static inline var CACHE_OP:String = "__aqwRuleOp";
    static inline var CACHE_SKILL:String = "__aqwRuleSkillId";

    /**
     * Compiles one combo step's rules, memoised onto the step itself.
     *
     * The cache is keyed on the identity of the rules array plus the operator and skill id, so an
     * editor that swaps in a fresh rules array recompiles, while the per-tick path costs three
     * reference comparisons instead of a re-walk of the rule tree.
     *
     * Returns null when the step imposes no conditions, which every caller treats as "allowed".
     */
    public static function compile(skill:Dynamic):RuleGroup {
        if (skill == null) return null;

        var rules:Dynamic = skill.rules;
        if (rules == null || !Std.isOfType(rules, Array)) return null;

        var arr:Array<Dynamic> = cast rules;
        if (arr.length == 0) return null;

        var op:String = (skill.multiAuraOperator != null) ? Std.string(skill.multiAuraOperator).toUpperCase() : "AND";
        var sid:Int = (skill.skillId != null) ? ApiUtils.parseInt(skill.skillId, 0) : 0;

        // Fast path: already compiled from this exact source.
        var cached:RuleGroup = Reflect.field(skill, CACHE_GROUP);
        if (cached != null && op == Reflect.field(skill, CACHE_OP)
            && sid == Reflect.field(skill, CACHE_SKILL)
            && arr == Reflect.field(skill, CACHE_SRC)) {
            return cached;
        }

        var conds:Array<Condition> = [];
        for (rule in arr) {
            var c:Condition = toCondition(rule);
            if (c != null) conds.push(c);
        }

        var group = new RuleGroup(conds, op == "OR");

        Reflect.setField(skill, CACHE_GROUP, group);
        Reflect.setField(skill, CACHE_SRC, arr);
        Reflect.setField(skill, CACHE_OP, op);
        Reflect.setField(skill, CACHE_SKILL, sid);
        return group;
    }

    /** Discards any memoised group. For the editor, after mutating a step in place. */
    public static function invalidate(skill:Dynamic):Void {
        if (skill == null) return;
        Reflect.setField(skill, CACHE_GROUP, null);
        Reflect.setField(skill, CACHE_SRC, null);
    }

    /** null means "imposes nothing", which evaluates to allowed. */
    public static function toCondition(rule:Dynamic):Condition {
        if (rule == null) return null;

        switch (Std.string(rule.type)) {
            case "None":
                return null;

            case "TargetCC":
                // Authored as `!targetcc`; the DSL parser records that as an explicit negate.
                return new Condition("targetCc", "==", true, null, rule.negate == true);

            case "MobAtkIn":
                return new Condition("mobAttackIn", "==", true, {
                    windowMs: (rule.window != null) ? ApiUtils.parseFloat(rule.window, 500.0) : 500.0
                });

            case "AfterMobAtk":
                return new Condition("afterMobAttack", "==", true, {
                    windowMs: (rule.window != null) ? ApiUtils.parseFloat(rule.window, 1000.0) : 1000.0,
                    evadedOnly: coerceEvadedOnly(rule.evadedOnly),
                    minDmg: (rule.minDmg != null) ? ApiUtils.parseInt(rule.minDmg, 0) : 0
                });

            case "Wait":
                // A zero or missing budget is vacuously satisfied, which `sinceSkillCast` also
                // produces: NEVER is >= 0, and an elapsed time is never negative.
                return new Condition("sinceSkillCast", ">=", (rule.timeout != null) ? ApiUtils.parseFloat(rule.timeout, 0.0) : 0.0);

            case "Health":
                return statRule(rule, "playerHp");

            case "Mana":
                // Mana deliberately has no `<= 100` fallback: only an explicit `isPercentage`
                // makes it a percentage. Health and TargetHealth do infer one.
                return statRule(rule, "playerMp", false);

            case "TargetHealth":
                return statRule(rule, "targetHp", true);

            case "PartyHealth":
                var partyVal:Float = (rule.value != null) ? ApiUtils.parseFloat(rule.value, 0) : 0;
                return new Condition("partyHealth", cmpOp(rule.comparison, "less"), partyVal, {
                    isPct: isPctFlag(rule.isPercentage, partyVal)
                });

            case "AuraTime", "AuraRemaining", "AuraTimer":
                return new Condition("buffRemaining", cmpOp(rule.comparison, null), (rule.value != null) ? ApiUtils.parseFloat(rule.value, 0) : 0, {
                    name: (rule.auraName != null) ? Std.string(rule.auraName) : "",
                    target: auraTarget(rule)
                });

            case "Aura", "MultiAura":
                return new Condition("buffStacks", cmpOp(rule.comparison, "greater"), (rule.value != null) ? ApiUtils.parseFloat(rule.value, 0) : 0, {
                    name: (rule.auraName != null) ? Std.string(rule.auraName) : "",
                    target: auraTarget(rule)
                });
        }

        // Unrecognised rules used to fall through to "allowed"; keep that so a malformed
        // condition cannot silently lock a rotation.
        return null;
    }

    /**
     * `greater` -> `>=`, `less` -> `<=`. The legacy comparison was lossy in exactly this way
     * (`>` behaved as `>=`, `<` as `<=`), so the mapping preserves behaviour rather than
     * "fixing" it; see SignalRegistry.cmp for the runtime side.
     */
    static function cmpOp(comparison:Dynamic, fallback:String):String {
        if (comparison == null) return (fallback == null) ? "<=" : (fallback == "greater" ? ">=" : "<=");
        var c:String = Std.string(comparison);
        if (c == "equal") return "==";
        if (c == "greater") return ">=";
        if (c == "less") return "<=";
        // Anything else keeps its literal text and is resolved by SignalRegistry.cmp's
        // legacy fallback chain, exactly as compare() used to.
        return c;
    }

    static function auraTarget(rule:Dynamic):String {
        return (rule.auraTarget != null) ? Std.string(rule.auraTarget) : "self";
    }

    /** Mirrors `isPercentage == true || (isPercentage == null && value <= 100)`. */
    static function isPctFlag(flag:Dynamic, value:Float):Bool {
        if (flag == true) return true;
        if (flag == null) return value <= 100;
        return false;
    }

    /** `playerHp` -> playerHpPct when a percentage, `playerMp` -> playerMpPct, `targetHp` -> targetHpPct. */
    static function statRule(rule:Dynamic, base:String, inferPct:Bool = true):Condition {
        var value:Float = (rule.value != null) ? ApiUtils.parseFloat(rule.value, 0) : 0;
        var pct:Bool = inferPct ? isPctFlag(rule.isPercentage, value) : (rule.isPercentage == true);
        return new Condition(base + (pct ? "Pct" : ""), cmpOp(rule.comparison, "greater"), value);
    }

    /**
     * Defensive because rules authored through the UI or hand-edited JSON can carry the flag as
     * a string or int. Anything other than an explicit false is treated as "require an evade".
     */
    static function coerceEvadedOnly(raw:Dynamic):Bool {
        if (raw == null) return true;
        return !(raw == false || raw == 0 || raw == "false" || raw == "0");
    }
}