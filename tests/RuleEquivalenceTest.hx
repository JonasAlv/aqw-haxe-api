package;

import com.aqwapi.combat.Condition;
import com.aqwapi.combat.EntityProbe;
import com.aqwapi.combat.RuleCompiler;
import com.aqwapi.combat.RuleGroup;
import com.aqwapi.combat.SignalContext;
import com.aqwapi.combat.SignalRegistry;
import com.aqwapi.utils.ApiUtils;
import com.aqwapi.utils.SkillDslParser;
import haxe.Json;

/**
 * Differential test: the typed rule layer must agree with the pre-refactor implementation on
 * every rule and every world state.
 *
 * `legacyEvaluate` below is a FROZEN COPY of `SkillRules.evaluateRule` as it stood before the
 * typed layer existed. It is deliberately not refactored to share code with the code under test -
 * if both sides called the same helper, the test would only prove the helper agrees with itself.
 *
 * Reads all state from SignalContext so it can run off-Flash, which is why the frozen copy takes
 * a context instead of reading the Api statics.
 */
class RuleEquivalenceTest {

    static var checks:Int = 0;
    static var failures:Int = 0;
    static var ruleTypes:Map<String, Int> = new Map();
    static var seen:Map<String, Bool> = new Map();

    static function main() {
        var states:Array<SignalContext> = buildStates();

        // Live configs first, then a synthetic corpus covering the rule types that no live
        // combo happens to use. Without it the differential test would silently skip
        // TargetHealth, PartyHealth, TargetCC, AuraTime and MobAtkIn.
        var live:Array<Dynamic> = loadCombos();
        Sys.println("Loaded " + live.length + " live combos from skills.json");
        if (live.length == 0) {
            Sys.println("FAIL: no combos found - cannot prove equivalence");
            Sys.exit(1);
        }
        var all:Array<Dynamic> = live.concat(syntheticCombos());
        Sys.println("Synthetic corpus adds " + (all.length - live.length) + " steps");

        for (combo in all) {
            for (step in (cast combo.skills : Array<Dynamic>)) {
                var rules:Array<Dynamic> = (step.rules != null) ? cast step.rules : [];
                for (rule in rules) {
                    var type:String = Std.string(rule.type);
                    ruleTypes.set(type, (ruleTypes.exists(type) ? ruleTypes.get(type) : 0) + 1);

                    var cond:Condition = RuleCompiler.toCondition(rule);
                    if (cond != null && !SignalRegistry.exists(cond.signal)) {
                        // The registry is deliberately permissive about unknown signals, so a
                        // typo'd name would degrade to "always allowed" with no error at all.
                        // Every compiled signal must therefore resolve.
                        failures++;
                        if (failures <= 20) Sys.println("FAIL [" + type + "] compiled to unregistered signal '" + cond.signal + "'");
                    }
                    for (state in states) {
                        if (cond == null) {
                            // A rule that imposes nothing must be vacuously allowed, which is
                            // what the legacy fallthrough did.
                            expectDropped(type, state, true);
                            continue;
                        }
                        var ctx = state;
                        var legacy:Bool = legacyEvaluate(rule, ctx);
                        var typed:Bool = cond.evaluate(ctx);
                        expect(type, "cond", ctx, legacy, cond, typed);
                    }
                }
            }
        }

        // Whole-step AND/OR grouping, not just individual rules.
        for (combo in all) {
            for (step in (cast combo.skills : Array<Dynamic>)) {
                if (step.rules == null) continue;
                var group:RuleGroup = RuleCompiler.compile(step);
                if (group == null || group.isEmpty()) continue;
                var isOr:Bool = (step.multiAuraOperator == "OR");
                for (state in states) {
                    var legacy:Bool = isOr ? legacyAny((cast step.rules : Array<Dynamic>), state)
                                           : legacyAll((cast step.rules : Array<Dynamic>), state);
                    expect("GROUP/" + (isOr ? "OR" : "AND") + "/" + Std.string(step.skillId), "group", state, legacy, group, group.evaluate(state));
                }
            }
        }

        // The compiler must be deterministic and the cache must not change the answer.
        for (combo in all) {
            for (step in (cast combo.skills : Array<Dynamic>)) {
                if (step.rules == null) continue;
                var a = RuleCompiler.compile(step);
                var b = RuleCompiler.compile(step);
                if (a != b) {
                    failures++;
                    Sys.println("FAIL: recompile returned a different group for step " + step.skillId);
                }
            }
        }

        report();
    }

