package com.aqwapi.combat;

import com.aqwapi.Api;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiUtils;

class SkillRules {

    /**
     * Evaluates a combo step's rules.
     *
     * The step is compiled to a typed RuleGroup once (see RuleCompiler.compile) and cached on the
     * step, so the per-tick path is a walk over typed Conditions instead of a switch over a
     * stringly-typed `Dynamic`. `evaluateRule` below is retained as the reference oracle the
     * typed path is checked against in tests/test-equivalence.
     */
    public static function evaluateSkillRules(skill:Dynamic, world:Dynamic, avatar:Dynamic, target:Dynamic, skillId:Int):Bool {
        if (skill == null || skill.rules == null) return true;
        var rules:Dynamic = skill.rules;
        if (!Std.isOfType(rules, Array)) return true;
        var arr:Array<Dynamic> = cast rules;
        if (arr.length == 0) return true;

        var group:RuleGroup = RuleCompiler.compile(skill);
        if (group == null || group.isEmpty()) return true;

        return group.evaluate(liveContext(world, avatar, target, skillId));
    }

    /**
     * Snapshots the live Api statics into a SignalContext.
     *
     * This is the single point where the rule layer touches global state, which is what keeps
     * SignalRegistry free of it and therefore testable off-Flash.
     */
    public static function liveContext(world:Dynamic, avatar:Dynamic, target:Dynamic, skillId:Int):SignalContext {
        var ctx = new SignalContext(world, avatar, target, EntityProbe.getPlayerStats(world, avatar), skillId);
        ctx.aura = Api.aura;
        ctx.skillLastFired = Api.skillLastFired;
        ctx.lastIncomingAttackAt = Api.lastIncomingAttackAt;
        ctx.lastIncomingAttackType = Api.lastIncomingAttackType;
        ctx.lastIncomingAttackHp = Api.lastIncomingAttackHp;
        ctx.lastIncomingAttackerMMID = Api.lastIncomingAttackerMMID;
        return ctx;
    }

