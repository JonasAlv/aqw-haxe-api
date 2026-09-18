package com.aqwapi.modules;

import com.aqwapi.events.ApiEvent;
import com.aqwapi.AqwApi;
import com.aqwapi.data.EntityDTO;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwTime;
import flash.events.TimerEvent;
import flash.utils.Timer;

class CombatManager {
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
    private static var _customRotation:Array<Int> = [5, 4, 3, 2, 1];
    private static var _rotationIndex:Int = 0;
    private static var _skillsData:Dynamic = null;
    private static var _waitUntil:Dynamic  = {};

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
        _waitUntil = {};

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
        AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.COMBAT_TOGGLED, "Combat Stopped"));
        ApiLogger.info("Combat", "Combat Stopped");
    }

    public static function setCustomRotation(rotation:Array<Int>):Void {
        _customRotation = rotation;
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
            var bundledFile:Dynamic = appDir.resolvePath("assets/AdvancedSkills.json");

            if (bundledFile.exists) {
                var stream:Dynamic = Type.createInstance(FileStreamClass, []);
                stream.open(bundledFile, "read");
                var raw:String = stream.readUTFBytes(stream.bytesAvailable);
                stream.close();
                _skillsData = haxe.Json.parse(raw);
            } else {
                _skillsData = {};
                if (!silent) ApiLogger.warn("Skills", "assets/AdvancedSkills.json missing!");
            }

            var customFile:Dynamic = appDir.resolvePath("skills_custom.json");
            if (customFile.exists) {
                try {
                    var cStream:Dynamic = Type.createInstance(FileStreamClass, []);
                    cStream.open(customFile, "read");
                    var cRaw:String = cStream.readUTFBytes(cStream.bytesAvailable);
                    cStream.close();
                    var customData:Dynamic = haxe.Json.parse(cRaw);
                    for (key in Reflect.fields(customData)) {
                        Reflect.setField(_skillsData, key, Reflect.field(customData, key));
                    }
                    if (!silent) ApiLogger.info("Skills", "Merged skills_custom.json override!");
                } catch (ce:Dynamic) {}
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
                var currentMonsters:Array<EntityDTO> = AqwApi.monsters.getByCell(Std.string(world.strFrame));
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

        if (target == null) return;

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

        if (useMode == "UseIfAvailable") {
            runUseIfAvailable(world, avatar, target, advancedSkills);
        } else {
            runWaitForCooldown(world, avatar, target, advancedSkills);
        }
    }

    private static function runWaitForCooldown(world:Dynamic, avatar:Dynamic, target:Dynamic, skills:Array<Dynamic>):Void {
        if (_rotationIndex >= skills.length) _rotationIndex = 0;
        var skill:Dynamic = skills[_rotationIndex];
        var skillId:Int = Std.int(skill.skillId) + 1;
        if (!evaluateRules(skill.rules, world, avatar, target, skillId)) {
            _rotationIndex = (_rotationIndex + 1) % skills.length;
            return;
        }
        if (tryFireSkill(world, avatar, skillId)) {
            _rotationIndex = (_rotationIndex + 1) % skills.length;
        }
    }

    private static function runUseIfAvailable(world:Dynamic, avatar:Dynamic, target:Dynamic, skills:Array<Dynamic>):Void {
        for (i in 0...skills.length) {
            var skill:Dynamic = skills[i];
            var skillId:Int = Std.int(skill.skillId) + 1;
            if (!evaluateRules(skill.rules, world, avatar, target, skillId)) continue;
            if (tryFireSkill(world, avatar, skillId)) return;
        }
    }

    private static function evaluateRules(rules:Dynamic, world:Dynamic, avatar:Dynamic, target:Dynamic, skillId:Int):Bool {
        if (rules == null) return true;
        if (!Std.isOfType(rules, Array)) return true;
        var arr:Array<Dynamic> = cast rules;
        if (arr.length == 0) return true;
        var pStats:Dynamic = getPlayerStats(world, avatar);
        for (rule in arr) {
            if (!evaluateRule(rule, world, avatar, target, pStats, skillId)) return false;
        }
        return true;
    }

    private static function evaluateRule(rule:Dynamic, world:Dynamic, avatar:Dynamic, target:Dynamic, pStats:Dynamic, skillId:Int):Bool {
        switch (Std.string(rule.type)) {
            case "None": return true;
            case "Wait":
                var wKey:String = "s" + skillId;
                var now:Float = AqwTime.now();
                var timeout:Float = rule.timeout != null ? rule.timeout : 0;
                var waitVal:Null<Float> = Reflect.field(_waitUntil, wKey);
                if (waitVal == null || now >= waitVal) {
                    Reflect.setField(_waitUntil, wKey, now + timeout);
                    return true;
                }
                return false;
            case "Health":
                var hp:Float = getStat(pStats, avatar, "HP");
                var maxHp:Float = getStat(pStats, avatar, "MaxHP");
                var hpPct:Float = (rule.isPercentage == true) ? (maxHp > 0 ? hp / maxHp * 100 : 0) : hp;
                return compare(hpPct, rule.value, Std.string(rule.comparison));
            case "Mana":
                var mp:Float = getStat(pStats, avatar, "MP");
                var maxMp:Float = getStat(pStats, avatar, "MaxMP");
                var mpPct:Float = (rule.isPercentage == true) ? (maxMp > 0 ? mp / maxMp * 100 : 0) : mp;
                return compare(mpPct, rule.value, Std.string(rule.comparison));
            case "Aura", "MultiAura":
                var hasAura:Bool = checkAura(Std.string(rule.auraName), Std.string(rule.auraTarget), world, avatar, target);
                return Std.string(rule.comparison) == "greater" ? hasAura : !hasAura;
        }
        return true;
    }

    private static function compare(val:Float, threshold:Float, comp:String):Bool {
        return comp == "greater" ? val > threshold : val < threshold;
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

    private static function checkAura(auraName:String, auraTarget:String, world:Dynamic, avatar:Dynamic, target:Dynamic):Bool {
        var auras:Dynamic = null;
        if (auraTarget == "self") {
            try { if (world.uoTreeLeaf != null && avatar.pnm != null) { var n:Dynamic = world.uoTreeLeaf(avatar.pnm); if (n != null && n.auras != null) auras = n.auras; } } catch (e:Dynamic) {}
            if (auras == null && avatar.auras != null) auras = avatar.auras;
        } else {
            if (target != null && target.dataLeaf != null && target.dataLeaf.auras != null) auras = target.dataLeaf.auras;
        }
        if (auras == null) return false;
        var search:String = auraName.toLowerCase();
        if (Std.isOfType(auras, Array)) {
            for (a in (cast auras : Array<Dynamic>)) {
                if (a != null && a.name != null && Std.string(a.name).toLowerCase() == search) return true;
                if (a != null && a.nam != null  && Std.string(a.nam).toLowerCase()  == search) return true;
            }
        } else {
            for (k in Reflect.fields(auras)) {
                var av:Dynamic = Reflect.field(auras, k);
                if (av != null && av.name != null && Std.string(av.name).toLowerCase() == search) return true;
                if (av != null && av.nam  != null && Std.string(av.nam).toLowerCase()  == search) return true;
            }
        }
        return false;
    }

    public static function findClassConfig(className:String):Dynamic {
        if (_skillsData == null) init();
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
        var valid:Array<Int> = [];
        for (idx in _customRotation) {
            var icon:Dynamic = getIcon(idx);
            if (icon != null && icon.actObj != null && icon.actObj.isOK != false) valid.push(idx);
        }
        if (valid.length == 0) return;
        if (_rotationIndex >= valid.length) _rotationIndex = 0;
        if (tryFireSkill(world, avatar, valid[_rotationIndex])) _rotationIndex = (_rotationIndex + 1) % valid.length;
    }

    private static function tryFireSkill(world:Dynamic, avatar:Dynamic, idx:Int):Bool {
        var icon:Dynamic = getIcon(idx);
        if (icon == null || icon.actObj == null || icon.actObj.isOK == false) return false;
        var pStats:Dynamic = getPlayerStats(world, avatar);
        var dl:Dynamic     = avatar.dataLeaf;
        if (dl != null && dl.intState == 0) return false;

        var mpRaw = Std.parseInt(Std.string(icon.actObj.mp));
        var mpCost:Int = icon.actObj.mp != null ? (mpRaw == null ? 0 : mpRaw) : 0;
        var curMp:Int  = (pStats != null && pStats.intMP != null) ? Std.int(pStats.intMP) : (dl != null ? Std.int(dl.intMP) : 0);
        if (curMp < mpCost) return false;

        var hpRaw = Std.parseInt(Std.string(icon.actObj.hp));
        var hpCost:Int = icon.actObj.hp != null ? (hpRaw == null ? 0 : hpRaw) : 0;
        var curHp:Int  = (pStats != null && pStats.intHP != null) ? Std.int(pStats.intHP) : (dl != null ? Std.int(dl.intHP) : 0);
        if (hpCost > 0 && curHp <= hpCost) return false;

        var ready:Bool = (world.actionTimeCheck != null) ? (world.actionTimeCheck(icon.actObj) == true) : true;
        if (!ready) {
            try {
                if (world.ActionResults != null && Reflect.field(world.ActionResults, icon.actObj.ref) != null) {
                    var ar:Dynamic = Reflect.field(world.ActionResults, icon.actObj.ref);
                    ready = (AqwTime.now() - ar.ts) >= icon.actObj.cd;
                }
            } catch (e:Dynamic) {}
        }
        if (ready) { world.testAction(icon.actObj); return true; }
        return false;
    }

    private static function getIcon(idx:Int):Dynamic {
        if (AqwApi.game == null || AqwApi.game.ui == null || AqwApi.game.ui.mcInterface == null || AqwApi.game.ui.mcInterface.actBar == null) return null;
        return AqwApi.game.ui.mcInterface.actBar.getChildByName("i" + idx);
    }
}