    static function report() {
        Sys.println("");
        Sys.println("Assertions: " + checks + ", failures: " + failures);
        Sys.println("Rule coverage: " + Std.string(ruleTypes));
        if (failures == 0) {
            Sys.println("EQUIVALENT");
            Sys.exit(0);
        } else {
            Sys.println("DIVERGED");
            Sys.exit(1);
        }
    }

    static function expectDropped(type:String, ctx:SignalContext, expected:Bool) {
        checks++;
        if (!expected) {
            failures++;
            if (failures <= 20) Sys.println("FAIL [" + type + "/dropped-as-allowed] legacy=true, typed=dropped @ " + describe(ctx));
        }
    }

    static function expect(type:String, kind:String, ctx:SignalContext, legacy:Bool, subject:Dynamic, typed:Bool) {
        checks++;
        if (legacy != typed) {
            failures++;
            if (failures <= 20) {
                Sys.println("FAIL [" + type + "/" + kind + "] legacy=" + legacy + " typed=" + typed
                    + "  subject=" + Std.string(subject) + "  @ " + describe(ctx));
            }
        }
    }

    // ---------------------------------------------------------------- synthetic corpus

    /**
     * Rule shapes the live configs do not currently exercise, written as DSL text so this also
     * covers the parser rather than only the compiler.
     *
     * The percentage cases matter most: `hp < 50%`, `hp < 50` and `hp < 2500` all parse to the
     * same rule type with different percentage inference, and Mana intentionally lacks the
     * `<= 100` inference that Health and TargetHealth have.
     */
    static function syntheticCombos():Array<Dynamic> {
        var snippets:Array<String> = [
            // Health / percentage inference
            "1[hp < 50%]", "1[hp > 50%]", "1[hp = 100%]", "1[hp < 50]", "1[hp > 50]",
            "1[hp < 2500]", "1[hp > 2500]", "1[health < 50%]", "1[hp >= 100%]",
            "1[mp < 50%]", "1[mp > 30]", "1[mana < 20%]", "1[mp < 20]", "1[mp > 2500]",
            // Target health
            "1[tgt:hp > 80%]", "1[target:health < 25%]", "1[mon:hp > 500]", "1[target_hp < 100]",
            "1[tgt:hp = 100%]", "1[target:health > 0]",
            // Party health
            "1[party:hp < 50%]", "1[party:health < 40%]", "1[party:hp < 2000]", "1[party.hp > 10%]",
            // Aura presence and stacks
            "1[aura(self:Speed)]", "1[!aura(self:Speed)]", "1[aura(target:Speed)]",
            "1[aura(self:Speed) >= 3]", "1[aura(self:Speed) <= 2]", "1[aura(target:Tracer Rounds) >= 1]",
            "1[multiAura(self:Might) >= 2]", "1[aura(self:Speed) > 0]", "1[aura(self:Speed) < 1]",
            // Aura timers
            "1[auraTime(self:Speed) <= 1.5s]", "1[auraTime(target:Tracer Rounds) <= 2s]",
            "1[auraRemaining(self:Speed) < 500ms]", "1[auratimer(self:Might) >= 3]",
            "1[auraTime(self:Nope) <= 5s]",
            // Wait
            "1[wait(5000ms)]", "1[wait(0)]", "1[wait(2000)]",
            // Crowd control
            "1[targetCC]", "1[!targetCC]", "1[targetstun]", "1[!mobCC]",
            // Reactive counters
            "1[afterMobAtk:2000]", "1[afterMobAtk:2000:any]", "1[afterMobAtk:2000:any:150]",
            "1[afterMobAtk(2000, any, 150)]", "1[aftermobatk:500:evaded]", "1[mobatk:1000]",
            // Predictive
            "1[mobAtkIn:500]", "1[mobAtkIn(750)]", "1[mobAtkIn]", "1[afterMobAtk]",
            // Grouping
            "1[hp > 50% & tgt:hp > 50%]", "1[hp > 50% | mp < 20%]",
            "1[hp > 50% & tgt:hp > 50% & aura(self:Speed)]",
            "1[targetCC | afterMobAtk:2000:any]",
            // Degenerate / typo handling
            "1[]", "1[nosuchcondition]", "1[hp > 50% & nosuchcondition]"
        ];

        var out:Array<Dynamic> = [];
        for (snippet in snippets) {
            var steps:Array<Dynamic> = SkillDslParser.parseCombo(snippet);
            if (steps == null || steps.length == 0) continue;
            out.push({cls: "__synthetic", mode: snippet, skills: steps});
        }
        return out;
    }

