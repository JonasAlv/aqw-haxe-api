package com.aqwapi.managers;

import com.aqwapi.modules.CombatEngine;
import com.aqwapi.utils.ApiUtils;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.Api;
import com.aqwapi.Game;

class CombatManager {
    private var _game:Game;

    public function new(gameReference:Game) {
        _game = gameReference;
    }

    private var _infiniteRange:Bool = true;

    public function applyInfiniteRange():Void {
        if (!_infiniteRange || _game == null || _game.world == null || _game.world.actions == null) return;
        try {
            var active:Dynamic = _game.world.actions.active;
            if (active != null) {
                var len:Int = (Reflect.hasField(active, "length")) ? Std.int(active.length) : 6;
                for (i in 0...len) {
                    var act:Dynamic = active[i];
                    if (act != null) {
                        act.range = 20000;
                    }
                }
            }
        } catch (e:Dynamic) {}
    }

    public function setInfiniteRange(enabled:Bool = true):Void {
        _infiniteRange = enabled;
        applyInfiniteRange();
    }

    public function magnetize():Void {
        if (_game == null || _game.world == null || _game.world.myAvatar == null) return;
        try {
            var myAvt:Dynamic = _game.world.myAvatar;
            if (myAvt != null && myAvt.target != null && myAvt.target.pMC != null && myAvt.pMC != null) {
                myAvt.target.pMC.x = myAvt.pMC.x;
                myAvt.target.pMC.y = myAvt.pMC.y;
            }
        } catch (e:Dynamic) {}
    }

    public function attack(monsterName:String):Void {
        if (_game == null || _game.world == null || _game.world.myAvatar == null) return;
        var targetMonster:Dynamic = null;
        var sName:String = (monsterName != null) ? monsterName : "*";
        var targetName:String = sName.toLowerCase();

        // 1. Wildcard / any monster in current cell
        if (targetName == "*" || targetName == "any" || targetName == "") {
            var currentCell = (_game.world.strFrame != null) ? Std.string(_game.world.strFrame) : "";
            var living = Api.monster.getByCell(currentCell);
            for (m in living) {
                if (m != null && m.alive && m.raw != null && Reflect.field(m.raw, "pMC") != null) {
                    targetMonster = m.raw;
                    break;
                }
            }
        }

        // 2. MonMapID integer lookup (native world.getMonster(int))
        if (targetMonster == null) {
            var idInt:Int = ApiUtils.parseInt(sName, 0);
            if (idInt > 0 && _game.world.getMonster != null) {
                try {
                    var avt:Dynamic = _game.world.getMonster(idInt);
                    if (avt != null && Reflect.field(avt, "pMC") != null) {
                        targetMonster = avt;
                    }
                } catch (e:Dynamic) {}
            }
        }

        // 3. Fallback to findByMapId
        if (targetMonster == null) {
            var ent:com.aqwapi.data.EntityDTO = Api.monster.findByMapId(sName, true);
            if (ent != null && ent.raw != null && Reflect.field(ent.raw, "pMC") != null) {
                targetMonster = ent.raw;
            }
        }

        // 4. Fallback to findByName
        if (targetMonster == null) {
            var entName:com.aqwapi.data.EntityDTO = Api.monster.findByName(sName, true);
            if (entName != null && entName.raw != null && Reflect.field(entName.raw, "pMC") != null) {
                targetMonster = entName.raw;
            }
        }

        if (targetMonster != null) {
            try {
                var mc:Dynamic = Reflect.field(targetMonster, "pMC");
                if (mc != null) {
                    if (_game.world.setTarget != null) _game.world.setTarget(targetMonster);
                    applyInfiniteRange();
                }
            } catch (e:Dynamic) {}
        }
    }

    public function selectTarget(monsterName:String):Void {
        attack(monsterName);
        cancelAutoAttack();
    }

