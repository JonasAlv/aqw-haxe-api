package com.aqwapi.modules;

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

    // Target lock
    public static var targetName:String = null;
    public static var lockedMMID:String = null;
    public static var globalStopOnTargetAuras:Array<String> = null;

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
    private static var _lastTargetMMID:String = null;
    private static var _targetChanged:Bool = false;
    private static var _lastDetectedClass:String = "";
    private static var _pausedByTargetAura:Bool = false;
    private static var _waitUntil:Dynamic = {};
    private static var _lastFallbackWarnTime:Float = 0;

    /**
     * Monster MapIDs temporarily excluded from target acquisition, mapped to the monotonic
     * timestamp at which the exclusion expires. Populated when a target is dropped for
     * carrying a forbidden reflect/shield aura - without this the engine re-acquires the
     * same monster on the very next tick and spins in a drop/acquire loop at 10Hz.
     */
    private static var _temporaryIgnore:Map<String, Float> = new Map<String, Float>();
    private static inline var TEMP_IGNORE_MS:Float = 4000;

    /** True while `mmid` is inside its penalty box. `exists` is checked first because Flash is
     *  a static target where `Float` cannot be null. */
    private static function isTemporarilyIgnored(mmid:String):Bool {
        if (mmid == null || mmid == "" || _temporaryIgnore == null) return false;
        if (!_temporaryIgnore.exists(mmid)) return false;
        if (ApiTime.now() < _temporaryIgnore.get(mmid)) return true;
        _temporaryIgnore.remove(mmid);
        return false;
    }

    private static function ignoreTemporarily(mmid:String, ms:Float = TEMP_IGNORE_MS):Void {
        if (mmid == null || mmid == "") return;
        _temporaryIgnore.set(mmid, ApiTime.now() + ms);
        pruneTemporaryIgnore();
    }

    /** Keeps the map bounded - without this every distinct monster ever dropped stays
     *  resident for the lifetime of the session. `keys()` returns a copy, so removing
     *  during the walk is safe. */
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
            _timer = new Timer(100);
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
        _temporaryIgnore = new Map<String, Float>();
        if (_timer != null && _timer.running) {
            _timer.stop();
        }
        if (Api.game != null && Api.game.world != null) {
            var world:Dynamic = Api.game.world;
            if (world.cancelAutoAttack != null) {
                try { world.cancelAutoAttack(); } catch (_:Dynamic) {}
            }
        }
    }

    public static function toggleSmart():Void {
        if (IS_ON && isSmart) stop();
        else start(true);
    }

    public static function toggleCustom():Void {
        if (IS_ON && !isSmart) stop();
        else start(false);
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

        // Auto Attack - always the verified AA action, never action bar slot 0 (which may
        // hold a real skill on some classes and would report a meaningless range).
        try {
            var act:Dynamic = (aaAct != null) ? aaAct : SkillCaster.getAutoAttackAction(world);
            if (act != null && act.range != null) {
                var aaR:Float = ApiUtils.parseFloat(act.range, 301);
                if (aaR >= 20000) isAaInfinite = true;
                else if (aaR > 0 && aaR <= 301) isAaClose = true;
            }
        } catch (_:Dynamic) {}

        // Active Skills (slots 1 to 5)
        var hasCloseSkill:Bool = false;
        var hasInfiniteSkill:Bool = false;

        try {
            for (i in 1...5) {
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

    /**
     * True when the player cannot act at all: dead, or hard crowd-controlled.
     *
     * Deliberately NOT keyed on `intState == 2`. Nothing in this codebase corroborates
     * that mapping - `EntityDTO` and `SkillCaster.fireSkill` both gate on aura
     * *categories* - and treating a common state value as "stunned" would freeze the
     * rotation during ordinary movement.
     *
     * Uses `world.auraCatOf`, the same authoritative mechanism SkillCaster.fireSkill
     * uses for its CC guard, so the two can never disagree. Cached per tick because
     * both rotation entry points call this and a stun does not expire mid-tick.
     */
    private static function isDisabled(avatar:Dynamic, world:Dynamic):Bool {
        if (avatar == null || avatar.dataLeaf == null) return false;

        var now:Float = ApiTime.now();
        if (now < _ccCheckValidUntil) return _ccCheckResult;
        _ccCheckValidUntil = now + CC_CHECK_CACHE_MS;

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
    private static inline var CC_CHECK_CACHE_MS:Float = 50;

    /**
     * True when the resolved Auto Attack is a genuine, mana-free basic attack.
     *
     * Guards the background AA fire on classes that put a real (MP-costing, GCD-bound)
     * skill in action bar slot 0. `aaAct` comes from `SkillCaster.getAutoAttackAction`,
     * so it is already the verified AA action - never slot 0 - and the `mp` check is only
     * a second line of defence against a mis-resolved action.
     */
    private static function isFreeAutoAttack(aaAct:Dynamic):Bool {
        if (aaAct == null) return false;
        if (aaAct.isOK == false) return false;
        try {
            if (aaAct.mp != null) return ApiUtils.parseInt(aaAct.mp, 0) <= 0;
        } catch (_:Dynamic) {}
        return true;
    }

    private static function onTick(e:TimerEvent):Void {
        if (Api.game == null || Api.game.world == null || Api.game.world.myAvatar == null) return;
        if (Api.map != null && !Api.map.isLoaded) return;
        var world:Dynamic = Api.game.world;
        var avatar:Dynamic = world.myAvatar;

        if (avatar.dataLeaf != null && avatar.dataLeaf.intState == 0) return;
        var target:Dynamic = avatar.target;

        if (target != null) {
            var isInvalid:Bool = false;
            if (target.pMC == null || target.dataLeaf == null || target.objData == null) isInvalid = true;
            else if (target.dataLeaf.intHP != null && target.dataLeaf.intHP <= 0) isInvalid = true;
            else if (target.dataLeaf.intState != null && target.dataLeaf.intState == 0) isInvalid = true;
            else {
                var ent = new EntityDTO(target);
                if (targetName != null && targetName != "*" && targetName != "") {
                    if (ent.name != "" && ent.name.toLowerCase().indexOf(targetName.toLowerCase()) == -1) {
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
            }
        }

        if (target == null) {
            try {
                var currentMonsters:Array<EntityDTO> = Api.monster.getByCell(Std.string(world.strFrame));
                for (monsterTarget in currentMonsters) {
                    if (monsterTarget == null || !monsterTarget.alive || !monsterTarget.hasGraphic) continue;
                    var raw = monsterTarget.raw;
                    if (raw == null || raw.pMC == null || raw.objData == null || raw.dataLeaf == null) continue;
                    if (lockedMMID != null && monsterTarget.mapId != lockedMMID) continue;
                    if (isTemporarilyIgnored(monsterTarget.mapId)) continue;
                    if (targetName != null && targetName != "*" && monsterTarget.name.toLowerCase().indexOf(targetName.toLowerCase()) == -1) continue;
                    if (world.setTarget != null) {
                        world.setTarget(monsterTarget.raw);
                        target = monsterTarget.raw;
                        break;
                    }
                }
            } catch (_:Dynamic) {}

            if (target == null && lockedMMID == null) {
                try {
                    if (world.getMonster != null) {
                        var monName:String = (targetName != null && targetName != "*") ? targetName.toLowerCase() : "Any";
                        var anyMon:Dynamic = world.getMonster(monName);
                        if (anyMon != null && anyMon.pMC != null && anyMon.objData != null && anyMon.dataLeaf != null) {
                            var monHp:Int = (anyMon.dataLeaf.intHP != null) ? Std.int(anyMon.dataLeaf.intHP) : 1;
                            var monState:Int = (anyMon.dataLeaf.intState != null) ? Std.int(anyMon.dataLeaf.intState) : 1;
                            var anyMMID:String = (anyMon.dataLeaf.MonMapID != null) ? Std.string(anyMon.dataLeaf.MonMapID) : null;
                            // Must honour the penalty box too, otherwise world.getMonster
                            // hands back the shielded monster we just dropped.
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

        if (curTargetMMID != null && curTargetMMID != _lastTargetMMID) {
            _lastTargetMMID = curTargetMMID;
            _targetChanged = true;
            _skillWaitStart = ApiTime.now();
            _stepFirstFailTime = -1;
        }

        // Resolve the genuine Auto Attack once per tick and share it with both
        // shouldApproachTarget and fireAutoAttack, instead of each re-resolving.
        var aaAct:Dynamic = null;
        try { aaAct = SkillCaster.getAutoAttackAction(world); } catch (_:Dynamic) {}

        if (isSmart) {
            var activeModeConfig = SkillManager.resolveActiveModeConfig(world, avatar, target, smartClass, skillMode);
            if (Api.aura.shouldStopForTargetAuras(globalStopOnTargetAuras, activeModeConfig, world, avatar, target)) {
                if (!_pausedByTargetAura) {
                    _pausedByTargetAura = true;
                    ApiLogger.warn("Combat", "Target has forbidden reflect/shield aura, dropping target!");
                }
                if (world.cancelAutoAttack != null) {
                    try { world.cancelAutoAttack(); } catch (_:Dynamic) {}
                }
                // Drop the target. Returning early without clearing it leaves the same
                // monster re-validated (and re-blocked) every tick - a soft lock that
                // never reaches target acquisition.
                //
                // The penalty box is what makes the drop stick: BOTH acquisition paths
                // below must refuse this MMID, otherwise the same monster is re-acquired
                // on the next tick and the engine cycles at 10Hz.
                var dropMMID:String = null;
                try {
                    if (target != null && target.dataLeaf != null && target.dataLeaf.MonMapID != null) dropMMID = Std.string(target.dataLeaf.MonMapID);
                    else if (target != null && target.objData != null && target.objData.MonMapID != null) dropMMID = Std.string(target.objData.MonMapID);
                } catch (_:Dynamic) {}
                ignoreTemporarily(dropMMID);
                if (world.cancelTarget != null) {
                    try { world.cancelTarget(); } catch (_:Dynamic) {}
                }
                try { avatar.target = null; } catch (_:Dynamic) {}
                target = null;
                _targetChanged = true;
                return;
            } else if (_pausedByTargetAura) {
                _pausedByTargetAura = false;
                ApiLogger.info("Combat", "Target reflect/shield aura expired, resuming combat!");
            }

            try {
                if (shouldApproachTarget(world, aaAct)) {
                    if (world.approachTarget != null) {
                        try { untyped world.approachTarget(); } catch (_:Dynamic) {}
                    }
                    // Auto Attack is GCD-independent, so it can still land while closing
                    // distance. Without this the bot walks and fires nothing whenever the
                    // whole rotation is blocked.
                    if (isFreeAutoAttack(aaAct)) {
                        SkillCaster.fireAutoAttack(world, avatar, aaAct);
                    }
                } else {
                    // Auto Attack is completely independent of GCD and skill rotations.
                    // Always fire whenever ready (out of CD) to damage target and regenerate mana.
                    if (isFreeAutoAttack(aaAct)) {
                        SkillCaster.fireAutoAttack(world, avatar, aaAct);
                    }
                }
            } catch (_:Dynamic) {}

            try {
                runAdvancedRotation(world, avatar, target, activeModeConfig);
            } catch (rotErr:Dynamic) {
                ApiLogger.error("Combat", "Advanced rotation error: " + rotErr);
            }
        } else {
            try {
                if (shouldApproachTarget(world, aaAct)) {
                    if (world.approachTarget != null) {
                        try { untyped world.approachTarget(); } catch (_:Dynamic) {}
                    }
                    if (isFreeAutoAttack(aaAct)) {
                        SkillCaster.fireAutoAttack(world, avatar, aaAct);
                    }
                } else {
                    if (isFreeAutoAttack(aaAct)) {
                        SkillCaster.fireAutoAttack(world, avatar, aaAct);
                    }
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
                // Resolve into a LOCAL. `skillMode` is global state that the UI and
                // HScriptEngine snapshot/restore, so writing the auto-detected mode back
                // into it would clobber the user's explicit preference.
                var activeModeStr:String = SkillManager.resolveActiveModeName(className, skillMode);
                activeModeConfig = SkillManager.resolveActiveModeConfig(world, avatar, target, smartClass, activeModeStr);
            }
        }

        // A forced smartClass that does not match what the player is wearing makes the
        // rotation meaningless - skill slot N resolves to a different skill entirely.
        // Fall back to the equipped class's own rotation instead of firing the wrong one.
        if (!isCurrentClass && className != SkillManager.getCurrentClassName()) {
            var equipped:String = SkillManager.getCurrentClassName();
            var mismatchNow = ApiTime.now();
            if (mismatchNow - _lastFallbackWarnTime > 3000) {
                _lastFallbackWarnTime = mismatchNow;
                ApiLogger.warn("Combat", "Class mismatch! smartClass is set to '" + className + "' but player is wearing '"
                    + equipped + "'. Using the equipped class's rotation instead.");
            }
            confClass = "Current";
            isCurrentClass = true;
            className = equipped;
            activeModeConfig = SkillManager.resolveActiveModeConfig(world, avatar, target, "Current", skillMode);
        }

        var modeConfig:Dynamic = (activeModeConfig != null) ? activeModeConfig : SkillManager.resolveActiveModeConfig(world, avatar, target, confClass, skillMode);
        if (modeConfig == null) {
            var now = ApiTime.now();
            if (now - _lastFallbackWarnTime > 3000) {
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
        if (skills.length == 0) {
            var now = ApiTime.now();
            if (now - _lastFallbackWarnTime > 3000) {
                _lastFallbackWarnTime = now;
                ApiLogger.warn("Combat", "Smart Combat: combo skills empty for class '" + className + "'. Falling back to custom rotation.");
            }
            runSimpleRotation(world, avatar);
            return;
        }

        var resetOnTarget:Bool = (modeConfig.resetComboOnTargetChange == true || modeConfig.resetOnTarget == true);
        if (_targetChanged && resetOnTarget) {
            _skillIndex = 0;
            _skillWaitStart = ApiTime.now();
            _stepFirstFailTime = -1;
            _targetChanged = false;
        }

        if (skillUseMode.toLowerCase() == "waitforcooldown") {
            runWaitForCooldown(world, avatar, target, skills, skillTimeout);
        } else {
            runUseIfAvailable(world, avatar, target, skills);
        }
    }

    private static function runWaitForCooldown(world:Dynamic, avatar:Dynamic, target:Dynamic, skills:Array<Dynamic>, skillTimeout:Float):Void {
        // Player is dead or crowd-controlled. Do nothing at all - crucially, do NOT
        // evaluate rules (a rule failure advances the combo index) and do NOT let the
        // per-slot `skillTimeout` elapse while we are unable to act, which would make the
        // rotation skip a step the moment CC wears off.
        if (isDisabled(avatar, world)) {
            _skillWaitStart = ApiTime.now();
            return;
        }

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

        // Verify action exists on current class
        var actObj:Dynamic = SkillCaster.getSkillAction(skillId);
        if (actObj == null || actObj.isOK == false) {
            _skillIndex = (_skillIndex + 1) % skills.length;
            _skillWaitStart = ApiTime.now();
            _stepFirstFailTime = -1;
            return;
        }

        var rulesPass:Bool = SkillRules.evaluateSkillRules(skill, world, avatar, target, skillId, _waitUntil);
        var now:Float = ApiTime.now();

        // If rule condition is not met (e.g. hp < 50%), skip to next skill in combo
        if (!rulesPass) {
            _skillIndex = (_skillIndex + 1) % skills.length;
            _skillWaitStart = now;
            _stepFirstFailTime = -1;
            return;
        }
        _stepFirstFailTime = -1;

        // If game GCD is active, wait without advancing
        if (SkillCaster.isGcdActive(world)) return;

        var fireResult:Int = SkillCaster.fireSkill(world, avatar, skillId);
        if (fireResult == SkillCaster.SR_FIRED) {
            // Successfully fired, advance to next skill
            _skillIndex = (_skillIndex + 1) % skills.length;
            _skillWaitStart = now;
            _stepFirstFailTime = -1;
            return;
        }

        // TimingBlocked (on cooldown) or ResourceBlocked (out of mana):
        // In WaitForCooldown mode, we MUST wait for the skill to become ready!
        var elapsedWait:Float = now - _skillWaitStart;

        // Safety cap on how long one slot may hold the rotation while the skill is not
        // ready. `_skillWaitStart` is set when the slot is entered, which normally happens
        // right after a successful cast while the GCD is still running - so the GCD is
        // consumed first and `timeout` is effectively "GCD + timeout". A slot entered via a
        // skip (failed rules / missing action) has no GCD pending and gets the full budget.
        //
        // Semantics: timeout > 0 is a real cap in ms; 0 or absent means wait indefinitely,
        // which is the safe guard for rotations that must never drop a proc.
        if (skillTimeout > 0 && elapsedWait >= skillTimeout) {
            if (now - _lastTimeoutSkipLogTime > 3000) {
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

        // Safety fallback: if resource blocked (out of MP) for > 10 seconds, advance to avoid locking rotation
        if (fireResult == SkillCaster.SR_RESOURCE && elapsedWait >= 10000) {
            _skillIndex = (_skillIndex + 1) % skills.length;
            _skillWaitStart = now;
            _stepFirstFailTime = -1;
            return;
        }

        // Otherwise: DO NOT ADVANCE! Stay at _skillIndex and wait for cooldown/mana!
    }

    private static function runUseIfAvailable(world:Dynamic, avatar:Dynamic, target:Dynamic, skills:Array<Dynamic>):Void {
        if (isDisabled(avatar, world)) return;
        if (SkillCaster.isGcdActive(world)) return;
        var now:Float = ApiTime.now();

        for (skill in skills) {
            if (skill == null) continue;
            var skillId:Int = (skill.skillId != null) ? ApiUtils.parseInt(skill.skillId, -1) : ((skill.idx != null) ? ApiUtils.parseInt(skill.idx, -1) : -1);
            if (skillId < 0 || skillId > 5) continue;
            if (!SkillRules.evaluateSkillRules(skill, world, avatar, target, skillId, _waitUntil)) continue;
            if (SkillCaster.fireSkill(world, avatar, skillId) == SkillCaster.SR_FIRED) return;
        }
    }

    private static function runSimpleRotation(world:Dynamic, avatar:Dynamic):Void {
        if (_customRotation == null || _customRotation.length == 0) return;
        if (_targetChanged) {
            _rotationIndex = 0;
            _targetChanged = false;
        }

        if (customMode == "priority") {
            for (idx in _customRotation) {
                if (SkillCaster.fireSkill(world, avatar, idx) == SkillCaster.SR_FIRED) return;
            }
        } else {
            if (_rotationIndex >= _customRotation.length) _rotationIndex = 0;
            var targetIdx:Int = _customRotation[_rotationIndex];
            var res:Int = SkillCaster.fireSkill(world, avatar, targetIdx);
            if (res == SkillCaster.SR_FIRED || res == SkillCaster.SR_RESOURCE) {
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

    // Static forwarders to SkillManager / SkillCaster
    public static inline function cleanClassName(name:String):String return SkillManager.cleanClassName(name);
    public static inline function getCurrentClassName():String return SkillManager.getCurrentClassName();
    public static inline function findClassConfig(className:String):Dynamic return SkillManager.findClassConfig(className);
    public static inline function getKnownClasses():Array<String> return SkillManager.getKnownClasses();
    public static inline function getAvailableModes(className:String):Array<String> return SkillManager.getAvailableModes(className);
    public static inline function registerCustomMode(c:String, m:String, sm:String, t:Int, cm:String, sa:String = null, rc:Null<Bool> = null):Void SkillManager.registerCustomMode(c, m, sm, t, cm, sa, rc);
    public static inline function unregisterCustomMode(c:String, m:String):Bool return SkillManager.unregisterCustomMode(c, m);
    public static inline function reloadSkills(silent:Bool = false):Void SkillManager.reload(silent);
    public static inline function canFireSkill(idx:Int):Bool return SkillCaster.canFireSkill(idx);
    public static inline function tryFireSkillPublic(idx:Int):Bool return SkillCaster.fireSkill(Api.game.world, Api.game.world.myAvatar, idx) == SkillCaster.SR_FIRED;
}
