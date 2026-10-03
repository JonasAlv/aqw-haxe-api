package com.aqwapi.combat;

import com.aqwapi.utils.ApiUtils;

/**
 * Every predicate the rule layer can evaluate, in one place.
 *
 * Two flavours of signal:
 *
 *   scalar    - reads a single number out of the world and compares it (playerHp, buffStacks, ...)
 *   aggregate - inherently a set or a multi-gate predicate, so it receives the comparison
 *               operator and threshold and answers directly (partyHealth, afterMobAttack, ...)
 *
 * An unknown signal evaluates to `true`. That mirrors the legacy `SkillRules.evaluateRule`
 * fallthrough, so a rule the compiled layer does not recognise degrades to "allowed" instead of
 * silently freezing a rotation.
 *
 * Reads all state from SignalContext rather than the Api statics - see SignalContext.
 */
class SignalRegistry {

    /** Stands in for "this never happened". Larger than any real elapsed time, so a
     *  `>= waitMs` comparison against it succeeds, which is exactly what a never-fired
     *  cooldown should do. */
    public static inline var NEVER:Float = 1e18;

    /** True when `signal` names a registered predicate. */
    public static function exists(signal:String):Bool return resolve(signal) != null;

    public static function test(cond:Condition, ctx:SignalContext):Bool {
        var fn = resolve(cond.signal);
        if (fn == null) return true;
        return fn(cond, ctx);
    }

    static function resolve(signal:String):(Condition, SignalContext)->Bool {
        return switch (signal) {
            case "playerHp":       playerHp;
            case "playerHpPct":    playerHpPct;
            case "playerMp":       playerMp;
            case "playerMpPct":    playerMpPct;
            case "targetHp":       targetHp;
            case "targetHpPct":    targetHpPct;
            case "partyHealth":    partyHealth;
            case "buffStacks":     buffStacks;
            case "buffRemaining":  buffRemaining;
            case "targetCc":       targetCc;
            case "sinceSkillCast": sinceSkillCast;
            case "afterMobAttack": afterMobAttack;
            case "mobAttackIn":    mobAttackIn;
            default:               null;
        }
    }

    // ---------------------------------------------------------------- comparison

    /**
     * Faithful port of `SkillRules.compare`.
     *
     * The legacy mapping is lossy and deliberately preserved: `greater` and `>` both mean `>=`,
     * and anything unrecognised - including `<` - falls through to `<=`. Changing that would
     * change the behaviour of rules already live in skills.json, so new strict operators are
     * opt-in via the explicit op strings below.
     */
    public static function cmp(val:Float, threshold:Float, op:String):Bool {
        if (op == "==" || op == "=" || op == "equal") return val == threshold;
        if (op == ">" || op == ">=" || op == "greater") return val >= threshold;
        if (op == "<") return val < threshold;
        if (op == "!=") return val != threshold;
        return val <= threshold;
    }

    // ---------------------------------------------------------------- player

    static function playerHp(cond:Condition, ctx:SignalContext):Bool {
        return cmp(EntityProbe.getStat(ctx.pStats, ctx.avatar, "HP"), num(cond.value), cond.op);
    }

    static function playerHpPct(cond:Condition, ctx:SignalContext):Bool {
        var hp = EntityProbe.getStat(ctx.pStats, ctx.avatar, "HP");
        var maxHp = EntityProbe.getStat(ctx.pStats, ctx.avatar, "MaxHP");
        return cmp(pct(hp, maxHp), num(cond.value), cond.op);
    }

    static function playerMp(cond:Condition, ctx:SignalContext):Bool {
        return cmp(EntityProbe.getStat(ctx.pStats, ctx.avatar, "MP"), num(cond.value), cond.op);
    }

    static function playerMpPct(cond:Condition, ctx:SignalContext):Bool {
        var mp = EntityProbe.getStat(ctx.pStats, ctx.avatar, "MP");
        var maxMp = EntityProbe.getStat(ctx.pStats, ctx.avatar, "MaxMP");
        return cmp(pct(mp, maxMp), num(cond.value), cond.op);
    }

    // ---------------------------------------------------------------- target

    static function targetHp(cond:Condition, ctx:SignalContext):Bool {
        if (!EntityProbe.targetHp(ctx)) return false;
        return cmp(ctx.targetHpValue, num(cond.value), cond.op);
    }

    static function targetHpPct(cond:Condition, ctx:SignalContext):Bool {
        if (!EntityProbe.targetHp(ctx)) return false;
        return cmp(pct(ctx.targetHpValue, ctx.targetHpMax), num(cond.value), cond.op);
    }

    /** True while the target is hard CC'd, via the client's own aura-category normalisation. */
    static function targetCc(cond:Condition, ctx:SignalContext):Bool {
        return EntityProbe.hasHardCc(ctx.target, ctx.world);
    }

    // ---------------------------------------------------------------- party

