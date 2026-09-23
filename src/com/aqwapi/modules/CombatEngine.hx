package com.aqwapi.modules;

import com.aqwapi.events.ApiEvent;
import com.aqwapi.AqwApi;
import com.aqwapi.data.EntityDTO;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwTime;
import com.aqwapi.utils.AqwUtils;
import flash.events.TimerEvent;
import flash.utils.Timer;

class CombatEngine {
    public static var IS_ON:Bool          = false;
    public static var isSmart:Bool        = false;
    public static var lockedMMID:String   = null;
    public static var targetName:String   = null;
    public static var skillMode:String    = "Base";

    public static var farmClass:String  = "";
    public static var farmMode:String   = "Base";
    public static var soloClass:String  = "";
    public static var soloMode:String   = "Base";
    public static var bossClass:String  = "";
    public static var bossMode:String   = "Base";
    public static var dodgeClass:String = "";
    public static var dodgeMode:String  = "Base";

    private static var _timer:Timer;
    private static var _customRotation:Array<Int> = [4, 3, 2, 1];
    private static var _rotationIndex:Int = 0;
    public static var customMode:String = "priority";
    private static var _sequenceStepStartTime:Float = 0;
    private static var _skillsData:Dynamic = null;
    private static var _waitUntil:Dynamic  = {};
    private static var _lastTargetMMID:String = null;
    private static var _skillWaitStart:Float = 0;

    public static function init():Void {
        reloadSkills();
    }

    public static function toggleSmart():Void {
        if (IS_ON && isSmart) { stop(); return; }
        reloadSkills();
        start(true);
    }

    public static function toggleCustom():Void {
        if (IS_ON && !isSmart) { stop(); return; }
        start(false);
    }

