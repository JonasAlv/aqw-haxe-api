package com.aqwapi.scripting;

import com.aqwapi.Api;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.events.GameEvent;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiUtils;
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

    public function sleep(ms:Float):Void {
        waitTimer = ApiTime.now() + ms;
    }

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
        _interp = new ScriptInterp();

        _timer = new Timer(tickInterval);
        _timer.addEventListener(TimerEvent.TIMER, onTimerTick, false, 0, true);

        Api.dispatcher.addEventListener(GameEvent.ZONE_ENTERED, onGameZoneEntered);
        Api.dispatcher.addEventListener(GameEvent.QUEST_UPDATED, onGameQuestUpdated);
        Api.dispatcher.addEventListener(GameEvent.INVENTORY_CHANGED, onGameInventoryChanged);

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
        _interp = new ScriptInterp();

        // Core API
        _interp.variables.set("api", Api);
        _interp.variables.set("bot", Api);
        _interp.variables.set("Api", Api);
        _interp.variables.set("Bot", Api);
        _interp.variables.set("player", Api.player);
        _interp.variables.set("combat", Api.combat);
        _interp.variables.set("map", Api.map);
        _interp.variables.set("quest", Api.quest);
        _interp.variables.set("inventory", Api.inventory);
        _interp.variables.set("drop", Api.drop);
        _interp.variables.set("shop", Api.shop);
        _interp.variables.set("monster", Api.monster);
        _interp.variables.set("enhancement", Api.enhancement);
        _interp.variables.set("enhancements", Api.enhancement);
        _interp.variables.set("events", Api.dispatcher);

        // Enhancement shortcuts
        _interp.variables.set("smartEnhance", function(?a:Dynamic, ?b:Dynamic, ?c:Dynamic):Void {
            Api.smartEnhance(a, b, c);
        });
        _interp.variables.set("enhanceEquipped", function(?a:Dynamic, ?b:Dynamic, ?c:Dynamic, ?d:Dynamic, ?e:Dynamic):Void {
            Api.enhanceEquipped(a, b, c, d, e);
        });
        _interp.variables.set("enhanceItem", function(?a:Dynamic, ?b:Dynamic, ?c:Dynamic, ?d:Dynamic, ?e:Dynamic, ?f:Dynamic):Void {
            Api.enhanceItem(a, b, c, d, e, f);
        });
        _interp.variables.set("isAweUnlocked", function():Bool {
            return Api.enhancement.isAweUnlocked();
        });
        _interp.variables.set("isForgeUnlocked", function(name:String):Bool {
            return Api.enhancement.isForgeUnlocked(name);
        });
        _interp.variables.set("isEnhancing", function():Bool {
            return Api.enhancement != null && Api.enhancement.isBusy;
        });
        _interp.variables.set("isEnhanceBusy", function():Bool {
            return Api.enhancement != null && Api.enhancement.isBusy;
        });

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
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, Std.string(msg)));
        });

        // Async Delay
        _interp.variables.set("sleep", function(ms:Float):Void {
            waitTimer = ApiTime.now() + ms;
        });

        // Common API Shortcuts
        _interp.variables.set("join", function(mapName:String, cell:String = "Enter", pad:String = "Spawn"):Void {
            Api.map.join(mapName, cell, pad);
        });
        _interp.variables.set("joinHouse", function(username:String = ""):Void {
            Api.map.joinHouse(username);
        });
        _interp.variables.set("jump", function(cell:String, pad:String = "Enter"):Void {
            Api.map.jump(cell, pad);
        });
        _interp.variables.set("snapTo", function(target:Dynamic):Void {
            Api.map.snapTo(target);
        });
        _interp.variables.set("getMapItem", function(itemId:Int):Bool {
            return Api.map.getMapItem(itemId);
        });
        _interp.variables.set("attack", function(monster:Dynamic):Void {
            Api.combat.attack(Std.string(monster));
        });
        _interp.variables.set("selectTarget", function(monster:Dynamic):Void {
            Api.combat.selectTarget(Std.string(monster));
        });
        _interp.variables.set("target", function(monster:Dynamic):Void {
            Api.combat.selectTarget(Std.string(monster));
        });
        _interp.variables.set("hasItem", function(itemName:String, quantity:Int = 1):Bool {
            return Api.inventory.hasItem(itemName, quantity);
        });
        _interp.variables.set("getItemCount", function(itemName:String):Int {
            return Api.inventory.getItemCount(itemName);
        });
        _interp.variables.set("getDrop", function(drops:Dynamic):Void {
            if (Std.isOfType(drops, Array)) {
                Api.drop.acceptPendingDrops(cast drops);
            } else if (drops != null) {
                var str = Std.string(drops);
                if (str.indexOf(",") != -1) {
                    var parts:Array<Dynamic> = [];
                    for (p in str.split(",")) parts.push(StringTools.trim(p));
                    Api.drop.acceptPendingDrops(parts);
                } else {
                    Api.drop.getDrop(str);
                }
            }
        });
        _interp.variables.set("getDrops", function(drops:Dynamic = "all"):Void {
            if (drops == null || drops == "all" || drops == "any" || drops == "*") {
                Api.drop.acceptPendingDrops(["all"]);
            } else if (Std.isOfType(drops, Array)) {
                Api.drop.acceptPendingDrops(cast drops);
            } else {
                var str = Std.string(drops);
                if (str.indexOf(",") != -1) {
                    var parts:Array<Dynamic> = [];
                    for (p in str.split(",")) parts.push(StringTools.trim(p));
                    Api.drop.acceptPendingDrops(parts);
                } else {
                    Api.drop.getDrop(str);
                }
            }
        });
        _interp.variables.set("loadQuest", function(questId:Int):Void {
            Api.quest.load(questId);
        });
        _interp.variables.set("loadQuests", function(questIds:Dynamic):Void {
            if (Std.isOfType(questIds, Array)) {
                var arr:Array<Dynamic> = cast questIds;
                var intArr:Array<Int> = [];
                for (item in arr) {
                    var qid = ApiUtils.parseInt(item, 0);
                    if (qid > 0) intArr.push(qid);
                }
                Api.quest.loadMultiple(intArr);
            } else if (questIds != null) {
                var qid = ApiUtils.parseInt(questIds, 0);
                if (qid > 0) Api.quest.load(qid);
            }
        });
        _interp.variables.set("isQuestLoaded", function(questId:Int):Bool {
            return Api.quest.isLoaded(questId);
        });
        _interp.variables.set("showQuests", function(questIds:Dynamic):Void {
            Api.quest.showQuests(Std.string(questIds));
        });
        _interp.variables.set("openQuest", function(questId:Int):Void {
            Api.quest.showQuests(Std.string(questId));
        });
        _interp.variables.set("acceptQuest", function(questId:Int):Void {
            Api.quest.accept(questId);
        });
        _interp.variables.set("acceptQuests", function(questIds:Dynamic):Void {
            if (Std.isOfType(questIds, Array)) {
                var arr:Array<Dynamic> = cast questIds;
                var intArr:Array<Int> = [];
                for (item in arr) {
                    var qid = ApiUtils.parseInt(item, 0);
                    if (qid > 0) intArr.push(qid);
                }
                Api.quest.acceptMultiple(intArr);
            } else if (questIds != null) {
                var qid = ApiUtils.parseInt(questIds, 0);
                if (qid > 0) Api.quest.accept(qid);
            }
        });
        _interp.variables.set("ensureAccept", function(questId:Int):Void {
            if (!Api.quest.isAccepted(questId)) {
                if (!Api.quest.isLoaded(questId)) Api.quest.load(questId);
                Api.quest.accept(questId);
            }
        });
        _interp.variables.set("ensureQuest", function(questId:Int):Void {
            if (!Api.quest.isAccepted(questId)) {
                if (!Api.quest.isLoaded(questId)) Api.quest.load(questId);
                Api.quest.accept(questId);
            }
        });
        _interp.variables.set("completeQuest", function(questId:Int, itemId:Int = -1):Void {
            Api.quest.complete(questId, itemId);
        });
        _interp.variables.set("completeQuests", function(questIds:Dynamic):Void {
            if (Std.isOfType(questIds, Array)) {
                var arr:Array<Dynamic> = cast questIds;
                var intArr:Array<Int> = [];
                for (item in arr) {
                    var qid = ApiUtils.parseInt(item, 0);
                    if (qid > 0) intArr.push(qid);
                }
                Api.quest.completeMultiple(intArr);
            } else if (questIds != null) {
                var qid = ApiUtils.parseInt(questIds, 0);
                if (qid > 0 && Api.quest.isAccepted(qid)) Api.quest.complete(qid);
            }
        });
        _interp.variables.set("turnIn", function(questId:Int, itemId:Int = -1):Void {
            Api.quest.complete(questId, itemId);
        });
        _interp.variables.set("turnInQuests", function(questIds:Dynamic):Void {
            if (Std.isOfType(questIds, Array)) {
                var arr:Array<Dynamic> = cast questIds;
                var intArr:Array<Int> = [];
                for (item in arr) {
                    var qid = ApiUtils.parseInt(item, 0);
                    if (qid > 0) intArr.push(qid);
                }
                Api.quest.completeMultiple(intArr);
            } else if (questIds != null) {
                var qid = ApiUtils.parseInt(questIds, 0);
                if (qid > 0 && Api.quest.isAccepted(qid)) Api.quest.complete(qid);
            }
        });
        _interp.variables.set("isQuestComplete", function(questId:Int):Bool {
            return Api.quest.isComplete(questId);
        });
        _interp.variables.set("isQuestAccepted", function(questId:Int):Bool {
            return Api.quest.isAccepted(questId);
        });
        _interp.variables.set("isQuestAvailable", function(questId:Int):Bool {
            return Api.quest.isAvailable(questId);
        });
        _interp.variables.set("isQuestUnlocked", function(questId:Int):Bool {
            return Api.quest.isUnlocked(questId);
        });
        _interp.variables.set("hasBeenCompleted", function(questId:Int):Bool {
            return Api.quest.hasBeenCompleted(questId);
        });
        _interp.variables.set("isDailyComplete", function(questId:Int):Bool {
            return Api.quest.isDailyComplete(questId);
        });
        _interp.variables.set("canCompleteQuest", function(questId:Int):Bool {
            return Api.quest.canComplete(questId);
        });
        _interp.variables.set("canTurnInQuest", function(questId:Int):Bool {
            return Api.quest.canComplete(questId);
        });
        _interp.variables.set("canTurnIn", function(questId:Int):Bool {
            return Api.quest.canComplete(questId);
        });
        _interp.variables.set("getQuestValue", function(slot:Int):Int {
            return Api.quest.getQuestValue(slot);
        });
        _interp.variables.set("dropCombat", function():Void {
            Api.combat.dropCombat();
        });
        _interp.variables.set("cancelAutoAttack", function():Void {
            Api.combat.cancelAutoAttack();
        });
        _interp.variables.set("cancelTarget", function():Void {
            Api.combat.cancelTarget();
        });
        _interp.variables.set("pauseCombat", function():Void {
            Api.combat.pauseCombat();
        });
        _interp.variables.set("pauseAttack", function():Void {
            Api.combat.pauseCombat();
        });
        _interp.variables.set("approach", function():Void {
            Api.combat.approachTarget();
        });
        _interp.variables.set("approachTarget", function():Void {
            Api.combat.approachTarget();
        });
        _interp.variables.set("attackTarget", function(target:Dynamic = null):Void {
            if (target == null) {
                Api.combat.attack("*");
            } else if (Reflect.hasField(target, "mapId")) {
                Api.combat.attack(Std.string(Reflect.field(target, "mapId")));
            } else {
                Api.combat.attack(Std.string(target));
            }
            Api.combat.approachTarget();
        });
        _interp.variables.set("setInfiniteRange", function(enabled:Bool = true):Void {
            Api.combat.setInfiniteRange(enabled);
        });
        _interp.variables.set("infiniteRange", function(enabled:Bool = true):Void {
            Api.combat.setInfiniteRange(enabled);
        });
        _interp.variables.set("magnetize", function():Void {
            Api.combat.magnetize();
        });
        _interp.variables.set("setSpawnPoint", function(cell:String = null, pad:String = null):Void {
            Api.player.setSpawnPoint(cell, pad);
        });
        _interp.variables.set("setDeathSpawn", function(enabled:Bool = true):Void {
            Api.map.autoDeathSpawn = enabled;
        });
        _interp.variables.set("deathSpawn", function(enabled:Bool = true):Void {
            Api.map.autoDeathSpawn = enabled;
        });
        _interp.variables.set("walkTo", function(x:Float, y:Float, speed:Float = 16):Void {
            if (Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null) {
                try {
                    var avt:Dynamic = Api.game.world.myAvatar;
                    if (avt.pMC != null) {
                        if (avt.pMC.walkTo != null) avt.pMC.walkTo(x, y, speed);
                        if (Api.game.world.pushMove != null) Api.game.world.pushMove(avt.pMC, x, y, speed);
                    }
                } catch (e:Dynamic) {}
            }
        });
        _interp.variables.set("useSkill", function(index:Int):Bool {
            return Api.combat.useSkill(index);
        });
        _interp.variables.set("canUseSkill", function(index:Int):Bool {
            return Api.combat.canUseSkill(index);
        });
        _interp.variables.set("equip", function(itemName:String):Void {
            Api.inventory.equip(itemName);
        });
        _interp.variables.set("equipPotion", function(itemName:String):Void {
            if (Api.inventory != null) Api.inventory.equipUsable(itemName);
        });
        _interp.variables.set("equipUsable", function(itemName:String):Void {
            if (Api.inventory != null) Api.inventory.equipUsable(itemName);
        });
        _interp.variables.set("refreshPotion", function(potionName:String, auraName:String = ""):Bool {
            var aName:String = (auraName != null && auraName != "") ? auraName : potionName;
            if (Api.player != null && Api.player.hasAura(aName)) return false;
            if (Api.inventory != null && Api.inventory.hasItem(potionName)) {
                Api.inventory.equipUsable(potionName);
            }
            if (Api.combat != null && Api.combat.canUseSkill(5)) {
                return Api.combat.useSkill(5);
            }
            return false;
        });
        _interp.variables.set("usePotion", function(potionName:String, auraName:String = ""):Bool {
            var aName:String = (auraName != null && auraName != "") ? auraName : potionName;
            if (Api.player != null && Api.player.hasAura(aName)) return false;
            if (Api.inventory != null && Api.inventory.hasItem(potionName)) {
                Api.inventory.equipUsable(potionName);
            }
            if (Api.combat != null && Api.combat.canUseSkill(5)) {
                return Api.combat.useSkill(5);
            }
            return false;
        });
        _interp.variables.set("equipClass", function(type:String):Bool {
            return Api.combat.equipLoadout(type);
        });
        _interp.variables.set("equipLoadout", function(type:String):Bool {
            return Api.combat.equipLoadout(type);
        });
        _interp.variables.set("stop", function():Void {
            stop();
        });
        _interp.variables.set("isCombatOn", function():Bool {
            return Api.combat != null && Api.combat.isAutoRunning;
        });
        _interp.variables.set("startCombat", function(smart:Bool = true):Void {
            if (Api.combat != null) {
                if (smart) Api.combat.startSmart();
                else Api.combat.startCustom("");
            }
        });
        _interp.variables.set("stopCombat", function():Void {
            if (Api.combat != null) Api.combat.stopAuto();
        });

        // Bank Operations
        _interp.variables.set("loadBank", function():Void {
            Api.inventory.loadBank();
        });
        _interp.variables.set("openBank", function():Void {
            Api.inventory.toggleBank();
        });
        _interp.variables.set("toggleBank", function():Void {
            Api.inventory.toggleBank();
        });
        _interp.variables.set("bank", function(itemName:String):Void {
            Api.inventory.bank(itemName);
        });
        _interp.variables.set("bankItem", function(itemName:String):Void {
            Api.inventory.bank(itemName);
        });
        _interp.variables.set("unbank", function(itemName:String):Void {
            Api.inventory.unbank(itemName);
        });
        _interp.variables.set("unbankItem", function(itemName:String):Void {
            Api.inventory.unbank(itemName);
        });
        _interp.variables.set("isInBank", function(itemNameOrId:String):Bool {
            return Api.inventory.isInBank(itemNameOrId);
        });
        _interp.variables.set("isBankLoaded", function():Bool {
            return Api.inventory.isBankLoaded;
        });

        // Inventory Capacity
        _interp.variables.set("isInventoryFull", function():Bool {
            return Api.inventory.isFull;
        });
        _interp.variables.set("isBagFull", function():Bool {
            return Api.inventory.isFull;
        });
        _interp.variables.set("freeSlots", function():Int {
            return Api.inventory.freeSlots;
        });
        _interp.variables.set("usedSlots", function():Int {
            return Api.inventory.usedSlots;
        });
        _interp.variables.set("maxSlots", function():Int {
            return Api.inventory.maxSlots;
        });

        // Shop Operations
        _interp.variables.set("loadShop", function(shopId:Int):Void {
            Api.shop.loadShop(shopId);
        });
        _interp.variables.set("buyItem", function(shopId:Dynamic, itemNameOrId:String = null, quantity:Int = 1):Void {
            if (itemNameOrId == null) {
                Api.shop.buyItem(Std.string(shopId), quantity);
            } else {
                var sId:Int = ApiUtils.parseInt(shopId, 0);
                if (sId > 0 && !Api.shop.isShopLoaded) Api.shop.loadShop(sId);
                Api.shop.buyItem(itemNameOrId, quantity);
            }
        });
        _interp.variables.set("sellItem", function(itemNameOrId:String, quantity:Int = 1):Void {
            Api.shop.sellItem(itemNameOrId, quantity);
        });
        _interp.variables.set("isShopLoaded", function():Bool {
            return Api.shop.isShopLoaded;
        });

        // Packets & Network
        _interp.variables.set("sendPacket", function(packet:String):Void {
            if (Api.game != null && Api.game.sfc != null) {
                Api.game.sfc.sendString(packet);
            }
        });
        _interp.variables.set("sendXt", function(cmd:String, args:Array<Dynamic> = null):Void {
            if (Api.transport != null) {
                Api.transport.sendExtensionCommand(cmd, args != null ? args : []);
            }
        });
        _interp.variables.set("dungeonQueue", function(mapName:String, roomNum:Int = -1):Void {
            Api.map.dungeonQueue(mapName, roomNum);
        });
        _interp.variables.set("setPrivateRoom", function(enabled:Bool, roomNumber:Int = 100000):Void {
            Api.map.usePrivateRoom = enabled;
            if (roomNumber > 0) Api.map.privateRoomNumber = roomNumber;
        });
        _interp.variables.set("isPrivateRoom", function():Bool {
            return Api.map.usePrivateRoom;
        });

        // Target & Auras
        _interp.variables.set("getTarget", function():Dynamic {
            return Api.player.target;
        });
        _interp.variables.set("hasTargetAura", function(auraName:String):Bool {
            var t = Api.player.target;
            if (t != null && t.hasAura(auraName)) return true;
            if (Api.player != null && Api.monster != null) {
                var cellMonsters = Api.monster.getByCell(Api.player.cell);
                for (m in cellMonsters) {
                    if (m != null && m.alive && m.hasAura(auraName)) return true;
                }
            }
            return false;
        });
        _interp.variables.set("hasPlayerAura", function(auraName:String):Bool {
            return Api.player.hasAura(auraName);
        });
        _interp.variables.set("targetHasAura", function(auraName:String):Bool {
            var t = Api.player.target;
            if (t != null && t.hasAura(auraName)) return true;
            if (Api.player != null && Api.monster != null) {
                var cellMonsters = Api.monster.getByCell(Api.player.cell);
                for (m in cellMonsters) {
                    if (m != null && m.alive && m.hasAura(auraName)) return true;
                }
            }
            return false;
        });
        _interp.variables.set("playerHasAura", function(auraName:String):Bool {
            return Api.player.hasAura(auraName);
        });
        _interp.variables.set("hasMonsterAura", function(auraName:String, cell:String = null):Bool {
            var c = (cell != null && cell != "") ? cell : (Api.player != null ? Api.player.cell : "");
            if (Api.monster != null) {
                var cellMonsters = Api.monster.getByCell(c);
                for (m in cellMonsters) {
                    if (m != null && m.alive && m.hasAura(auraName)) return true;
                }
            }
            return false;
        });
        _interp.variables.set("hasAura", function(auraName:String, targetOnly:Bool = false):Bool {
            if (!targetOnly && Api.player != null && Api.player.hasAura(auraName)) return true;
            var t = Api.player.target;
            if (t != null && t.hasAura(auraName)) return true;
            if (Api.player != null && Api.monster != null) {
                var cellMonsters = Api.monster.getByCell(Api.player.cell);
                for (m in cellMonsters) {
                    if (m != null && m.alive && m.hasAura(auraName)) return true;
                }
            }
            return false;
        });

        // Player Status Helpers
        _interp.variables.set("hpPercent", function():Float {
            if (Api.player == null || Api.player.maxHp <= 0) return 0.0;
            return Api.player.hp / Api.player.maxHp;
        });
        _interp.variables.set("mpPercent", function():Float {
            if (Api.player == null || Api.player.maxMp <= 0) return 0.0;
            return Api.player.mp / Api.player.maxMp;
        });
        _interp.variables.set("isAlive", function():Bool {
            return Api.player != null && Api.player.isAlive;
        });
        _interp.variables.set("isDead", function():Bool {
            return Api.player == null || !Api.player.isAlive;
        });
        _interp.variables.set("inCombat", function():Bool {
            return Api.player != null && Api.player.isInCombat;
        });
        _interp.variables.set("gold", function():Int {
            return (Api.player != null) ? Api.player.gold : 0;
        });
        _interp.variables.set("coins", function():Int {
            return (Api.player != null) ? Api.player.coins : 0;
        });
        _interp.variables.set("ac", function():Int {
            return (Api.player != null) ? Api.player.ac : 0;
        });
        _interp.variables.set("xp", function():Int {
            return (Api.player != null) ? Api.player.xp : 0;
        });
        _interp.variables.set("maxXp", function():Int {
            return (Api.player != null) ? Api.player.maxXp : 0;
        });
        _interp.variables.set("isMember", function():Bool {
            return (Api.player != null) && Api.player.isMember;
        });

        // Map & Cell Shortcuts
        _interp.variables.set("cell", function():String {
            return Api.player != null ? Api.player.cell : "";
        });
        _interp.variables.set("pad", function():String {
            return Api.player != null ? Api.player.pad : "";
        });
        _interp.variables.set("mapName", function():String {
            return Api.map != null ? Api.map.name : "";
        });
        _interp.variables.set("isCell", function(cellName:String):Bool {
            return Api.player != null && Api.player.cell.toLowerCase() == cellName.toLowerCase();
        });
        _interp.variables.set("isMap", function(mapName:String):Bool {
            return Api.map != null && Api.map.name.toLowerCase() == mapName.toLowerCase();
        });

        // Monster & Cell Query
        _interp.variables.set("isMonsterAliveInCell", function(cell:String):Bool {
            var list = Api.monster.getByCell(cell);
            for (m in list) {
                if (m != null && m.alive && m.hp > 0 && m.hasGraphic) return true;
            }
            return false;
        });
        _interp.variables.set("getLivingMonstersInCell", function(cell:String):Array<Dynamic> {
            var list = Api.monster.getByCell(cell);
            var res:Array<Dynamic> = [];
            for (m in list) {
                if (m != null && m.alive && m.hp > 0 && m.hasGraphic) res.push(m);
            }
            return res;
        });
        _interp.variables.set("isRoomClear", function(cell:String = null):Bool {
            var c = (cell != null && cell != "") ? cell : (Api.player != null ? Api.player.cell : "");
            var list = Api.monster.getByCell(c);
            for (m in list) {
                if (m != null && m.alive && m.hp > 0 && m.hasGraphic) return false;
            }
            return true;
        });
        _interp.variables.set("isCellClear", function(cell:String = null):Bool {
            var c = (cell != null && cell != "") ? cell : (Api.player != null ? Api.player.cell : "");
            var list = Api.monster.getByCell(c);
            for (m in list) {
                if (m != null && m.alive && m.hp > 0 && m.hasGraphic) return false;
            }
            return true;
        });
        _interp.variables.set("getMonsters", function(cell:String = null):Array<Dynamic> {
            var c = (cell != null && cell != "") ? cell : (Api.player != null ? Api.player.cell : "");
            var list = Api.monster.getByCell(c);
            var res:Array<Dynamic> = [];
            for (m in list) {
                if (m != null && m.alive && m.hp > 0 && m.hasGraphic) res.push(m);
            }
            return res;
        });
        _interp.variables.set("getFirstMonster", function(cell:String = null):Dynamic {
            var c = (cell != null && cell != "") ? cell : (Api.player != null ? Api.player.cell : "");
            var list = Api.monster.getByCell(c);
            for (m in list) {
                if (m != null && m.alive && m.hp > 0 && m.hasGraphic) return m;
            }
            return null;
        });

        // Cutscene & UI
        _interp.variables.set("skipCutscene", function():Void {
            if (Api.game != null) {
                try {
                    var g:Dynamic = Api.game;
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
        _interp.variables.set("ApiTime", com.aqwapi.utils.ApiTime);
        _interp.variables.set("now", function():Float {
            return ApiTime.now();
        });
        _interp.variables.set("time", function():Float {
            return ApiTime.now();
        });
        _interp.variables.set("ApiUtils", com.aqwapi.utils.ApiUtils);
        _interp.variables.set("ApiJson", com.aqwapi.utils.ApiJson);
        _interp.variables.set("ApiStorage", com.aqwapi.utils.ApiStorage);
        _interp.variables.set("isNaN", function(v:Dynamic):Bool {
            return ApiUtils.isNaN(v);
        });
        _interp.variables.set("parseInt", function(v:Dynamic):Null<Int> {
            return ApiUtils.parseInt(v);
        });
        _interp.variables.set("parseFloat", function(v:Dynamic):Float {
            return ApiUtils.parseFloat(v);
        });
        _interp.variables.set("delay", function(ms:Int, cb:Void->Void):Void {
            ApiTime.delay(ms, cb);
        });
    }

    public function loadScript(scriptCode:String):Bool {
        if ((Api.game == null || Api.game.world == null) && Api.game != null) {
            Api.init(Api.game);
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
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, msg));
            return false;
        } catch (e:Dynamic) {
            var msg = "Parse error: " + Std.string(e);
            ApiLogger.error("HScript", msg);
            statusText = msg;
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, msg));
            return false;
        }

        _resetSandbox();

        try {
            _interp.execute(_program);
        } catch (e:Dynamic) {
            var msg = "Execution error on load: " + Std.string(e);
            ApiLogger.error("HScript", msg);
            statusText = msg;
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, msg));
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
        if ((Api.game == null || Api.game.world == null) && Api.game != null) {
            Api.init(Api.game);
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
        if (Api.combat != null) Api.combat.setInfiniteRange(true);
        if (Api.map != null) Api.map.autoDeathSpawn = true;

        _timer.delay = tickInterval;
        _timer.start();
        statusText = "Running HScript...";
        Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.SCRIPT_STARTED, "HScript Started!"));
        ApiLogger.info("HScript", "HScript Started!");

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

        if (_hasOnStop) {
            try {
                var fn = _interp.variables.get("onStop");
                fn();
            } catch (e:Dynamic) {
                ApiLogger.error("HScript", "onStop error: " + Std.string(e));
            }
        }

        Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.SCRIPT_STOPPED, "HScript Stopped!"));
        ApiLogger.info("HScript", "HScript Stopped!");

        if (Api.quest != null) Api.quest.stopAuto();
        if (Api.combat != null) Api.combat.stopAuto();
        else CombatEngine.stop();
    }


    private function onTimerTick(e:TimerEvent):Void {
        if (!isRunning) return;
        if (Api.game == null || Api.game.world == null) return;

        var world = Api.game.world;
        if (world.myAvatar != null && world.myAvatar.dataLeaf != null && world.myAvatar.dataLeaf.intState == 0) {
            statusText = "Waiting for respawn...";
            return;
        }

        var now = ApiTime.now();
        if (waitTimer > 0 && now < waitTimer) return;

        if (_hasOnTick) {
            try {
                var fn = _interp.variables.get("onTick");
                fn();
            } catch (err:Dynamic) {
                _handleScriptError("onTick error: " + Std.string(err), err);
            }
        } else {
            var bgCombat = CombatEngine.IS_ON;
            var bgQuest = Api.quest != null && Api.quest.isAutoRunning;
            if (bgCombat || bgQuest) {
                statusText = bgCombat ? "Auto-combat running" : "Auto-quest running";
                return;
            }
            stop();
            statusText = "Script Finished!";
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "Script Finished!"));
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
        Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "HScript Error: " + msg));
        stop();
    }
}