    public function approachTarget():Void {
        if (_game == null || _game.world == null) return;
        try {
            var avt:Dynamic = _game.world.myAvatar;
            if (avt != null && avt.target != null && avt.target.pMC != null) {
                if (_game.world.approachTarget != null) _game.world.approachTarget();
            }
        } catch (e:Dynamic) {}
    }

    public function cancelAutoAttack():Void {
        if (_game == null || _game.world == null) return;
        try {
            if (_game.world.cancelAutoAttack != null) {
                _game.world.cancelAutoAttack();
            }
        } catch (_:Dynamic) {}
    }

    public function cancelTarget():Void {
        if (_game == null || _game.world == null) return;
        try {
            if (_game.world.cancelTarget != null) {
                _game.world.cancelTarget();
            }
            if (_game.world.myAvatar != null) {
                _game.world.myAvatar.target = null;
            }
        } catch (e:Dynamic) {}
    }

    public function pauseCombat():Void {
        cancelAutoAttack();
        cancelTarget();
    }

    public function useSkill(index:Int):Bool {
        applyInfiniteRange();
        return CombatEngine.tryFireSkillPublic(index);
    }

    public function canUseSkill(index:Int):Bool {
        return CombatEngine.canFireSkill(index);
    }

    public function dropCombat():Void {
        cancelAutoAttack();
        cancelTarget();
        if (Api.map != null) {
            Api.map.reload();
        } else if (_game != null && _game.world != null && _game.world.moveToCell != null) {
            try {
                var currentCell:String = _game.world.strFrame != null ? Std.string(_game.world.strFrame) : "";
                var currentPad:String = _game.world.strPad != null ? Std.string(_game.world.strPad) : "";
                if (currentCell != "") {
                    if (currentPad == null || currentPad == "" || (currentCell.toLowerCase() != "enter" && currentPad == "Spawn")) {
                        currentPad = (currentCell.toLowerCase() == "enter") ? "Spawn" : "Left";
                    }
                    _game.world.moveToCell(currentCell, currentPad);
                }
            } catch (e:Dynamic) {}
        }
    }

    public function startSmart():Void { CombatEngine.start(true, false); }

    public function start(smart:Bool = true):Void {
        if (smart) startSmart();
        else CombatEngine.start(false, false);
    }

    public function stopAttack():Void {
        stopAuto();
    }

    public function stopCombat():Void {
        stopAuto();
        dropCombat();
    }

    public inline function endCombat():Void {
        stopCombat();
    }

    public function stop():Void {
        stopCombat();
    }

    public function isRunning():Bool {
        return CombatEngine.IS_ON;
    }

    public function ensure(smart:Bool = true):Void {
        if (Api.map != null && !Api.map.isLoaded) return;
        if (!isRunning()) start(smart);
    }

    private var _huntMonster:String = null;
    private var _huntTargetKills:Int = 0;
    private var _huntCurrentKills:Int = 0;
    private var _huntLastCell:String = null;
    private var _huntMonAliveMap:Map<String, Bool> = new Map();
    private var _activeHuntKey:String = null;
    private var _completedHunts:Map<String, Bool> = new Map();

    public function resetHunt():Void {
        _huntMonster = null;
        _huntTargetKills = 0;
        _huntCurrentKills = 0;
        _huntLastCell = null;
        _activeHuntKey = null;
        _completedHunts = new Map();
        _huntMonAliveMap = new Map();
    }

