package com.aqwapi.combat;

import com.aqwapi.utils.ApiTime;

/**
 * Everything a condition needs to be evaluated, gathered once per rule evaluation.
 *
 * Deliberately Api-free: all live state arrives by injection. `SkillRules` fills this from the
 * Api statics at the call site, while tests supply a synthetic snapshot. That is what lets the
 * whole rule layer be compiled and exercised off-Flash.
 *
 * Conditions are pure reads: they never mutate anything except the two targetHp scratch fields,
 * which exist only to avoid allocating an out-parameter tuple per tick.
 */
class SignalContext {
    public var world:Dynamic;
    public var avatar:Dynamic;
    public var target:Dynamic;

    /** `world.uoTreeLeaf(avatar.pnm)` - null when the stats tree is unavailable. */
    public var pStats:Dynamic;

    public var skillId:Int;

    /** Monotonic ms, read once so every condition in a group agrees on "now". */
    public var now:Float;

    /** Aura lookup, duck-typed to `com.aqwapi.managers.AuraManager`. */
    public var aura:Dynamic;

    /** skillId -> monotonic timestamp of its last actual cast. */
    public var skillLastFired:Map<Int, Float>;

    /** Monotonic timestamp of the last monster attack resolved against us, or <= 0 for none. */
    public var lastIncomingAttackAt:Float;

    /** "miss" | "dodge" | "parry" | ... from the server's own action resolution. */
    public var lastIncomingAttackType:String;

    public var lastIncomingAttackHp:Int;

    public var lastIncomingAttackerMMID:String;

    /** Scratch output of EntityProbe.targetHp. */
    public var targetHpValue:Float;

    /** Scratch output of EntityProbe.targetHp. */
    public var targetHpMax:Float;

    public function new(world:Dynamic, avatar:Dynamic, target:Dynamic, pStats:Dynamic, skillId:Int) {
        this.world = world;
        this.avatar = avatar;
        this.target = target;
        this.pStats = pStats;
        this.skillId = skillId;
        this.now = ApiTime.now();
        this.skillLastFired = null;
        this.lastIncomingAttackAt = 0;
        this.lastIncomingAttackType = "";
        this.lastIncomingAttackHp = 0;
        this.lastIncomingAttackerMMID = "";
    }
}