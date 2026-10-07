package com.aqwapi.managers;

import com.aqwapi.modules.CombatEngine;
import com.aqwapi.utils.ApiUtils;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.Api;
import com.aqwapi.Game;

class CombatManager {
    private var _game:Game;
    public var taunt(default, null):com.aqwapi.combat.TauntCoordinator;

    // Cell Farm / Provoke All
    public var autoProvoke(default, set):Bool = false;
    private var _lastProvokeTime:Float = 0;

    // Potion / Consumable Auto-Use
    public var autoPotionEnabled:Bool = false;
    public var autoPotionName:String = null;
    public var autoPotionIntervalMs:Float = 15000;
    public var autoPotionHpThreshold:Float = 0;
    private var _lastPotionUseTime:Float = 0;

    private var _infiniteRange:Bool = true;
    public var lastCombatExitTime:Float = 0;

    public function new(gameReference:Game) {
        _game = gameReference;
        taunt = new com.aqwapi.combat.TauntCoordinator(_game);
    }

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

    public function magnetizeAll(targets:Dynamic = null):Void {
        if (Api.monster != null) Api.monster.magnetizeAll(targets);
    }

    public function aggro(monster:Dynamic = null):Void {
        if (Api.monster != null) Api.monster.aggro(monster);
    }

    public function aggroMonsters(targets:Dynamic = null):Void {
        if (Api.monster != null) Api.monster.aggroMonsters(targets);
    }

    public function pullMonsters(targets:Dynamic = null):Void {
        if (Api.monster != null) Api.monster.pullMonsters(targets);
    }

    public inline function pull(targets:Dynamic = null):Void {
        pullMonsters(targets);
    }

    public function set_autoProvoke(v:Bool):Bool {
        autoProvoke = v;
        CombatEngine.aggroAll = v;
        CombatEngine.pullAll = v;
        if (v) {
            aggroMonsters("*");
            magnetizeAll("*");
        }
        return autoProvoke;
    }

    public function provokeAll(enabled:Bool = true):Void {
        set_autoProvoke(enabled);
    }

    public function farmCell(cellName:String = null):Void {
        if (cellName != null && cellName != "" && Api.map != null) {
            if (!Api.map.isCell(cellName)) {
                Api.map.jump(cellName);
            }
        }
        provokeAll(true);
        CombatEngine.targetName = "*";
        startSmart();
    }

    public function usePotion(potionName:String):Bool {
        if (potionName == null || potionName == "") return false;
        var now = com.aqwapi.utils.ApiTime.now();
        if (now - _lastPotionUseTime < 1500) return false;

        if (Api.inventory != null) {
            if (!Api.inventory.hasItem(potionName)) {
                ApiLogger.warn("Combat", "usePotion: Item '" + potionName + "' not found in inventory.");
                return false;
            }
            Api.inventory.equipUsable(potionName);
        }

        var success = false;
        try {
            success = CombatEngine.tryFireSkillPublic(5);
        } catch (_:Dynamic) {}

        if (success) {
            _lastPotionUseTime = now;
            ApiLogger.info("Combat", "Used potion/scroll: " + potionName);
        }
        return success;
    }

    public function autoPotion(potionName:String, intervalMs:Float = 15000, hpThreshold:Float = 0):Void {
        autoPotionEnabled = true;
        autoPotionName = potionName;
        autoPotionIntervalMs = intervalMs > 2000 ? intervalMs : 15000;
        autoPotionHpThreshold = hpThreshold;
        if (potionName != null && potionName != "" && Api.inventory != null) {
            Api.inventory.equipUsable(potionName);
        }
        ApiLogger.info("Combat", "AutoPotion enabled for '" + potionName + "' (Interval: " + autoPotionIntervalMs + "ms, HP%: " + autoPotionHpThreshold + ")");
    }

    public function stopAutoPotion():Void {
        autoPotionEnabled = false;
        autoPotionName = null;
        ApiLogger.info("Combat", "AutoPotion disabled.");
    }

    public function checkAutoPotion(now:Float):Bool {
        if (!autoPotionEnabled || autoPotionName == null || autoPotionName == "") return false;
        if (now - _lastPotionUseTime < 2500) return false;

        var shouldFire = false;
        if (autoPotionHpThreshold > 0) {
            var curHp = (Api.player != null) ? Api.player.hpPercent : 100.0;
            if (curHp <= autoPotionHpThreshold) {
                shouldFire = true;
            }
        } else {
            if (now - _lastPotionUseTime >= autoPotionIntervalMs) {
                shouldFire = true;
            }
        }

        if (shouldFire) {
            return usePotion(autoPotionName);
        }
        return false;
    }