    public static function start(smart:Bool, silent:Bool = false):Void {
        stop();
        reloadSkills(silent);
        isSmart = smart;
        IS_ON = true;
        _rotationIndex = 0;
        _sequenceStepStartTime = AqwTime.now();
        _waitUntil = {};
        _lastTargetMMID = null;
        _skillWaitStart = AqwTime.now();

        if (lockedMMID == null && AqwApi.game != null && AqwApi.game.world != null && AqwApi.game.world.myAvatar != null) {
            var avatar:Dynamic = AqwApi.game.world.myAvatar;
            if (avatar.target != null) {
                var ent = new EntityDTO(avatar.target);
                if (ent.mapId != "") lockedMMID = ent.mapId;
                else {
                    var mmidSrc:Dynamic = (avatar.target.dataLeaf != null) ? avatar.target.dataLeaf : (avatar.target.objData != null ? avatar.target.objData : null);
                    if (mmidSrc != null && mmidSrc.MonMapID != null) lockedMMID = Std.string(mmidSrc.MonMapID);
                }
            }
        }

        AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.COMBAT_TOGGLED, isSmart ? "Smart Combat Activated" : "Custom Combat Activated"));
        if (!silent) ApiLogger.info("Combat", isSmart ? "Smart Combat Activated" : "Custom Combat Activated");

        if (_timer == null) {
            _timer = new Timer(500);
            _timer.addEventListener(TimerEvent.TIMER, onTick, false, 0, true);
        }
        _timer.start();
    }

    public static function stop():Void {
        if (!IS_ON) return;
        IS_ON = false;
        if (_timer != null) { _timer.stop(); _timer = null; }
        lockedMMID = null;
        targetName = null;
        _lastTargetMMID = null;
        _skillWaitStart = 0;
        if (AqwApi.game != null && AqwApi.game.world != null) {
            try {
                if (AqwApi.game.world.cancelAutoAttack != null) {
                    AqwApi.game.world.cancelAutoAttack();
                }
            } catch (e:Dynamic) {}
        }
        AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.COMBAT_TOGGLED, "Combat Stopped"));
        ApiLogger.info("Combat", "Combat Stopped");
    }

    public static function setCustomRotation(rotation:Array<Int>, mode:String = "auto"):Void {
        _customRotation = rotation;
        if (mode == "auto") {
            var seen:Map<Int, Bool> = new Map<Int, Bool>();
            var hasDupes:Bool = false;
            for (r in rotation) {
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
        _sequenceStepStartTime = AqwTime.now();
    }

    public static function reloadSkills(silent:Bool = false):Void {
        try {
            var FileClass:Dynamic = Type.resolveClass("flash.filesystem.File");
            var FileStreamClass:Dynamic = Type.resolveClass("flash.filesystem.FileStream");

            if (FileClass == null || FileStreamClass == null) {
                _skillsData = {};
                return;
            }

            var appDir:Dynamic = Reflect.getProperty(FileClass, "applicationDirectory");
            var storageDir:Dynamic = Reflect.getProperty(FileClass, "applicationStorageDirectory");

            var bundledFile:Dynamic = null;
            if (appDir != null) {
                bundledFile = appDir.resolvePath("assets/AdvancedSkills.json");
                if (!bundledFile.exists) bundledFile = appDir.resolvePath("assets/advancedskills.json");
                if (!bundledFile.exists) bundledFile = appDir.resolvePath("AdvancedSkills.json");
                if (!bundledFile.exists) bundledFile = appDir.resolvePath("advancedskills.json");
            }
            if ((bundledFile == null || !bundledFile.exists) && storageDir != null) {
                bundledFile = storageDir.resolvePath("AdvancedSkills.json");
                if (!bundledFile.exists) bundledFile = storageDir.resolvePath("assets/AdvancedSkills.json");
            }

            if (bundledFile != null && bundledFile.exists) {
                var FileModeClass:Dynamic = Type.resolveClass("flash.filesystem.FileMode");
                var readMode:String = (FileModeClass != null) ? Reflect.getProperty(FileModeClass, "READ") : "read";
                var stream:Dynamic = Type.createInstance(FileStreamClass, []);
                stream.open(bundledFile, readMode);
                var raw:String = stream.readUTFBytes(stream.bytesAvailable);
                stream.close();
                _skillsData = haxe.Json.parse(raw);
            } else {
                _skillsData = {};
                if (!silent) ApiLogger.warn("Skills", "assets/AdvancedSkills.json missing!");
            }

            var customFiles:Array<Dynamic> = [];
            if (storageDir != null) customFiles.push(storageDir.resolvePath("skills_custom.json"));
            if (appDir != null) customFiles.push(appDir.resolvePath("skills_custom.json"));

            for (customFile in customFiles) {
                if (customFile != null && customFile.exists) {
                    try {
                        var FileModeClass2:Dynamic = Type.resolveClass("flash.filesystem.FileMode");
                        var readMode2:String = (FileModeClass2 != null) ? Reflect.getProperty(FileModeClass2, "READ") : "read";
                        var cStream:Dynamic = Type.createInstance(FileStreamClass, []);
                        cStream.open(customFile, readMode2);
                        var cRaw:String = cStream.readUTFBytes(cStream.bytesAvailable);
                        cStream.close();
                        var customData:Dynamic = haxe.Json.parse(cRaw);
                        for (key in Reflect.fields(customData)) {
                            Reflect.setField(_skillsData, key, Reflect.field(customData, key));
                        }
                        if (!silent) ApiLogger.info("Skills", "Merged skills_custom.json override!");
                        break;
                    } catch (ce:Dynamic) {}
                }
            }

        } catch (e:Dynamic) {
            if (!silent) ApiLogger.error("Skills", "AdvancedSkills.json error: " + Std.string(e));
        }
    }

    private static function onTick(e:TimerEvent):Void {
        if (AqwApi.game == null || AqwApi.game.world == null || AqwApi.game.world.myAvatar == null) return;

        var world:Dynamic  = AqwApi.game.world;
        var avatar:Dynamic = world.myAvatar;

        if (avatar.dataLeaf != null && avatar.dataLeaf.intState == 0) return;

        var target:Dynamic = avatar.target;

        if (target != null && target.dataLeaf != null && (target.dataLeaf.intHP <= 0 || target.dataLeaf.intState == 0)) {
            if (world.cancelTarget != null) {
                try { world.cancelTarget(); } catch (e:Dynamic) {}
            }
            target = null;
        }

        if (target == null) {
            try {
                var currentMonsters:Array<EntityDTO> = AqwApi.monster.getByCell(Std.string(world.strFrame));
                for (monsterTarget in currentMonsters) {
                    if (monsterTarget == null || !monsterTarget.alive) continue;
                    if (lockedMMID != null && monsterTarget.mapId != lockedMMID) continue;
                    if (targetName != null && targetName != "*" && monsterTarget.name.toLowerCase().indexOf(targetName.toLowerCase()) == -1) continue;
                    if (world.setTarget != null) {
                        world.setTarget(monsterTarget.raw);
                        target = monsterTarget.raw;
                        break;
                    }
                }
            } catch (err:Dynamic) {}

            // Fallback: If still no target and not locked to a specific MMID, try native world.getMonster
            if (target == null && lockedMMID == null) {
                try {
                    if (world.getMonster != null) {
                        var monName:String = (targetName != null && targetName != "*") ? targetName.toLowerCase() : "Any";
                        var anyMon:Dynamic = world.getMonster(monName);
                        if (anyMon != null) {
                            var monHp:Int = (anyMon.dataLeaf != null && anyMon.dataLeaf.intHP != null) ? Std.int(anyMon.dataLeaf.intHP) : 1;
                            var monState:Int = (anyMon.dataLeaf != null && anyMon.dataLeaf.intState != null) ? Std.int(anyMon.dataLeaf.intState) : 1;
                            if (monHp > 0 && monState != 0) {
                                if (world.setTarget != null) {
                                    world.setTarget(anyMon);
                                    target = anyMon;
                                }
                            }
                        }
                    }
                } catch (e:Dynamic) {}
            }
        }

        if (target == null) {
            _lastTargetMMID = null;
            return;
        }

        var curTargetMMID:String = null;
        if (target.dataLeaf != null && target.dataLeaf.MonMapID != null) {
            curTargetMMID = Std.string(target.dataLeaf.MonMapID);
        } else if (target.objData != null && target.objData.MonMapID != null) {
            curTargetMMID = Std.string(target.objData.MonMapID);
        }
        if (curTargetMMID != null && curTargetMMID != _lastTargetMMID) {
            _lastTargetMMID = curTargetMMID;
            _rotationIndex = 0;
            _skillWaitStart = AqwTime.now();
        }

        if (world.approachTarget != null) {
            try { world.approachTarget(); } catch (e:Dynamic) {}
        }

        if (isSmart) {
            runAdvancedRotation(world, avatar, target);
        } else {
            runSimpleRotation(world, avatar);
        }
    }

    private static function runAdvancedRotation(world:Dynamic, avatar:Dynamic, target:Dynamic):Void {
        var className:String = (avatar.objData != null && avatar.objData.strClassName != null) ? Std.string(avatar.objData.strClassName) : "";
        var config:Dynamic = findClassConfig(className);

        if (config == null) { runSimpleRotation(world, avatar); return; }

        var modeConfig:Dynamic = null;
        if (Reflect.field(config, skillMode) != null) {
            modeConfig = Reflect.field(config, skillMode);
        } else if (Reflect.field(config, "Base") != null) {
            modeConfig = Reflect.field(config, "Base");
        } else {
            for (key in Reflect.fields(config)) { modeConfig = Reflect.field(config, key); break; }
        }

        if (modeConfig == null || modeConfig.skills == null || !Std.isOfType(modeConfig.skills, Array) || (cast modeConfig.skills : Array<Dynamic>).length == 0) {
            runSimpleRotation(world, avatar);
            return;
        }

        var advancedSkills:Array<Dynamic> = cast modeConfig.skills;
        var useMode:String = modeConfig.skillUseMode != null ? Std.string(modeConfig.skillUseMode) : "WaitForCooldown";
        var skillTimeout:Float = (modeConfig.skillTimeout != null) ? com.aqwapi.utils.AqwUtils.parseInt(modeConfig.skillTimeout, 1000) : 1000;
        if (skillTimeout <= 0) skillTimeout = 1000;

        if (useMode == "UseIfAvailable") {
            runUseIfAvailable(world, avatar, target, advancedSkills);
        } else {
            runWaitForCooldown(world, avatar, target, advancedSkills, skillTimeout);
        }
    }

    private static function runWaitForCooldown(world:Dynamic, avatar:Dynamic, target:Dynamic, skills:Array<Dynamic>, skillTimeout:Float):Void {
        if (_rotationIndex >= skills.length) _rotationIndex = 0;
        var skill:Dynamic = skills[_rotationIndex];
        var skillId:Int = com.aqwapi.utils.AqwUtils.parseInt(skill.skillId, 1);

        if (!evaluateSkillRules(skill, world, avatar, target, skillId)) {
            _rotationIndex = (_rotationIndex + 1) % skills.length;
            _skillWaitStart = AqwTime.now();
            return;
        }

        if (tryFireSkill(world, avatar, skillId)) {
            _rotationIndex = (_rotationIndex + 1) % skills.length;
            _skillWaitStart = AqwTime.now();
        } else {
            var now:Float = AqwTime.now();
            if (skillTimeout > 0 && (now - _skillWaitStart) >= skillTimeout) {
                _rotationIndex = (_rotationIndex + 1) % skills.length;
                _skillWaitStart = now;
            }
        }
    }

    private static function runUseIfAvailable(world:Dynamic, avatar:Dynamic, target:Dynamic, skills:Array<Dynamic>):Void {
        for (i in 0...skills.length) {
            var skill:Dynamic = skills[i];
            var skillId:Int = com.aqwapi.utils.AqwUtils.parseInt(skill.skillId, 1);
            if (!evaluateSkillRules(skill, world, avatar, target, skillId)) continue;
            if (tryFireSkill(world, avatar, skillId)) return;
        }
    }

    private static function evaluateSkillRules(skill:Dynamic, world:Dynamic, avatar:Dynamic, target:Dynamic, skillId:Int):Bool {
        if (skill == null || skill.rules == null) return true;
        if (!Std.isOfType(skill.rules, Array)) return true;
        var arr:Array<Dynamic> = cast skill.rules;
        if (arr.length == 0) return true;

        var isMultiAura:Bool = (skill.isMultiAura == true);
        var multiAuraOp:String = (skill.multiAuraOperator != null) ? Std.string(skill.multiAuraOperator).toUpperCase() : "AND";
        var pStats:Dynamic = getPlayerStats(world, avatar);

        if (isMultiAura) {
            var multiAuraRules:Array<Dynamic> = [];
            var otherRules:Array<Dynamic> = [];

            for (rule in arr) {
                if (rule != null && Std.string(rule.type) == "MultiAura") {
                    multiAuraRules.push(rule);
                } else {
                    otherRules.push(rule);
                }
            }

            for (rule in otherRules) {
                if (!evaluateRule(rule, world, avatar, target, pStats, skillId)) return false;
            }

            if (multiAuraRules.length > 0) {
                if (multiAuraOp == "OR") {
                    var anyPassed:Bool = false;
                    for (mRule in multiAuraRules) {
                        if (evaluateRule(mRule, world, avatar, target, pStats, skillId)) {
                            anyPassed = true;
                            break;
                        }
                    }
                    if (!anyPassed) return false;
                } else {
                    for (mRule in multiAuraRules) {
                        if (!evaluateRule(mRule, world, avatar, target, pStats, skillId)) return false;
                    }
                }
            }
            return true;
        } else {
            for (rule in arr) {
                if (!evaluateRule(rule, world, avatar, target, pStats, skillId)) return false;
            }
            return true;
        }
    }

    private static function evaluateRule(rule:Dynamic, world:Dynamic, avatar:Dynamic, target:Dynamic, pStats:Dynamic, skillId:Int):Bool {
        if (rule == null) return true;
        switch (Std.string(rule.type)) {
            case "None":
                return true;

            case "Wait":
                var wKey:String = "s" + skillId;
                var now:Float = AqwTime.now();
                var timeout:Float = rule.timeout != null ? com.aqwapi.utils.AqwUtils.parseInt(rule.timeout, 0) : 0;
                var waitVal:Null<Float> = Reflect.field(_waitUntil, wKey);
                if (waitVal == null || now >= waitVal) {
                    Reflect.setField(_waitUntil, wKey, now + timeout);
                    return true;
                }
                return false;

            case "Health":
                var hp:Float = getStat(pStats, avatar, "HP");
                var maxHp:Float = getStat(pStats, avatar, "MaxHP");
                var hpPct:Float = (rule.isPercentage != false) ? (maxHp > 0 ? (hp / maxHp * 100) : 0) : hp;
                var targetVal:Float = AqwUtils.parseFloat(rule.value, 0);
                return compare(hpPct, targetVal, Std.string(rule.comparison));

            case "Mana":
                var mp:Float = getStat(pStats, avatar, "MP");
                var maxMp:Float = getStat(pStats, avatar, "MaxMP");
                var mpPct:Float = (rule.isPercentage != false) ? (maxMp > 0 ? (mp / maxMp * 100) : 0) : mp;
                var targetVal:Float = AqwUtils.parseFloat(rule.value, 0);
                return compare(mpPct, targetVal, Std.string(rule.comparison));

            case "PartyHealth":
                return evaluatePartyHealth(rule, world, avatar);

            case "Aura", "MultiAura":
                var auraName:String = (rule.auraName != null) ? Std.string(rule.auraName) : "";
                var auraTarget:String = (rule.auraTarget != null) ? Std.string(rule.auraTarget) : "self";
                var stacks:Float = getAuraStacks(auraName, auraTarget, world, avatar, target);
                var threshold:Float = AqwUtils.parseFloat(rule.value, 0);
                var comp:String = (rule.comparison != null) ? Std.string(rule.comparison) : "greater";
                if (comp == "greater") {
                    return (threshold > 0) ? (stacks >= threshold) : (stacks > 0);
                } else {
                    return (threshold > 0) ? (stacks <= threshold) : (stacks <= 0);
                }
        }
        return true;
    }

    private static function compare(val:Float, threshold:Float, comp:String):Bool {
        return comp == "greater" ? val > threshold : val < threshold;
    }

    private static function evaluatePartyHealth(rule:Dynamic, world:Dynamic, avatar:Dynamic):Bool {
        if (world == null || world.players == null) return false;
        var threshold:Float = AqwUtils.parseFloat(rule.value, 0);
        var isPct:Bool = (rule.isPercentage != false);
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
                var maxHp:Float = (dl.intHPMax != null) ? Std.int(dl.intHPMax) : 1;
                if (hp <= 0) continue;
                var val:Float = isPct ? (maxHp > 0 ? (hp / maxHp * 100) : 0) : hp;
                if (compare(val, threshold, comp)) return true;
            }
        } catch (e:Dynamic) {}
        return false;
    }

    private static function getPlayerStats(world:Dynamic, avatar:Dynamic):Dynamic {
        try { if (world.uoTreeLeaf != null && avatar.pnm != null) return world.uoTreeLeaf(avatar.pnm); } catch (e:Dynamic) {}
        return null;
    }

    private static function getStat(pStats:Dynamic, avatar:Dynamic, stat:String):Float {
        var dl:Dynamic = avatar.dataLeaf;
        switch (stat) {
            case "HP":    return (pStats != null && pStats.intHP != null)    ? pStats.intHP    : (dl != null ? dl.intHP    : 0);
            case "MaxHP": return (pStats != null && pStats.intHPMax != null) ? pStats.intHPMax : (dl != null ? dl.intHPMax : 1);
            case "MP":    return (pStats != null && pStats.intMP != null)    ? pStats.intMP    : (dl != null ? dl.intMP    : 0);
            case "MaxMP": return (pStats != null && pStats.intMPMax != null) ? pStats.intMPMax : (dl != null ? dl.intMPMax : 1);
        }
        return 0;
    }

    private static function getAuraStacks(auraName:String, auraTarget:String, world:Dynamic, avatar:Dynamic, target:Dynamic):Float {
        if (world == null || avatar == null || auraName == "") return 0;
        var auras:Dynamic = null;
        var targetIsSelf:Bool = (auraTarget != null && auraTarget.toLowerCase() == "self");

        if (targetIsSelf) {
            try {
                if (world.uoTree != null && avatar.pnm != null) {
                    var uo = Reflect.field(world.uoTree, Std.string(avatar.pnm).toLowerCase());
                    if (uo != null && uo.auras != null) auras = uo.auras;
                }
            } catch (e:Dynamic) {}
            if (auras == null) {
                try {
                    if (world.uoTreeLeaf != null && avatar.pnm != null) {
                        var n:Dynamic = world.uoTreeLeaf(avatar.pnm);
                        if (n != null && n.auras != null) auras = n.auras;
                    }
                } catch (e:Dynamic) {}
            }
            if (auras == null && avatar.auras != null) auras = avatar.auras;
        } else {
            // Target monster
            if (target != null) {
                try {
                    var mmid:Dynamic = null;
                    if (target.dataLeaf != null && target.dataLeaf.MonMapID != null) mmid = target.dataLeaf.MonMapID;
                    else if (target.objData != null && target.objData.MonMapID != null) mmid = target.objData.MonMapID;
                    if (mmid != null && world.monTree != null) {
                        var monObj = Reflect.field(world.monTree, Std.string(mmid));
                        if (monObj != null && monObj.auras != null) auras = monObj.auras;
                    }
                } catch (e:Dynamic) {}
                if (auras == null && target.dataLeaf != null && target.dataLeaf.auras != null) {
                    auras = target.dataLeaf.auras;
                }
                if (auras == null && target.auras != null) {
                    auras = target.auras;
                }
            }
        }

        if (auras == null) return 0;
        var search:String = auraName.toLowerCase();
        var totalStacks:Float = 0;

        var processAura = function(a:Dynamic):Void {
            if (a == null) return;
            // Filter expired auras (a.e == 1 in AQW Flash)
            if (a.e == 1 || a.e == "1" || a.e == true) return;
            var name:String = (a.nam != null) ? Std.string(a.nam) : ((a.name != null) ? Std.string(a.name) : "");
            if (name != "" && name.toLowerCase() == search) {
                var val:Dynamic = a.val;
                totalStacks += (val == null) ? 1 : AqwUtils.parseFloat(val, 1);
            }
        };

        if (Std.isOfType(auras, Array)) {
            for (a in (cast auras : Array<Dynamic>)) processAura(a);
        } else {
            for (k in Reflect.fields(auras)) processAura(Reflect.field(auras, k));
        }
        return totalStacks;
    }

    private static function checkAura(auraName:String, auraTarget:String, world:Dynamic, avatar:Dynamic, target:Dynamic):Bool {
        return getAuraStacks(auraName, auraTarget, world, avatar, target) > 0;
    }

    public static function findClassConfig(className:String):Dynamic {
        if (_skillsData == null || Reflect.fields(_skillsData).length == 0) init();
        if (_skillsData == null || className == "") return null;
        var lower:String = className.toLowerCase();
        for (key in Reflect.fields(_skillsData)) {
            if (key.toLowerCase() == lower) return Reflect.field(_skillsData, key);
        }
        return null;
    }

    public static function getAvailableModes(className:String):Array<String> {
        var config:Dynamic = findClassConfig(className);
        if (config == null) return ["Base"];
        if (Std.isOfType(config, Array)) return ["Base"];
        var modes:Array<String> = [];
        for (mode in Reflect.fields(config)) modes.push(mode);
        if (modes.length == 0) return ["Base"];
        return modes;
    }

    private static function runSimpleRotation(world:Dynamic, avatar:Dynamic):Void {
        if (_customRotation == null || _customRotation.length == 0) return;

        if (customMode == "priority") {
            // PRIORITY MODE: On each tick, fire highest priority ready skill (e.g. CAv 3,4,2,1)
            // Never stalls on long cooldowns (15s Flux, 20s Bulwark) and continuously spams ready fillers
            for (idx in _customRotation) {
                if (tryFireSkill(world, avatar, idx)) return;
            }
        } else {
            // SEQUENCE MODE: Steps through combo strictly in order (e.g. DoT 3,2,1,2,4,2)
            // Advances only when each skill successfully casts; never scrambles buffs or skips
            if (_rotationIndex >= _customRotation.length) _rotationIndex = 0;
            var targetSkill:Int = _customRotation[_rotationIndex];
            if (tryFireSkill(world, avatar, targetSkill)) {
                _rotationIndex = (_rotationIndex + 1) % _customRotation.length;
                _sequenceStepStartTime = AqwTime.now();
            } else {
                var now:Float = AqwTime.now();
                if ((now - _sequenceStepStartTime) > 8000) {
                    // Failsafe: if a skill is blocked for >8s (e.g. zero-mana boss drain), advance
                    _rotationIndex = (_rotationIndex + 1) % _customRotation.length;
                    _sequenceStepStartTime = now;
                }
            }
        }
    }

    private static function tryFireSkill(world:Dynamic, avatar:Dynamic, idx:Int):Bool {
        var actObj:Dynamic = getSkillAction(idx);
        if (actObj == null || actObj.isOK == false) return false;
        var pStats:Dynamic = getPlayerStats(world, avatar);
        var dl:Dynamic     = avatar.dataLeaf;
        if (dl != null && dl.intState == 0) return false;

        var mpCost:Int = actObj.mp != null ? com.aqwapi.utils.AqwUtils.parseInt(actObj.mp, 0) : 0;
        var curMp:Int  = (pStats != null && pStats.intMP != null) ? Std.int(pStats.intMP) : (dl != null ? Std.int(dl.intMP) : 0);
        if (curMp < mpCost) return false;

        var hpCost:Int = actObj.hp != null ? com.aqwapi.utils.AqwUtils.parseInt(actObj.hp, 0) : 0;
        var curHp:Int  = (pStats != null && pStats.intHP != null) ? Std.int(pStats.intHP) : (dl != null ? Std.int(dl.intHP) : 0);
        if (hpCost > 0 && curHp <= hpCost) return false;

        var ready:Bool = (world.actionTimeCheck != null) ? (world.actionTimeCheck(actObj) == true) : true;
        if (!ready) {
            try {
                if (world.ActionResults != null && Reflect.field(world.ActionResults, actObj.ref) != null) {
                    var ar:Dynamic = Reflect.field(world.ActionResults, actObj.ref);
                    ready = (AqwTime.now() - ar.ts) >= actObj.cd;
                }
            } catch (e:Dynamic) {}
        }
        if (ready) {
            try {
                if (AqwApi.combat != null) {
                    var sc:Dynamic = AqwApi.combat;
                    if (sc.infiniteRange == true) {
                        actObj.range = 20000;
                    }
                }
            } catch (e:Dynamic) {}
            world.testAction(actObj);
            return true;
        }
        return false;
    }

    public static function tryFireSkillPublic(idx:Int):Bool {
        if (AqwApi.game == null || AqwApi.game.world == null || AqwApi.game.world.myAvatar == null) return false;
        return tryFireSkill(AqwApi.game.world, AqwApi.game.world.myAvatar, idx);
    }

    public static function canFireSkill(idx:Int):Bool {
        if (AqwApi.game == null || AqwApi.game.world == null || AqwApi.game.world.myAvatar == null) return false;
        var actObj:Dynamic = getSkillAction(idx);
        if (actObj == null || actObj.isOK == false) return false;
        var world = AqwApi.game.world;
        var avatar = world.myAvatar;
        var pStats:Dynamic = getPlayerStats(world, avatar);
        var dl:Dynamic     = avatar.dataLeaf;
        if (dl != null && dl.intState == 0) return false;

        var mpCost:Int = actObj.mp != null ? com.aqwapi.utils.AqwUtils.parseInt(actObj.mp, 0) : 0;
        var curMp:Int  = (pStats != null && pStats.intMP != null) ? Std.int(pStats.intMP) : (dl != null ? Std.int(dl.intMP) : 0);
        if (curMp < mpCost) return false;

        var hpCost:Int = actObj.hp != null ? com.aqwapi.utils.AqwUtils.parseInt(actObj.hp, 0) : 0;
        var curHp:Int  = (pStats != null && pStats.intHP != null) ? Std.int(pStats.intHP) : (dl != null ? Std.int(dl.intHP) : 0);
        if (hpCost > 0 && curHp <= hpCost) return false;

        var ready:Bool = (world.actionTimeCheck != null) ? (world.actionTimeCheck(actObj) == true) : true;
        if (!ready) {
            try {
                if (world.ActionResults != null && Reflect.field(world.ActionResults, actObj.ref) != null) {
                    var ar:Dynamic = Reflect.field(world.ActionResults, actObj.ref);
                    ready = (AqwTime.now() - ar.ts) >= actObj.cd;
                }
            } catch (e:Dynamic) {}
        }
        return ready;
    }

    private static function getSkillAction(idx:Int):Dynamic {
        var icon:Dynamic = getIcon(idx);
        if (icon != null && icon.actObj != null) return icon.actObj;
        if (AqwApi.game != null && AqwApi.game.world != null && AqwApi.game.world.actions != null && AqwApi.game.world.actions.active != null) {
            try {
                var actList:Array<Dynamic> = cast AqwApi.game.world.actions.active;
                if (idx >= 0 && idx < actList.length) {
                    var act:Dynamic = actList[idx];
                    if (act != null) return act;
                }
            } catch (e:Dynamic) {}
        }
        return null;
    }

    private static function getIcon(idx:Int):Dynamic {
        if (AqwApi.game == null || AqwApi.game.ui == null || AqwApi.game.ui.mcInterface == null || AqwApi.game.ui.mcInterface.actBar == null) return null;
        var childName:String = (idx == 0) ? "i1" : ("i" + (idx + 1));
        return AqwApi.game.ui.mcInterface.actBar.getChildByName(childName);
    }
}