    public function hunt(monsterName:String, itemOrCount:Dynamic = null, quantityOrCallback:Dynamic = 1, mmidOrCallback:Dynamic = null, onComplete:Dynamic = null):Bool {
        var targetMMID:Dynamic = null;
        var isKillCount:Bool = false;
        var targetKills:Int = 0;
        var targetQuantity:Int = 1;
        var callback:Dynamic = null;

        if (Reflect.isFunction(quantityOrCallback)) {
            callback = quantityOrCallback;
            targetQuantity = 1;
        } else if (quantityOrCallback != null) {
            targetQuantity = Std.int(quantityOrCallback);
        }

        if (Reflect.isFunction(mmidOrCallback)) {
            callback = mmidOrCallback;
        } else if (mmidOrCallback != null) {
            targetMMID = mmidOrCallback;
        }

        if (Reflect.isFunction(onComplete)) {
            callback = onComplete;
        }

        var isArrayItems:Bool = false;
        var itemList:Array<{item:String, qty:Int}> = [];

        if (itemOrCount != null) {
            if (Std.isOfType(itemOrCount, Int) || Std.isOfType(itemOrCount, Float)) {
                isKillCount = true;
                targetKills = Std.int(itemOrCount);
                if (targetMMID == null && targetQuantity > 1 && !Reflect.isFunction(quantityOrCallback)) {
                    targetMMID = targetQuantity;
                }
            } else if (Std.isOfType(itemOrCount, Array)) {
                isArrayItems = true;
                var rawArr:Array<Dynamic> = cast itemOrCount;
                for (elem in rawArr) {
                    if (elem == null) continue;
                    if (Std.isOfType(elem, Array)) {
                        var sub:Array<Dynamic> = cast elem;
                        var sName:String = Std.string(sub[0]);
                        var qVal:Int = (sub.length > 1) ? ApiUtils.parseInt(sub[1], 1) : targetQuantity;
                        itemList.push({item: sName, qty: qVal});
                    } else {
                        var sElem:String = Std.string(elem);
                        if (sElem.indexOf(":") != -1) {
                            var p = sElem.split(":");
                            itemList.push({item: StringTools.trim(p[0]), qty: ApiUtils.parseInt(p[1], 1)});
                        } else {
                            itemList.push({item: sElem, qty: targetQuantity});
                        }
                    }
                }
            }
        }

        var huntKey:String = "";
        if (isKillCount) {
            huntKey = monsterName + ":k" + targetKills + (targetMMID != null ? ("#" + targetMMID) : "");
        } else if (isArrayItems) {
            var kParts:Array<String> = [];
            for (it in itemList) kParts.push(it.item + "x" + it.qty);
            huntKey = monsterName + ":items[" + kParts.join(",") + "]" + (targetMMID != null ? ("#" + targetMMID) : "");
        } else {
            huntKey = monsterName + ":i" + Std.string(itemOrCount) + "x" + targetQuantity + (targetMMID != null ? ("#" + targetMMID) : "");
        }

        // 1a. If tracking multiple items in an array
        if (isArrayItems && itemList.length > 0) {
            var allCollected:Bool = true;
            for (it in itemList) {
                if (Api.inventory == null || !Api.inventory.hasItem(it.item, it.qty)) {
                    allCollected = false;
                    break;
                }
            }
            if (allCollected) {
                if (CombatEngine.targetName != null && monsterName != null
                    && CombatEngine.targetName.toLowerCase() == monsterName.toLowerCase()) {
                    CombatEngine.targetName = null;
                }
                CombatEngine.lockedMMID = null;
                if (_activeHuntKey == huntKey) {
                    _activeHuntKey = null;
                    stopCombat();
                    if (callback != null) {
                        try { callback(); } catch (e:Dynamic) {}
                    }
                }
                return true;
            }
        }

        // 1b. If tracking an individual item drop
        if (!isKillCount && !isArrayItems && itemOrCount != null && Std.string(itemOrCount) != "") {
            var itemName:String = Std.string(itemOrCount);
            if (Api.inventory != null && Api.inventory.hasItem(itemName, targetQuantity)) {
                if (CombatEngine.targetName != null && monsterName != null
                    && CombatEngine.targetName.toLowerCase() == monsterName.toLowerCase()) {
                    CombatEngine.targetName = null;
                }
                CombatEngine.lockedMMID = null;
                if (_activeHuntKey == huntKey) {
                    _activeHuntKey = null;
                    stopCombat();
                    if (callback != null) {
                        try { callback(); } catch (e:Dynamic) {}
                    }
                }
                return true;
            }
        }

        // 2. If tracking kill count (e.g. hunt("Possessed Armor", 10))
        if (isKillCount && targetKills > 0) {
            if (_completedHunts.exists(huntKey)) {
                return true;
            }
            if (_huntMonster != huntKey || _huntTargetKills != targetKills) {
                // If another hunt is currently active and not yet finished, yield
                if (_activeHuntKey != null && _activeHuntKey != huntKey) {
                    return false;
                }
                _huntMonster = huntKey;
                _activeHuntKey = huntKey;
                _huntTargetKills = targetKills;
                _huntCurrentKills = 0;
                _huntLastCell = null;
                _huntMonAliveMap = new Map();
            }
            if (_huntCurrentKills >= _huntTargetKills) {
                if (CombatEngine.targetName != null && monsterName != null
                    && CombatEngine.targetName.toLowerCase() == monsterName.toLowerCase()) {
                    CombatEngine.targetName = null;
                }
                CombatEngine.lockedMMID = null;
                _huntMonAliveMap = new Map();
                _completedHunts.set(huntKey, true);
                if (_activeHuntKey == huntKey) _activeHuntKey = null;
                stopCombat();
                if (callback != null) {
                    try { callback(); } catch (e:Dynamic) {}
                }
                return true;
            }
        }

        // If another hunt task is currently running, don't interrupt it
        if (_activeHuntKey != null && _activeHuntKey != huntKey) {
            return false;
        }
        _activeHuntKey = huntKey;

        // 3. Safety checks: player dead or map loading
        if (Api.player != null && !Api.player.isAlive) return false;
        if (Api.map != null && !Api.map.isLoaded) return false;

        // 4. Resolve which cell the monster spawns in across the map
        var targetCell:String = "";
        if (Api.monster != null) {
            targetCell = Api.monster.getMonsterCell(monsterName, targetMMID);
        }

        // 5. Move to that cell if found and not already there
        if (targetCell != "" && Api.map != null && !Api.map.isCell(targetCell)) {
            var defaultPad = (targetCell.toLowerCase() == "enter") ? "Spawn" : "Left";
            Api.map.jump(targetCell, defaultPad);
            return false;
        }

        // If monster is not found across the map and not in current cell, wait
        if (targetCell == "" && monsterName != null && monsterName != "" && monsterName != "*") {
            var inCurCell = (Api.monster != null) ? (Api.monster.findByName(monsterName, false) != null) : false;
            if (!inCurCell) {
                return false;
            }
        }

        // 6. Lock combat engine target to this specific monster & MMID
        if (targetMMID != null) {
            CombatEngine.lockedMMID = Std.string(targetMMID);
        } else {
            CombatEngine.lockedMMID = null;
        }
        if (monsterName != null && monsterName != "" && monsterName != "*") {
            CombatEngine.targetName = monsterName;
        }

        // 7. Ensure combat engine is running
        ensure(true);

        // 8. Track individual monster kill transitions if counting kills
        if (isKillCount && targetKills > 0) {
            var cell:String = (targetCell != "") ? targetCell : (Api.player != null ? Api.player.cell : "");
            var curCellLower:String = (Api.player != null && Api.player.cell != null) ? Api.player.cell.toLowerCase() : "";
            if (_huntLastCell != curCellLower) {
                _huntLastCell = curCellLower;
                _huntMonAliveMap = new Map();
            }

            var cellMons = (Api.monster != null) ? Api.monster.getByCell(cell) : [];
            var search:String = monsterName.toLowerCase();
            var mmidStr:String = targetMMID != null ? Std.string(targetMMID) : null;
            var seenThisTick:Map<String, Bool> = new Map();

            for (m in cellMons) {
                if (m == null) continue;
                if (mmidStr != null && m.mapId != mmidStr) continue;
                if (search != "*" && m.name.toLowerCase().indexOf(search) == -1) continue;

                var key:String = (m.mapId != null && m.mapId != "") ? m.mapId : (m.name + "_" + m.id);
                var isAliveNow:Bool = (m.alive && m.hp > 0 && m.state != 0);
                seenThisTick.set(key, true);

                if (_huntMonAliveMap.exists(key)) {
                    var wasAlive:Bool = _huntMonAliveMap.get(key);
                    if (wasAlive && !isAliveNow) {
                        _huntMonAliveMap.set(key, false);
                        _huntCurrentKills++;
                        ApiLogger.info("Combat", "Hunt kill: " + monsterName + (targetMMID != null ? (" [MMID " + targetMMID + "]") : "") + " (" + _huntCurrentKills + "/" + _huntTargetKills + ")");
                        if (_huntCurrentKills >= _huntTargetKills) {
                            CombatEngine.targetName = null;
                            CombatEngine.lockedMMID = null;
                            _huntMonAliveMap = new Map();
                            _completedHunts.set(huntKey, true);
                            if (_activeHuntKey == huntKey) _activeHuntKey = null;
                            stopCombat();
                            if (callback != null) {
                                try { callback(); } catch (e:Dynamic) {}
                            }
                            return true;
                        }
                    } else if (!wasAlive && isAliveNow) {
                        _huntMonAliveMap.set(key, true);
                    }
                } else {
                    _huntMonAliveMap.set(key, isAliveNow);
                }
            }

            // Also check for monsters that were previously alive and disappeared from cell while in same room
            for (key in _huntMonAliveMap.keys()) {
                if (_huntMonAliveMap.get(key) == true && !seenThisTick.exists(key)) {
                    _huntMonAliveMap.set(key, false);
                    _huntCurrentKills++;
                    ApiLogger.info("Combat", "Hunt kill: " + monsterName + (targetMMID != null ? (" [MMID " + targetMMID + "]") : "") + " (" + _huntCurrentKills + "/" + _huntTargetKills + ")");
                    if (_huntCurrentKills >= _huntTargetKills) {
                        CombatEngine.targetName = null;
                        CombatEngine.lockedMMID = null;
                        _huntMonAliveMap = new Map();
                        _completedHunts.set(huntKey, true);
                        if (_activeHuntKey == huntKey) _activeHuntKey = null;
                        stopCombat();
                        if (callback != null) {
                            try { callback(); } catch (e:Dynamic) {}
                        }
                        return true;
                    }
                }
            }

            return false;
        }

        // 9. If no item and no kill count specified, return true once the monster in cell is dead
        if (itemOrCount == null || Std.string(itemOrCount) == "") {
            var cell:String = (targetCell != "") ? targetCell : (Api.player != null ? Api.player.cell : "");
            var alive:Bool = (Api.monster != null) ? Api.monster.isMonsterAliveInCell(cell) : false;
            return !alive;
        }

        return false;
    }