    // ---------------------------------------------------------------- world fixtures

    static function buildStates():Array<SignalContext> {
        var out:Array<SignalContext> = [];

        // Player stats across the ranges a rotation can be written against: healthy, hurt,
        // near-dead, full/near-empty mana.
        var playerStats:Array<Array<Float>> = [
            [1000, 1000, 500, 500],   // full
            [700, 1000, 350, 500],    // typical
            [250, 1000, 120, 500],    // hurt
            [0, 1000, 0, 500],        // dead / empty
            [1500, 2000, 900, 1000],  // buffed
            [900, 1000, 500, 0]       // broken max-MP stat
        ];

        var targets:Array<Dynamic> = [
            null,
            mkTarget(500, 1000, "m:1", []),
            mkTarget(100, 1000, "m:1", []),
            mkTarget(1000, 1000, "m:1", []),
            mkTarget(100, 100, "m:1", []),
            mkTarget(50, 100, "m:2", [{nam: "Stun", val: 1, cat: "Stun"}]),
            mkTarget(50, 100, "m:2", [{nam: "Tracer Rounds", val: 22, dur: 1.5, ts: 0}]),
            mkTarget(50, 100, "m:2", [{nam: "Tracer Rounds", val: 22, dur: 30, ts: 0}]),
            mkTarget(50, 100, "m:2", [{nam: "Speed", val: 3, dur: 0.4, ts: 0}]),
            {dataLeaf: null, objData: null},   // entity with no readable HP at all
            {objData: {intHP: 60, intHPMax: 200, MonMapID: "m:9"}}  // objData-only path
        ];

        // Reactive-combat context: none, fresh evade, fresh hit, stale evade, wrong attacker.
        var reactive:Array<React> = [
            new React(0, "", 0, ""),
            new React(10000, "miss", 0, "m:1"),
            new React(10000, "dodge", 0, "m:1"),
            new React(10000, "parry", 0, "m:1"),
            new React(10000, "hit", 400, "m:1"),
            new React(10000, "d", 400, "m:1"),       // damage-over-time tick
            new React(10000, "miss", 500, "m:1"),
            new React(10000, "miss", 0, "m:77"),     // wrong attacker
            new React(0, "miss", 0, "m:1")           // stale: attack long ago
        ];

        // Cooldown context: never fired, fired long ago, fired just now.
        var fires:Array<Dynamic> = [
            new Map<Int, Float>(),
            firedAt(100000),
            firedAt(500)
        ];

        for (stats in playerStats) {
            for (target in targets) {
                for (react in reactive) {
                    for (fired in fires) {
                        out.push(mkState(stats, target, react, fired));
                    }
                }
            }
        }
        return out;
    }

    static function firedAt(ago:Float):Map<Int, Float> {
        var m = new Map<Int, Float>();
        // skillId 1 and 2 have different cooldowns so wait() and cross-skill reads differ.
        m.set(1, com.aqwapi.utils.ApiTime.now() - ago);
        m.set(2, com.aqwapi.utils.ApiTime.now() - ago * 0.5);
        return m;
    }

