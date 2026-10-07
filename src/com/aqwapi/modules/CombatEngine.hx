package com.aqwapi.modules;

import com.aqwapi.utils.ApiTimings;

import flash.events.TimerEvent;
import flash.utils.Timer;
import com.aqwapi.Api;
import com.aqwapi.combat.SkillCaster;
import com.aqwapi.combat.SkillRules;
import com.aqwapi.data.EntityDTO;
import com.aqwapi.managers.SkillManager;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiUtils;
import com.aqwapi.utils.SkillDslParser;

class CombatEngine {
    private static var _timer:Timer;
    public static var IS_ON:Bool = false;
    public static var isSmart:Bool = true;
    public static var skillMode:String = "Auto";
    public static var customMode:String = "auto";
    public static var smartClass:String = "Current";
    // Loadout profiles
    public static var farmClass:String = "Current";
    public static var farmMode:String = "Auto";
    public static var soloClass:String = "Current";
    public static var soloMode:String = "Auto";
    public static var bossClass:String = "Current";
    public static var bossMode:String = "Auto";
    public static var dodgeClass:String = "Current";
    public static var dodgeMode:String = "Auto";
    // Target lock & prioritization
    public static var targetName:String = null;
    public static var lockedMMID:String = null;
    public static var priorityTargets:Array<String> = [];
    public static var huntPriority:String = "lowest_hp";
    // Counter & reflect aura handling
    public static var counterHandler:Bool = false;
    public static var globalStopOnTargetAuras:Array<String> = [];
    public static var pausedAuraName:String = null;
    public static var isPausedByAura(get, never):Bool;
    public static inline function get_isPausedByAura():Bool { return _pausedByTargetAura; }
    // Monster aggro & pull mechanics
    public static var aggroAll:Bool = false;
    public static var pullAll:Bool = false;
    public static var aggroTargets:Array<String> = [];
    private static var _lastAggroTime:Float = -10000;
    // Internal execution state
    public static var customRotation(get, never):Array<Int>;
    public static inline function get_customRotation():Array<Int> { return _customRotation; }
    private static var _customRotation:Array<Int> = [];
    private static var _rotationIndex:Int = 0;
    private static var _sequenceStepStartTime:Float = 0;
    private static var _skillIndex:Int = 0;
    private static var _skillWaitStart:Float = 0;
    private static var _stepFirstFailTime:Float = -1;
    private static var _lastTimeoutSkipLogTime:Float = -10000;
    private static var _lastHardLockLogTime:Float = -10000;
    private static var _lastTargetMMID:String = null;
    private static var _targetChanged:Bool = false;
    private static var _lastDetectedClass:String = "";
    private static var _pausedByTargetAura:Bool = false;
    private static var _waitUntil:Dynamic = {};
    private static var _lastFallbackWarnTime:Float = 0;
    private static var _lastWarnedMismatchClass:String = "";
    private static var _temporaryIgnore:Map<String, Float> = new Map<String, Float>();

    private static function isTemporarilyIgnored(mmid:String):Bool {
        if (mmid == null || mmid == "" || _temporaryIgnore == null) return false;
        if (!_temporaryIgnore.exists(mmid)) return false;
        if (ApiTime.now() < _temporaryIgnore.get(mmid)) return true;
        _temporaryIgnore.remove(mmid);
        return false;
    }
    
    private static function ignoreTemporarily(mmid:String, ms:Float = ApiTimings.TEMP_IGNORE_MS):Void {
        if (mmid == null || mmid == "") return;
        _temporaryIgnore.set(mmid, ApiTime.now() + ms);
        pruneTemporaryIgnore();
    }
    
    private static function pruneTemporaryIgnore():Void {
        if (_temporaryIgnore == null) return;
        var now:Float = ApiTime.now();
        for (mmid in _temporaryIgnore.keys()) {
            if (now >= _temporaryIgnore.get(mmid)) _temporaryIgnore.remove(mmid);
        }
    }
    
    public static function init():Void {
        SkillManager.ensureLoaded(true);
        if (_timer == null) {
            _timer = new Timer(ApiTimings.COMBAT_TICK_MS);
            _timer.addEventListener(TimerEvent.TIMER, onTick);
        }
    }
    
    public static function start(smart:Bool, silent:Bool = false):Void {
        var t0:Float = ApiTime.now();
        SkillManager.invalidateCurrentClass();
        init();
        isSmart = smart;
        IS_ON = true;
        var confClass = (smartClass != null && smartClass != "" && smartClass != "Current") ? smartClass : "Current";
        var isCurrentClass = (confClass == "Current");
        var activeClass = isCurrentClass ? SkillManager.getCurrentClassName() : confClass;
        if (activeClass == "" && Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null && Api.game.world.myAvatar.objData != null) {
            if (Api.game.world.myAvatar.objData.strClassName != null) {
                activeClass = Std.string(Api.game.world.myAvatar.objData.strClassName);
            }
        }
        if (smart && activeClass != "") {
            skillMode = SkillManager.resolveActiveModeName(activeClass, skillMode);
            _lastDetectedClass = activeClass;
        } else if (confClass == "Current") {
            _lastDetectedClass = "";
        }
        _rotationIndex = 0;
        _sequenceStepStartTime = ApiTime.now();
        _skillIndex = 0;
        _skillWaitStart = ApiTime.now();
        _stepFirstFailTime = -1;
        _targetChanged = false;
        _pausedByTargetAura = false;
        pausedAuraName = null;
        _lastCastAt = -10000;
        _lastSkillAt = -10000;
        _avatarBusyAnim = false;
        ActionFeed.reset();
        _waitUntil = {};
        if (_timer != null && !_timer.running) {
            _timer.start();
        }
        if (!silent) {
            if (smart) {
                var c = (activeClass != "") ? activeClass : SkillManager.getCurrentClassName();
                var took = Math.round(ApiTime.now() - t0);
                ApiLogger.info("Combat", "Smart combat started in " + took + "ms. Class: '" + c + "', Mode: '" + skillMode + "'");
            } else {
                var took = Math.round(ApiTime.now() - t0);
                ApiLogger.info("Combat", "Custom combat started in " + took + "ms.");
            }
        }
    }
    