    public function kill(monsterName:String, itemOrCount:Dynamic = null, quantity:Int = 1, mmid:Dynamic = null):Bool {
        return hunt(monsterName, itemOrCount, quantity, mmid);
    }

    public function huntQuest(questId:Int, monsterName:String = null, ?callback:Dynamic):Bool {
        if (Api.quest == null) return false;
        if (!Api.quest.isLoaded(questId)) {
            Api.quest.load(questId);
            return false;
        }
        if (!Api.quest.isAccepted(questId)) {
            Api.quest.accept(questId);
            return false;
        }
        if (Api.quest.canComplete(questId)) {
            if (CombatEngine.targetName != null && monsterName != null
                && CombatEngine.targetName.toLowerCase() == monsterName.toLowerCase()) {
                CombatEngine.targetName = null;
            }
            CombatEngine.lockedMMID = null;
            stopCombat();
            if (callback != null && Reflect.isFunction(callback)) {
                try { callback(); } catch (e:Dynamic) {}
            }
            return true;
        }

        if (monsterName != null && monsterName != "") {
            hunt(monsterName);
        } else {
            ensure(true);
        }
        return false;
    }

    public function startCustom(rotation:String, mode:String = "auto"):Void {
        if (rotation != null && rotation.length > 0) {
            var rotInts:Array<Int> = [];
            if (rotation.indexOf(",") != -1) {
                var rotParts = rotation.split(",");
                for (rp in rotParts) {
                    var ri = ApiUtils.parseInt(rp, -1);
                    if (ri >= 0) rotInts.push(ri);
                }
            } else {
                for (i in 0...rotation.length) {
                    var charVal = ApiUtils.parseInt(rotation.charAt(i), -1);
                    if (charVal >= 0) rotInts.push(charVal);
                }
            }
            if (rotInts.length > 0) CombatEngine.setCustomRotation(rotInts, mode);
        }
        CombatEngine.start(false, false);
    }