    public function checkAutoProvoke(now:Float):Void {
        if (!autoProvoke) return;
        if (now - _lastProvokeTime < 800) return;
        _lastProvokeTime = now;
        aggroMonsters("*");
        magnetizeAll("*");
    }

    public inline function enableTaunt(presetOrBoss:String, ?announceParty:Bool):Void {
        if (taunt != null) taunt.configurePreset(presetOrBoss, announceParty);
    }

    public inline function disableTaunt():Void {
        if (taunt != null) taunt.disable();
    }

    public function attack(monsterName:String):Void {
        if (_game == null || _game.world == null || _game.world.myAvatar == null) return;
        var targetMonster:Dynamic = null;
        var sName:String = (monsterName != null) ? monsterName : "*";
        var targetName:String = sName.toLowerCase();

        var currentCell = (_game.world.strFrame != null) ? Std.string(_game.world.strFrame) : "";

        // 1. Wildcard / any monster in current cell (prioritizing lowest HP)
        if (targetName == "*" || targetName == "any" || targetName == "") {
            var best = Api.monster.getBestMonsterTargetInCell(currentCell, "*");
            if (best != null && best.raw != null && Reflect.field(best.raw, "pMC") != null) {
                targetMonster = best.raw;
            }
        }

        // 2. Matching monster by name or ID in current cell (prioritizing lowest HP)
        if (targetMonster == null && currentCell != "") {
            var best = Api.monster.getBestMonsterTargetInCell(currentCell, sName);
            if (best != null && best.raw != null && Reflect.field(best.raw, "pMC") != null) {
                targetMonster = best.raw;
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
        lastCombatExitTime = com.aqwapi.utils.ApiTime.now();
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

    public function startSmartStandalone(confClass:String = "Current", confMode:String = "Auto"):Void {
        resetHunt();
        CombatEngine.targetName = null;
        CombatEngine.lockedMMID = null;

        var needsEquip:Bool = false;
        if (confClass != null && confClass != "" && confClass.toLowerCase() != "current") {
            var curClass = SkillManager.getCurrentClassName();
            if (curClass == "" || curClass.toLowerCase() != confClass.toLowerCase()) {
                needsEquip = true;
            }
        }

        CombatEngine.smartClass = confClass;
        var effClass = (confClass != null && confClass != "" && confClass.toLowerCase() != "current") ? confClass : SkillManager.getCurrentClassName();
        if (effClass != "") {
            this.mode = SkillManager.resolveActiveModeName(effClass, confMode);
            CombatEngine.skillMode = this.mode;
        } else {
            this.mode = confMode;
            CombatEngine.skillMode = confMode;
        }

        if (needsEquip && Api.inventory != null) {
            com.aqwapi.utils.ApiLogger.info("Combat", "Equipping '" + confClass + "' before starting Smart Combat...");
            Api.inventory.equipWait(confClass, function() {
                com.aqwapi.utils.ApiTime.delay(600, function() {
                    startSmart();
                });
            });
        } else {
            startSmart();
        }
    }

    public function startAuto():Void {
        if (CombatEngine.customRotation == null || CombatEngine.customRotation.length == 0) {
            CombatEngine.setCustomRotation([0, 1, 2, 3, 4], "priority");
        }
        CombatEngine.start(false, false);
    }

    public function start(smart:Bool = true):Void {
        if (smart) startSmart();
        else startAuto();
    }

    public function stopAttack():Void {
        stopAuto();
    }

    public function stopCombat():Void {
        stopAuto();
        dropCombat();
        lastCombatExitTime = com.aqwapi.utils.ApiTime.now();
        resetHunt();
        CombatEngine.targetName = null;
        CombatEngine.lockedMMID = null;
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

    public var counterHandler(get, set):Bool;
    @:getter(counterHandler)
    public function get_counterHandler_prop():Bool { return CombatEngine.counterHandler; }
    @:setter(counterHandler)
    public function set_counterHandler_prop(v:Bool):Void { CombatEngine.counterHandler = v; }
    public function get_counterHandler():Bool { return CombatEngine.counterHandler; }
    public function set_counterHandler(v:Bool):Bool { CombatEngine.counterHandler = v; return v; }

    public function enableCounterHandler(enable:Bool = true):Void {
        CombatEngine.counterHandler = enable;
    }

    public function pauseOnAuras(auras:Dynamic):Void {
        if (CombatEngine.globalStopOnTargetAuras == null) CombatEngine.globalStopOnTargetAuras = [];
        if (Std.isOfType(auras, Array)) {
            for (a in (cast auras : Array<Dynamic>)) {
                if (a != null && Std.string(a) != "") {
                    var s = StringTools.trim(Std.string(a));
                    if (CombatEngine.globalStopOnTargetAuras.indexOf(s) == -1) {
                        CombatEngine.globalStopOnTargetAuras.push(s);
                    }
                }
            }
        } else if (auras != null) {
            var parts = Std.string(auras).split(",");
            for (p in parts) {
                var s = StringTools.trim(p);
                if (s != "" && CombatEngine.globalStopOnTargetAuras.indexOf(s) == -1) {
                    CombatEngine.globalStopOnTargetAuras.push(s);
                }
            }
        }
    }

    public function clearPauseAuras():Void {
        CombatEngine.globalStopOnTargetAuras = [];
    }

    public var isPausedByAura(get, never):Bool;
    @:getter(isPausedByAura)
    public function get_isPausedByAura_prop():Bool { return CombatEngine.isPausedByAura; }
    public function get_isPausedByAura():Bool { return CombatEngine.isPausedByAura; }

    private var _globalAggroAll:Bool = false;
    private var _globalPullAll:Bool = false;

    public var aggroAll(get, set):Bool;
    @:getter(aggroAll)
    public function get_aggroAll_prop():Bool { return CombatEngine.aggroAll; }
    @:setter(aggroAll)
    public function set_aggroAll_prop(v:Bool):Void { _globalAggroAll = v; CombatEngine.aggroAll = v; }
    public function get_aggroAll():Bool { return CombatEngine.aggroAll; }
    public function set_aggroAll(v:Bool):Bool { _globalAggroAll = v; CombatEngine.aggroAll = v; return v; }

    public function enableAggro(enable:Bool = true):Void {
        _globalAggroAll = enable;
        CombatEngine.aggroAll = enable;
    }

    public var pullAll(get, set):Bool;
    @:getter(pullAll)
    public function get_pullAll_prop():Bool { return CombatEngine.pullAll; }
    @:setter(pullAll)
    public function set_pullAll_prop(v:Bool):Void { _globalPullAll = v; CombatEngine.pullAll = v; }
    public function get_pullAll():Bool { return CombatEngine.pullAll; }
    public function set_pullAll(v:Bool):Bool { _globalPullAll = v; CombatEngine.pullAll = v; return v; }

    public function enablePull(enable:Bool = true):Void {
        _globalPullAll = enable;
        CombatEngine.pullAll = enable;
    }

    public function setTargetPriority(targets:Dynamic):Void {
        CombatEngine.priorityTargets = [];
        if (Std.isOfType(targets, Array)) {
            for (t in (cast targets : Array<Dynamic>)) {
                if (t != null && Std.string(t) != "") {
                    CombatEngine.priorityTargets.push(StringTools.trim(Std.string(t)));
                }
            }
        } else if (targets != null && Std.string(targets) != "") {
            CombatEngine.priorityTargets.push(StringTools.trim(Std.string(targets)));
        }
    }

    public function setHuntPriority(priority:String):Void {
        var p = (priority != null) ? priority.toLowerCase() : "lowest_hp";
        if (p == "highest" || p == "highest_hp" || p == "max_hp") CombatEngine.huntPriority = "highest_hp";
        else if (p == "closest" || p == "distance" || p == "near") CombatEngine.huntPriority = "closest";
        else CombatEngine.huntPriority = "lowest_hp";
    }

    private function _applyHuntOptions(opts:Dynamic, ?primaryMonster:String):Void {
        if (opts == null || !Reflect.isObject(opts) || Std.isOfType(opts, Array) || Std.isOfType(opts, String) || Std.isOfType(opts, Int) || Std.isOfType(opts, Float)) return;

        var pri:Dynamic = null;
        if (Reflect.hasField(opts, "priority")) pri = Reflect.field(opts, "priority");
        else if (Reflect.hasField(opts, "minions")) pri = Reflect.field(opts, "minions");
        else if (Reflect.hasField(opts, "secondary")) pri = Reflect.field(opts, "secondary");

        if (pri != null) {
            setTargetPriority(pri);
            if (primaryMonster != null && primaryMonster != "" && primaryMonster != "*") {
                if (CombatEngine.priorityTargets.indexOf(primaryMonster) == -1) {
                    CombatEngine.priorityTargets.push(primaryMonster);
                }
            }
        }

        if (Reflect.hasField(opts, "huntPriority")) {
            setHuntPriority(Std.string(Reflect.field(opts, "huntPriority")));
        } else if (Reflect.hasField(opts, "strategy")) {
            setHuntPriority(Std.string(Reflect.field(opts, "strategy")));
        }

        if (Reflect.hasField(opts, "counterHandler")) {
            enableCounterHandler(Reflect.field(opts, "counterHandler") == true);
        }

        if (Reflect.hasField(opts, "pauseOnAuras")) {
            pauseOnAuras(Reflect.field(opts, "pauseOnAuras"));
        } else if (Reflect.hasField(opts, "stopOnAuras")) {
            pauseOnAuras(Reflect.field(opts, "stopOnAuras"));
        }

        if (Reflect.hasField(opts, "aggro")) {
            CombatEngine.aggroAll = (Reflect.field(opts, "aggro") == true);
        } else if (Reflect.hasField(opts, "aggroAll")) {
            CombatEngine.aggroAll = (Reflect.field(opts, "aggroAll") == true);
        } else if (Reflect.hasField(opts, "aggroMonsters")) {
            var aggroVal:Dynamic = Reflect.field(opts, "aggroMonsters");
            if (aggroVal != null) {
                if (Std.isOfType(aggroVal, Bool)) {
                    CombatEngine.aggroAll = (aggroVal == true);
                } else if (Std.isOfType(aggroVal, Array)) {
                    CombatEngine.aggroTargets = [];
                    for (a in (cast aggroVal : Array<Dynamic>)) {
                        if (a != null && Std.string(a) != "") CombatEngine.aggroTargets.push(Std.string(a));
                    }
                } else {
                    var sVal:String = Std.string(aggroVal);
                    if (sVal != "") CombatEngine.aggroTargets = [sVal];
                }
            }
        }

        if (Reflect.hasField(opts, "pull")) {
            CombatEngine.pullAll = (Reflect.field(opts, "pull") == true);
        } else if (Reflect.hasField(opts, "pullAll")) {
            CombatEngine.pullAll = (Reflect.field(opts, "pullAll") == true);
        } else if (Reflect.hasField(opts, "magnetizeAll")) {
            CombatEngine.pullAll = (Reflect.field(opts, "magnetizeAll") == true);
        }

        if (Reflect.hasField(opts, "temp")) {
            _huntIsTemp = (Reflect.field(opts, "temp") == true);
        } else if (Reflect.hasField(opts, "isTemp")) {
            _huntIsTemp = (Reflect.field(opts, "isTemp") == true);
        }
    }

    private var _huntMonster:String = null;
    private var _huntTargetKills:Int = 0;
    private var _huntCurrentKills:Int = 0;
    private var _huntLastCell:String = null;
    private var _huntMonAliveMap:Map<String, Bool> = new Map();
    private var _activeHuntKey:String = null;
    private var _completedHunts:Map<String, Bool> = new Map();
    private var _huntIsTemp:Bool = false;

    public function resetHunt():Void {
        _huntMonster = null;
        _huntTargetKills = 0;
        _huntCurrentKills = 0;
        _huntLastCell = null;
        _huntIsTemp = false;
        _activeHuntKey = null;
        _completedHunts = new Map();
        _huntMonAliveMap = new Map();
        CombatEngine.targetName = null;
        CombatEngine.lockedMMID = null;
        CombatEngine.priorityTargets = [];
        CombatEngine.huntPriority = "lowest_hp";
        if (!_globalAggroAll) CombatEngine.aggroAll = false;
        if (!_globalPullAll) CombatEngine.pullAll = false;
        CombatEngine.aggroTargets = [];
    }

    public function hunt(monster:Dynamic, itemOrCount:Dynamic = null, quantityOrCallback:Dynamic = null, mmidOrCallback:Dynamic = null, onComplete:Dynamic = null):Bool {
        var monsterName:String = "*";
        var priorityList:Array<String> = [];

        if (monster != null) {
            if (Std.isOfType(monster, Array)) {
                var mArr:Array<Dynamic> = cast monster;
                for (elem in mArr) {
                    if (elem != null && Std.string(elem) != "") {
                        priorityList.push(StringTools.trim(Std.string(elem)));
                    }
                }
                if (priorityList.length > 0) {
                    monsterName = priorityList[priorityList.length - 1];
                }
            } else {
                monsterName = Std.string(monster);
                priorityList.push(monsterName);
            }
        }

        var targetMMID:Dynamic = null;
        var isKillCount:Bool = false;
        var targetKills:Int = 0;
        var targetQuantity:Int = 1;
        var callback:Dynamic = null;

        _applyHuntOptions(quantityOrCallback, monsterName);
        _applyHuntOptions(mmidOrCallback, monsterName);
        _applyHuntOptions(onComplete, monsterName);

        if (Reflect.isFunction(quantityOrCallback)) {
            callback = quantityOrCallback;
            targetQuantity = 1;
        } else if (quantityOrCallback != null && (Std.isOfType(quantityOrCallback, Int) || Std.isOfType(quantityOrCallback, Float))) {
            targetQuantity = Std.int(quantityOrCallback);
        }

        if (Reflect.isFunction(mmidOrCallback)) {
            callback = mmidOrCallback;
        } else if (mmidOrCallback != null && !Reflect.isObject(mmidOrCallback) && (Std.isOfType(mmidOrCallback, String) || Std.isOfType(mmidOrCallback, Int) || Std.isOfType(mmidOrCallback, Float))) {
            targetMMID = mmidOrCallback;
        }

        if (Reflect.isFunction(onComplete)) {
            callback = onComplete;
        }

        if (priorityList.length > 1 && (CombatEngine.priorityTargets == null || CombatEngine.priorityTargets.length == 0)) {
            CombatEngine.priorityTargets = priorityList.copy();
        }

        var isArrayItems:Bool = false;
        var itemList:Array<{item:String, qty:Int}> = [];

        if (itemOrCount != null) {
            if (Std.isOfType(itemOrCount, Int) || Std.isOfType(itemOrCount, Float)) {
                // If quantityOrCallback is also a positive number, e.g. hunt(mob, itemId, qty), then itemOrCount is an itemId!
                if (quantityOrCallback != null && !Reflect.isFunction(quantityOrCallback) && (Std.isOfType(quantityOrCallback, Int) || Std.isOfType(quantityOrCallback, Float)) && Std.int(quantityOrCallback) > 0) {
                    isKillCount = false;
                    targetQuantity = Std.int(quantityOrCallback);
                } else {
                    isKillCount = true;
                    targetKills = Std.int(itemOrCount);
                    if (targetMMID == null && quantityOrCallback != null && !Reflect.isFunction(quantityOrCallback)) {
                        targetMMID = quantityOrCallback;
                    }
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
            var hasEnough:Bool = false;
            if (Api.inventory != null) {
                if (_huntIsTemp) {
                    hasEnough = Api.inventory.hasTempItem(itemName, targetQuantity);
                } else {
                    hasEnough = (Api.inventory.getQuantity(itemName) + Api.inventory.getBankQuantity(itemName)) >= targetQuantity;
                }
            }
            if (hasEnough) {
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

        var isBoundedHunt:Bool = (isKillCount && targetKills > 0) || (isArrayItems && itemList.length > 0) || (!isKillCount && !isArrayItems && itemOrCount != null && Std.string(itemOrCount) != "");

        if (isBoundedHunt) {
            _activeHuntKey = huntKey;
        } else {
            // Unbounded hunt: hunting a monster directly without a completion count
            // Clear active hunt lock to allow dynamic target switching
            _activeHuntKey = null;
        }

        // 3. Safety checks: player dead, map loading, or banking/unbanking items
        if (Api.player != null && !Api.player.isAlive) return false;
        if (Api.map != null && !Api.map.isLoaded) return false;
        if (Api.inventory != null && (Api.inventory.isUnbanking || Api.inventory.isBanking)) return false;

        // 4. Resolve which cell the monster spawns in across the map
        var targetCell:String = "";
        if (Api.monster != null) {
            targetCell = Api.monster.getMonsterCell(monsterName, targetMMID);
            if (targetCell == "" && priorityList.length > 0) {
                for (pMon in priorityList) {
                    targetCell = Api.monster.getMonsterCell(pMon);
                    if (targetCell != "") break;
                }
            }
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
            if (!inCurCell && priorityList.length > 0) {
                for (pMon in priorityList) {
                    if (Api.monster != null && Api.monster.findByName(pMon, false) != null) {
                        inCurCell = true;
                        break;
                    }
                }
            }
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
                        ApiLogger.debug("Combat", "Hunt kill: " + monsterName + (targetMMID != null ? (" [MMID " + targetMMID + "]") : "") + " (" + _huntCurrentKills + "/" + _huntTargetKills + ")");
                        if (_huntCurrentKills >= _huntTargetKills) {
                            ApiLogger.info("Combat", "Hunt complete: " + monsterName + " (" + _huntTargetKills + "/" + _huntTargetKills + ")");
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
                    ApiLogger.debug("Combat", "Hunt kill: " + monsterName + (targetMMID != null ? (" [MMID " + targetMMID + "]") : "") + " (" + _huntCurrentKills + "/" + _huntTargetKills + ")");
                    if (_huntCurrentKills >= _huntTargetKills) {
                        ApiLogger.info("Combat", "Hunt complete: " + monsterName + " (" + _huntTargetKills + "/" + _huntTargetKills + ")");
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

    public function kill(monsterName:String, itemOrCount:Dynamic = null, quantity:Dynamic = null, mmid:Dynamic = null):Bool {
        return hunt(monsterName, itemOrCount, quantity, mmid);
    }

    /**
     * Universal farming method (Skua-style FarmItem / HuntForItem).
     * Whitelists item drops, sweeps screen drops, monitors temp/inventory/bank counts,
     * and hunts monsters until target quantity is reached.
     */
    public function farmItem(monster:Dynamic, item:String, quantity:Int = 1, isTemp:Bool = false, ?onComplete:Dynamic):Bool {
        if (item == null || item == "") return true;

        // 1. Ensure item is in drop whitelist so incoming drops are auto-accepted
        if (Api.drop != null) {
            var found = false;
            if (Api.drop.targetDrops != null) {
                for (d in Api.drop.targetDrops) {
                    if (d != null && Std.string(d).toLowerCase() == item.toLowerCase()) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    Api.drop.targetDrops.push(item);
                }
            }
            Api.drop.pickup(item);
        }

        // 2. Check current owned count across inventory / bank / temp
        var curQty = 0;
        if (Api.inventory != null) {
            if (isTemp) {
                curQty = Api.inventory.getTempQuantity(item);
            } else {
                curQty = Api.inventory.getQuantity(item) + Api.inventory.getBankQuantity(item);
            }
        }

        if (curQty >= quantity) {
            if (CombatEngine.targetName != null && monster != null
                && CombatEngine.targetName.toLowerCase() == Std.string(monster).toLowerCase()) {
                CombatEngine.targetName = null;
            }
            CombatEngine.lockedMMID = null;
            stopCombat();
            if (onComplete != null && Reflect.isFunction(onComplete)) {
                try { onComplete(); } catch (_:Dynamic) {}
            }
            return true;
        }

        // 3. Delegate to hunt with temp option
        _huntIsTemp = isTemp;
        return hunt(monster, item, quantity, { temp: isTemp }, onComplete);
    }

    public inline function huntForItem(monster:Dynamic, item:String, quantity:Int = 1, isTemp:Bool = false, ?onComplete:Dynamic):Bool {
        return farmItem(monster, item, quantity, isTemp, onComplete);
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

        var isCurrent = (c == null || c == "" || c.toLowerCase() == "current");
        if (!isCurrent && Api.inventory != null) {
            Api.inventory.equip(c);
        }

        com.aqwapi.modules.CombatEngine.smartClass = isCurrent ? "Current" : c;

        var effClass = isCurrent ? SkillManager.getCurrentClassName() : c;
        if (effClass != "") {
            m = SkillManager.resolveActiveModeName(effClass, m);
        }
        if (m != null && m != "") com.aqwapi.modules.CombatEngine.skillMode = m;
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
