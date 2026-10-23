package com.aqwapi.combat;

import com.aqwapi.Api;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiUtils;
import com.aqwapi.utils.ApiTimings;

class SkillCaster {
    public static inline var SR_FIRED:Int    = 0;  // Fired successfully
    public static inline var SR_TIMING:Int   = 1;  // TimingBlocked: GCD or per-skill CD not ready
    public static inline var SR_RESOURCE:Int = 2;  // ResourceBlocked: not enough MP/HP, dead, or skill not found

    /**
     * Checks if the game's native GCD is active (`World.actionTimeCheck` in World.as:9340).
     */
    public static function isGcdActive(world:Dynamic):Bool {
        if (world == null) return false;
        try {
            var gcdTs:Float = (world.GCDTS != null) ? ApiUtils.parseFloat(world.GCDTS, 0) : 0;
            var gcdMs:Float = (world.GCD != null) ? ApiUtils.parseFloat(world.GCD, ApiTimings.NATIVE_GCD_MS) : ApiTimings.NATIVE_GCD_MS;
            if (gcdTs > 0) {
                var nowMs:Float = (world.dateObj != null && world.dateObj.getTime != null)
                    ? ApiUtils.parseFloat(world.dateObj.getTime(), ApiTime.epochMs())
                    : ApiTime.epochMs();
                if ((nowMs - gcdTs) < gcdMs) return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }

    /**
     * Resolves the Action object for a given skill slot (0..5).
     * Slot 0 is whatever is on the action bar — Auto Attack for most classes,
     * a real skill for others. Auto Attack itself is resolved by
     * `getAutoAttackAction`, never by assuming index 0 is `"aa"`.
     */
    public static function getSkillAction(idx:Int):Dynamic {
        if (Api.game != null && Api.game.world != null) {
            var world:Dynamic = Api.game.world;
            // AQW's sixth action-bar slot is the consumable action ref `i1`, not `a5`.
            // Resolve the actual displayed i6 button first. The game's keyboard handler resolves
            // actionMap[5] and then calls testAction(); the external bridge cannot safely read
            // World.actionMap on every build because it is internal, while actBar.i6.actObj is the
            // same action object installed for the visible native button.
            if (idx == 5) {
                try {
                    var potionIcon:Dynamic = getIcon(5);
                    if (potionIcon != null && potionIcon.actObj != null) return potionIcon.actObj;
                } catch (_:Dynamic) {}
                try {
                    if (world.actions != null && world.actions.active != null) {
                        var activePotion:Dynamic = world.actions.active[5];
                        if (activePotion != null && activePotion.ref == "i1") return activePotion;
                    }
                } catch (_:Dynamic) {}
                try {
                    if (world.getActionByRef != null) {
                        var potionAct:Dynamic = world.getActionByRef("i1");
                        if (potionAct != null) return potionAct;
                    }
                } catch (_:Dynamic) {}
            }
            // 1. `actions.active` is public and is what `World.getAutoAttack()` itself scans, so it
            //    is the reliable slot index. Preferred over the refs below.
            if (world.actions != null && world.actions.active != null) {
                try {
                    var actList:Array<Dynamic> = cast world.actions.active;
                    // AQW identifies the consumable action by ref `i1`; it is not guaranteed to be
                    // at array index 5 after a class/action-bar refresh. Resolve it by the game's
                    // stable ref before using the slot-index fallback.
                    if (idx == 5) {
                        for (potionAct in actList) {
                            if (potionAct != null && potionAct.ref == "i1") return potionAct;
                        }
                    }
                    if (idx >= 0 && idx < actList.length) {
                        var act:Dynamic = actList[idx];
                        if (act != null) return act;
                    }
                } catch (_:Dynamic) {}
            }
            // 2. Native actionMap. It is `internal` on World (World.as:254), so reading it from this
            //    SWF throws ReferenceError #1069 and the resolution falls through - which is fine,
            //    step 1 already answered, but keep it ahead of the ref guesswork for safety.
            try {
                if (world.actionMap != null && world.actionMap[idx] != null && world.getActionByRef != null) {
                    var act:Dynamic = world.getActionByRef(Std.string(world.actionMap[idx]));
                    if (act != null) return act;
                }
            } catch (_:Dynamic) {}
            // 3. Ref convention fallback for skills 1..5 only ("a1".."a5").
            // Slot 0 must not fall back to "aa": some classes put a real skill there.
            try {
                if (idx > 0 && world.getActionByRef != null) {
                    var act:Dynamic = world.getActionByRef("a" + idx);
                    if (act != null) return act;
                }
            } catch (_:Dynamic) {}
        }
        var icon:Dynamic = getIcon(idx);
        if (icon != null && icon.actObj != null) return icon.actObj;
        return null;
    }

    public static function getIcon(idx:Int):Dynamic {
        if (Api.game == null || Api.game.ui == null || Api.game.ui.mcInterface == null || Api.game.ui.mcInterface.actBar == null) return null;
        var childName:String = (idx == 0) ? "i1" : ("i" + (idx + 1));
        return Api.game.ui.mcInterface.actBar.getChildByName(childName);
    }

    /**
     * Resolves the genuine Auto Attack action without ever trusting action bar slot 0.
     *
     * `getSkillAction(0)` reads whatever is actually mapped to slot 0. This resolver
     * skips `actionMap` and `actions.active` so Auto Attack is never confused with a
     * real skill occupying that slot.
     *
     * Resolution order:
     *   1. `world.getAutoAttack()` - the game's own accessor, authoritative and unaffected
     *      by actionMap layout
     *   2. `world.getActionByRef("aa")` - canonical AA ref
     *   3. `actBar` child "i1" - the leftmost action bar icon is always the AA icon
     */
    public static function getAutoAttackAction(world:Dynamic):Dynamic {
        if (world == null) return null;

        try {
            if (world.getAutoAttack != null) {
                var act:Dynamic = world.getAutoAttack();
                if (act != null) return act;
            }
        } catch (_:Dynamic) {}

        try {
            if (world.getActionByRef != null) {
                var act:Dynamic = world.getActionByRef("aa");
                if (act != null) return act;
            }
        } catch (_:Dynamic) {}

        var icon:Dynamic = getIcon(0);
        if (icon != null && icon.actObj != null) return icon.actObj;
        return null;
    }

    /**
     * True when action bar slot 0 holds a REAL skill rather than the Auto Attack.
     *
     * Decided by action REF NAME where available, since refs are stable strings while action
     * object identity is not guaranteed across the game's several accessors. Falls back to
     * identity comparison against `getAutoAttackAction` when `actionMap` is unavailable.
     */
    public static function slotZeroIsRealSkill(world:Dynamic):Bool {
        try {
            if (world != null && world.actionMap != null && world.actionMap[0] != null) {
                var ref:String = Std.string(world.actionMap[0]).toLowerCase();
                if (ref != "") {
                    return ref != "aa" && ref != "autoattack" && ref != "auto";
                }
            }
        } catch (_:Dynamic) {}

        var aa:Dynamic = getAutoAttackAction(world);
        if (aa == null) return false;
        var slot0:Dynamic = getSkillAction(0);
        if (slot0 == null) return false;
        if (slot0 == aa) return false;
        if (Reflect.compareMethods(slot0, aa)) return false;
        return true;
    }

    /**
     * Applies the infinite-range override to an action and returns the original range so the
     * caller can restore it. Returns -1 when the action has no readable range.
     *
     * Without the restore, a permanent `range = 20000` leaks into `shouldApproachTarget`,
     * which reads slot 0's range to decide between approaching and attacking - making the bot
     * never approach even when the real Auto Attack is melee.
     */
    public static function applyInfiniteRange(actObj:Dynamic):Float {
        if (actObj == null) return -1;
        var previous:Float = -1;
        try {
            if (actObj.range != null) previous = ApiUtils.parseFloat(actObj.range, -1);
            actObj.range = 20000;
        } catch (_:Dynamic) {}
        return previous;
    }

    public static function restoreRange(actObj:Dynamic, previous:Float):Void {
        if (actObj == null || previous < 0) return;
        try {
            actObj.range = previous;
        } catch (_:Dynamic) {}
    }

    /**
     * Checks if skill `idx` can currently fire (not resource blocked, locked, or on CD).
     * Non-mutating check without executing world.testAction.
     */
    public static function canFireSkill(idx:Int):Bool {
        if (Api.game == null || Api.game.world == null || Api.game.world.myAvatar == null) return false;
        var world:Dynamic = Api.game.world;
        var avatar:Dynamic = Api.game.world.myAvatar;

        var actObj:Dynamic = getSkillAction(idx);
        if (actObj == null || actObj.isOK == false) return false;
        if (actObj.skillLock == true || actObj.lock == true) return false;

        var dl:Dynamic = (avatar != null) ? avatar.dataLeaf : null;
        if (dl != null && dl.intState == 0) return false;

        if (idx == 5 && world.potionAckActID != null && Std.int(world.potionAckActID) != -1) return false;

        var timingReady:Bool = false;
        try { timingReady = (world.actionTimeCheck(actObj, true) == true); } catch (_:Dynamic) {}
        if (!timingReady) return false;

        if (actObj.sp != null && ApiUtils.parseInt(actObj.sp, 0) > 0 && world.checkSP != null) {
            try {
                if (world.checkSP(actObj) == false) return false;
            } catch (_:Dynamic) {}
        }

        var rawMp:Int = actObj.mp != null ? ApiUtils.parseInt(actObj.mp, 0) : 0;
        if (rawMp > 0 && dl != null) {
            var cmc:Float = 1.0;
            if (dl.sta != null && Reflect.field(dl.sta, "$cmc") != null) {
                cmc = ApiUtils.parseFloat(Reflect.field(dl.sta, "$cmc"), 1.0);
            }
            var effectiveMpCost:Int = Math.round(rawMp * cmc);
            var curMp:Int = (dl.intMP != null) ? Std.int(dl.intMP) : 0;
            if (curMp < effectiveMpCost) return false;
        }

        return true;
    }

    /**
     * Returns remaining cooldown in milliseconds for skill `idx`.
     * Returns 0 if ready, auto attack, or action not found.
     */
    public static function getCooldownRemaining(idx:Int, allowAuto:Bool = true):Float {
        if (Api.game == null || Api.game.world == null) return 0;
        var world:Dynamic = Api.game.world;
        var actObj:Dynamic = getSkillAction(idx);
        if (actObj == null || actObj.isOK == false) return 0;
        if (allowAuto && isGenuineAutoAttack(actObj)) return 0;
        try {
            if (world.actionTimeCheck != null && world.actionTimeCheck(actObj, true) == true) {
                return 0;
            }
        } catch (_:Dynamic) {}
        try {
            var rawCd:Float = (actObj.OldCD != null) ? ApiUtils.parseFloat(actObj.OldCD, 0) : ApiUtils.parseFloat(actObj.cd, 0);
            if (rawCd <= 0) return 0;
            var haste:Float = 1.0;
            try {
                var av:Dynamic = (world.myAvatar != null) ? world.myAvatar : null;
                var dl:Dynamic = (av != null) ? av.dataLeaf : null;
                if (dl != null && dl.sta != null) {
                    var tha:Dynamic = Reflect.field(dl.sta, "$tha");
                    if (tha != null) {
                        var thaVal:Float = ApiUtils.parseFloat(tha, 0);
                        haste = 1.0 - Math.min(Math.max(thaVal, -1.0), 0.5);
                    }
                }
            } catch (_:Dynamic) {}
            var cd:Float = rawCd * haste;
            var ts:Dynamic = (actObj.ts != null) ? actObj.ts : actObj.time;
            var lastTime:Float = ApiUtils.parseFloat(ts, 0);
            if (lastTime <= 0) return 0;
            var now:Float = (world.dateObj != null && world.dateObj.getTime != null) ? ApiUtils.parseFloat(world.dateObj.getTime(), ApiTime.now()) : ApiTime.now();
            var remaining:Float = cd - (now - lastTime);
            return (remaining > 0) ? remaining : 0;
        } catch (_:Dynamic) {}
        return 0;
    }

    /**
     * Executes skill `idx` against the current target, applying all safety and resource guards.
     */
    public static function fireSkill(world:Dynamic, avatar:Dynamic, idx:Int):Int {
        // 1. Resolve action object & check skillLock / lock (World.as:10472)
        var actObj:Dynamic = getSkillAction(idx);
        if (actObj == null || actObj.isOK == false) return SR_RESOURCE;
        if (actObj.skillLock == true || actObj.lock == true) return SR_TIMING;

        // 2. Player must be alive
        var dl:Dynamic = (avatar != null) ? avatar.dataLeaf : null;
        if (dl != null && dl.intState == 0) return SR_RESOURCE;

        // 2b. Consumable slot 5 pending acknowledgement check (World.as:9944)
        if (idx == 5 && world != null && world.potionAckActID != null && Std.int(world.potionAckActID) != -1) return SR_TIMING;
        if (idx == 5 && world != null && world.lockdownPots == true) return SR_TIMING;

        // 3. Timing guard — GCD + per-skill CD
        var timingReady:Bool = false;
        try { timingReady = (world.actionTimeCheck(actObj) == true); } catch (_:Dynamic) {}
        if (!timingReady) return SR_TIMING;

        // 4. Crowd control guard (stun, stone, paralyze, disable)
        if (dl != null && dl.auras != null && world.auraCatOf != null) {
            try {
                var auras:Array<Dynamic> = cast dl.auras;
                for (aura in auras) {
                    var cat:String = world.auraCatOf(aura);
                    if (cat == "stun" || cat == "stone" || cat == "paralyze" || cat == "disable" || cat == "disabled") {
                        return SR_TIMING;
                    }
                }
            } catch (_:Dynamic) {}
        }

        // 5. Resource guard (SP & MP cost scaled by class multiplier sta.$cmc)
        if (actObj.sp != null && ApiUtils.parseInt(actObj.sp, 0) > 0 && world != null && world.checkSP != null) {
            try {
                if (world.checkSP(actObj) == false) return SR_RESOURCE;
            } catch (_:Dynamic) {}
        }
        var rawMp:Int = actObj.mp != null ? ApiUtils.parseInt(actObj.mp, 0) : 0;
        if (rawMp > 0) {
            var curDl:Dynamic = (dl != null) ? dl : ((world != null && world.rootClass != null && world.rootClass.sfc != null && world.uoTreeLeaf != null) ? world.uoTreeLeaf(world.rootClass.sfc.myUserName) : null);
            if (curDl != null) {
                var cmc:Float = 1.0;
                if (curDl.sta != null) {
                    var rawCmc:Dynamic = Reflect.field(curDl.sta, "$cmc");
                    if (rawCmc != null) cmc = ApiUtils.parseFloat(rawCmc, 1.0);
                }
                var effectiveMpCost:Int = Math.round(rawMp * cmc);
                var curMp:Int = (curDl.intMP != null) ? Std.int(curDl.intMP) : 0;
                if (curMp < effectiveMpCost) return SR_RESOURCE;
            }
        }

        // 6. Infinite range check
        if (Api.combat != null && Api.combat.infiniteRange) {
            actObj.range = 20000;
        }

        // 7. Fire
        try {
            if (world != null && world.testAction != null) {
                world.testAction(actObj);
            }
        } catch (_:Dynamic) {
            return SR_RESOURCE;
        }
        return SR_FIRED;
    }

    /**
     * Press an action-bar slot using the same boundary as Game.key_actBar().
     *
     * The native keyboard handler only resolves the mapped action, checks isOK, and delegates
     * every other rule to World.testAction(). This is intentionally separate from fireSkill():
     * mechanic consumables such as Vigil must not be blocked by an API-side interpretation of
     * GCD, lock, or potion state before AQW gets to perform its own validation.
     */
    public static function pressNativeActionBarSlot(world:Dynamic, idx:Int):Bool {
        if (world == null || idx < 0 || idx > 5) return false;
        var action:Dynamic = getSkillAction(idx);
        if (action == null || action.isOK == false) return false;

        try {
            world.testAction(action);
            return true;
        } catch (_:Dynamic) { return false; }
    }

    /**
     * Presses a consumable action as if the player repeatedly pressed its action-bar key.
     *
     * Unlike a normal rotation skill, a mechanic guard must be able to submit the action while
     * the API-side GCD estimate is stale. The game's own testAction() remains the final authority;
     * this method only avoids suppressing the native validation before it is reached.
     */
    public static function pressConsumable(world:Dynamic, avatar:Dynamic, idx:Int):Bool {
        if (world == null || avatar == null || idx < 0 || idx > 5) return false;

        var actObj:Dynamic = getSkillAction(idx);
        if (actObj == null || actObj.isOK == false) return false;
        var dl:Dynamic = avatar.dataLeaf;
        if (dl != null && dl.intState == 0) return false;

        // This is the same lock the native action-bar handler observes. Repeatedly submitting a
        // locked action only produces server-side "Please slow down" responses and cannot create
        // another valid potion request.
        if (actObj.lock == true) return false;

        // Do not send another press while AQW is waiting for the previous consumable response.
        if (idx == 5 && world.potionAckActID != null && Std.int(world.potionAckActID) != -1) {
            return false;
        }

        try {
            if (world.testAction != null) {
                world.testAction(actObj);
                return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }

    /**
     * True when the action really is the class Auto Attack, not action bar slot 0.
     *
     * `World.getAutoAttack()` scans `actions.active` for an action with `auto == true` and, when
     * there is none, falls back to `actions.active[0]`. On classes whose slot 0 holds a real skill
     * that fallback returns the skill, so firing it from here would cast slot 0 off cooldown,
     * outside the rotation and outside the GCD. Genuine Auto Attacks are the ones flagged
     * `auto == true` (`World.actionTimeCheck` relies on that flag too), with `typ == "aa"` as
     * the secondary marker the game checks when arming its out-of-range AA retry.
     */
    public static function isGenuineAutoAttack(actObj:Dynamic):Bool {
        if (actObj == null) return false;
        try {
            if (actObj.auto == true) return true;
        } catch (_:Dynamic) {}
        try {
            if (Std.string(actObj.typ).toLowerCase() == "aa") return true;
        } catch (_:Dynamic) {}
        return false;
    }

    /**
     * Fires Auto Attack off cooldown, independent of GCD and combo slots.
     * CombatEngine only calls this when the active class/mode has `autoattack: true`.
     * When that flag is false, slot 0 is a combo skill and must be fired via `fireSkill`.
     *
     * `aaAct` may be supplied by the caller (CombatEngine resolves it once per tick).
     * When null it is resolved via `getAutoAttackAction`, which never treats slot 0 as AA.
     */
    public static function fireAutoAttack(world:Dynamic, avatar:Dynamic, aaAct:Dynamic = null):Bool {
        if (world == null) return false;
        var actObj:Dynamic = (aaAct != null) ? aaAct : getAutoAttackAction(world);
        if (actObj == null || actObj.isOK == false) return false;
        // Reject the slot 0 fallback: a real skill there belongs to the rotation, not here.
        if (!isGenuineAutoAttack(actObj)) return false;

        var dl:Dynamic = (avatar != null) ? avatar.dataLeaf : null;
        if (dl != null && dl.intState == 0) return false;

        var timingReady:Bool = false;
        try { timingReady = (world.actionTimeCheck(actObj) == true); } catch (_:Dynamic) {}
        if (!timingReady) return false;

        if (dl != null && dl.auras != null && world.auraCatOf != null) {
            try {
                var auras:Array<Dynamic> = cast dl.auras;
                for (aura in auras) {
                    var cat:String = world.auraCatOf(aura);
                    if (cat == "stun" || cat == "stone" || cat == "paralyze" || cat == "disable" || cat == "disabled") {
                        return false;
                    }
                }
            } catch (_:Dynamic) {}
        }

        var prevRange:Float = -1;
        if (Api.combat != null && Api.combat.infiniteRange) {
            prevRange = applyInfiniteRange(actObj);
        }

        var fired:Bool = false;
        try {
            if (world.testAction != null) {
                world.testAction(actObj);
                fired = true;
            }
        } catch (_:Dynamic) {}

        restoreRange(actObj, prevRange);
        return fired;
    }
}