    public function stopAuto():Void {
        CombatEngine.stop();
        cancelAutoAttack();
        _huntMonster = null;
        _huntTargetKills = 0;
        _huntCurrentKills = 0;
        _huntLastCell = null;
        _huntMonAliveMap = new Map();
    }

    public function equipLoadout(type:String):Bool {
        var c = ""; var m = "";
        type = type.toLowerCase();
        if (type == "farm") { c = CombatEngine.farmClass; m = CombatEngine.farmMode; }
        else if (type == "solo") { c = CombatEngine.soloClass; m = CombatEngine.soloMode; }
        else if (type == "boss") { c = CombatEngine.bossClass; m = CombatEngine.bossMode; }
        else if (type == "dodge") { c = CombatEngine.dodgeClass; m = CombatEngine.dodgeMode; }
        else return false;
        if (c != null && c != "" && c != "Current" && Api.inventory != null) Api.inventory.equip(c);
        if (m != null && m != "") CombatEngine.skillMode = m;
        return true;
    }

    public var isAutoRunning(get, never):Bool;
    @:getter(isAutoRunning)
    public function get_isAutoRunning_prop():Bool { return CombatEngine.IS_ON; }
    public function get_isAutoRunning():Bool { return CombatEngine.IS_ON; }

    public var isSmartRunning(get, never):Bool;
    @:getter(isSmartRunning)
    public function get_isSmartRunning_prop():Bool { return CombatEngine.IS_ON && CombatEngine.isSmart; }
    public function get_isSmartRunning():Bool { return CombatEngine.IS_ON && CombatEngine.isSmart; }