    public static function stop():Void {
        IS_ON = false;
        targetName = null;
        lockedMMID = null;
        priorityTargets = [];
        _pausedByTargetAura = false;
        pausedAuraName = null;
        _temporaryIgnore = new Map<String, Float>();
        if (_timer != null && _timer.running) {
            _timer.stop();
        }
        if (Api.game != null && Api.game.world != null) {
            var world:Dynamic = Api.game.world;
            clearNativeAutoAttack(world);
            if (world.cancelAutoAttack != null) {
                try { world.cancelAutoAttack(); } catch (_:Dynamic) {}
            }
        }
    }
    
    public static function toggleSmart():Void {
        if (IS_ON && isSmart) {
            stop();
        } else {
            targetName = null;
            lockedMMID = null;
            start(true);
        }
    }
    
    public static function toggleCustom():Void {
        if (IS_ON && !isSmart) {
            stop();
        } else {
            targetName = null;
            lockedMMID = null;
            start(false);
        }
    }
    
    public static function setCustomRotation(rotation:Array<Int>, mode:String = "auto"):Void {
        _customRotation = (rotation != null) ? rotation : [];
        if (mode == "auto" || mode == null || mode == "") {
            var seen = new Map<Int, Bool>();
            var hasDupes = false;
            for (r in _customRotation) {
                if (seen.exists(r)) {
                    hasDupes = true;
                    break;
                }
                seen.set(r, true);
            }
            customMode = hasDupes ? "sequence" : "priority";
        } else {
            customMode = mode;
        }
        _rotationIndex = 0;
        _sequenceStepStartTime = ApiTime.now();
    }
    
    public static function shouldApproachTarget(world:Dynamic, aaAct:Dynamic = null):Bool {
        if (world == null) return false;
        if (Api.combat != null && Api.combat.infiniteRange) return false;
        var isAaClose:Bool = false;
        var isAaInfinite:Bool = false;
        try {
            var act:Dynamic = (aaAct != null) ? aaAct : SkillCaster.getAutoAttackAction(world);
            if (act != null && act.range != null) {
                var aaR:Float = ApiUtils.parseFloat(act.range, 301);
                if (aaR >= 20000) isAaInfinite = true;
                else if (aaR > 0 && aaR <= 301) isAaClose = true;
            }
        } catch (_:Dynamic) {}

        // Active skill slots 0..5 (slot 0 may be AA or a real skill)
        var hasCloseSkill:Bool = false;
        var hasInfiniteSkill:Bool = false;
        try {
            for (i in 0...6) {
                var act:Dynamic = SkillCaster.getSkillAction(i);
                if (act == null && world.actions != null && world.actions.active != null) {
                    try {
                        var actList:Array<Dynamic> = cast world.actions.active;
                        if (actList != null && i < actList.length) act = actList[i];
                    } catch (_:Dynamic) {}
                }
                if (act == null || act.range == null) continue;
                var tgt:String = (act.tgt != null) ? Std.string(act.tgt).toLowerCase() : "";
                if (tgt == "self" || tgt == "friendly") continue;
                if (Reflect.hasField(act, "tgtMin") && Reflect.field(act, "tgtMin") == 0) continue;
                var r:Float = ApiUtils.parseFloat(act.range, 0);
                if (r >= 20000) hasInfiniteSkill = true;
                else if (r > 0 && r <= 301) hasCloseSkill = true;
            }
        } catch (_:Dynamic) {}

        if (isAaInfinite || hasInfiniteSkill) return false;
        if (isAaClose || hasCloseSkill) return true;
        return false;
    }
    
    private static var _lastCastAt:Float = -10000;
    private static var _lastSkillAt:Float = -10000;
    private static var _avatarBusyAnim:Bool = false;

    /**
     * Minimum gap between two casts we start, shared by the Auto Attack and the rotation.
     * Both used to be able to fire inside the same 100 ms tick, doubling the rate at which the
     * game spawned and tore down spell effects.
     */

    /**
     * Client side Global Cooldown gate for rotation skills, taken from `World.GCD` (1500 ms).
     *
     * `World.actionTimeCheck()` enforces the GCD against `World.GCDTS`, which only advances in
     * `globalCoolDownExcept` when the server returns a result. A client that fires on its own
     * schedule therefore slips several casts into one GCD window. That matters far beyond damage:
     * `World.getActionResult()` fires `testAction(getAutoAttack())` after every single target skill
     * result (World.as:9765), so on classes where slot 0 holds a real skill - Chrono ShadowHunter
     * fires slot 0 whenever 2/3/4 is used - each out-of-GCD cast triggers another MP-burning slot 0
     * cast and the class drains out of mana. Gating at the game's own GCD is the rate a human plays
     * at, and it leaves the mechanic itself untouched.
     */
    private static function skillGapMs():Float {
        var g:Float = ApiTimings.MIN_CAST_GAP_MS;
        try {
            if (Api.game != null && Api.game.world != null && Api.game.world.GCD != null) {
                g = ApiUtils.parseInt(Api.game.world.GCD, 0);
            }
        } catch (_:Dynamic) {}
        return (g > ApiTimings.MIN_CAST_GAP_MS) ? g : ApiTimings.MIN_CAST_GAP_MS;
    }

    /** Gate for rotation skills: never out of step with the game's Global Cooldown. */
    public static inline function skillGateOpen():Bool {
        if (_avatarBusyAnim) return false;
        return (ApiTime.now() - _lastSkillAt) >= skillGapMs();
    }

    public static inline function noteSkillCast():Void {
        _lastSkillAt = ApiTime.now();
        _lastCastAt = _lastSkillAt;
    }