    static function mkState(stats:Array<Float>, target:Dynamic, react:React, fired:Map<Int, Float>):SignalContext {
        // Self-auras vary with the player-stat fixture so `aura(self:X)` conditions have to
        // actually discriminate rather than being constant across the matrix.
        var selfAuras:Array<Dynamic> = switch (Std.int(stats[0])) {
            case 0: [];                                        // dead: no buffs
            case 250: [{nam: "Tracer Rounds", val: 22, dur: 1.5, ts: 0}];
            case 700: [{nam: "Speed", val: 3, dur: 12, ts: 0}];
            case 1500: [{nam: "Corpse  Ascendion", val: 1, dur: 90, ts: 0}, {nam: "Might", val: 2, dur: 4, ts: 0}];
            default: [{nam: "Might", val: 5, dur: 0.3, ts: 0}];
        };
        var avatar = {
            pnm: "me",
            dataLeaf: {
                intHP: stats[0],
                intHPMax: stats[1],
                intMP: stats[2],
                intMPMax: stats[3],
                auras: selfAuras
            }
        };
        var players:Array<Dynamic> = [
            {strFrame: "Frame 1", dataLeaf: {intHP: stats[0], intHPMax: stats[1]}},
            {strFrame: "Frame 1", dataLeaf: {intHP: 10, intHPMax: 1000}},
            {strFrame: "Frame 2", dataLeaf: {intHP: 5, intHPMax: 1000}},
            {strFrame: "Frame 1", dataLeaf: {intHP: 0, intHPMax: 1000}},
            null
        ];
        var world = {
            strFrame: "Frame 1",
            players: players,
            auraCatOf: function(a:Dynamic):String return (a != null && a.cat != null) ? Std.string(a.cat) : ""
        };
        // uoTreeLeaf deliberately absent: avatar.dataLeaf is authoritative, and this also
        // exercises the stats-tree fallback path being skipped.
        var ctx = new SignalContext(world, avatar, target, null, 1);
        ctx.aura = new MockAura();
        ctx.skillLastFired = fired;
        ctx.lastIncomingAttackAt = react.at;
        ctx.lastIncomingAttackType = react.type;
        ctx.lastIncomingAttackHp = react.hp;
        ctx.lastIncomingAttackerMMID = react.mmid;
        return ctx;
    }

    static function mkTarget(hp:Float, maxHp:Float, mmid:String, auras:Array<Dynamic>):Dynamic {
        return {
            dataLeaf: {
                intHP: Std.int(hp),
                intHPMax: Std.int(maxHp),
                MonMapID: mmid,
                auras: auras
            }
        };
    }

    static function describe(ctx:SignalContext):String {
        return "hp=" + EntityProbe.getStat(ctx.pStats, ctx.avatar, "HP")
            + " atkType=" + ctx.lastIncomingAttackType
            + " fired=" + (ctx.skillLastFired != null && ctx.skillLastFired.exists(1));
    }

    /**
     * Duck-typed stand-in for AuraManager; resolves against the same entity fixtures.
     */

    // ---------------------------------------------------------------- frozen legacy

