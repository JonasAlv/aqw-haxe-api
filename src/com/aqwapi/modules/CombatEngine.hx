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
    private static var _customRotation:Array<Int> = [];
    private static var _rotationIndex:Int = 0;
    private static var _sequenceStepStartTime:Float = 0;
    private static var _skillIndex:Int = 0;
    private static var _skillWaitStart:Float = 0;
    private static var _stepFirstFailTime:Float = -1;
    private static var _lastTargetMMID:String = null;
    private static var _targetChanged:Bool = false;
    private static var _lastDetectedClass:String = "";
    private static var _pausedByTargetAura:Bool = false;
    private static var _waitUntil:Dynamic = {};
    private static var _lastFallbackWarnTime:Float = 0;

    public static function init():Void {
        // Only load from disk if not already loaded — data is preloaded at startup via Api.preloadAssets().
        // Calling reload() unconditionally caused a synchronous disk read lag spike on every combat start.
        if (!SkillManager.isLoaded()) SkillManager.reload(true);
        if (_timer == null) {
            _timer = new Timer(100);
            _timer.addEventListener(TimerEvent.TIMER, onTick);
        }
    }

    public static function start(smart:Bool, silent:Bool = false):Void {
        init();
        isSmart = smart;
        IS_ON = true;

        var confClass = (smartClass != null && smartClass != "" && smartClass != "Current") ? smartClass : "Current";
        if (confClass == "Current") {
            if (skillMode == null || skillMode == "") {
                skillMode = "Auto";
            }
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
                var c = (smartClass != null && smartClass != "" && smartClass != "Current") ? smartClass : SkillManager.getCurrentClassName();
                ApiLogger.info("Combat", "Smart combat started. Class: '" + c + "', Mode: '" + skillMode + "'");
            } else {
                ApiLogger.info("Combat", "Custom combat started.");
            }
        }
    }

    public static function stop():Void {
        IS_ON = false;
        if (_timer != null && _timer.running) {
            _timer.stop();
        }
        if (Api.game != null && Api.game.world != null) {
            var world:Dynamic = Api.game.world;
            try {
                if (world.cancelAutoAttack != null) {
                    world.cancelAutoAttack();
                }
            } catch (_:Dynamic) {}
            try {
                if (world.autoActionTimer != null && world.autoActionTimer.running) {
                    world.autoActionTimer.stop();
                }
            } catch (_:Dynamic) {}
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

    public static function shouldApproachTarget(world:Dynamic):Bool {
        if (world == null) return false;
        if (Api.combat != null && Api.combat.infiniteRange) return false;

        var isAaClose:Bool = false;
        var isAaInfinite:Bool = false;

        // Auto Attack (slot 0)
        try {
            var aaAct:Dynamic = SkillCaster.getSkillAction(0);
            if (aaAct == null && world.getAutoAttack != null) {
                try { aaAct = world.getAutoAttack(); } catch (_:Dynamic) {}
            }
            if (aaAct == null && world.actions != null && world.actions.active != null) {
                try {
                    var actList:Array<Dynamic> = cast world.actions.active;
                    if (actList != null && actList.length > 0) aaAct = actList[0];
                } catch (_:Dynamic) {}
            }
            if (aaAct != null && aaAct.range != null) {
                var aaR:Float = ApiUtils.parseFloat(aaAct.range, 301);
                if (aaR >= 20000) isAaInfinite = true;
                else if (aaR > 0 && aaR <= 301) isAaClose = true;
            }
        } catch (_:Dynamic) {}

        // Active Skills (slots 1 to 4)
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

    private static function onTick(e:TimerEvent):Void {
        if (Api.game == null || Api.game.world == null || Api.game.world.myAvatar == null) return;
        var world:Dynamic = Api.game.world;
        var avatar:Dynamic = world.myAvatar;

        if (avatar.dataLeaf != null && avatar.dataLeaf.intState == 0) return;
        var target:Dynamic = avatar.target;

        if (target != null) {
            var isInvalid:Bool = false;
            if (target.pMC == null || target.dataLeaf == null || target.objData == null) isInvalid = true;
            else if (target.dataLeaf.intHP != null && target.dataLeaf.intHP <= 0) isInvalid = true;
            else if (target.dataLeaf.intState != null && target.dataLeaf.intState == 0) isInvalid = true;

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
                            if (monHp > 0 && monState != 0) {
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

        if (isSmart) {
            var activeModeConfig = SkillManager.resolveActiveModeConfig(world, avatar, target, smartClass, skillMode);
            if (Api.aura.shouldStopForTargetAuras(globalStopOnTargetAuras, activeModeConfig, world, avatar, target)) {
                if (!_pausedByTargetAura) {
                    _pausedByTargetAura = true;
                    ApiLogger.warn("Combat", "Target has forbidden reflect/shield aura, pausing combat!");
                }
                if (world.cancelAutoAttack != null) {
                    try { world.cancelAutoAttack(); } catch (_:Dynamic) {}
                }
                try {
                    if (world.autoActionTimer != null && world.autoActionTimer.running) {
                        world.autoActionTimer.stop();
                    }
                } catch (_:Dynamic) {}
                return;
            } else if (_pausedByTargetAura) {
                _pausedByTargetAura = false;
                ApiLogger.info("Combat", "Target reflect/shield aura expired, resuming combat!");
            }

            try {
                if (shouldApproachTarget(world)) {
                    if (world.approachTarget != null) {
                        try { untyped world.approachTarget(); } catch (_:Dynamic) {}
                    }
                } else {
                    var isAAActive:Bool = false;
                    try {
                        isAAActive = (world.autoActionTimer != null && world.autoActionTimer.running);
                    } catch (_:Dynamic) {}
                    if (!isAAActive && !SkillCaster.isGcdActive(world)) {
                        SkillCaster.fireSkill(world, avatar, 0);
                    }
                }
            } catch (_:Dynamic) {}

            try {
                runAdvancedRotation(world, avatar, target);
            } catch (rotErr:Dynamic) {
                ApiLogger.error("Combat", "Advanced rotation error: " + rotErr);
            }
        } else {
            runSimpleRotation(world, avatar);
        }
    }

    private static function runAdvancedRotation(world:Dynamic, avatar:Dynamic, target:Dynamic):Void {
        var confClass = (smartClass != null && smartClass != "" && smartClass != "Current") ? smartClass : "Current";
        var isCurrentClass = (confClass == "Current");
        var className:String = isCurrentClass ? SkillManager.getCurrentClassName() : confClass;
        var config:Dynamic = (className != "") ? SkillManager.findClassConfig(className) : null;
        if (config == null) {
            var now = ApiTime.now();
            if (now - _lastFallbackWarnTime > 3000) {
                _lastFallbackWarnTime = now;
                ApiLogger.warn("Combat", "Smart Combat: class config not found for '" + className + "'. Falling back to custom rotation.");
            }
            runSimpleRotation(world, avatar);
            return;
        }

        if (isCurrentClass && className != "") {
            if (_lastDetectedClass == "") {
                _lastDetectedClass = className;
                if (skillMode == null || skillMode == "") {
                    skillMode = "Auto";
                }
            } else if (_lastDetectedClass != className) {
                _lastDetectedClass = className;
                var avail = SkillManager.getAvailableModes(className);
                if (skillMode != "Auto" && avail.indexOf(skillMode) == -1) {
                    skillMode = "Auto";
                }
            }
        }

        var modeConfig:Dynamic = SkillManager.resolveActiveModeConfig(world, avatar, target, smartClass, skillMode);
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
        var skillTimeout:Float = (modeConfig.timeout != null) ? ApiUtils.parseFloat(modeConfig.timeout, 100) : ((modeConfig.skillTimeout != null) ? ApiUtils.parseFloat(modeConfig.skillTimeout, 100) : 100);
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

        var rulesPass:Bool = SkillRules.evaluateSkillRules(skill, world, avatar, target, skillId, _waitUntil);
        var now:Float = ApiTime.now();

        if (!rulesPass) {
            _skillIndex = (_skillIndex + 1) % skills.length;
            _skillWaitStart = now;
            _stepFirstFailTime = -1;
            return;
        }
        _stepFirstFailTime = -1;

        if (SkillCaster.isGcdActive(world)) return;

        var fireResult:Int = SkillCaster.fireSkill(world, avatar, skillId);
        if (fireResult == SkillCaster.SR_FIRED || fireResult == SkillCaster.SR_RESOURCE) {
            _skillIndex = (_skillIndex + 1) % skills.length;
            _skillWaitStart = now;
            _stepFirstFailTime = -1;
        } else {
            var elapsedWait:Float = now - _skillWaitStart;
            // skillTimeout is in ms: if <= 0 or elapsedWait >= skillTimeout, move to next skill
            if (skillTimeout <= 0 || elapsedWait >= skillTimeout) {
                _skillIndex = (_skillIndex + 1) % skills.length;
                _skillWaitStart = now;
                _stepFirstFailTime = -1;
            }
        }
    }

    private static function runUseIfAvailable(world:Dynamic, avatar:Dynamic, target:Dynamic, skills:Array<Dynamic>):Void {
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
