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

    public static var smartClass:String = "Current";
    public static var farmClass:String  = "Current";
    public static var farmMode:String   = "Base";
    public static var soloClass:String  = "Current";
    public static var soloMode:String   = "Base";
    public static var bossClass:String  = "Current";
    public static var bossMode:String   = "Base";
    public static var dodgeClass:String = "Current";
    public static var dodgeMode:String  = "Base";

    private static function getSettingString(key:String, def:String):String {
        try {
            var cls:Dynamic = Type.resolveClass("util.HelperSetting");
            if (cls != null && cls.getString != null) {
                var val:Dynamic = cls.getString(key, def);
                if (val != null) return Std.string(val);
            }
        } catch (e:Dynamic) {}
        return def;
    }

    private static var _timer:Timer;
    private static var _customRotation:Array<Int> = [4, 3, 2, 1];
    private static var _rotationIndex:Int = 0;
    public static var customMode:String = "priority";
    private static var _sequenceStepStartTime:Float = 0;
    private static var _skillsData:Dynamic = null;
    private static var _waitUntil:Dynamic  = {};
    private static var _lastTargetMMID:String = null;
    private static var _skillWaitStart:Float = 0;
    private static var _stepFirstFailTime:Float = -1;  // when current step first failed to fire (GCD/CD block)
    private static var _skillsLoaded:Bool = false;

    public static function init():Void {
        _skillsLoaded = true;
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
        if (isSmart) {
            var confClass = (smartClass != null && smartClass != "" && smartClass != "Current") ? smartClass : getSettingString("api_smart_class", "Current");
            if (confClass != null && confClass != "" && confClass != "Current") {
                if (AqwApi.inventory != null) {
                    AqwApi.inventory.equip(confClass);
                }
            }
            var confMode = getSettingString("api_smart_mode", "");
            if (confMode != null && confMode != "") {
                skillMode = confMode;
            } else if (skillMode == null || skillMode == "") {
                skillMode = "Base";
            }
        }
        IS_ON = true;
        _rotationIndex = 0;
        _sequenceStepStartTime = AqwTime.now();
        _waitUntil = {};
        _lastTargetMMID = null;
        _skillWaitStart = AqwTime.now();
        _stepFirstFailTime = -1;

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
            _timer = new Timer(100);
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
        _skillsLoaded = true;
        try {
            var FileClass:Dynamic = Type.resolveClass("flash.filesystem.File");
            var FileStreamClass:Dynamic = Type.resolveClass("flash.filesystem.FileStream");

            if (FileClass == null || FileStreamClass == null) {
                _skillsData = {};
                return;
            }

            var appDir:Dynamic = Reflect.getProperty(FileClass, "applicationDirectory");
            var storageDir:Dynamic = Reflect.getProperty(FileClass, "applicationStorageDirectory");
            var FileModeClass:Dynamic = Type.resolveClass("flash.filesystem.FileMode");
            var readMode:String = (FileModeClass != null) ? Reflect.getProperty(FileModeClass, "READ") : "read";

            var readFileText = function(file:Dynamic):String {
                if (file == null || !file.exists) return null;
                try {
                    var stream:Dynamic = Type.createInstance(FileStreamClass, []);
                    stream.open(file, readMode);
                    var content:String = stream.readUTFBytes(stream.bytesAvailable);
                    stream.close();
                    return content;
                } catch (e:Dynamic) {
                    return null;
                }
            };

            // 1. Load bundled skills.txt
            var rawTxt:String = null;
            if (appDir != null) {
                rawTxt = readFileText(appDir.resolvePath("assets/skills.txt"));
                if (rawTxt == null) rawTxt = readFileText(appDir.resolvePath("skills.txt"));
            }
            if (rawTxt == null && storageDir != null) {
                rawTxt = readFileText(storageDir.resolvePath("skills.txt"));
                if (rawTxt == null) rawTxt = readFileText(storageDir.resolvePath("assets/skills.txt"));
            }

            if (rawTxt != null && rawTxt.length > 0) {
                _skillsData = com.aqwapi.utils.SkillDslParser.parse(rawTxt);
                if (!silent) ApiLogger.info("Skills", "Loaded skills.txt successfully!");
            } else {
                _skillsData = {};
                if (!silent) ApiLogger.warn("Skills", "assets/skills.txt not found!");
            }

            if (_skillsData == null) _skillsData = {};

            // 2. User custom overrides: skills_custom.txt
            var checkCustom = function(dir:Dynamic):Void {
                if (dir == null) return;
                var cTxt = readFileText(dir.resolvePath("skills_custom.txt"));
                if (cTxt != null && cTxt.length > 0) {
                    var parsedCustom:Dynamic = com.aqwapi.utils.SkillDslParser.parse(cTxt);
                    if (parsedCustom != null) {
                        for (key in Reflect.fields(parsedCustom)) {
                            Reflect.setField(_skillsData, key, Reflect.field(parsedCustom, key));
                        }
                        if (!silent) ApiLogger.info("Skills", "Merged skills_custom.txt overrides!");
                    }
                }
            };

            checkCustom(storageDir);
            checkCustom(appDir);

        } catch (e:Dynamic) {
            _skillsData = {};
            var msg:String = Std.string(e);
            #if flash
            try {
                if (Std.isOfType(e, flash.errors.Error)) {
                    var err:flash.errors.Error = cast e;
                    var st:String = err.getStackTrace();
                    if (st != null && st != "") msg += " @ " + st;
                }
            } catch (_:Dynamic) {}
            #end
            if (!silent) ApiLogger.error("Skills", "skills.txt load error: " + msg);
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

        if (isSmart) {
            // Always auto-attack / approach — respects infinite range toggle
            try {
                var infRange:Bool = false;
                try {
                    // Read directly from HelperSetting to avoid any cross-package getter issues
                    var helperCls:Dynamic = Type.resolveClass("util.HelperSetting");
                    if (helperCls != null) infRange = (helperCls.getBool("api_infinite_range", false) == true);
                } catch (re:Dynamic) {
                    // Fallback: read from CombatManager field via untyped
                    if (AqwApi.combat != null) infRange = (untyped AqwApi.combat._infiniteRange == true);
                }

                if (infRange) {
                    // Infinite range ON: fire AA directly (skill 0) without range check
                    tryFireSkill(world, avatar, 0);
                } else {
                    // Normal: let world.approachTarget handle range check, walking, and AA firing
                    if (world.approachTarget != null) {
                        try { untyped world.approachTarget(); } catch (ae:Dynamic) {}
                    }
                }
            } catch (e:Dynamic) {}

            runAdvancedRotation(world, avatar, target);
        } else {
            runSimpleRotation(world, avatar);
        }
    }
    private static function runAdvancedRotation(world:Dynamic, avatar:Dynamic, target:Dynamic):Void {
        var confClass = (smartClass != null && smartClass != "" && smartClass != "Current") ? smartClass : getSettingString("api_smart_class", "Current");
        var className:String = "";
        if (confClass != null && confClass != "" && confClass != "Current") {
            className = confClass;
        } else {
            className = getCurrentClassName();
            if (className == "" && avatar.objData != null && avatar.objData.strClassName != null) {
                className = Std.string(avatar.objData.strClassName);
            }
        }
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
        var skillTimeout:Float = (modeConfig.skillTimeout != null) ? com.aqwapi.utils.AqwUtils.parseInt(modeConfig.skillTimeout, 5000) : 5000;
        // skillTimeout == 0  → wait indefinitely (only rule failure or successful fire advances the step)
        // skillTimeout >  0  → skip after N ms of being stuck (safety net)
        // For WaitForCooldown: clamp to at least 2000ms so legacy skillTimeout:100 configs
        // don't skip skills that are simply waiting on the GCD (1500ms).
        // UseIfAvailable has no timeout logic so this only applies to WaitForCooldown.
        if (useMode != "UseIfAvailable" && skillTimeout > 0 && skillTimeout < 2000) {
            skillTimeout = 2000;
        }

        if (useMode == "UseIfAvailable") {
            runUseIfAvailable(world, avatar, target, advancedSkills);
        } else {
            runWaitForCooldown(world, avatar, target, advancedSkills, skillTimeout);
        }
    }

    private static function runWaitForCooldown(world:Dynamic, avatar:Dynamic, target:Dynamic, skills:Array<Dynamic>, skillTimeout:Float):Void {
        var len:Int = skills.length;
        if (len == 0) return;
        if (_rotationIndex >= len) _rotationIndex = 0;
        var skill:Dynamic = skills[_rotationIndex];
        var skillId:Int = AqwUtils.parseInt(skill.skillId, 1);

        // ── Rule check ────────────────────────────────────────────────
        // If the skill's condition isn't met, skip immediately (no wait).
        if (!evaluateSkillRules(skill, world, avatar, target, skillId)) {
            advanceStep(len);
            return;
        }

        // ── Fire attempt ──────────────────────────────────────────────
        var result:Int = fireSkill(world, avatar, skillId);

        switch (result) {
            case SR_FIRED:
                // Skill sent — advance to next step
                advanceStep(len);

            case SR_RESOURCE:
                // MP/HP/state blocks this skill permanently until something external changes.
                // Skip immediately so the rotation can reach the next step (e.g. Corvak at 0 MP).
                advanceStep(len);

            case SR_TIMING:
                // GCD or per-skill CD not ready — wait, retry next tick (100ms).
                // Safety-net: if stuck on this step for longer than skillTimeout, force-advance.
                if (skillTimeout > 0) {
                    var now:Float = AqwTime.now();
                    if (_stepFirstFailTime < 0) _stepFirstFailTime = now;
                    if ((now - _stepFirstFailTime) >= skillTimeout) advanceStep(len);
                }
                // skillTimeout == 0 → wait indefinitely (only rules or resource-block can advance)
        }
    }

    /** Advance _rotationIndex to the next step and reset per-step state. */
    private static inline function advanceStep(len:Int):Void {
        _rotationIndex = (_rotationIndex + 1) % len;
        _stepFirstFailTime = -1;
    }

    private static function runUseIfAvailable(world:Dynamic, avatar:Dynamic, target:Dynamic, skills:Array<Dynamic>):Void {
        // Scan from index 0 every tick — fire the first skill whose rules pass AND timing is ready.
        // Resource-blocked and timing-blocked skills are both skipped (try the next one).
        for (i in 0...skills.length) {
            var skill:Dynamic = skills[i];
            var skillId:Int = AqwUtils.parseInt(skill.skillId, 1);
            if (!evaluateSkillRules(skill, world, avatar, target, skillId)) continue;
            if (fireSkill(world, avatar, skillId) == SR_FIRED) return;
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
        return comp == "greater" ? val >= threshold : val <= threshold;
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
        var dl:Dynamic = (avatar != null) ? avatar.dataLeaf : null;
        switch (stat) {
            case "HP":    return (dl != null && dl.intHP != null)    ? dl.intHP    : ((pStats != null && pStats.intHP != null) ? pStats.intHP : 0);
            case "MaxHP": return (dl != null && dl.intHPMax != null) ? dl.intHPMax : ((pStats != null && pStats.intHPMax != null) ? pStats.intHPMax : 1);
            case "MP":    return (dl != null && dl.intMP != null)    ? dl.intMP    : ((pStats != null && pStats.intMP != null) ? pStats.intMP : 0);
            case "MaxMP": return (dl != null && dl.intMPMax != null) ? dl.intMPMax : ((pStats != null && pStats.intMPMax != null) ? pStats.intMPMax : 1);
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

    public static function cleanClassName(name:String):String {
        if (name == null) return "";
        var s:String = name.toLowerCase();
        var parenStart:Int = s.indexOf("(");
        if (parenStart != -1) {
            s = s.substring(0, parenStart);
        }
        var result:StringBuf = new StringBuf();
        for (i in 0...s.length) {
            var c:Int = s.charCodeAt(i);
            if ((c >= 97 && c <= 122) || (c >= 48 && c <= 57)) {
                result.addChar(c);
            }
        }
        return result.toString();
    }

    public static function getCurrentClassName():String {
        try {
            if (AqwApi.game != null && AqwApi.game.world != null && AqwApi.game.world.myAvatar != null) {
                var av:Dynamic = AqwApi.game.world.myAvatar;
                // Primary: objData.strClassName (fastest, always set when a class is equipped)
                if (av.objData != null && av.objData.strClassName != null) {
                    var c:String = Std.string(av.objData.strClassName);
                    if (c != "" && c != "null") return c;
                }
                // Fallback: scan equipped items for class (sType=="Class" / bClass==1 / sES=="ar")
                if (av.items != null) {
                    try {
                        var items:Array<Dynamic> = cast av.items;
                        for (it in items) {
                            if (it == null) continue;
                            var equipped:Bool = (it.bEquip == 1 || it.bEquip == "1" || it.bEquip == true);
                            if (!equipped) continue;
                            var isClass:Bool = false;
                            if (it.sType != null && Std.string(it.sType).toLowerCase() == "class") isClass = true;
                            else if (it.bClass == 1 || it.bClass == true) isClass = true;
                            else if (it.sES != null && Std.string(it.sES).toLowerCase() == "ar") isClass = true;
                            if (isClass && it.sName != null) {
                                var s:String = Std.string(it.sName);
                                if (s != "" && s != "null") return s;
                            }
                        }
                    } catch (ie:Dynamic) {}
                }
            }
        } catch (e:Dynamic) {}
        return "";
    }

    public static function findClassConfig(className:String):Dynamic {
        if (!_skillsLoaded) init();
        if (_skillsData == null || className == null || className == "") return null;

        if (className.toLowerCase() == "current") {
            var cur:String = getCurrentClassName();
            if (cur != "" && cur.toLowerCase() != "current") {
                return findClassConfig(cur);
            }
            return null;
        }

        var lower:String = className.toLowerCase();
        for (key in Reflect.fields(_skillsData)) {
            if (key.toLowerCase() == lower) return Reflect.field(_skillsData, key);
        }

        var cleanTarget:String = cleanClassName(className);
        if (cleanTarget != "") {
            for (key in Reflect.fields(_skillsData)) {
                if (cleanClassName(key) == cleanTarget) {
                    return Reflect.field(_skillsData, key);
                }
            }
            for (key in Reflect.fields(_skillsData)) {
                var cleanKey:String = cleanClassName(key);
                if (cleanKey != "" && (cleanKey == cleanTarget || cleanTarget.indexOf(cleanKey) != -1 || cleanKey.indexOf(cleanTarget) != -1)) {
                    return Reflect.field(_skillsData, key);
                }
            }
        }

        return null;
    }

    public static function getKnownClasses():Array<String> {
        if (!_skillsLoaded) init();
        if (_skillsData == null) return [];
        var list:Array<String> = [];
        for (key in Reflect.fields(_skillsData)) {
            if (key != null && key != "") {
                list.push(key);
            }
        }
        list.sort(function(a, b) {
            var la:String = a.toLowerCase();
            var lb:String = b.toLowerCase();
            if (la < lb) return -1;
            if (la > lb) return 1;
            return 0;
        });
        return list;
    }

    public static function getAvailableModes(className:String):Array<String> {
        if (className == null || className == "" || className.toLowerCase() == "current") {
            var cur:String = getCurrentClassName();
            if (cur != "" && cur.toLowerCase() != "current") {
                className = cur;
            }
        }
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
            // PRIORITY: scan in order, fire the first skill that's timing-ready
            for (idx in _customRotation) {
                if (fireSkill(world, avatar, idx) == SR_FIRED) return;
            }
        } else {
            // SEQUENCE: step through in order, one skill per attempt
            if (_rotationIndex >= _customRotation.length) _rotationIndex = 0;
            var targetIdx:Int = _customRotation[_rotationIndex];
            var res:Int = fireSkill(world, avatar, targetIdx);
            if (res == SR_FIRED || res == SR_RESOURCE) {
                // Advance on fire OR resource-block (skip stuck skills, don't hang forever)
                _rotationIndex = (_rotationIndex + 1) % _customRotation.length;
                _sequenceStepStartTime = AqwTime.now();
            } else {
                // TimingBlocked — safety-net: if stuck > 8s, force advance
                var now:Float = AqwTime.now();
                if ((now - _sequenceStepStartTime) > 8000) {
                    _rotationIndex = (_rotationIndex + 1) % _customRotation.length;
                    _sequenceStepStartTime = now;
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────
    //  Skill fire result — three mutually exclusive outcomes
    // ─────────────────────────────────────────────────────────────────
    //  Fired          : skill was sent to the game → advance rotation step
    //  TimingBlocked  : GCD or per-skill CD not ready → WAIT, retry next tick
    //  ResourceBlocked: not enough MP/HP, dead, or skill not found
    //                   → SKIP this step immediately (won't resolve by waiting)
    // ─────────────────────────────────────────────────────────────────
    private static inline var SR_FIRED:Int    = 0;  // Fired
    private static inline var SR_TIMING:Int   = 1;  // TimingBlocked
    private static inline var SR_RESOURCE:Int = 2;  // ResourceBlocked

    /**
     * Try to fire skill `idx` right now.
     * Returns one of the SR_* constants.
     */
    private static function fireSkill(world:Dynamic, avatar:Dynamic, idx:Int):Int {
        // 1. Resolve the action object for this skill slot
        var actObj:Dynamic = getSkillAction(idx);
        if (actObj == null || actObj.isOK == false) return SR_RESOURCE;

        // 2. Player must be alive
        var dl:Dynamic = (avatar != null) ? avatar.dataLeaf : null;
        if (dl != null && dl.intState == 0) return SR_RESOURCE;

        // 3. Timing guard — GCD + per-skill CD (game-native, haste-scaled)
        // Checked first: if on GCD or CD, this is temporary → TimingBlocked (wait)
        var timingReady:Bool = false;
        try { timingReady = (world.actionTimeCheck(actObj) == true); } catch (e:Dynamic) {}
        if (!timingReady) return SR_TIMING;

        // 4. Crowd control guard (stun, stone, paralyze, disable)
        // If disabled, wait for CC to expire rather than skipping combo steps
        if (dl != null && dl.auras != null && world.auraCatOf != null) {
            try {
                var auras:Array<Dynamic> = cast dl.auras;
                for (aura in auras) {
                    var cat:String = world.auraCatOf(aura);
                    if (cat == "stun" || cat == "stone" || cat == "paralyze" || cat == "disable" || cat == "disabled") {
                        return SR_TIMING;
                    }
                }
            } catch (e:Dynamic) {}
        }

        // 5. Resource guard (MP cost scaled by class multiplier sta.$cmc)
        // Exactly matches World.as L8606: Math.round(actionObj.mp * cLeaf.sta["$cmc"]) > cLeaf.intMP
        var rawMp:Int = actObj.mp != null ? AqwUtils.parseInt(actObj.mp, 0) : 0;
        if (rawMp > 0 && dl != null) {
            var cmc:Float = 1.0;
            if (dl.sta != null && Reflect.field(dl.sta, "$cmc") != null) {
                cmc = AqwUtils.parseFloat(Reflect.field(dl.sta, "$cmc"), 1.0);
            }
            var effectiveMpCost:Int = Math.round(rawMp * cmc);
            var curMp:Int = (dl.intMP != null) ? Std.int(dl.intMP) : 0;
            if (curMp < effectiveMpCost) return SR_RESOURCE;
        }

        // 6. Infinite range (scripting toggle)
        try {
            var infRange:Bool = false;
            var helperCls:Dynamic = Type.resolveClass("util.HelperSetting");
            if (helperCls != null) infRange = (helperCls.getBool("api_infinite_range", false) == true);
            else if (AqwApi.combat != null) infRange = (untyped AqwApi.combat._infiniteRange == true);
            if (infRange) actObj.range = 20000;
        } catch (e:Dynamic) {}

        // 7. Fire
        world.testAction(actObj);
        return SR_FIRED;
    }

    // ── Backwards-compat wrappers used by external callers ─────────────

    /** @deprecated — use fireSkill() internally; kept for external API callers */
    private static function tryFireSkill(world:Dynamic, avatar:Dynamic, idx:Int):Bool {
        return fireSkill(world, avatar, idx) == SR_FIRED;
    }

    public static function tryFireSkillPublic(idx:Int):Bool {
        if (AqwApi.game == null || AqwApi.game.world == null || AqwApi.game.world.myAvatar == null) return false;
        return fireSkill(AqwApi.game.world, AqwApi.game.world.myAvatar, idx) == SR_FIRED;
    }

    public static function canFireSkill(idx:Int):Bool {
        if (AqwApi.game == null || AqwApi.game.world == null || AqwApi.game.world.myAvatar == null) return false;
        var res = fireSkill(AqwApi.game.world, AqwApi.game.world.myAvatar, idx);
        return res == SR_FIRED || res == SR_TIMING;
    }

    private static function getSkillAction(idx:Int):Dynamic {
        if (AqwApi.game != null && AqwApi.game.world != null) {
            var world:Dynamic = AqwApi.game.world;
            // 1. Native actionMap: exact slot-to-action mapping as used by Game.as keyboard dispatch
            try {
                if (world.actionMap != null && world.actionMap[idx] != null && world.getActionByRef != null) {
                    var act:Dynamic = world.getActionByRef(Std.string(world.actionMap[idx]));
                    if (act != null) return act;
                }
            } catch (e:Dynamic) {}
            // 2. Ref convention fallback ("aa" for 0, "a1".."a5" for 1..5)
            try {
                if (world.getActionByRef != null) {
                    var ref:String = (idx == 0) ? "aa" : ("a" + idx);
                    var act:Dynamic = world.getActionByRef(ref);
                    if (act != null) return act;
                }
            } catch (e:Dynamic) {}
            // 3. active actions array fallback
            if (world.actions != null && world.actions.active != null) {
                try {
                    var actList:Array<Dynamic> = cast world.actions.active;
                    if (idx >= 0 && idx < actList.length) {
                        var act:Dynamic = actList[idx];
                        if (act != null) return act;
                    }
                } catch (e:Dynamic) {}
            }
        }
        var icon:Dynamic = getIcon(idx);
        if (icon != null && icon.actObj != null) return icon.actObj;
        return null;
    }

    private static function getIcon(idx:Int):Dynamic {
        if (AqwApi.game == null || AqwApi.game.ui == null || AqwApi.game.ui.mcInterface == null || AqwApi.game.ui.mcInterface.actBar == null) return null;
        var childName:String = (idx == 0) ? "i1" : ("i" + (idx + 1));
        return AqwApi.game.ui.mcInterface.actBar.getChildByName(childName);
    }
}