    /**
     * Existential over every living player in the same frame - true if ANY of them matches.
     * Aggregate because "any" has no single number to compare against.
     */
    static function partyHealth(cond:Condition, ctx:SignalContext):Bool {
        var world = ctx.world;
        if (world == null || world.players == null) return false;
        var isPct:Bool = (cond.args != null && cond.args.isPct == true);
        var threshold:Float = num(cond.value);
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
                if (cmp(isPct ? pct(hp, maxHp) : hp, threshold, cond.op)) return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }

    // ---------------------------------------------------------------- auras

    /**
     * Returns [stacks, remainingSec]. `ctx.aura` is duck-typed to AuraManager; a null aura
     * yields zeroes, which every aura rule treats as "not present".
     */
    static function auraOf(ctx:SignalContext, cond:Condition):Array<Float> {
        if (ctx.aura == null) return [0, 0];
        var name:String = (cond.args != null && cond.args.name != null) ? Std.string(cond.args.name) : "";
        var on:String = (cond.args != null && cond.args.target != null) ? Std.string(cond.args.target) : "self";
        return [ctx.aura.getStacks(name, on, ctx.world, ctx.avatar, ctx.target),
                ctx.aura.getRemaining(name, on, ctx.world, ctx.avatar, ctx.target)];
    }

    /**
     * Stack-count comparison with the legacy threshold-0 special case preserved: `greater`
     * against 0 means "has the buff at all" (strictly > 0), not `>= 0`, which would be
     * unconditionally true.
     */
    static function buffStacks(cond:Condition, ctx:SignalContext):Bool {
        var stacks:Float = auraOf(ctx, cond)[0];
        var threshold:Float = num(cond.value);
        switch (cond.op) {
            case ">":
                return stacks > threshold;
            case "<":
                return stacks < threshold;
            case "==":
                return stacks == threshold;
            case "!=":
                return stacks != threshold;
            case ">=":
                return (threshold > 0) ? (stacks >= threshold) : (stacks > 0);
            default:
                return (threshold > 0) ? (stacks <= threshold) : (stacks <= 0);
        }
    }

    static function buffRemaining(cond:Condition, ctx:SignalContext):Bool {
        var buf:Array<Float> = auraOf(ctx, cond);
        if (buf[0] <= 0) return false;
        return cmp(buf[1], num(cond.value), cond.op);
    }

    // ---------------------------------------------------------------- cooldowns

    /** NEVER for a skill that has not fired yet, so `>= waitMs` passes on the first tick. */
    static function sinceSkillCast(cond:Condition, ctx:SignalContext):Bool {
        var id:Int = ctx.skillId;
        if (cond.args != null && cond.args.skillId != null) id = toInt(cond.args.skillId);
        var fired:Map<Int, Float> = ctx.skillLastFired;
        if (fired == null || !fired.exists(id)) return cmp(NEVER, num(cond.value), cond.op);
        return cmp(ctx.now - fired.get(id), num(cond.value), cond.op);
    }

    // ---------------------------------------------------------------- reactive combat

    /**
     * Reactive counter, gated on a monster attack landing on the player inside the window and
     * coming from the current target.
     *
     * Aggregate because the rule is a conjunction over four independent facts, two of which
     * ("no attack seen yet", "attacker is not the current target") must short-circuit to false
     * before the rest are read.
     */
    static function afterMobAttack(cond:Condition, ctx:SignalContext):Bool {
        if (ctx.lastIncomingAttackAt <= 0) return false;

        var sinceAttack:Float = ctx.now - ctx.lastIncomingAttackAt;
        var winMs:Float = (cond.args != null && cond.args.windowMs != null) ? num(cond.args.windowMs) : 1000.0;
        if (sinceAttack > winMs) return false;

        if (ctx.target != null && ctx.lastIncomingAttackerMMID != "") {
            var curMMID:String = EntityProbe.targetMMID(ctx.target);
            if (curMMID != null && curMMID != ctx.lastIncomingAttackerMMID) return false;
        }

        var minDmg:Int = (cond.args != null && cond.args.minDmg != null) ? toInt(cond.args.minDmg) : 0;
        if (minDmg > 0 && ctx.lastIncomingAttackHp < minDmg) return false;

        if (cond.args == null || cond.args.evadedOnly != false) {
            var t:String = ctx.lastIncomingAttackType;
            if (t != "miss" && t != "dodge" && t != "parry") return false;
        }
        return true;
    }

    /**
     * Predictive: true only when the learned cadence says a swing is imminent. An unstable
     * prediction returns false so ordinary priority execution takes over, and warns once.
     */
    static function mobAttackIn(cond:Condition, ctx:SignalContext):Bool {
        var winMs:Float = (cond.args != null && cond.args.windowMs != null) ? num(cond.args.windowMs) : 500.0;
        var eta:Null<Float> = AttackCadence.timeUntilNext(ctx.now);
        if (eta == null) {
            AttackCadence.warnUnstableOnce();
            return false;
        }
        return eta <= winMs;
    }

    // ---------------------------------------------------------------- helpers

    static inline function num(v:Dynamic):Float return ApiUtils.parseFloat(v, 0);

    static function toInt(v:Dynamic):Int return ApiUtils.parseInt(v, 0);

    static inline function pct(cur:Float, max:Float):Float return max > 0 ? (cur / max * 100) : 0;
}