    /** FROZEN: SkillRules.evaluateRule before the typed refactor. */
    static function legacyEvaluate(rule:Dynamic, ctx:SignalContext):Bool {
        if (rule == null) return true;
        switch (Std.string(rule.type)) {
            case "None":
                return true;

            case "TargetCC":
                var targetCc:Bool = EntityProbe.hasHardCc(ctx.target, ctx.world);
                return (rule.negate == true) ? !targetCc : targetCc;

            case "MobAtkIn":
                // The predictor has no learned samples in this fixture, so it is always null,
                // which the legacy code turns into false.
                return false;

            case "Wait":
                var waitMs:Float = (rule.timeout != null) ? ApiUtils.parseFloat(rule.timeout, 0.0) : 0.0;
                if (waitMs <= 0) return true;
                if (ctx.skillLastFired == null || !ctx.skillLastFired.exists(ctx.skillId)) return true;
                return (ctx.now - ctx.skillLastFired.get(ctx.skillId)) >= waitMs;

            case "AfterMobAtk":
                if (ctx.lastIncomingAttackAt <= 0) return false;
                var sinceAttack:Float = ctx.now - ctx.lastIncomingAttackAt;
                var winMs:Float = (rule.window != null) ? ApiUtils.parseFloat(rule.window, 1000.0) : 1000.0;
                if (sinceAttack > winMs) return false;
                if (ctx.target != null && ctx.lastIncomingAttackerMMID != "") {
                    var curMMID:String = null;
                    if (ctx.target.dataLeaf != null && ctx.target.dataLeaf.MonMapID != null) curMMID = Std.string(ctx.target.dataLeaf.MonMapID);
                    else if (ctx.target.objData != null && ctx.target.objData.MonMapID != null) curMMID = Std.string(ctx.target.objData.MonMapID);
                    if (curMMID != null && curMMID != ctx.lastIncomingAttackerMMID) return false;
                }
                var minDmg:Int = (rule.minDmg != null) ? ApiUtils.parseInt(rule.minDmg, 0) : 0;
                if (minDmg > 0 && ctx.lastIncomingAttackHp < minDmg) return false;
                var evadedOnly:Bool = true;
                if (rule.evadedOnly != null) {
                    var raw:Dynamic = rule.evadedOnly;
                    evadedOnly = !(raw == false || raw == 0 || raw == "false" || raw == "0");
                }
                if (evadedOnly) {
                    var t:String = ctx.lastIncomingAttackType;
                    if (t != "miss" && t != "dodge" && t != "parry") return false;
                }
                return true;

            case "Health":
                var hp:Float = EntityProbe.getStat(ctx.pStats, ctx.avatar, "HP");
                var maxHp:Float = EntityProbe.getStat(ctx.pStats, ctx.avatar, "MaxHP");
                var targetVal:Float = ApiUtils.parseFloat(rule.value, 0);
                var isPct:Bool = (rule.isPercentage == true || (rule.isPercentage == null && targetVal <= 100));
                var currentVal:Float = isPct ? (maxHp > 0 ? (hp / maxHp * 100) : 0) : hp;
                return legacyCompare(currentVal, targetVal, Std.string(rule.comparison));

            case "TargetHealth":
                if (ctx.target == null) return false;
                var dl:Dynamic = ctx.target.dataLeaf;
                var od:Dynamic = ctx.target.objData;
                var hp2:Float = 0;
                var maxHp2:Float = 100;
                if (dl != null && dl.intHP != null) {
                    hp2 = ApiUtils.parseFloat(dl.intHP, 0);
                    maxHp2 = (dl.intHPMax != null && dl.intHPMax > 0) ? ApiUtils.parseFloat(dl.intHPMax, 100) : 100;
                } else if (od != null && od.intHP != null) {
                    hp2 = ApiUtils.parseFloat(od.intHP, 0);
                    maxHp2 = (od.intHPMax != null && od.intHPMax > 0) ? ApiUtils.parseFloat(od.intHPMax, 100) : 100;
                } else {
                    return false;
                }
                var tVal:Float = ApiUtils.parseFloat(rule.value, 0);
                var tPct:Bool = (rule.isPercentage == true || (rule.isPercentage == null && tVal <= 100));
                var tCur:Float = tPct ? (maxHp2 > 0 ? (hp2 / maxHp2 * 100) : 0) : hp2;
                return legacyCompare(tCur, tVal, Std.string(rule.comparison));

            case "Mana":
                var mp:Float = EntityProbe.getStat(ctx.pStats, ctx.avatar, "MP");
                var maxMp:Float = EntityProbe.getStat(ctx.pStats, ctx.avatar, "MaxMP");
                var mVal:Float = ApiUtils.parseFloat(rule.value, 0);
                var mPct:Bool = (rule.isPercentage == true);
                var mCur:Float = mPct ? (maxMp > 0 ? (mp / maxMp * 100) : 0) : mp;
                return legacyCompare(mCur, mVal, Std.string(rule.comparison));

            case "PartyHealth":
                return legacyPartyHealth(rule, ctx);

            case "AuraTime", "AuraRemaining", "AuraTimer":
                var auraName:String = (rule.auraName != null) ? Std.string(rule.auraName) : "";
                var auraTarget:String = (rule.auraTarget != null) ? Std.string(rule.auraTarget) : "self";
                var stacks:Float = ctx.aura.getStacks(auraName, auraTarget, ctx.world, ctx.avatar, ctx.target);
                if (stacks <= 0) return false;
                var remainingSec:Float = ctx.aura.getRemaining(auraName, auraTarget, ctx.world, ctx.avatar, ctx.target);
                var threshold:Float = ApiUtils.parseFloat(rule.value, 0);
                return legacyCompare(remainingSec, threshold, Std.string(rule.comparison));

            case "Aura", "MultiAura":
                var auraName2:String = (rule.auraName != null) ? Std.string(rule.auraName) : "";
                var auraTarget2:String = (rule.auraTarget != null) ? Std.string(rule.auraTarget) : "self";
                var stacks2:Float = ctx.aura.getStacks(auraName2, auraTarget2, ctx.world, ctx.avatar, ctx.target);
                var threshold2:Float = ApiUtils.parseFloat(rule.value, 0);
                var comp:String = (rule.comparison != null) ? Std.string(rule.comparison) : "greater";
                if (comp == "greater") {
                    return (threshold2 > 0) ? (stacks2 >= threshold2) : (stacks2 > 0);
                } else {
                    return (threshold2 > 0) ? (stacks2 <= threshold2) : (stacks2 <= 0);
                }
        }
        return true;
    }