    /** LEGACY REFERENCE IMPLEMENTATION. Superseeded by RuleCompiler + SignalRegistry. */
    public static function evaluateRule(rule:Dynamic, world:Dynamic, avatar:Dynamic, target:Dynamic, pStats:Dynamic, skillId:Int):Bool {
        if (rule == null) return true;
        switch (Std.string(rule.type)) {
            case "None":
                return true;

            case "TargetCC":
                // True while the current target is hard crowd-controlled. Uses the same
                // authoritative aura-category signal as the player CC guard, so the two
                // can never disagree about what counts as CC.
                var targetCc:Bool = hasHardCc(target, world);
                return (rule.negate == true) ? !targetCc : targetCc;

            case "MobAtkIn":
                // Predictive: fires only when the learned cadence says a swing is imminent.
                // A null prediction means the predictor has too few samples or the spread is
                // too wide, which returns false so ordinary priority execution takes over.
                var mobWin:Float = (rule.window != null) ? ApiUtils.parseFloat(rule.window, 500.0) : 500.0;
                var eta:Null<Float> = AttackCadence.timeUntilNext(ApiTime.now());
                if (eta == null) {
                    AttackCadence.warnUnstableOnce();
                    return false;
                }
                return eta <= mobWin;

            case "Wait":
                // READ-ONLY. Previously this armed a timestamp as a side effect of being
                // evaluated, which meant a skill could burn its whole wait budget without
                // ever being cast - most visibly when the GCD returned between evaluation
                // and the cast. The budget is now committed by Api.noteSkillFired only on
                // a real SR_FIRED.
                var waitMs:Float = (rule.timeout != null) ? ApiUtils.parseFloat(rule.timeout, 0.0) : 0.0;
                if (waitMs <= 0) return true;
                if (!Api.skillLastFired.exists(skillId)) return true;
                return (ApiTime.now() - Api.skillLastFired.get(skillId)) >= waitMs;

            case "AfterMobAtk":
                // Reactive counter. Only usable in `UseIfAvailable` mode - in
                // WaitForCooldown a failing rule advances _skillIndex and skips the step.
                if (Api.lastIncomingAttackAt <= 0) return false;

                var sinceAttack:Float = ApiTime.now() - Api.lastIncomingAttackAt;
                var winMs:Float = (rule.window != null) ? ApiUtils.parseFloat(rule.window, 1000.0) : 1000.0;
                if (sinceAttack > winMs) return false;

                // Ignore hits that came from something other than the current target.
                if (target != null && Api.lastIncomingAttackerMMID != "") {
                    var curMMID:String = null;
                    if (target.dataLeaf != null && target.dataLeaf.MonMapID != null) curMMID = Std.string(target.dataLeaf.MonMapID);
                    else if (target.objData != null && target.objData.MonMapID != null) curMMID = Std.string(target.objData.MonMapID);
                    if (curMMID != null && curMMID != Api.lastIncomingAttackerMMID) return false;
                }

                // Damage gate: only react when the hit actually hurt.
                var minDmg:Int = (rule.minDmg != null) ? ApiUtils.parseInt(rule.minDmg, 0) : 0;
                if (minDmg > 0 && Api.lastIncomingAttackHp < minDmg) return false;

                // Default to requiring an evaded outcome. Coerce defensively because a rule
                // authored through the UI/JSON may carry the flag as a string or int.
                var evadedOnly:Bool = true;
                if (rule.evadedOnly != null) {
                    var raw:Dynamic = rule.evadedOnly;
                    evadedOnly = !(raw == false || raw == 0 || raw == "false" || raw == "0");
                }
                if (evadedOnly) {
                    var t:String = Api.lastIncomingAttackType;
                    if (t != "miss" && t != "dodge" && t != "parry") return false;
                }
                return true;

            case "Health":
                var hp:Float = getStat(pStats, avatar, "HP");
                var maxHp:Float = getStat(pStats, avatar, "MaxHP");
                var targetVal:Float = ApiUtils.parseFloat(rule.value, 0);
                var isPct:Bool = (rule.isPercentage == true || (rule.isPercentage == null && targetVal <= 100));
                var currentVal:Float = isPct ? (maxHp > 0 ? (hp / maxHp * 100) : 0) : hp;
                return compare(currentVal, targetVal, Std.string(rule.comparison));

            case "TargetHealth":
                if (target == null) return false;
                var dl:Dynamic = target.dataLeaf;
                var od:Dynamic = target.objData;
                var hp:Float = 0;
                var maxHp:Float = 100;
                if (dl != null && dl.intHP != null) {
                    hp = ApiUtils.parseFloat(dl.intHP, 0);
                    maxHp = (dl.intHPMax != null && dl.intHPMax > 0) ? ApiUtils.parseFloat(dl.intHPMax, 100) : 100;
                } else if (od != null && od.intHP != null) {
                    hp = ApiUtils.parseFloat(od.intHP, 0);
                    maxHp = (od.intHPMax != null && od.intHPMax > 0) ? ApiUtils.parseFloat(od.intHPMax, 100) : 100;
                } else {
                    return false;
                }
                var targetVal:Float = ApiUtils.parseFloat(rule.value, 0);
                var isPct:Bool = (rule.isPercentage == true || (rule.isPercentage == null && targetVal <= 100));
                var currentVal:Float = isPct ? (maxHp > 0 ? (hp / maxHp * 100) : 0) : hp;
                return compare(currentVal, targetVal, Std.string(rule.comparison));

            case "Mana":
                var mp:Float = getStat(pStats, avatar, "MP");
                var maxMp:Float = getStat(pStats, avatar, "MaxMP");
                var targetVal:Float = ApiUtils.parseFloat(rule.value, 0);
                var isPct:Bool = (rule.isPercentage == true);
                var currentVal:Float = isPct ? (maxMp > 0 ? (mp / maxMp * 100) : 0) : mp;
                return compare(currentVal, targetVal, Std.string(rule.comparison));

            case "PartyHealth":
                return evaluatePartyHealth(rule, world, avatar);

            case "AuraTime", "AuraRemaining", "AuraTimer":
                var auraName:String = (rule.auraName != null) ? Std.string(rule.auraName) : "";
                var auraTarget:String = (rule.auraTarget != null) ? Std.string(rule.auraTarget) : "self";
                var stacks:Float = Api.aura.getStacks(auraName, auraTarget, world, avatar, target);
                if (stacks <= 0) return false;
                var remainingSec:Float = Api.aura.getRemaining(auraName, auraTarget, world, avatar, target);
                var threshold:Float = ApiUtils.parseFloat(rule.value, 0);
                return compare(remainingSec, threshold, Std.string(rule.comparison));

            case "Aura", "MultiAura":
                var auraName:String = (rule.auraName != null) ? Std.string(rule.auraName) : "";
                var auraTarget:String = (rule.auraTarget != null) ? Std.string(rule.auraTarget) : "self";
                var stacks:Float = Api.aura.getStacks(auraName, auraTarget, world, avatar, target);
                var threshold:Float = ApiUtils.parseFloat(rule.value, 0);
                var comp:String = (rule.comparison != null) ? Std.string(rule.comparison) : "greater";
                if (comp == "greater") {
                    return (threshold > 0) ? (stacks >= threshold) : (stacks > 0);
                } else {
                    return (threshold > 0) ? (stacks <= threshold) : (stacks <= 0);
                }
        }
        return true;
    }

