package com.aqwapi.scripting;

import com.aqwapi.AqwApi;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.events.GameEvent;
import com.aqwapi.modules.CombatManager;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwTime;
import flash.events.TimerEvent;
import flash.utils.Timer;
import hscript.Expr;
import hscript.Interp;
import hscript.Parser;
import hscript.Printer;

class HScriptEngine {
    private var _parser:Parser;
    private var _interp:Interp;
    private var _program:Expr;
    private var _timer:Timer;

    public var isRunning:Bool = false;
    public var waitTimer:Float = 0;
    public var statusText:String = "Stopped";
    public var tickInterval:Int = 100;

    private var _hasOnStart:Bool = false;
    private var _hasOnTick:Bool = false;
    private var _hasOnStop:Bool = false;
    private var _hasOnPacket:Bool = false;
    private var _hasOnZoneEntered:Bool = false;
    private var _hasOnQuestUpdated:Bool = false;
    private var _hasOnInventoryChanged:Bool = false;

    private static var _instance:HScriptEngine;
    public static var SINGLETON(get, never):HScriptEngine;
    @:getter(SINGLETON)
    public static function get_SINGLETON_prop():HScriptEngine {
        if (_instance == null) _instance = new HScriptEngine();
        return _instance;
    }
    public static function get_SINGLETON():HScriptEngine {
        if (_instance == null) _instance = new HScriptEngine();
        return _instance;
    }

    public function new() {
        _parser = new Parser();
        _parser.allowTypes = true;
        _parser.allowJSON = true;
        _parser.allowMetadata = true;
        _interp = new Interp();

        _timer = new Timer(tickInterval);
        _timer.addEventListener(TimerEvent.TIMER, onTimerTick, false, 0, true);

        AqwApi.dispatcher.addEventListener(GameEvent.ZONE_ENTERED, onGameZoneEntered);
        AqwApi.dispatcher.addEventListener(GameEvent.QUEST_UPDATED, onGameQuestUpdated);
        AqwApi.dispatcher.addEventListener(GameEvent.INVENTORY_CHANGED, onGameInventoryChanged);

        _resetSandbox();
    }

    public function reset():Void {
        if (isRunning) stop();
        waitTimer = 0;
        statusText = (_program != null) ? "Ready." : "Stopped.";

        if (_program != null) {
            _resetSandbox();
            try {
                _interp.execute(_program);
                _hasOnStart = _interp.variables.exists("onStart") && Reflect.isFunction(_interp.variables.get("onStart"));
                _hasOnTick = _interp.variables.exists("onTick") && Reflect.isFunction(_interp.variables.get("onTick"));
                _hasOnStop = _interp.variables.exists("onStop") && Reflect.isFunction(_interp.variables.get("onStop"));
                _hasOnPacket = _interp.variables.exists("onPacket") && Reflect.isFunction(_interp.variables.get("onPacket"));
                _hasOnZoneEntered = _interp.variables.exists("onZoneEntered") && Reflect.isFunction(_interp.variables.get("onZoneEntered"));
                _hasOnQuestUpdated = _interp.variables.exists("onQuestUpdated") && Reflect.isFunction(_interp.variables.get("onQuestUpdated"));
                _hasOnInventoryChanged = _interp.variables.exists("onInventoryChanged") && Reflect.isFunction(_interp.variables.get("onInventoryChanged"));
            } catch (e:Dynamic) {
                ApiLogger.error("HScript", "Reset error: " + Std.string(e));
            }
        }
    }

    public function clear():Void {
        if (isRunning) stop();
        _program = null;
        _hasOnStart = false;
        _hasOnTick = false;
        _hasOnStop = false;
        _hasOnPacket = false;
        _hasOnZoneEntered = false;
        _hasOnQuestUpdated = false;
        _hasOnInventoryChanged = false;
        waitTimer = 0;
        statusText = "No script loaded.";
        _resetSandbox();
    }


