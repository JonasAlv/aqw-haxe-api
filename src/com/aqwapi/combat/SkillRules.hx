package com.aqwapi.combat;

import com.aqwapi.Api;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiUtils;

class SkillRules {

    public static function evaluateSkillRules(skill:Dynamic, world:Dynamic, avatar:Dynamic, target:Dynamic, skillId:Int, waitUntil:Dynamic):Bool {
        if (skill == null || skill.rules == null) return true;
        var rules:Dynamic = skill.rules;
        if (!Std.isOfType(rules, Array)) return true;
        var arr:Array<Dynamic> = cast rules;
        if (arr.length == 0) return true;

        var pStats:Dynamic = getPlayerStats(world, avatar);
        var multiAuraOp:String = (skill.multiAuraOperator != null) ? Std.string(skill.multiAuraOperator).toUpperCase() : "AND";

        if (multiAuraOp == "OR") {
            var anyPassed:Bool = false;
            for (rule in arr) {
                if (evaluateRule(rule, world, avatar, target, pStats, skillId, waitUntil)) {
                    anyPassed = true;
                    break;
                }
            }
            return anyPassed;
        } else {
            for (rule in arr) {
                if (!evaluateRule(rule, world, avatar, target, pStats, skillId, waitUntil)) return false;
            }
            return true;
        }
    }

    public static function evaluateRule(rule:Dynamic, world:Dynamic, avatar:Dynamic, target:Dynamic, pStats:Dynamic, skillId:Int, waitUntil:Dynamic):Bool {
        if (rule == null) return true;
        switch (Std.string(rule.type)) {
            case "None":
                return true;

            case "Wait":
                var wKey:String = "s" + skillId;
                var now:Float = ApiTime.now();
                var timeout:Float = rule.timeout != null ? ApiUtils.parseInt(rule.timeout, 0) : 0;
                var waitVal:Null<Float> = (waitUntil != null) ? Reflect.field(waitUntil, wKey) : null;
                if (waitVal == null || now >= waitVal) {
                    if (waitUntil != null) Reflect.setField(waitUntil, wKey, now + timeout);
                    return true;
                }
                return false;

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
        try { if (world.uoTreeLeaf != null && avatar.pnm != null) return world.uoTreeLeaf(avatar.pnm); } catch (_:Dynamic) {}
        return null;
    }

    public static function getStat(pStats:Dynamic, avatar:Dynamic, stat:String):Float {
        var dl:Dynamic = (avatar != null) ? avatar.dataLeaf : null;
        switch (stat) {
            case "HP":    return (dl != null && dl.intHP != null) ? dl.intHP : ((pStats != null && pStats.intHP != null) ? pStats.intHP : 0);
            case "MaxHP": return (dl != null && dl.intHPMax != null && dl.intHPMax > 0) ? dl.intHPMax : ((pStats != null && pStats.intHPMax != null && pStats.intHPMax > 0) ? pStats.intHPMax : 100);
            case "MP":    return (dl != null && dl.intMP != null) ? dl.intMP : ((pStats != null && pStats.intMP != null) ? pStats.intMP : 0);
            case "MaxMP": return (dl != null && dl.intMPMax != null && dl.intMPMax > 0) ? dl.intMPMax : ((pStats != null && pStats.intMPMax != null && pStats.intMPMax > 0) ? pStats.intMPMax : 100);
        }
        return 0;
    }
}