    public var isCustomRunning(get, never):Bool;
    @:getter(isCustomRunning)
    public function get_isCustomRunning_prop():Bool { return CombatEngine.IS_ON && !CombatEngine.isSmart; }
    public function get_isCustomRunning():Bool { return CombatEngine.IS_ON && !CombatEngine.isSmart; }

    public var mode(get, set):String;
    @:getter(mode)
    public function get_mode_prop():String { return CombatEngine.skillMode; }
    @:setter(mode)
    public function set_mode_prop(v:String):Void { CombatEngine.skillMode = v; }
    public function get_mode():String { return CombatEngine.skillMode; }
    public function set_mode(v:String):String { CombatEngine.skillMode = v; return v; }

    public var skillMode(get, set):String;
    @:getter(skillMode)
    public function get_skillMode_prop():String { return CombatEngine.skillMode; }
    @:setter(skillMode)
    public function set_skillMode_prop(v:String):Void { CombatEngine.skillMode = v; }
    public function get_skillMode():String { return CombatEngine.skillMode; }
    public function set_skillMode(v:String):String { CombatEngine.skillMode = v; return v; }

    public var smartClass(get, set):String;
    @:getter(smartClass)
    public function get_smartClass_prop():String { return CombatEngine.smartClass; }
    @:setter(smartClass)
    public function set_smartClass_prop(v:String):Void { CombatEngine.smartClass = v; }
    public function get_smartClass():String { return CombatEngine.smartClass; }
    public function set_smartClass(v:String):String { CombatEngine.smartClass = v; return v; }