    private function _resetSandbox():Void {
        _interp = new Interp();

        // Core API
        _interp.variables.set("api", AqwApi);
        _interp.variables.set("bot", AqwApi);
        _interp.variables.set("player", AqwApi.player);
        _interp.variables.set("combat", AqwApi.combat);
        _interp.variables.set("map", AqwApi.map);
        _interp.variables.set("quest", AqwApi.quest);
        _interp.variables.set("inventory", AqwApi.inventory);
        _interp.variables.set("drops", AqwApi.drops);
        _interp.variables.set("shop", AqwApi.shop);
        _interp.variables.set("monsters", AqwApi.monsters);
        _interp.variables.set("events", AqwApi.dispatcher);

        // Logging & Notifications
        _interp.variables.set("log", function(msg:Dynamic):Void {
            ApiLogger.info("HScript", Std.string(msg));
        });
        _interp.variables.set("warn", function(msg:Dynamic):Void {
            ApiLogger.warn("HScript", Std.string(msg));
        });
        _interp.variables.set("error", function(msg:Dynamic):Void {
            ApiLogger.error("HScript", Std.string(msg));
        });
        _interp.variables.set("clearLog", function():Void {
            ApiLogger.clearLog();
        });
        _interp.variables.set("notify", function(msg:Dynamic):Void {
            AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, Std.string(msg)));
        });

        // Async Delay
        _interp.variables.set("sleep", function(ms:Float):Void {
            waitTimer = AqwTime.now() + ms;
        });

        // Common API Shortcuts
        _interp.variables.set("join", function(mapName:String, cell:String = "Enter", pad:String = "Spawn"):Void {
            AqwApi.map.join(mapName, cell, pad);
        });
        _interp.variables.set("jump", function(cell:String, pad:String = "Enter"):Void {
            AqwApi.map.jump(cell, pad);
        });
        _interp.variables.set("snapTo", function(target:Dynamic):Void {
            AqwApi.map.snapTo(target);
        });
        _interp.variables.set("getMapItem", function(itemId:Int):Bool {
            return AqwApi.map.getMapItem(itemId);
        });
        _interp.variables.set("attack", function(monster:Dynamic):Void {
            AqwApi.combat.attack(Std.string(monster));
        });
        _interp.variables.set("hasItem", function(itemName:String, quantity:Int = 1):Bool {
            return AqwApi.inventory.hasItem(itemName, quantity);
        });
        _interp.variables.set("getItemCount", function(itemName:String):Int {
            return AqwApi.inventory.getQuestQuantity(itemName);
        });
        _interp.variables.set("getDrop", function(drops:Dynamic):Void {
            if (Std.isOfType(drops, Array)) {
                AqwApi.drops.acceptPendingDrops(cast drops);
            } else if (drops != null) {
                var str = Std.string(drops);
                if (str.indexOf(",") != -1) {
                    var parts:Array<Dynamic> = [];
                    for (p in str.split(",")) parts.push(StringTools.trim(p));
                    AqwApi.drops.acceptPendingDrops(parts);
                } else {
                    AqwApi.drops.getDrop(str);
                }
            }
        });
        _interp.variables.set("getDrops", function(drops:Dynamic = "all"):Void {
            if (drops == null || drops == "all" || drops == "any" || drops == "*") {
                AqwApi.drops.acceptPendingDrops(["all"]);
            } else if (Std.isOfType(drops, Array)) {
                AqwApi.drops.acceptPendingDrops(cast drops);
            } else {
                var str = Std.string(drops);
                if (str.indexOf(",") != -1) {
                    var parts:Array<Dynamic> = [];
                    for (p in str.split(",")) parts.push(StringTools.trim(p));
                    AqwApi.drops.acceptPendingDrops(parts);
                } else {
                    AqwApi.drops.getDrop(str);
                }
            }
        });
        _interp.variables.set("loadQuest", function(questId:Int):Void {
            AqwApi.quest.load(questId);
        });
        _interp.variables.set("loadQuests", function(questIds:Dynamic):Void {
            if (Std.isOfType(questIds, Array)) {
                var arr:Array<Dynamic> = cast questIds;
                var intArr:Array<Int> = [];
                for (item in arr) {
                    var qid = com.aqwapi.utils.AqwUtils.parseInt(item, 0);
                    if (qid > 0) intArr.push(qid);
                }
                AqwApi.quest.loadMultiple(intArr);
            } else if (questIds != null) {
                var qid = com.aqwapi.utils.AqwUtils.parseInt(questIds, 0);
                if (qid > 0) AqwApi.quest.load(qid);
            }
        });
        _interp.variables.set("isQuestLoaded", function(questId:Int):Bool {
            return AqwApi.quest.isLoaded(questId);
        });
        _interp.variables.set("showQuests", function(questIds:Dynamic):Void {
            AqwApi.quest.showQuests(Std.string(questIds));
        });
        _interp.variables.set("openQuest", function(questId:Int):Void {
            AqwApi.quest.showQuests(Std.string(questId));
        });
        _interp.variables.set("acceptQuest", function(questId:Int):Void {
            AqwApi.quest.accept(questId);
        });
        _interp.variables.set("acceptQuests", function(questIds:Dynamic):Void {
            if (Std.isOfType(questIds, Array)) {
                var arr:Array<Dynamic> = cast questIds;
                var intArr:Array<Int> = [];
                for (item in arr) {
                    var qid = com.aqwapi.utils.AqwUtils.parseInt(item, 0);
                    if (qid > 0) intArr.push(qid);
                }
                AqwApi.quest.acceptMultiple(intArr);
            } else if (questIds != null) {
                var qid = com.aqwapi.utils.AqwUtils.parseInt(questIds, 0);
                if (qid > 0) AqwApi.quest.accept(qid);
            }
        });
        _interp.variables.set("ensureAccept", function(questId:Int):Void {
            AqwApi.quest.accept(questId);
        });
        _interp.variables.set("completeQuest", function(questId:Int, itemId:Int = -1):Void {
            AqwApi.quest.complete(questId, itemId);
        });
        _interp.variables.set("completeQuests", function(questIds:Dynamic):Void {
            if (Std.isOfType(questIds, Array)) {
                var arr:Array<Dynamic> = cast questIds;
                var intArr:Array<Int> = [];
                for (item in arr) {
                    var qid = com.aqwapi.utils.AqwUtils.parseInt(item, 0);
                    if (qid > 0) intArr.push(qid);
                }
                AqwApi.quest.completeMultiple(intArr);
            } else if (questIds != null) {
                var qid = com.aqwapi.utils.AqwUtils.parseInt(questIds, 0);
                if (qid > 0 && AqwApi.quest.isAccepted(qid)) AqwApi.quest.complete(qid);
            }
        });
        _interp.variables.set("turnIn", function(questId:Int, itemId:Int = -1):Void {
            AqwApi.quest.complete(questId, itemId);
        });
        _interp.variables.set("turnInQuests", function(questIds:Dynamic):Void {
            if (Std.isOfType(questIds, Array)) {
                var arr:Array<Dynamic> = cast questIds;
                var intArr:Array<Int> = [];
                for (item in arr) {
                    var qid = com.aqwapi.utils.AqwUtils.parseInt(item, 0);
                    if (qid > 0) intArr.push(qid);
                }
                AqwApi.quest.completeMultiple(intArr);
            } else if (questIds != null) {
                var qid = com.aqwapi.utils.AqwUtils.parseInt(questIds, 0);
                if (qid > 0 && AqwApi.quest.isAccepted(qid)) AqwApi.quest.complete(qid);
            }
        });
        _interp.variables.set("isQuestComplete", function(questId:Int):Bool {
            return AqwApi.quest.isComplete(questId);
        });
        _interp.variables.set("isQuestAccepted", function(questId:Int):Bool {
            return AqwApi.quest.isAccepted(questId);
        });
        _interp.variables.set("isQuestAvailable", function(questId:Int):Bool {
            return AqwApi.quest.isAvailable(questId);
        });
        _interp.variables.set("isQuestUnlocked", function(questId:Int):Bool {
            return AqwApi.quest.isUnlocked(questId);
        });
        _interp.variables.set("hasBeenCompleted", function(questId:Int):Bool {
            return AqwApi.quest.hasBeenCompleted(questId);
        });
        _interp.variables.set("isDailyComplete", function(questId:Int):Bool {
            return AqwApi.quest.isDailyComplete(questId);
        });
        _interp.variables.set("canCompleteQuest", function(questId:Int):Bool {
            return AqwApi.quest.canComplete(questId);
        });
        _interp.variables.set("canTurnInQuest", function(questId:Int):Bool {
            return AqwApi.quest.canComplete(questId);
        });
        _interp.variables.set("getQuestValue", function(slot:Int):Int {
            return AqwApi.quest.getQuestValue(slot);
        });
        _interp.variables.set("dropCombat", function():Void {
            AqwApi.combat.dropCombat();
        });
        _interp.variables.set("cancelAutoAttack", function():Void {
            AqwApi.combat.cancelAutoAttack();
        });
        _interp.variables.set("cancelTarget", function():Void {
            AqwApi.combat.cancelTarget();
        });
        _interp.variables.set("pauseCombat", function():Void {
            AqwApi.combat.pauseCombat();
        });
        _interp.variables.set("pauseAttack", function():Void {
            AqwApi.combat.pauseCombat();
        });
        _interp.variables.set("approach", function():Void {
            AqwApi.combat.approachTarget();
        });
        _interp.variables.set("approachTarget", function():Void {
            AqwApi.combat.approachTarget();
        });
        _interp.variables.set("attackTarget", function(target:Dynamic = null):Void {
            if (target == null) {
                AqwApi.combat.attack("*");
            } else if (Reflect.hasField(target, "mapId")) {
                AqwApi.combat.attack(Std.string(Reflect.field(target, "mapId")));
            } else {
                AqwApi.combat.attack(Std.string(target));
            }
            AqwApi.combat.approachTarget();
        });
        _interp.variables.set("setInfiniteRange", function(enabled:Bool = true):Void {
            AqwApi.combat.setInfiniteRange(enabled);
        });
        _interp.variables.set("infiniteRange", function(enabled:Bool = true):Void {
            AqwApi.combat.setInfiniteRange(enabled);
        });
        _interp.variables.set("magnetize", function():Void {
            AqwApi.combat.magnetize();
        });
        _interp.variables.set("setSpawnPoint", function(cell:String = null, pad:String = null):Void {
            AqwApi.player.setSpawnPoint(cell, pad);
        });
        _interp.variables.set("setDeathSpawn", function(enabled:Bool = true):Void {
            AqwApi.map.autoDeathSpawn = enabled;
        });
        _interp.variables.set("deathSpawn", function(enabled:Bool = true):Void {
            AqwApi.map.autoDeathSpawn = enabled;
        });
        _interp.variables.set("walkTo", function(x:Float, y:Float, speed:Float = 16):Void {
            if (AqwApi.game != null && AqwApi.game.world != null && AqwApi.game.world.myAvatar != null) {
                try {
                    var avt:Dynamic = AqwApi.game.world.myAvatar;
                    if (avt.pMC != null) {
                        if (avt.pMC.walkTo != null) avt.pMC.walkTo(x, y, speed);
                        if (AqwApi.game.world.pushMove != null) AqwApi.game.world.pushMove(avt.pMC, x, y, speed);
                    }
                } catch (e:Dynamic) {}
            }
        });
        _interp.variables.set("useSkill", function(index:Int):Bool {
            return AqwApi.combat.useSkill(index);
        });
        _interp.variables.set("canUseSkill", function(index:Int):Bool {
            return AqwApi.combat.canUseSkill(index);
        });
        _interp.variables.set("equip", function(itemName:String):Void {
            AqwApi.inventory.equip(itemName);
        });
        _interp.variables.set("equipClass", function(type:String):Bool {
            return AqwApi.combat.equipLoadout(type);
        });
        _interp.variables.set("equipLoadout", function(type:String):Bool {
            return AqwApi.combat.equipLoadout(type);
        });
        _interp.variables.set("stop", function():Void {
            stop();
        });

        // Packets & Network
        _interp.variables.set("sendPacket", function(packet:String):Void {
            if (AqwApi.game != null && AqwApi.game.sfc != null) {
                AqwApi.game.sfc.sendString(packet);
            }
        });
        _interp.variables.set("sendXt", function(cmd:String, args:Array<Dynamic> = null):Void {
            if (AqwApi.transport != null) {
                AqwApi.transport.sendExtensionCommand(cmd, args != null ? args : []);
            }
        });
        _interp.variables.set("dungeonQueue", function(mapName:String, roomNum:Int = -1):Void {
            var roomId = AqwApi.map.roomId;
            var num = (roomNum > 0) ? roomNum : (100000 + Std.random(90000));
            AqwApi.map.privateRoomNumber = num;
            var targetMap = (mapName.indexOf("-") != -1) ? mapName : (mapName + "-" + num);
            var packet = "%xt%zm%dungeonQueue%" + roomId + "%" + targetMap + "%";
            if (AqwApi.game != null && AqwApi.game.sfc != null) {
                AqwApi.game.sfc.sendString(packet);
            }
        });
        _interp.variables.set("setPrivateRoom", function(enabled:Bool, roomNumber:Int = 100000):Void {
            AqwApi.map.usePrivateRoom = enabled;
            if (roomNumber > 0) AqwApi.map.privateRoomNumber = roomNumber;
        });

        // Target & Auras
        _interp.variables.set("getTarget", function():Dynamic {
            return AqwApi.player.target;
        });
        _interp.variables.set("hasTargetAura", function(auraName:String):Bool {
            var t = AqwApi.player.target;
            if (t != null && t.hasAura(auraName)) return true;
            if (AqwApi.player != null && AqwApi.monsters != null) {
                var cellMonsters = AqwApi.monsters.getByCell(AqwApi.player.cell);
                for (m in cellMonsters) {
                    if (m != null && m.alive && m.hasAura(auraName)) return true;
                }
            }
            return false;
        });
        _interp.variables.set("hasPlayerAura", function(auraName:String):Bool {
            return AqwApi.player.hasAura(auraName);
        });
        _interp.variables.set("targetHasAura", function(auraName:String):Bool {
            var t = AqwApi.player.target;
            if (t != null && t.hasAura(auraName)) return true;
            if (AqwApi.player != null && AqwApi.monsters != null) {
                var cellMonsters = AqwApi.monsters.getByCell(AqwApi.player.cell);
                for (m in cellMonsters) {
                    if (m != null && m.alive && m.hasAura(auraName)) return true;
                }
            }
            return false;
        });
        _interp.variables.set("playerHasAura", function(auraName:String):Bool {
            return AqwApi.player.hasAura(auraName);
        });
        _interp.variables.set("hasMonsterAura", function(auraName:String, cell:String = null):Bool {
            var c = (cell != null && cell != "") ? cell : (AqwApi.player != null ? AqwApi.player.cell : "");
            if (AqwApi.monsters != null) {
                var cellMonsters = AqwApi.monsters.getByCell(c);
                for (m in cellMonsters) {
                    if (m != null && m.alive && m.hasAura(auraName)) return true;
                }
            }
            return false;
        });
        _interp.variables.set("hasAura", function(auraName:String, targetOnly:Bool = false):Bool {
            if (!targetOnly && AqwApi.player != null && AqwApi.player.hasAura(auraName)) return true;
            var t = AqwApi.player.target;
            if (t != null && t.hasAura(auraName)) return true;
            if (AqwApi.player != null && AqwApi.monsters != null) {
                var cellMonsters = AqwApi.monsters.getByCell(AqwApi.player.cell);
                for (m in cellMonsters) {
                    if (m != null && m.alive && m.hasAura(auraName)) return true;
                }
            }
            return false;
        });

        // Player Status Helpers
        _interp.variables.set("hpPercent", function():Float {
            if (AqwApi.player == null || AqwApi.player.maxHp <= 0) return 0.0;
            return AqwApi.player.hp / AqwApi.player.maxHp;
        });
        _interp.variables.set("mpPercent", function():Float {
            if (AqwApi.player == null || AqwApi.player.maxMp <= 0) return 0.0;
            return AqwApi.player.mp / AqwApi.player.maxMp;
        });
        _interp.variables.set("isAlive", function():Bool {
            return AqwApi.player != null && AqwApi.player.isAlive;
        });
        _interp.variables.set("isDead", function():Bool {
            return AqwApi.player == null || !AqwApi.player.isAlive;
        });
        _interp.variables.set("inCombat", function():Bool {
            return AqwApi.player != null && AqwApi.player.isInCombat;
        });

        // Monster & Cell Query
        _interp.variables.set("isMonsterAliveInCell", function(cell:String):Bool {
            var list = AqwApi.monsters.getByCell(cell);
            for (m in list) {
                if (m != null && m.alive && m.hp > 0 && m.hasGraphic) return true;
            }
            return false;
        });
        _interp.variables.set("getLivingMonstersInCell", function(cell:String):Array<Dynamic> {
            var list = AqwApi.monsters.getByCell(cell);
            var res:Array<Dynamic> = [];
            for (m in list) {
                if (m != null && m.alive && m.hp > 0 && m.hasGraphic) res.push(m);
            }
            return res;
        });
        _interp.variables.set("isRoomClear", function(cell:String = null):Bool {
            var c = (cell != null && cell != "") ? cell : (AqwApi.player != null ? AqwApi.player.cell : "");
            var list = AqwApi.monsters.getByCell(c);
            for (m in list) {
                if (m != null && m.alive && m.hp > 0 && m.hasGraphic) return false;
            }
            return true;
        });
        _interp.variables.set("isCellClear", function(cell:String = null):Bool {
            var c = (cell != null && cell != "") ? cell : (AqwApi.player != null ? AqwApi.player.cell : "");
            var list = AqwApi.monsters.getByCell(c);
            for (m in list) {
                if (m != null && m.alive && m.hp > 0 && m.hasGraphic) return false;
            }
            return true;
        });
        _interp.variables.set("getMonsters", function(cell:String = null):Array<Dynamic> {
            var c = (cell != null && cell != "") ? cell : (AqwApi.player != null ? AqwApi.player.cell : "");
            var list = AqwApi.monsters.getByCell(c);
            var res:Array<Dynamic> = [];
            for (m in list) {
                if (m != null && m.alive && m.hp > 0 && m.hasGraphic) res.push(m);
            }
            return res;
        });
        _interp.variables.set("getFirstMonster", function(cell:String = null):Dynamic {
            var c = (cell != null && cell != "") ? cell : (AqwApi.player != null ? AqwApi.player.cell : "");
            var list = AqwApi.monsters.getByCell(c);
            for (m in list) {
                if (m != null && m.alive && m.hp > 0 && m.hasGraphic) return m;
            }
            return null;
        });

        // Cutscene & UI
        _interp.variables.set("skipCutscene", function():Void {
            if (AqwApi.game != null) {
                try {
                    var g:Dynamic = AqwApi.game;
                    var w:Dynamic = g.world;

                    // 1. Cancel active cutscene handler
                    if (w != null) {
                        if (Reflect.hasField(w, "cHandle") && w.cHandle != null) {
                            try { w.cHandle.cancel(); } catch (e:Dynamic) {}
                        }
                        // Set map session seenIt0 so dungeon map doesn't re-trigger cutscenes
                        if (Reflect.hasField(w, "objSession") && w.objSession != null && w.strMapName != null) {
                            try {
                                var sName:String = Std.string(w.strMapName);
                                var sess:Dynamic = Reflect.field(w.objSession, sName);
                                if (sess != null) Reflect.setField(sess, "seenIt0", true);
                            } catch (e:Dynamic) {}
                        }
                    }

                    // 2. Clear external cutscene SWF from game/world
                    if (Reflect.hasField(g, "mcExtSWF") && g.mcExtSWF != null && g.mcExtSWF.numChildren > 0) {
                        if (Reflect.hasField(g, "clearExternamSWF")) {
                            try { g.clearExternamSWF(); } catch (e:Dynamic) {}
                        } else {
                            try {
                                while (g.mcExtSWF.numChildren > 0) g.mcExtSWF.removeChildAt(0);
                                if (Reflect.hasField(g, "showInterface")) g.showInterface();
                                if (w != null) w.visible = true;
                            } catch (e:Dynamic) {}
                        }
                    }

                    // 3. Close popup only if a modal is actually active (not idle/none)
                    if (g.ui != null && Reflect.hasField(g.ui, "mcPopup")) {
                        var p:Dynamic = g.ui.mcPopup;
                        if (p != null) {
                            var lbl:String = (p.currentLabel != null) ? Std.string(p.currentLabel) : "";
                            if (lbl != "" && lbl != "Idle" && lbl != "none") {
                                if (Reflect.hasField(p, "onClose")) p.onClose();
                            }
                        }
                    }
                } catch (e:Dynamic) {}
            }
        });

        // Utilities
        _interp.variables.set("Math", Math);
        _interp.variables.set("Std", Std);
        _interp.variables.set("StringTools", StringTools);
        _interp.variables.set("Date", Date);
        _interp.variables.set("AqwTime", AqwTime);
        _interp.variables.set("isNaN", function(v:Dynamic):Bool {
            return (untyped __global__["isNaN"])(v);
        });
        _interp.variables.set("parseInt", function(v:Dynamic):Null<Int> {
            return com.aqwapi.utils.AqwUtils.parseInt(v);
        });
        _interp.variables.set("parseFloat", function(v:Dynamic):Float {
            return com.aqwapi.utils.AqwUtils.parseFloat(v);
        });
    }

    public function loadScript(scriptCode:String):Bool {
        if ((AqwApi.game == null || AqwApi.game.world == null) && AqwApi.game != null) {
            AqwApi.init(AqwApi.game);
        }

        reset();

        // Strip //hscript or #hscript header line if present
        var cleanCode = scriptCode;
        if (cleanCode.indexOf("//hscript") == 0) cleanCode = cleanCode.substring(9);
        else if (cleanCode.indexOf("#hscript") == 0) cleanCode = cleanCode.substring(8);

        try {
            _program = _parser.parseString(cleanCode);
        } catch (e:hscript.Expr.Error) {
            var msg = "Parse error at line " + _parser.line + ": " + Printer.errorToString(e);
            ApiLogger.error("HScript", msg);
            statusText = msg;
            AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, msg));
            return false;
        } catch (e:Dynamic) {
            var msg = "Parse error: " + Std.string(e);
            ApiLogger.error("HScript", msg);
            statusText = msg;
            AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, msg));
            return false;
        }

        try {
            _interp.execute(_program);
        } catch (e:Dynamic) {
            var msg = "Execution error on load: " + Std.string(e);
            ApiLogger.error("HScript", msg);
            statusText = msg;
            AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, msg));
            return false;
        }

        _hasOnStart = _interp.variables.exists("onStart") && Reflect.isFunction(_interp.variables.get("onStart"));
        _hasOnTick = _interp.variables.exists("onTick") && Reflect.isFunction(_interp.variables.get("onTick"));
        _hasOnStop = _interp.variables.exists("onStop") && Reflect.isFunction(_interp.variables.get("onStop"));
        _hasOnPacket = _interp.variables.exists("onPacket") && Reflect.isFunction(_interp.variables.get("onPacket"));
        _hasOnZoneEntered = _interp.variables.exists("onZoneEntered") && Reflect.isFunction(_interp.variables.get("onZoneEntered"));
        _hasOnQuestUpdated = _interp.variables.exists("onQuestUpdated") && Reflect.isFunction(_interp.variables.get("onQuestUpdated"));
        _hasOnInventoryChanged = _interp.variables.exists("onInventoryChanged") && Reflect.isFunction(_interp.variables.get("onInventoryChanged"));

        statusText = "Loaded HScript (" + (_hasOnTick ? "tick-loop" : "exec-once") + ")";
        ApiLogger.info("HScript", statusText);
        return true;
    }

    public function start():Void {
        if ((AqwApi.game == null || AqwApi.game.world == null) && AqwApi.game != null) {
            AqwApi.init(AqwApi.game);
        }
        if (_program == null) {
            ApiLogger.warn("HScript", "Cannot start: no script loaded.");
            return;
        }

        // Truncate bot.log to start fresh on every script run
        ApiLogger.clearLog();

        isRunning = true;
        waitTimer = 0;

        // Scripting ergonomics: Infinite Range and Death Spawn are always ON by default during scripts
        if (AqwApi.combat != null) AqwApi.combat.setInfiniteRange(true);
        if (AqwApi.map != null) AqwApi.map.autoDeathSpawn = true;

        _timer.delay = tickInterval;
        _timer.start();
        statusText = "Running HScript...";
        AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.SCRIPT_STARTED, "HScript Started!"));
        ApiLogger.info("HScript", "HScript Started!");

        try {
            com.aqwapi.modules.ScriptManager.SINGLETON.isRunning = true;
            com.aqwapi.modules.ScriptManager.SINGLETON.statusText = statusText;
        } catch (e:Dynamic) {}

        if (_hasOnStart) {
            try {
                var fn = _interp.variables.get("onStart");
                fn();
            } catch (e:Dynamic) {
                _handleScriptError("onStart error: " + Std.string(e), e);
            }
        }
    }

    public function stop():Void {
        if (!isRunning) return;
        isRunning = false;
        _timer.stop();
        statusText = "Stopped.";

        try {
            com.aqwapi.modules.ScriptManager.SINGLETON.isRunning = false;
            com.aqwapi.modules.ScriptManager.SINGLETON.statusText = statusText;
        } catch (e:Dynamic) {}

        if (_hasOnStop) {
            try {
                var fn = _interp.variables.get("onStop");
                fn();
            } catch (e:Dynamic) {
                ApiLogger.error("HScript", "onStop error: " + Std.string(e));
            }
        }

        AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.SCRIPT_STOPPED, "HScript Stopped!"));
        ApiLogger.info("HScript", "HScript Stopped!");

        if (AqwApi.quest != null) AqwApi.quest.stopAuto();
        if (AqwApi.combat != null) AqwApi.combat.stopAuto();
        else CombatManager.stop();
    }


    private function onTimerTick(e:TimerEvent):Void {
        if (!isRunning) return;
        if (AqwApi.game == null || AqwApi.game.world == null) return;

        var world = AqwApi.game.world;
        if (world.myAvatar != null && world.myAvatar.dataLeaf != null && world.myAvatar.dataLeaf.intState == 0) {
            statusText = "Waiting for respawn...";
            return;
        }

        var now = AqwTime.now();
        if (waitTimer > 0 && now < waitTimer) return;

        if (_hasOnTick) {
            try {
                var fn = _interp.variables.get("onTick");
                fn();
            } catch (err:Dynamic) {
                _handleScriptError("onTick error: " + Std.string(err), err);
            }
        } else {
            var bgCombat = CombatManager.IS_ON;
            var bgQuest = AqwApi.quest != null && AqwApi.quest.isAutoRunning;
            if (bgCombat || bgQuest) {
                statusText = bgCombat ? "Auto-combat running" : "Auto-quest running";
                return;
            }
            stop();
            statusText = "Script Finished!";
            AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "Script Finished!"));
            ApiLogger.info("HScript", "Script Finished!");
        }
    }

    private function onGameZoneEntered(e:GameEvent):Void {
        if (isRunning && _hasOnZoneEntered) {
            try { _interp.variables.get("onZoneEntered")(e.data); } catch(err:Dynamic) { _handleScriptError("onZoneEntered: " + err, err); }
        }
    }

    private function onGameQuestUpdated(e:GameEvent):Void {
        if (isRunning && _hasOnQuestUpdated) {
            try { _interp.variables.get("onQuestUpdated")(e.data); } catch(err:Dynamic) { _handleScriptError("onQuestUpdated: " + err, err); }
        }
    }

    private function onGameInventoryChanged(e:GameEvent):Void {
        if (isRunning && _hasOnInventoryChanged) {
            try { _interp.variables.get("onInventoryChanged")(e.data); } catch(err:Dynamic) { _handleScriptError("onInventoryChanged: " + err, err); }
        }
    }

    public function handlePacket(type:String, cmd:String, data:Dynamic):Void {
        if (isRunning && _hasOnPacket) {
            try { _interp.variables.get("onPacket")(type, cmd, data); } catch(err:Dynamic) { _handleScriptError("onPacket: " + err, err); }
        }
    }

    private function _handleScriptError(msg:String, err:Dynamic = null):Void {
        var fullMsg = msg;
        if (err != null) {
            try {
                var stack:String = (Reflect.field(err, "getStackTrace") != null) ? (untyped err).getStackTrace() : "";
                if (stack != null && stack != "") fullMsg += "\n" + stack;
            } catch (e:Dynamic) {}
        }
        ApiLogger.error("HScript", fullMsg);
        statusText = "Error: " + msg;
        AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "HScript Error: " + msg));
        stop();
    }
}