    /** FROZEN: SkillRules.compare - the lossy operator mapping that must not drift. */
    static function legacyCompare(val:Float, threshold:Float, comp:String):Bool {
        if (comp == "equal" || comp == "==" || comp == "=") return val == threshold;
        return comp == "greater" ? val >= threshold : val <= threshold;
    }

    /** FROZEN: SkillRules.evaluatePartyHealth. */
    static function legacyPartyHealth(rule:Dynamic, ctx:SignalContext):Bool {
        var world = ctx.world;
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
                if (hp <= 0) continue;
                var maxHp:Float = (dl.intHPMax != null && dl.intHPMax > 0) ? Std.int(dl.intHPMax) : 100;
                var val:Float = isPct ? (maxHp > 0 ? (hp / maxHp * 100) : 0) : hp;
                if (legacyCompare(val, threshold, comp)) return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }

    static function legacyAll(rules:Array<Dynamic>, ctx:SignalContext):Bool {
        for (r in rules) if (!legacyEvaluate(r, ctx)) return false;
        return true;
    }

    static function legacyAny(rules:Array<Dynamic>, ctx:SignalContext):Bool {
        for (r in rules) if (legacyEvaluate(r, ctx)) return true;
        return false;
    }

    // ---------------------------------------------------------------- loading

    static function loadCombos():Array<Dynamic> {
        var path = "../aqw-mobile-mod/loader/assets/skills.json";
        if (!sys.FileSystem.exists(path)) {
            Sys.println("WARN: " + path + " not found");
            return [];
        }
        var parsed:Dynamic;
        try {
            parsed = Json.parse(sys.io.File.getContent(path));
        } catch (e:Dynamic) {
            Sys.println("WARN: skills.json is not parseable right now (" + e + ") - skipping");
            return [];
        }
        var out:Array<Dynamic> = [];
        for (className in Reflect.fields(parsed)) {
            var modes:Dynamic = Reflect.field(parsed, className);
            if (modes == null) continue;
            for (modeName in Reflect.fields(modes)) {
                var mode:Dynamic = Reflect.field(modes, modeName);
                if (mode == null) continue;
                var combo:String = mode.combo;
                if (combo == null || combo.length == 0) continue;
                var steps:Array<Dynamic> = SkillDslParser.parseCombo(combo);
                if (steps == null || steps.length == 0) continue;
                out.push({cls: className, mode: modeName, skills: steps});
            }
        }
        return out;
    }
}