    /**
     * True while the avatar is playing a combat animation, using the game's own `combatAnims`
     * list (`World.combatAnims`, checked in `AvatarMC.gotoAndPlay` / `AvatarMC.checkQueue`).
     *
     * Requesting an action mid-swing makes the avatar queue another combat animation
     * (`AvatarMC.animQueue`), which `checkQueue` then plays back to back. Each replay re-runs the
     * animation's frame scripts, which `removeChild` a `SpellW`; that dispatches
     * `REMOVED_FROM_STAGE` into `SpellW.killSpell`, which removes the clip again. Enough queued
     * swings in one ENTER_FRAME and Flash overflows the dispatch stack with Error #2094. Waiting
     * for the swing to finish is also how a human plays - one action per animation.
     */
    private static function avatarInCombatAnim(world:Dynamic, avatar:Dynamic):Bool {
        try {
            if (world == null || avatar == null) return false;
            var pMC:Dynamic = avatar.pMC;
            if (pMC == null || pMC.mcChar == null) return false;
            var label:String = Std.string(pMC.mcChar.currentLabel);
            if (label == null || label == "") return false;
            var anims:Array<Dynamic> = cast world.combatAnims;
            if (anims == null || anims.length == 0) return false;
            for (a in anims) {
                if (Std.string(a) == label) return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }

    public static inline function castGateOpen():Bool {
        if (_avatarBusyAnim) return false;
        return (ApiTime.now() - _lastCastAt) >= ApiTimings.MIN_CAST_GAP_MS;
    }

    // -------------------------------------------------------------------------
    // Target action counter (the `[counter]` DSL rule)
    // -------------------------------------------------------------------------

    /**
     * How long a target action stays "fresh" when a rule does not say. Long enough to cover one
     * swing plus the reaction window, short enough that `[counter]` does not stay true across a lull.
     */

    /**
     * Stamps when the target resolved an attack against us, so `[counter]` can gate a riposte on it.
     *
     * Detection is the server's own hit packet rather than the target's animation. Reading
     * `pMC.mcChar.currentLabel` against `world.combatAnims` was implemented first and never fired in a
     * live fight: monster attack animations are not in that list, so the gate stayed false while the
     * mob hit repeatedly. `ActionFeed` hooks the extension-response dispatcher instead, which is where
     * the resolution actually arrives.
     *
     * Deliberately dodge-agnostic: the window opens on a dodged or missed swing as well as a landed
     * one, because a riposte has to answer every attack, not only the ones that connected.
     */
    private static var _feedTargetId:String = null;

    /**
     * Earliest attack timestamp a window-less `[counter]` will accept.
     *
     * Set a fixed delay after our last cast, so a mob swinging in the same instant we cast the arm
     * skill does not immediately spend the riposte. Tunable via `ApiTimings.COUNTER_ARM_DELAY_MS`.
     */
    public static function counterArmCutoff():Float {
        if (_lastCastAt < -1000) return -1e30;   // nothing cast yet: accept everything
        return _lastCastAt + ApiTimings.COUNTER_ARM_DELAY_MS;
    }

    private static function noteTargetAction(world:Dynamic, target:Dynamic):Void {
        ActionFeed.install();
        // Keyed on the target's stable identity (MonMapID / UserID), NOT the target object. The game
        // replaces the target wrapper as its state updates, so keying on the object made every
        // replacement look like a new mob and cleared the buffer constantly - seen live as `buffer=0`
        // and `consumed=0/93` with 93 hits recorded. Losing the target entirely still clears it.
        // Stable identity when we can resolve one; fall back to the object only when we cannot,
        // otherwise two different mobs with no readable id would look identical.
        var tag:String = (target == null) ? null : ActionFeed.targetIdentity();
        var id:String = (tag != null) ? tag : ("obj:" + Std.string(target));
        if (_feedTargetId != id) {
            _feedTargetId = id;
            ActionFeed.reset();
        }
    }

    /**
     * Whether the target acted on us within `windowMs`, used by the `[counter]` rule.
     *
     * `typeFilter` narrows to a single resolution type ("miss", "dodge", "crit", ...); null or empty
     * accepts every one.
     *
     * Reports `-1` while there is no target at all, so a riposte can never fire at thin air after the
     * mob dies or drops.
     */
    public static function targetActionAgeMs(?windowMs:Float, ?typeFilter:String):Float {
        if ((Api.game == null || Api.game.world == null)) return -1;
        try {
            if (Api.game.world.myAvatar == null || Api.game.world.myAvatar.target == null) return -1;
        } catch (_:Dynamic) {
            return -1;
        }
        var window:Float = (windowMs != null && windowMs > 0) ? windowMs : ApiTimings.COUNTER_WINDOW_MS;
        return ActionFeed.lastActionAgeMs(window, typeFilter);
    }

    public static inline function targetActionFresh(?windowMs:Float, ?typeFilter:String):Bool {
        return targetActionAgeMs(windowMs, typeFilter) >= 0;
    }

    public static inline function noteCast():Void {
        _lastCastAt = ApiTime.now();
    }

    /**
     * `autoattack: false` means hands off, not suppressed: the API never fires Auto Attack and never
     * calls `cancelAutoAttack()`, so the game keeps its own default behaviour. Manual play never
     * spams action bar slot 0 on classes like Chrono ShadowHunter, so there is nothing to suppress
     * - resetting `World.autoActionTimer` every tick only fought the game over its own state.
     *
     * `autoattack: true` means the API owns Auto Attack: `SkillCaster.fireAutoAttack` fires it off
     * cooldown, outside the combo and the GCD, and `approachTarget()` is still never used to
     * request one (see `targetWithinActionRange`).
     */

    private static function isDisabled(avatar:Dynamic, world:Dynamic):Bool {
        if (avatar == null || avatar.dataLeaf == null) return false;
        var now:Float = ApiTime.now();
        if (now < _ccCheckValidUntil) return _ccCheckResult;
        _ccCheckValidUntil = now + ApiTimings.CC_CHECK_CACHE_MS;
        _ccCheckResult = false;
        if (avatar.dataLeaf.intState == 0) {
            _ccCheckResult = true;
            return true;
        }
        if (avatar.dataLeaf.auras != null && world != null && world.auraCatOf != null) {
            try {
                var auras:Array<Dynamic> = cast avatar.dataLeaf.auras;
                for (aura in auras) {
                    if (aura == null) continue;
                    var cat:String = world.auraCatOf(aura);
                    if (cat == null) continue;
                    cat = cat.toLowerCase();
                    if (cat == "stun" || cat == "stone" || cat == "paralyze" || cat == "disable" || cat == "disabled") {
                        _ccCheckResult = true;
                        return true;
                    }
                }
            } catch (_:Dynamic) {}
        }
        return false;
    }
    
    private static var _ccCheckResult:Bool = false;
    private static var _ccCheckValidUntil:Float = 0;
    
    private static function isFreeAutoAttack(aaAct:Dynamic):Bool {
        if (aaAct == null) return false;
        if (aaAct.isOK == false) return false;
        try {
            if (aaAct.mp != null) return ApiUtils.parseInt(aaAct.mp, 0) <= 0;
        } catch (_:Dynamic) {}
        return true;
    }
    
    /**
     * True when the target is already inside `act`'s range.
     *
     * `World.approachTarget()` fires `testAction(getAutoAttack())` itself whenever the target is in
     * range, and `getAutoAttack()` falls back to `actions.active[0]` on classes that have no action
     * flagged `auto`. Calling it while in range therefore cast action bar slot 0 on the game's side,
     * straight past `autoattack: false`, the cast gate and `isGenuineAutoAttack`. Movement is only
     * requested when the target is genuinely out of range, which leaves `fireAutoAttack` as the sole
     * driver of Auto Attack.
     */
    /**
     * True when the target is already inside `act`'s melee reach.
     *
     * This mirrors `World.actionRangeCheck()` (World.as:9177) rather than calling it: that method is
     * `private`, and a private member of a sealed game class cannot be reached from another SWF - the
     * access throws ReferenceError #1069, which our catch turned into "always out of range". That made
     * the engine call `World.approachTarget()` on every tick, and `approachTarget()` fires
     * `testAction(getAutoAttack())` whenever the game agrees the target is in range - action bar slot
     * 0 on classes like Chrono ShadowHunter. Only `public` members are safe to touch from here.
     */
    private static function targetWithinActionRange(world:Dynamic, avatar:Dynamic, target:Dynamic, act:Dynamic):Bool {
        if (world == null || avatar == null || target == null || act == null) return false;
        try {
            // Same short circuit the game uses: an action that needs no target is always in range.
            if (ApiUtils.parseInt(act.tgtMin, -1) == 0) return true;

            var reach:Int = ApiUtils.parseInt(act.range, -1);
            if (reach < 0) return false;
            // Ranged actions never need an approach, so never walk toward them.
            if (reach > 301) return true;

            var scale:Float = ApiUtils.parseInt(world.SCALE, 1);
            if (scale <= 0) scale = 1;

            var avChar:Dynamic = (avatar.pMC != null) ? avatar.pMC.mcChar : null;
            var tgChar:Dynamic = (target.pMC != null) ? target.pMC.mcChar : null;
            if (avChar == null || tgChar == null) return false;
            var avPt:Dynamic = avChar.localToGlobal(new flash.geom.Point());
            var tgPt:Dynamic = tgChar.localToGlobal(new flash.geom.Point());
            if (avPt == null || tgPt == null) return false;

            var dx:Float = Math.abs(tgPt.x - avPt.x);
            var dy:Float = Math.abs(tgPt.y - avPt.y);
            return (dx <= reach * scale && dy <= 30 * scale);
        } catch (_:Dynamic) {}
        return false;
    }

    /**
     * Asks the game to walk toward the current target, without requesting an Auto Attack.
     *
     * `World.approachTarget()` sets the internal `world.actionReady = true` when the target is out of
     * range (World.as:8351), and `AvatarMC.stopWalking()` fires `testAction(getAutoAttack())` when the
     * walk ends (AvatarMC.as:2686) - action bar slot 0 on classes without a real `auto` action. That
     * flag is `internal` and cannot be cleared from this SWF (ReferenceError #1069), so the reach
     * check in `targetWithinActionRange` is what keeps the engine from requesting an approach it does
     * not need in the first place.
     */
    /**
     * `World.cancelAutoAttack()` is the only public lever: it resets `autoActionTimer` and
     * `AATestTimer` (World.as:8993), which is what disarms the native retry path
     * `autoActionHandler` -> `testAction(getAutoAttack(), true)` (World.as:8936). The timer itself is
     * `internal`, so the engine cannot hold it open the way it would have to in order to also block
     * the post-skill Auto Attack in `getActionResult` (World.as:9765) - resetting the timer is what
     * opens that gate. That residual cast is the class mechanic firing after 2/3/4, at the rate
     * `skillGateOpen()` allows, which is the rate a human plays at.
     *
     * Touching `autoActionTimer` or `actionReady` directly throws ReferenceError #1069 from this
     * SWF, so both are left alone.
     */
    private static function clearNativeAutoAttack(world:Dynamic):Void {
        if (world == null) return;
        try {
            if (world.cancelAutoAttack != null) untyped world.cancelAutoAttack();
        } catch (_:Dynamic) {}
    }

    private static function approachTargetOnly(world:Dynamic):Void {
        if (world == null) return;
        try {
            if (world.approachTarget != null) untyped world.approachTarget();
        } catch (_:Dynamic) {}
    }

    private static function onTick(e:TimerEvent):Void {
        if (Api.game == null || Api.game.world == null || Api.game.world.myAvatar == null) return;
        if (Api.map != null && !Api.map.isLoaded) return;
        var world:Dynamic = Api.game.world;
        var avatar:Dynamic = world.myAvatar;
        if (avatar.dataLeaf != null && avatar.dataLeaf.intState == 0) return;
        _avatarBusyAnim = avatarInCombatAnim(world, avatar);
        var nowTick:Float = ApiTime.now();
        if (Api.combat != null) {
            Api.combat.checkAutoProvoke(nowTick);
            Api.combat.checkAutoPotion(nowTick);
            if (Api.combat.taunt != null && Api.combat.taunt.enabled && avatar.target == null) {
                Api.combat.taunt.checkTauntTick(nowTick);
            }
        }
        var target:Dynamic = avatar.target;
        noteTargetAction(world, target);
        if (target != null) {
            var isInvalid:Bool = false;
            if (target.pMC == null || target.dataLeaf == null || target.objData == null) isInvalid = true;
            else if (target.dataLeaf.intHP != null && target.dataLeaf.intHP <= 0) isInvalid = true;
            else if (target.dataLeaf.intState != null && target.dataLeaf.intState == 0) isInvalid = true;
            else {
                var ent = new EntityDTO(target);
                if (priorityTargets != null && priorityTargets.length > 0) {
                    var curPriIdx:Int = -1;
                    for (i in 0...priorityTargets.length) {
                        var pName = priorityTargets[i];
                        if (pName == null || pName == "" || pName == "*") {
                            curPriIdx = i;
                            break;
                        }
                        var pLower = pName.toLowerCase();
                        var pId = ApiUtils.parseInt(pName, 0);
                        var isNameMatch = (ent.name != "" && ent.name.toLowerCase().indexOf(pLower) != -1);
                        var isIdMatch = (pId > 0 && (ent.id == pName || ent.monsterId == pName || ent.mapId == pName));
                        if (isNameMatch || isIdMatch) {
                            curPriIdx = i;
                            break;
                        }
                    }
                    if (curPriIdx == -1) {
                        isInvalid = true;
                    } else if (curPriIdx > 0) {
                        // Check if any higher-priority target is currently alive in the cell
                        var cellMons:Array<EntityDTO> = (Api.monster != null) ? Api.monster.getByCell(Std.string(world.strFrame)) : [];
                        for (hIdx in 0...curPriIdx) {
                            var hName = priorityTargets[hIdx];
                            if (hName == null || hName == "") continue;
                            var hLower = hName.toLowerCase();
                            var hId = ApiUtils.parseInt(hName, 0);
                            for (m in cellMons) {
                                if (m == null || !m.alive || !m.hasGraphic) continue;
                                var hMatchName = (m.name != "" && m.name.toLowerCase().indexOf(hLower) != -1);
                                var hMatchId = (hId > 0 && (m.id == hName || m.monsterId == hName || m.mapId == hName));
                                if (hMatchName || hMatchId) {
                                    isInvalid = true;
                                    break;
                                }
                            }
                            if (isInvalid) break;
                        }
                    }
                } else if (targetName != null && targetName != "*" && targetName != "") {
                    var tLower = targetName.toLowerCase();
                    var tId = ApiUtils.parseInt(targetName, 0);
                    var isNameMatch = (ent.name != "" && ent.name.toLowerCase().indexOf(tLower) != -1);
                    var isIdMatch = (tId > 0 && (ent.id == targetName || ent.monsterId == targetName || ent.mapId == targetName));
                    if (!isNameMatch && !isIdMatch) {
                        isInvalid = true;
                    }
                }
                if (!isInvalid && lockedMMID != null) {
                    if (ent.mapId != lockedMMID) {
                        isInvalid = true;
                    }
                }
            }
            if (isInvalid) {
                if (world.cancelTarget != null) {
                    try { world.cancelTarget(); } catch (_:Dynamic) {}
                }
                target = null;
                _lastTargetMMID = null;
                _targetChanged = true;
                _pausedByTargetAura = false;
                pausedAuraName = null;
            }
        }
        if (target == null) {
            try {
                var currentMonsters:Array<EntityDTO> = (Api.monster != null) ? Api.monster.getByCell(Std.string(world.strFrame)) : [];
                if (Api.monster != null) currentMonsters = Api.monster.sortMonsters(currentMonsters, huntPriority);

                if (priorityTargets != null && priorityTargets.length > 0) {
                    for (pTarget in priorityTargets) {
                        if (pTarget == null || pTarget == "") continue;
                        var pLower = pTarget.toLowerCase();
                        var pId = ApiUtils.parseInt(pTarget, 0);
                        var foundRaw:Dynamic = null;
                        for (monsterTarget in currentMonsters) {
                            if (monsterTarget == null || !monsterTarget.alive || !monsterTarget.hasGraphic) continue;
                            var raw = monsterTarget.raw;
                            if (raw == null || raw.pMC == null || raw.objData == null || raw.dataLeaf == null) continue;
                            if (lockedMMID != null && monsterTarget.mapId != lockedMMID) continue;
                            if (isTemporarilyIgnored(monsterTarget.mapId)) continue;
                            
                            var isWild = (pTarget == "*");
                            var isNameMatch = (monsterTarget.name != "" && monsterTarget.name.toLowerCase().indexOf(pLower) != -1);
                            var isIdMatch = (pId > 0 && (monsterTarget.id == pTarget || monsterTarget.monsterId == pTarget || monsterTarget.mapId == pTarget));
                            if (isWild || isNameMatch || isIdMatch) {
                                foundRaw = monsterTarget.raw;
                                break;
                            }
                        }
                        if (foundRaw != null) {
                            if (world.setTarget != null) {
                                world.setTarget(foundRaw);
                                target = foundRaw;
                                break;
                            }
                        }
                    }
                } else {
                    for (monsterTarget in currentMonsters) {
                        if (monsterTarget == null || !monsterTarget.alive || !monsterTarget.hasGraphic) continue;
                        var raw = monsterTarget.raw;
                        if (raw == null || raw.pMC == null || raw.objData == null || raw.dataLeaf == null) continue;
                        if (lockedMMID != null && monsterTarget.mapId != lockedMMID) continue;
                        if (isTemporarilyIgnored(monsterTarget.mapId)) continue;
                        if (targetName != null && targetName != "*" && targetName != "") {
                            var tLower = targetName.toLowerCase();
                            var tId = ApiUtils.parseInt(targetName, 0);
                            var isNameMatch = (monsterTarget.name != "" && monsterTarget.name.toLowerCase().indexOf(tLower) != -1);
                            var isIdMatch = (tId > 0 && (monsterTarget.id == targetName || monsterTarget.monsterId == targetName || monsterTarget.mapId == targetName));
                            if (!isNameMatch && !isIdMatch) continue;
                        }
                        if (world.setTarget != null) {
                            world.setTarget(monsterTarget.raw);
                            target = monsterTarget.raw;
                            break;
                        }
                    }
                }
            } catch (_:Dynamic) {}
            if (target == null && lockedMMID == null && (priorityTargets == null || priorityTargets.length == 0)) {
                try {
                    if (world.getMonster != null) {
                        var monName:String = (targetName != null && targetName != "*") ? targetName.toLowerCase() : "Any";
                        var anyMon:Dynamic = world.getMonster(monName);
                        if (anyMon != null && anyMon.pMC != null && anyMon.objData != null && anyMon.dataLeaf != null) {
                            var monHp:Int = (anyMon.dataLeaf.intHP != null) ? Std.int(anyMon.dataLeaf.intHP) : 1;
                            var monState:Int = (anyMon.dataLeaf.intState != null) ? Std.int(anyMon.dataLeaf.intState) : 1;
                            var anyMMID:String = (anyMon.dataLeaf.MonMapID != null) ? Std.string(anyMon.dataLeaf.MonMapID) : null;
                            if (isTemporarilyIgnored(anyMMID)) anyMon = null;
                            if (anyMon != null && monHp > 0 && monState != 0) {
                                if (world.setTarget != null) {
                                    world.setTarget(anyMon);
                                    target = anyMon;
                                }
                            }
                        }
                    }
                } catch (_:Dynamic) {}
            }
        }
        if (target == null || target.pMC == null || target.objData == null || target.dataLeaf == null) {
            _lastTargetMMID = null;
            return;
        }
        var curTargetMMID:String = null;
        if (target.dataLeaf != null && target.dataLeaf.MonMapID != null) curTargetMMID = Std.string(target.dataLeaf.MonMapID);
        else if (target.objData != null && target.objData.MonMapID != null) curTargetMMID = Std.string(target.objData.MonMapID);

        // A mob that dies while still being referenced keeps the SAME MonMapID, so the identity check
        // below never fires for it. That left reset-on-target-change dead exactly in the case it exists
        // for: kill a mob, pick up the next one, and the rotation carried on from wherever it was
        // instead of restarting - while the engine also kept trying to fight a corpse. Treat "no longer
        // alive" as a target change in its own right.
        var tgtHp:Int = 1;
        var tgtState:Int = 1;
        try {
            if (target.dataLeaf != null) {
                if (target.dataLeaf.intHP != null) tgtHp = Std.int(target.dataLeaf.intHP);
                if (target.dataLeaf.intState != null) tgtState = Std.int(target.dataLeaf.intState);
            }
        } catch (_:Dynamic) {}
        if (tgtHp <= 0 || tgtState == 0) {
            _lastTargetMMID = null;
            _targetChanged = true;
            _skillWaitStart = ApiTime.now();
            _stepFirstFailTime = -1;
            _pausedByTargetAura = false;
            pausedAuraName = null;
            if (world.cancelTarget != null) {
                try { world.cancelTarget(); } catch (_:Dynamic) {}
            }
            try { avatar.target = null; } catch (_:Dynamic) {}
            return;
        }

        if (curTargetMMID != null && curTargetMMID != _lastTargetMMID) {
            _lastTargetMMID = curTargetMMID;
            _targetChanged = true;
            _skillWaitStart = ApiTime.now();
            _stepFirstFailTime = -1;
        }
        var aaAct:Dynamic = null;
        try { aaAct = SkillCaster.getAutoAttackAction(world); } catch (_:Dynamic) {}

        var confClass = (smartClass != null && smartClass != "" && smartClass != "Current") ? smartClass : "Current";
        var isCurrentClass = (confClass == "Current");
        var activeClass = isCurrentClass ? SkillManager.getCurrentClassName() : confClass;
        var activeModeConfig:Dynamic = null;
        var allowAuto:Bool = true;
        if (isSmart) {
            activeModeConfig = SkillManager.resolveActiveModeConfig(world, avatar, target, smartClass, skillMode);
            allowAuto = SkillManager.modeHasAutoAttack(activeModeConfig, activeClass, skillMode);
        } else {
            allowAuto = SkillManager.classHasAutoAttack(activeClass, skillMode);
        }
        if (!allowAuto) clearNativeAutoAttack(world);

        var triggerAura:String = (Api.aura != null) ? Api.aura.findTriggeringTargetAura(counterHandler, globalStopOnTargetAuras, activeModeConfig, world, avatar, target) : null;
        if (triggerAura != null) {
            if (!_pausedByTargetAura) {
                _pausedByTargetAura = true;
                pausedAuraName = triggerAura;
                ApiLogger.warn("Combat", "Target counter/reflect aura detected ['" + triggerAura + "'] - holding attacks!");
            }
            clearNativeAutoAttack(world);
            if (world.cancelAutoAttack != null) {
                try { world.cancelAutoAttack(); } catch (_:Dynamic) {}
            }
            return;
        } else if (_pausedByTargetAura) {
            _pausedByTargetAura = false;
            var prevAura = pausedAuraName;
            pausedAuraName = null;
            ApiLogger.info("Combat", "Target counter/reflect aura expired" + (prevAura != null ? (" (" + prevAura + ")") : "") + " - resuming combat!");
        }

        if (aggroAll || pullAll || (aggroTargets != null && aggroTargets.length > 0)) {
            var now = ApiTime.now();
            if (pullAll) {
                if (Api.monster != null) {
                    Api.monster.magnetizeAll((aggroTargets != null && aggroTargets.length > 0) ? aggroTargets : "*");
                }
            }
            if ((aggroAll || (aggroTargets != null && aggroTargets.length > 0)) && (now - _lastAggroTime >= 1200)) {
                _lastAggroTime = now;
                if (Api.monster != null) {
                    Api.monster.aggroMonsters((aggroTargets != null && aggroTargets.length > 0) ? aggroTargets : "*");
                }
            }
        }

        var nowCombat = ApiTime.now();
        if (Api.combat != null && Api.combat.taunt != null && Api.combat.taunt.enabled) {
            if (Api.combat.taunt.checkTauntTick(nowCombat)) {
                return;
            }
        }

        if (isSmart) {
            try {
                if (shouldApproachTarget(world, aaAct) && !targetWithinActionRange(world, avatar, target, aaAct)) {
                    approachTargetOnly(world);
                }
                if (allowAuto && isFreeAutoAttack(aaAct) && castGateOpen()) {
                    if (SkillCaster.fireAutoAttack(world, avatar, aaAct)) noteCast();
                }
            } catch (_:Dynamic) {}
            try {
                runAdvancedRotation(world, avatar, target, activeModeConfig);
            } catch (rotErr:Dynamic) {
                ApiLogger.error("Combat", "Advanced rotation error: " + rotErr);
            }
        } else {
            try {
                if (shouldApproachTarget(world, aaAct) && !targetWithinActionRange(world, avatar, target, aaAct)) {
                    approachTargetOnly(world);
                }
                if (allowAuto && isFreeAutoAttack(aaAct) && castGateOpen()) {
                    if (SkillCaster.fireAutoAttack(world, avatar, aaAct)) noteCast();
                }
            } catch (_:Dynamic) {}
            runSimpleRotation(world, avatar);
        }
    }
    
    private static function runAdvancedRotation(world:Dynamic, avatar:Dynamic, target:Dynamic, activeModeConfig:Dynamic = null):Void {
        var confClass = (smartClass != null && smartClass != "" && smartClass != "Current") ? smartClass : "Current";
        var isCurrentClass = (confClass == "Current");
        var className:String = isCurrentClass ? SkillManager.getCurrentClassName() : confClass;
        if (isCurrentClass && className != "") {
            if (_lastDetectedClass == "" || _lastDetectedClass != className) {
                _lastDetectedClass = className;
                var activeModeStr:String = SkillManager.resolveActiveModeName(className, skillMode);
                activeModeConfig = SkillManager.resolveActiveModeConfig(world, avatar, target, smartClass, activeModeStr);
            }
        }
        if (!isCurrentClass && className != SkillManager.getCurrentClassName()) {
            var equipped:String = SkillManager.getCurrentClassName();
            if (_lastWarnedMismatchClass != equipped) {
                _lastWarnedMismatchClass = equipped;
                ApiLogger.warn("Combat", "Class mismatch! smartClass is set to '" + className + "' but player is wearing '"
                    + equipped + "'. Using the equipped class's rotation instead.");
            }
            confClass = "Current";
            isCurrentClass = true;
            className = equipped;
            activeModeConfig = SkillManager.resolveActiveModeConfig(world, avatar, target, "Current", skillMode);
        } else {
            _lastWarnedMismatchClass = "";
        }
        var modeConfig:Dynamic = (activeModeConfig != null) ? activeModeConfig : SkillManager.resolveActiveModeConfig(world, avatar, target, confClass, skillMode);
        if (modeConfig == null) {
            var now = ApiTime.now();
            if (now - _lastFallbackWarnTime > ApiTimings.WARN_THROTTLE_MS) {
                _lastFallbackWarnTime = now;
                ApiLogger.warn("Combat", "Smart Combat: mode config not found for class '" + className + "' mode '" + skillMode + "'. Falling back to custom rotation.");
            }
            runSimpleRotation(world, avatar);
            return;
        }
        var skillUseMode:String = (modeConfig.mode != null) ? modeConfig.mode : ((modeConfig.skillUseMode != null) ? modeConfig.skillUseMode : "WaitForCooldown");
        var skillTimeout:Float = (modeConfig.timeout != null) ? ApiUtils.parseFloat(modeConfig.timeout, 0) : ((modeConfig.skillTimeout != null) ? ApiUtils.parseFloat(modeConfig.skillTimeout, 0) : 0);
        var skills:Array<Dynamic> = (modeConfig.skills != null && Std.isOfType(modeConfig.skills, Array)) ? cast modeConfig.skills : [];
        if (skills.length == 0 && modeConfig.combo != null && Std.string(modeConfig.combo) != "") {
            skills = SkillDslParser.parseCombo(Std.string(modeConfig.combo));
            modeConfig.skills = skills;
        }
        // Consume the target-change latch before the empty-combo bail-out. Leaving it set would apply a
        // stale target change the moment the mode is fixed or the reset flag is switched on, which
        // reads as the rotation jumping for no reason.
        var resetOnTarget:Bool = (modeConfig.resetComboOnTargetChange == true || modeConfig.resetOnTarget == true);
        if (_targetChanged) {
            if (resetOnTarget) {
                // Logged because this path is otherwise invisible: a restart and a resume look
                // identical from the outside until you notice the wrong skill coming out.
                ApiLogger.info("Combat", "Reset on target change: restarting combo from slot 0 (class '"
                    + className + "', mode '" + skillMode + "', " + skills.length + " slots).");
                _skillIndex = 0;
                _skillWaitStart = ApiTime.now();
                _stepFirstFailTime = -1;
            }
            _targetChanged = false;
        }
        if (skills.length == 0) {
            var now = ApiTime.now();
            if (now - _lastFallbackWarnTime > ApiTimings.WARN_THROTTLE_MS) {
                _lastFallbackWarnTime = now;
                ApiLogger.warn("Combat", "Smart Combat: combo skills empty for class '" + className + "'. Falling back to custom rotation.");
            }
            runSimpleRotation(world, avatar);
            return;
        }
        if (skillUseMode.toLowerCase() == "waitforcooldown") {
            runWaitForCooldown(world, avatar, target, skills, skillTimeout);
        } else {
            runUseIfAvailable(world, avatar, target, skills);
        }
    }
    
    private static function runWaitForCooldown(world:Dynamic, avatar:Dynamic, target:Dynamic, skills:Array<Dynamic>, skillTimeout:Float):Void {
        if (isDisabled(avatar, world)) {
            _skillWaitStart = ApiTime.now();
            return;
        }
        if (!skillGateOpen()) return;
        if (_skillIndex >= skills.length) _skillIndex = 0;
        var skill:Dynamic = skills[_skillIndex];
        if (skill == null) { _skillIndex = 0; return; }
        var skillId:Int = (skill.skillId != null) ? ApiUtils.parseInt(skill.skillId, -1) : ((skill.idx != null) ? ApiUtils.parseInt(skill.idx, -1) : -1);
        if (skillId < 0 || skillId > 5) {
            _skillIndex = (_skillIndex + 1) % skills.length;
            _skillWaitStart = ApiTime.now();
            _stepFirstFailTime = -1;
            return;
        }
        var actObj:Dynamic = SkillCaster.getSkillAction(skillId);
        if (actObj == null || actObj.isOK == false) {
            _skillIndex = (_skillIndex + 1) % skills.length;
            _skillWaitStart = ApiTime.now();
            _stepFirstFailTime = -1;
            return;
        }
        var rulesPass:Bool = SkillRules.evaluateSkillRules(skill, world, avatar, target, skillId, _waitUntil);
        var now:Float = ApiTime.now();
        if (!rulesPass) {
            // A window-less `[counter]` is a hard lock: the slot is not "not ready", it is waiting for
            // the mob to actually attack. Advancing here is what made riposte skills get skipped
            // mid-combo, so stay put and retry next tick instead.
            // Guarded on `target` so losing the mob releases the lock rather than deadlocking forever.
            if (target != null && SkillRules.hasHardLockRule(skill)) {
                if (now - _lastHardLockLogTime > ApiTimings.WARN_THROTTLE_MS) {
                    _lastHardLockLogTime = now;
                    ApiLogger.diag("Combat", "Hard lock: holding slot " + _skillIndex + " (skill " + skillId
                        + ") until the target lands an attack. Waiting " + Std.string(Math.round(now - _skillWaitStart)) + "ms.");
                }
                return;
            }
            _skillIndex = (_skillIndex + 1) % skills.length;
            _skillWaitStart = now;
            _stepFirstFailTime = -1;
            return;
        }
        _stepFirstFailTime = -1;
        if (SkillCaster.isGcdActive(world)) return;
        var fireResult:Int = SkillCaster.fireSkill(world, avatar, skillId);
        if (fireResult == SkillCaster.SR_FIRED) {
            noteSkillCast();
            // A hard-locked `[counter]` is edge-triggered: this riposte answers the attack we just saw,
            // so mark that attack spent. Without this the very next `[counter]` slot in the rotation
            // would pass immediately on the same attack and the skills would chain with no mob hit in
            // between. Only hard locks consume - a timed `[counter <= 1.5s]` is a freshness check and
            // is meant to stay passable for its whole window.
            if (SkillRules.hasHardLockRule(skill)) ActionFeed.consumeForTarget();
            _skillIndex = (_skillIndex + 1) % skills.length;
            _skillWaitStart = now;
            _stepFirstFailTime = -1;
            return;
        }
        var elapsedWait:Float = now - _skillWaitStart;
        if (skillTimeout > 0 && elapsedWait >= skillTimeout) {
            if (now - _lastTimeoutSkipLogTime > ApiTimings.WARN_THROTTLE_MS) {
                _lastTimeoutSkipLogTime = now;
                ApiLogger.warn("Combat", "WaitForCooldown: slot " + _skillIndex + " (skill " + skillId
                    + ") still blocked after " + Std.string(Math.round(elapsedWait)) + "ms, skipping (timeout "
                    + Std.string(Math.round(skillTimeout)) + "ms).");
            }
            _skillIndex = (_skillIndex + 1) % skills.length;
            _skillWaitStart = now;
            _stepFirstFailTime = -1;
            return;
        }
        if (fireResult == SkillCaster.SR_RESOURCE && elapsedWait >= 10000) {
            _skillIndex = (_skillIndex + 1) % skills.length;
            _skillWaitStart = now;
            _stepFirstFailTime = -1;
            return;
        }
    }
    
    private static function runUseIfAvailable(world:Dynamic, avatar:Dynamic, target:Dynamic, skills:Array<Dynamic>):Void {
        if (isDisabled(avatar, world)) return;
        if (!skillGateOpen()) return;
        if (SkillCaster.isGcdActive(world)) return;
        var now:Float = ApiTime.now();
        for (skill in skills) {
            if (skill == null) continue;
            var skillId:Int = (skill.skillId != null) ? ApiUtils.parseInt(skill.skillId, -1) : ((skill.idx != null) ? ApiUtils.parseInt(skill.idx, -1) : -1);
            if (skillId < 0 || skillId > 5) continue;
            if (!SkillRules.evaluateSkillRules(skill, world, avatar, target, skillId, _waitUntil)) continue;
            if (SkillCaster.fireSkill(world, avatar, skillId) == SkillCaster.SR_FIRED) {
                noteSkillCast();
                return;
            }
        }
    }

    private static function runSimpleRotation(world:Dynamic, avatar:Dynamic):Void {
        if (_customRotation == null || _customRotation.length == 0) return;
        // Always restarts on a new target. This is the global custom rotation, which has no mode config
        // and therefore no `resetComboOnTargetChange` flag to read - the toggle only applies to mode-based
        // rotations. Noted explicitly so the difference from runAdvancedRotation is not mistaken for a bug.
        if (_targetChanged) {
            _rotationIndex = 0;
            _targetChanged = false;
        }
        if (!skillGateOpen()) return;
        if (customMode == "priority") {
            for (idx in _customRotation) {
                if (SkillCaster.fireSkill(world, avatar, idx) == SkillCaster.SR_FIRED) {
                    noteSkillCast();
                    return;
                }
            }
        } else {
            if (_rotationIndex >= _customRotation.length) _rotationIndex = 0;
            var targetIdx:Int = _customRotation[_rotationIndex];
            var res:Int = SkillCaster.fireSkill(world, avatar, targetIdx);
            if (res == SkillCaster.SR_FIRED || res == SkillCaster.SR_RESOURCE) {
                if (res == SkillCaster.SR_FIRED) noteSkillCast();
                _rotationIndex = (_rotationIndex + 1) % _customRotation.length;
                _sequenceStepStartTime = ApiTime.now();
            } else {
                var now:Float = ApiTime.now();
                if ((now - _sequenceStepStartTime) > 8000) {
                    _rotationIndex = (_rotationIndex + 1) % _customRotation.length;
                    _sequenceStepStartTime = now;
                }
            }
        }
    }
    
    public static inline function cleanClassName(name:String):String return SkillManager.cleanClassName(name);
    public static inline function getCurrentClassName():String return SkillManager.getCurrentClassName();
    public static inline function findClassConfig(className:String):Dynamic return SkillManager.findClassConfig(className);
    public static inline function getKnownClasses():Array<String> return SkillManager.getKnownClasses();
    public static inline function getAvailableModes(className:String):Array<String> return SkillManager.getAvailableModes(className);
    public static inline function registerCustomMode(c:String, m:String, sm:String, t:Int, cm:String, sa:String = null, rc:Null<Bool> = null, aa:Null<Bool> = null):Void SkillManager.registerCustomMode(c, m, sm, t, cm, sa, rc, aa);
    public static inline function unregisterCustomMode(c:String, m:String):Bool return SkillManager.unregisterCustomMode(c, m);
    public static inline function reloadSkills(silent:Bool = false):Void SkillManager.reload(silent);
    public static inline function canFireSkill(idx:Int):Bool return SkillCaster.canFireSkill(idx);
    public static inline function tryFireSkillPublic(idx:Int):Bool return SkillCaster.fireSkill(Api.game.world, Api.game.world.myAvatar, idx) == SkillCaster.SR_FIRED;
}