    public static function compare(val:Float, threshold:Float, comp:String):Bool {
        if (comp == "equal" || comp == "==" || comp == "=") return val == threshold;
        return comp == "greater" ? val >= threshold : val <= threshold;
    }

    public static function evaluatePartyHealth(rule:Dynamic, world:Dynamic, avatar:Dynamic):Bool {
        if (world == null || world.players == null) return false;
        var threshold:Float = ApiUtils.parseFloat(rule.value, 0);
        var isPct:Bool = (rule.isPercentage == true || (rule.isPercentage == null && threshold <= 100));
        var comp:String = (rule.comparison != null) ? Std.string(rule.comparison) : "less";
        var myFrame:String = (world.strFrame != null) ? Std.string(world.strFrame) : "";

        try {
            var players:Array<Dynamic> = cast world.players;
            for (p in players) {
                if (p == null) continue;
                var pFrame:String = (p.strFrame != null) ? Std.string(p.strFrame) : "";
                if (pFrame != myFrame) continue;
                var dl:Dynamic = p.dataLeaf;
                if (dl == null || dl.intHP == null) continue;
                var hp:Float = Std.int(dl.intHP);
                var maxHp:Float = (dl.intHPMax != null && dl.intHPMax > 0) ? Std.int(dl.intHPMax) : 100;
                if (hp <= 0) continue;
                var val:Float = isPct ? (maxHp > 0 ? (hp / maxHp * 100) : 0) : hp;
                if (compare(val, threshold, comp)) return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }

    public static function getPlayerStats(world:Dynamic, avatar:Dynamic):Dynamic {
        return EntityProbe.getPlayerStats(world, avatar);
    }

    /**
     * True when the given entity is hard crowd-controlled.
     *
     * Reads aura CATEGORIES via the client's own `auraCatOf`, which normalises the server-sent
     * `aura.cat` field. The five literals below are the complete set the client itself
     * compares against when deciding whether an action is blocked.
     */
    public static function hasHardCc(entity:Dynamic, world:Dynamic):Bool {
        return EntityProbe.hasHardCc(entity, world);
    }

    public static function getStat(pStats:Dynamic, avatar:Dynamic, stat:String):Float {
        return EntityProbe.getStat(pStats, avatar, stat);
    }
}