    public var farmClass(get, set):String;
    @:getter(farmClass)
    public function get_farmClass_prop():String { return CombatEngine.farmClass; }
    @:setter(farmClass)
    public function set_farmClass_prop(v:String):Void { CombatEngine.farmClass = v; }
    public function get_farmClass():String { return CombatEngine.farmClass; }
    public function set_farmClass(v:String):String { CombatEngine.farmClass = v; return v; }

    public var farmMode(get, set):String;
    @:getter(farmMode)
    public function get_farmMode_prop():String { return CombatEngine.farmMode; }
    @:setter(farmMode)
    public function set_farmMode_prop(v:String):Void { CombatEngine.farmMode = v; }
    public function get_farmMode():String { return CombatEngine.farmMode; }
    public function set_farmMode(v:String):String { CombatEngine.farmMode = v; return v; }

    public var soloClass(get, set):String;
    @:getter(soloClass)
    public function get_soloClass_prop():String { return CombatEngine.soloClass; }
    @:setter(soloClass)
    public function set_soloClass_prop(v:String):Void { CombatEngine.soloClass = v; }
    public function get_soloClass():String { return CombatEngine.soloClass; }
    public function set_soloClass(v:String):String { CombatEngine.soloClass = v; return v; }

    public var soloMode(get, set):String;
    @:getter(soloMode)
    public function get_soloMode_prop():String { return CombatEngine.soloMode; }
    @:setter(soloMode)
    public function set_soloMode_prop(v:String):Void { CombatEngine.soloMode = v; }
    public function get_soloMode():String { return CombatEngine.soloMode; }
    public function set_soloMode(v:String):String { CombatEngine.soloMode = v; return v; }

    public var bossClass(get, set):String;
    @:getter(bossClass)
    public function get_bossClass_prop():String { return CombatEngine.bossClass; }
    @:setter(bossClass)
    public function set_bossClass_prop(v:String):Void { CombatEngine.bossClass = v; }
    public function get_bossClass():String { return CombatEngine.bossClass; }
    public function set_bossClass(v:String):String { CombatEngine.bossClass = v; return v; }

    public var bossMode(get, set):String;
    @:getter(bossMode)
    public function get_bossMode_prop():String { return CombatEngine.bossMode; }
    @:setter(bossMode)
    public function set_bossMode_prop(v:String):Void { CombatEngine.bossMode = v; }
    public function get_bossMode():String { return CombatEngine.bossMode; }
    public function set_bossMode(v:String):String { CombatEngine.bossMode = v; return v; }

    public var dodgeClass(get, set):String;
    @:getter(dodgeClass)
    public function get_dodgeClass_prop():String { return CombatEngine.dodgeClass; }
    @:setter(dodgeClass)
    public function set_dodgeClass_prop(v:String):Void { CombatEngine.dodgeClass = v; }
    public function get_dodgeClass():String { return CombatEngine.dodgeClass; }
    public function set_dodgeClass(v:String):String { CombatEngine.dodgeClass = v; return v; }

    public var dodgeMode(get, set):String;
    @:getter(dodgeMode)
    public function get_dodgeMode_prop():String { return CombatEngine.dodgeMode; }
    @:setter(dodgeMode)
    public function set_dodgeMode_prop(v:String):Void { CombatEngine.dodgeMode = v; }
    public function get_dodgeMode():String { return CombatEngine.dodgeMode; }
    public function set_dodgeMode(v:String):String { CombatEngine.dodgeMode = v; return v; }

    public var infiniteRange(get, set):Bool;
    @:getter(infiniteRange)
    public function get_infiniteRange_prop():Bool { return _infiniteRange; }
    @:setter(infiniteRange)
    public function set_infiniteRange_prop(v:Bool):Void { setInfiniteRange(v); }
    public function get_infiniteRange():Bool { return _infiniteRange; }
    public function set_infiniteRange(v:Bool):Bool { setInfiniteRange(v); return v; }


}
