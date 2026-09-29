package com.aqwapi.scripting;

import com.aqwapi.Api;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiUtils;
import com.aqwapi.utils.ApiJson;
import com.aqwapi.utils.ApiStorage;
import com.aqwapi.managers.PresetManager;

/**
 * Normalized registry for all HScript sandbox variables and shortcuts.
 * Consolidates all top-level shortcuts and `bot.*` shortcuts in one dedicated canonical file.
 *
 * Any shortcut registered via `bind()` is automatically available BOTH as:
 *   1. `bot.<shortcut>(...)`  (e.g. `bot.hunt(...)`, `bot.isMap(...)`, `bot.ensure(...)`)
 *   2. `<shortcut>(...)`      (e.g. `hunt(...)`, `isMap(...)`, `ensure(...)`)
 */
class ScriptBindings {

    public static var shortcuts(default, null):Map<String, Dynamic> = new Map();
    private static var _initialized:Bool = false;

    public static inline function hasShortcut(name:String):Bool {
        ensureInitialized();
        return shortcuts.exists(name);
    }

    public static inline function getShortcut(name:String):Dynamic {
        ensureInitialized();
        return shortcuts.get(name);
    }

    public static inline function bind(name:String, fn:Dynamic):Void {
        shortcuts.set(name, fn);
    }

    public static function ensureInitialized(?engine:HScriptEngine):Void {
        if (_initialized) return;
        _initialized = true;

        registerMapShortcuts();
        registerCombatShortcuts();
        registerQuestShortcuts();
        registerInventoryShortcuts();
        registerDropShortcuts();
        registerShopAndBankShortcuts();
        registerPlayerStatusShortcuts();
        registerMonsterQueryShortcuts();
        registerNetworkShortcuts();
        registerEnhancementShortcuts();
        registerLoggingAndSystem(engine);
    }

    public static function registerAll(interp:ScriptInterp, engine:HScriptEngine):Void {
        if (interp == null) return;
        ensureInitialized(engine);

        // 1. Core Manager Namespaces (bot, api, map, combat, etc.)
        registerNamespaces(interp);

        // 2. All Shortcuts (copied to interp.variables for fast direct resolution)
        for (key in shortcuts.keys()) {
            interp.variables.set(key, shortcuts.get(key));
        }

        // 3. Std Libraries & Classes
        registerStdLibraries(interp);
    }

    /**
     * Core Manager Namespaces (e.g. bot, player, map, combat, etc.)
     */
    private static function registerNamespaces(interp:ScriptInterp):Void {
        interp.variables.set("api", Api);
        interp.variables.set("bot", Api);
        interp.variables.set("Api", Api);
        interp.variables.set("Bot", Api);
        interp.variables.set("player", Api.player);
        interp.variables.set("combat", Api.combat);
        interp.variables.set("aura", Api.aura);
        interp.variables.set("skills", Api.skills);
        interp.variables.set("map", Api.map);
        interp.variables.set("quest", Api.quest);
        interp.variables.set("quests", Api.quest);
        interp.variables.set("inventory", Api.inventory);
        interp.variables.set("drop", Api.drop);
        interp.variables.set("drops", Api.drop);
        interp.variables.set("shop", Api.shop);
        interp.variables.set("shops", Api.shop);
        interp.variables.set("monster", Api.monster);
        interp.variables.set("monsters", Api.monster);
        interp.variables.set("enhancement", Api.enhancement);
        interp.variables.set("enhancements", Api.enhancement);
        interp.variables.set("script", Api.script);
        interp.variables.set("events", Api.dispatcher);
    }

    /**
     * Map, Cell & Navigation Shortcuts
     */
    private static function registerMapShortcuts():Void {
        bind("join", function(mapName:String, cell:String = null, pad:String = null):Void {
            if (Api.map != null) Api.map.join(mapName, cell, pad);
        });
        bind("joinHouse", function(username:String = ""):Void {
            if (Api.map != null) Api.map.joinHouse(username);
        });
        bind("jump", function(cell:String, pad:String = null):Void {
            if (Api.map != null) Api.map.jump(cell, pad);
        });
        bind("snapTo", function(target:Dynamic):Void {
            if (Api.map != null) Api.map.snapTo(target);
        });
        bind("getMapItem", function(itemId:Int):Bool {
            return Api.map != null ? Api.map.getMapItem(itemId) : false;
        });

        // State & Position Queries
        bind("cell", function():String {
            return Api.player != null ? Api.player.cell : "";
        });
        bind("pad", function():String {
            return Api.player != null ? Api.player.pad : "";
        });
        bind("mapName", function():String {
            return Api.map != null ? Api.map.name : "";
        });
        bind("isCell", function(cellName:String):Bool {
            return Api.map != null ? Api.map.isCell(cellName) : false;
        });
        bind("isMap", function(mapName:String):Bool {
            return Api.map != null ? Api.map.isMap(mapName) : false;
        });
        bind("isAt", function(mapName:String, cellName:String = null):Bool {
            return Api.map != null ? Api.map.isAt(mapName, cellName) : false;
        });
        bind("isLoaded", function():Bool {
            return Api.map != null && Api.map.isLoaded;
        });

        // Ensure & Stay
        bind("ensureMap", function(mapName:String, cell:String = null, pad:String = null):Bool {
            return Api.map != null ? Api.map.ensure(mapName, cell, pad) : false;
        });
        bind("ensure", function(mapName:String, cell:String = null, pad:String = null):Bool {
            return Api.map != null ? Api.map.ensure(mapName, cell, pad) : false;
        });
        bind("ensureCell", function(cell:String, pad:String = null):Bool {
            if (Api.map == null) return false;
            if (Api.map.isCell(cell)) return true;
            Api.map.jump(cell, pad);
            return false;
        });
        bind("stay", function(mapName:String, cell:String = null, pad:String = null):Bool {
            return Api.map != null ? Api.map.stay(mapName, cell, pad) : false;
        });

        // Spawn points & movement
        bind("setSpawnPoint", function(cell:String = null, pad:String = null):Void {
            if (Api.player != null) Api.player.setSpawnPoint(cell, pad);
        });
        bind("setDeathSpawn", function(enabled:Bool = true):Void {
            if (Api.map != null) Api.map.autoDeathSpawn = enabled;
        });
        bind("deathSpawn", function(enabled:Bool = true):Void {
            if (Api.map != null) Api.map.autoDeathSpawn = enabled;
        });
        bind("walkTo", function(x:Float, y:Float, speed:Float = 16):Void {
            if (Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null) {
                try {
                    var avt:Dynamic = Api.game.world.myAvatar;
                    if (avt != null && avt.pMC != null) {
                        if (avt.pMC.walkTo != null) avt.pMC.walkTo(x, y, speed);
                        if (Api.game.world.pushMove != null) Api.game.world.pushMove(avt.pMC, x, y, speed);
                    }
                } catch (e:Dynamic) {}
            }
        });
        bind("getMapCells", function():Array<String> {
            return Api.map != null ? Api.map.getMapCells() : [];
        });
        bind("getCellPads", function():Array<String> {
            return Api.map != null ? Api.map.getCellPads() : [];
        });
        bind("getPads", function():Array<String> {
            return Api.map != null ? Api.map.getCellPads() : [];
        });
    }

    /**
     * Combat, Targeting & Hunting Shortcuts
     */
    private static function registerCombatShortcuts():Void {
        // High-level cross-map hunt & kill
        bind("hunt", function(monster:String, itemOrCount:Dynamic = null, qtyOrCallback:Dynamic = 1, mmidOrCallback:Dynamic = null, onComplete:Dynamic = null):Bool {
            return Api.combat != null ? Api.combat.hunt(monster, itemOrCount, qtyOrCallback, mmidOrCallback, onComplete) : false;
        });
        bind("kill", function(monster:String, itemOrCount:Dynamic = null, qtyOrCallback:Dynamic = 1, mmidOrCallback:Dynamic = null, onComplete:Dynamic = null):Bool {
            return Api.combat != null ? Api.combat.hunt(monster, itemOrCount, qtyOrCallback, mmidOrCallback, onComplete) : false;
        });
        bind("resetHunt", function():Void {
            if (Api.combat != null) Api.combat.resetHunt();
        });
        bind("huntQuest", function(questId:Int, monsterName:String = null, ?callback:Dynamic):Bool {
            return Api.combat != null ? Api.combat.huntQuest(questId, monsterName, callback) : false;
        });

        // Targeting & Direct Attack
        bind("attack", function(monster:Dynamic):Void {
            if (Api.combat != null) Api.combat.attack(Std.string(monster));
        });
        bind("selectTarget", function(monster:Dynamic):Void {
            if (Api.combat != null) Api.combat.selectTarget(Std.string(monster));
        });
        bind("target", function(monster:Dynamic):Void {
            if (Api.combat != null) Api.combat.selectTarget(Std.string(monster));
        });
        bind("attackTarget", function(target:Dynamic = null):Void {
            if (Api.combat == null) return;
            if (target == null) {
                Api.combat.attack("*");
            } else if (Reflect.hasField(target, "mapId")) {
                Api.combat.attack(Std.string(Reflect.field(target, "mapId")));
            } else {
                Api.combat.attack(Std.string(target));
            }
            Api.combat.approachTarget();
        });
        bind("dropCombat", function():Void {
            if (Api.combat != null) Api.combat.dropCombat();
        });
        bind("reload", function(pad:String = null):Void {
            if (Api.combat != null) Api.combat.dropCombat();
            else if (Api.map != null) Api.map.reload(pad);
        });
        bind("reloadCell", function(pad:String = null):Void {
            if (Api.combat != null) Api.combat.dropCombat();
            else if (Api.map != null) Api.map.reload(pad);
        });
        bind("cancelAutoAttack", function():Void {
            if (Api.combat != null) Api.combat.cancelAutoAttack();
        });
        bind("cancelTarget", function():Void {
            if (Api.combat != null) Api.combat.cancelTarget();
        });
        bind("pauseCombat", function():Void {
            if (Api.combat != null) Api.combat.pauseCombat();
        });
        bind("pauseAttack", function():Void {
            if (Api.combat != null) Api.combat.pauseCombat();
        });
        bind("approach", function():Void {
            if (Api.combat != null) Api.combat.approachTarget();
        });
        bind("approachTarget", function():Void {
            if (Api.combat != null) Api.combat.approachTarget();
        });

        // Combat Engine Control
        bind("isCombatOn", function():Bool {
            return Api.combat != null && Api.combat.isAutoRunning;
        });
        bind("startCombat", function(smart:Bool = true):Void {
            if (Api.combat != null) {
                if (smart) Api.combat.startSmart();
                else Api.combat.startCustom("");
            }
        });
        bind("stopCombat", function():Void {
            if (Api.combat != null) Api.combat.stopCombat();
        });
        bind("endCombat", function():Void {
            if (Api.combat != null) Api.combat.stopCombat();
        });
        bind("stopAttack", function():Void {
            if (Api.combat != null) Api.combat.stopAttack();
        });
        bind("ensureCombat", function(smart:Bool = true):Void {
            if (Api.combat != null) Api.combat.ensure(smart);
        });

        // Skill execution & loadouts
        bind("useSkill", function(index:Int):Bool {
            return Api.combat != null ? Api.combat.useSkill(index) : false;
        });
        bind("canUseSkill", function(index:Int):Bool {
            return Api.combat != null ? Api.combat.canUseSkill(index) : false;
        });
        bind("equipClass", function(type:String):Bool {
            return Api.combat != null ? Api.combat.equipLoadout(type) : false;
        });
        bind("equipLoadout", function(type:String):Bool {
            return Api.combat != null ? Api.combat.equipLoadout(type) : false;
        });

        // Infinite Range & Magnetize
        bind("setInfiniteRange", function(enabled:Bool = true):Void {
            if (Api.combat != null) Api.combat.setInfiniteRange(enabled);
        });
        bind("infiniteRange", function(enabled:Bool = true):Void {
            if (Api.combat != null) Api.combat.setInfiniteRange(enabled);
        });
        bind("magnetize", function():Void {
            if (Api.combat != null) Api.combat.magnetize();
        });
    }

    /**
     * Quest Automation & Operations
     */
    private static function registerQuestShortcuts():Void {
        bind("autoQuest", function(quests:Dynamic):Void {
            if (Api.quest != null) Api.quest.startAuto(quests);
        });
        bind("auto", function(quests:Dynamic):Void {
            if (Api.quest != null) Api.quest.startAuto(quests);
        });
        bind("stopAutoQuest", function():Void {
            if (Api.quest != null) Api.quest.stopAuto();
        });
        bind("isAutoQuestRunning", function():Bool {
            return Api.quest != null && Api.quest.isAutoRunning;
        });

        bind("loadQuest", function(questId:Int):Void {
            if (Api.quest != null) Api.quest.load(questId);
        });
        bind("loadQuests", function(questIds:Dynamic):Void {
            if (Api.quest == null) return;
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
        bind("isQuestLoaded", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.isLoaded(questId) : false;
        });
        bind("showQuests", function(questIds:Dynamic):Void {
            if (Api.quest != null) Api.quest.showQuests(Std.string(questIds));
        });
        bind("openQuest", function(questId:Int):Void {
            if (Api.quest != null) Api.quest.showQuests(Std.string(questId));
        });

        bind("acceptQuest", function(questId:Int):Void {
            if (Api.quest != null) Api.quest.accept(questId);
        });
        bind("acceptQuests", function(questIds:Dynamic):Void {
            if (Api.quest == null) return;
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
        bind("ensureAccept", function(questId:Int):Void {
            if (Api.quest == null) return;
            if (!Api.quest.isAccepted(questId)) {
                if (!Api.quest.isLoaded(questId)) Api.quest.load(questId);
                Api.quest.accept(questId);
            }
        });
        bind("ensureQuest", function(questId:Int):Void {
            if (Api.quest == null) return;
            if (!Api.quest.isAccepted(questId)) {
                if (!Api.quest.isLoaded(questId)) Api.quest.load(questId);
                Api.quest.accept(questId);
            }
        });
        bind("ensureComplete", function(questId:Int, ?arg1:Dynamic, ?arg2:Dynamic):Bool {
            if (Api.quest == null) return false;
            return Api.quest.ensureComplete(questId, arg1, arg2);
        });
        bind("ensureCompleteChoose", function(questId:Int, ?preferredItems:Dynamic):Bool {
            return Api.quest != null ? Api.quest.ensureCompleteChoose(questId, preferredItems) : false;
        });
        bind("isChoiceQuest", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.isChoiceQuest(questId) : false;
        });
        bind("getChoiceRewards", function(questId:Int):Array<Dynamic> {
            return Api.quest != null ? Api.quest.getChoiceRewards(questId) : [];
        });
        bind("getUnownedRewards", function(questId:Int):Array<Dynamic> {
            return Api.quest != null ? Api.quest.getUnownedRewards(questId) : [];
        });
        bind("getNextUnownedReward", function(questId:Int, ?preferredItems:Dynamic):Dynamic {
            return Api.quest != null ? Api.quest.getNextUnownedReward(questId, preferredItems) : null;
        });

        bind("completeQuest", function(questId:Int, ?rewardChoice:Dynamic):Void {
            if (Api.quest != null) Api.quest.complete(questId, rewardChoice);
        });
        bind("completeQuests", function(questIds:Dynamic):Void {
            if (Api.quest == null) return;
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
        bind("turnIn", function(questId:Int, itemId:Int = -1):Void {
            if (Api.quest != null) Api.quest.complete(questId, itemId);
        });
        bind("turnInQuests", function(questIds:Dynamic):Void {
            if (Api.quest == null) return;
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

        bind("isQuestComplete", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.isComplete(questId) : false;
        });
        bind("isQuestAccepted", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.isAccepted(questId) : false;
        });
        bind("isQuestAvailable", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.isAvailable(questId) : false;
        });
        bind("isQuestUnlocked", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.isUnlocked(questId) : false;
        });
        bind("hasBeenCompleted", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.hasBeenCompleted(questId) : false;
        });
        bind("isDailyComplete", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.isDailyComplete(questId) : false;
        });
        bind("canCompleteQuest", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.canComplete(questId) : false;
        });
        bind("canTurnInQuest", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.canComplete(questId) : false;
        });
        bind("canTurnIn", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.canComplete(questId) : false;
        });
        bind("getQuestValue", function(slot:Int):Int {
            return Api.quest != null ? Api.quest.getQuestValue(slot) : 0;
        });
    }

    /**
     * Inventory, Items & Potions
     */
    private static function registerInventoryShortcuts():Void {
        bind("hasItem", function(itemName:String, quantity:Int = 1):Bool {
            return Api.inventory != null ? Api.inventory.hasItem(itemName, quantity) : false;
        });
        bind("getItemCount", function(itemName:String):Int {
            return Api.inventory != null ? Api.inventory.getItemCount(itemName) : 0;
        });
        bind("equip", function(itemName:String):Void {
            if (Api.inventory != null) Api.inventory.equip(itemName);
        });
        bind("ensureEquipped", function(itemName:String):Bool {
            if (Api.inventory == null) return false;
            if (Api.inventory.isEquipped(itemName)) return true;
            Api.inventory.equip(itemName);
            return false;
        });
        bind("ensureEquip", function(itemName:String):Bool {
            if (Api.inventory == null) return false;
            if (Api.inventory.isEquipped(itemName)) return true;
            Api.inventory.equip(itemName);
            return false;
        });
        bind("equipPotion", function(itemName:String):Void {
            if (Api.inventory != null) Api.inventory.equipUsable(itemName);
        });
        bind("equipUsable", function(itemName:String):Void {
            if (Api.inventory != null) Api.inventory.equipUsable(itemName);
        });
        bind("refreshPotion", function(potionName:String, auraName:String = ""):Bool {
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
        bind("usePotion", function(potionName:String, auraName:String = ""):Bool {
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

        // Inventory Capacity
        bind("isInventoryFull", function():Bool {
            return Api.inventory != null && Api.inventory.isFull;
        });
        bind("isBagFull", function():Bool {
            return Api.inventory != null && Api.inventory.isFull;
        });
        bind("freeSlots", function():Int {
            return Api.inventory != null ? Api.inventory.freeSlots : 0;
        });
        bind("usedSlots", function():Int {
            return Api.inventory != null ? Api.inventory.usedSlots : 0;
        });
        bind("maxSlots", function():Int {
            return Api.inventory != null ? Api.inventory.maxSlots : 0;
        });
    }

    /**
     * Drops
     */
    private static function registerDropShortcuts():Void {
        var fnAcceptAC:Dynamic = function(?enabled:Dynamic):Void {
            var b:Bool = (enabled == null || enabled == true || enabled == 1 || enabled == "true");
            if (enabled == false || enabled == 0 || enabled == "false") b = false;
            if (Api.drop != null) Api.drop.acceptACDrops(b);
        };
        var fnAcceptAll:Dynamic = function(?enabled:Dynamic):Void {
            var b:Bool = (enabled == null || enabled == true || enabled == 1 || enabled == "true");
            if (enabled == false || enabled == 0 || enabled == "false") b = false;
            if (Api.drop != null) Api.drop.acceptAllDrops(b);
        };

        // Normalized primary function names
        bind("acceptAllDrops", fnAcceptAll);
        bind("acceptAcdrops", fnAcceptAC);
        bind("acceptAcDrops", fnAcceptAC);
        bind("acceptACDrops", fnAcceptAC);

        // Backward compatibility
        bind("acceptACs", fnAcceptAC);
        bind("acceptAll", fnAcceptAll);
        bind("getDrop", function(drops:Dynamic):Void {
            if (Api.drop == null) return;
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
        bind("getDrops", function(drops:Dynamic = "all"):Void {
            if (Api.drop == null) return;
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
    }

    /**
     * Shop & Bank Shortcuts
     */
    private static function registerShopAndBankShortcuts():Void {
        bind("loadShop", function(shopId:Int):Void {
            if (Api.shop != null) Api.shop.loadShop(shopId);
        });
        bind("buyItem", function(shopId:Dynamic, itemNameOrId:String = null, quantity:Int = 1):Void {
            if (Api.shop == null) return;
            if (itemNameOrId == null) {
                Api.shop.buyItem(Std.string(shopId), quantity);
            } else {
                var sId:Int = ApiUtils.parseInt(shopId, 0);
                if (sId > 0 && !Api.shop.isShopLoaded) Api.shop.loadShop(sId);
                Api.shop.buyItem(itemNameOrId, quantity);
            }
        });
        bind("sellItem", function(itemNameOrId:String, quantity:Int = 1):Void {
            if (Api.shop != null) Api.shop.sellItem(itemNameOrId, quantity);
        });
        bind("isShopLoaded", function():Bool {
            return Api.shop != null && Api.shop.isShopLoaded;
        });

        // Bank
        bind("loadBank", function():Void {
            if (Api.inventory != null) Api.inventory.loadBank();
        });
        bind("openBank", function():Void {
            if (Api.inventory != null) Api.inventory.toggleBank();
        });
        bind("toggleBank", function():Void {
            if (Api.inventory != null) Api.inventory.toggleBank();
        });
        bind("bank", function(items:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.bank(items);
        });
        bind("bankItem", function(items:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.bank(items);
        });
        bind("bankAll", function(?exclude:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.bankAll(exclude);
        });
        bind("bankAllExcept", function(exclude:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.bankAllExcept(exclude);
        });
        bind("isBanking", function():Bool {
            return Api.inventory != null && Api.inventory.isBanking;
        });
        bind("getBankableItems", function(?exclude:Dynamic):Array<String> {
            return Api.inventory != null ? Api.inventory.getBankableItems(exclude) : [];
        });
        bind("unbank", function(items:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.unbank(items);
        });
        bind("unbankItem", function(items:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.unbank(items);
        });
        bind("unbankPreset", function(presetName:String):Void {
            if (Api.inventory != null) Api.inventory.unbankPreset(presetName);
        });
        bind("ensureUnbanked", function(items:Dynamic):Bool {
            return Api.inventory != null ? Api.inventory.ensureUnbanked(items) : true;
        });
        bind("ensurePresetUnbanked", function(presetName:String):Bool {
            return Api.inventory != null ? Api.inventory.ensurePresetUnbanked(presetName) : true;
        });
        bind("getPresetItems", function(presetName:String):Array<String> {
            return PresetManager.instance.getPresetItems(presetName);
        });
        bind("hasPreset", function(presetName:String):Bool {
            return PresetManager.instance.hasPreset(presetName);
        });
        bind("getPresetNames", function():Array<String> {
            return PresetManager.instance.getPresetNames();
        });
        bind("isUnbanking", function():Bool {
            return Api.inventory != null && Api.inventory.isUnbanking;
        });
        bind("isInBank", function(itemNameOrId:String):Bool {
            return Api.inventory != null ? Api.inventory.isInBank(itemNameOrId) : false;
        });
        bind("isBankLoaded", function():Bool {
            return Api.inventory != null && Api.inventory.isBankLoaded;
        });
    }

    /**
     * Player Status & Auras
     */
    private static function registerPlayerStatusShortcuts():Void {
        bind("hp", function():Int {
            return Api.player != null ? Api.player.hp : 0;
        });
        bind("maxHp", function():Int {
            return Api.player != null ? Api.player.maxHp : 0;
        });
        bind("hpPercent", function():Float {
            if (Api.player == null || Api.player.maxHp <= 0) return 0.0;
            return Api.player.hp / Api.player.maxHp;
        });
        bind("mp", function():Int {
            return Api.player != null ? Api.player.mp : 0;
        });
        bind("maxMp", function():Int {
            return Api.player != null ? Api.player.maxMp : 0;
        });
        bind("mpPercent", function():Float {
            if (Api.player == null || Api.player.maxMp <= 0) return 0.0;
            return Api.player.mp / Api.player.maxMp;
        });
        bind("level", function():Int {
            return Api.player != null ? Api.player.level : 0;
        });
        bind("isAlive", function():Bool {
            return Api.player != null && Api.player.isAlive;
        });
        bind("isDead", function():Bool {
            return Api.player == null || !Api.player.isAlive;
        });
        bind("inCombat", function():Bool {
            return Api.player != null && Api.player.isInCombat;
        });
        bind("isInCombat", function():Bool {
            return Api.player != null && Api.player.isInCombat;
        });
        bind("isReady", function():Bool {
            return Api.isReady;
        });
        bind("rest", function():Void {
            if (Api.player != null) Api.player.rest();
        });
        bind("isResting", function():Bool {
            return Api.player != null && Api.player.isResting;
        });
        bind("gold", function():Int {
            return Api.player != null ? Api.player.gold : 0;
        });
        bind("coins", function():Int {
            return Api.player != null ? Api.player.coins : 0;
        });
        bind("ac", function():Int {
            return Api.player != null ? Api.player.ac : 0;
        });
        bind("xp", function():Int {
            return Api.player != null ? Api.player.xp : 0;
        });
        bind("maxXp", function():Int {
            return Api.player != null ? Api.player.maxXp : 0;
        });
        bind("isMember", function():Bool {
            return Api.player != null && Api.player.isMember;
        });

        // Target & Auras
        bind("getTarget", function():Dynamic {
            return Api.player != null ? Api.player.target : null;
        });
        bind("hasTargetAura", function(auraName:String):Bool {
            var t = (Api.player != null) ? Api.player.target : null;
            if (t != null && t.hasAura(auraName)) return true;
            if (Api.player != null && Api.monster != null) {
                var cellMonsters = Api.monster.getByCell(Api.player.cell);
                for (m in cellMonsters) {
                    if (m != null && m.alive && m.hasAura(auraName)) return true;
                }
            }
            return false;
        });
        bind("hasPlayerAura", function(auraName:String):Bool {
            return Api.player != null ? Api.player.hasAura(auraName) : false;
        });
        bind("targetHasAura", function(auraName:String):Bool {
            var t = (Api.player != null) ? Api.player.target : null;
            if (t != null && t.hasAura(auraName)) return true;
            if (Api.player != null && Api.monster != null) {
                var cellMonsters = Api.monster.getByCell(Api.player.cell);
                for (m in cellMonsters) {
                    if (m != null && m.alive && m.hasAura(auraName)) return true;
                }
            }
            return false;
        });
        bind("playerHasAura", function(auraName:String):Bool {
            return Api.player != null ? Api.player.hasAura(auraName) : false;
        });
        bind("hasMonsterAura", function(auraName:String, cell:String = null):Bool {
            var c = (cell != null && cell != "") ? cell : (Api.player != null ? Api.player.cell : "");
            if (Api.monster != null) {
                var cellMonsters = Api.monster.getByCell(c);
                for (m in cellMonsters) {
                    if (m != null && m.alive && m.hasAura(auraName)) return true;
                }
            }
            return false;
        });
        bind("hasAura", function(auraName:String, targetOnly:Bool = false):Bool {
            if (!targetOnly && Api.player != null && Api.player.hasAura(auraName)) return true;
            var t = (Api.player != null) ? Api.player.target : null;
            if (t != null && t.hasAura(auraName)) return true;
            if (Api.player != null && Api.monster != null) {
                var cellMonsters = Api.monster.getByCell(Api.player.cell);
                for (m in cellMonsters) {
                    if (m != null && m.alive && m.hasAura(auraName)) return true;
                }
            }
            return false;
        });
    }

    /**
     * Monster & Cell Clearing Queries
     */
    private static function registerMonsterQueryShortcuts():Void {
        bind("isMonsterAliveInCell", function(cell:String):Bool {
            return Api.monster != null ? Api.monster.isMonsterAliveInCell(cell) : false;
        });
        bind("getLivingMonstersInCell", function(cell:String):Array<Dynamic> {
            return Api.monster != null ? cast Api.monster.getLivingMonstersInCell(cell) : [];
        });
        bind("isRoomClear", function(cell:String = null):Bool {
            var c = (cell != null && cell != "") ? cell : (Api.player != null ? Api.player.cell : "");
            return Api.monster != null ? !Api.monster.isMonsterAliveInCell(c) : true;
        });
        bind("isCellClear", function(cell:String = null):Bool {
            var c = (cell != null && cell != "") ? cell : (Api.player != null ? Api.player.cell : "");
            return Api.monster != null ? !Api.monster.isMonsterAliveInCell(c) : true;
        });
        bind("getMonsters", function(cell:String = null):Array<Dynamic> {
            var c = (cell != null && cell != "") ? cell : (Api.player != null ? Api.player.cell : "");
            return Api.monster != null ? cast Api.monster.getByCell(c) : [];
        });
        bind("getFirstMonster", function(cell:String = null):Dynamic {
            var c = (cell != null && cell != "") ? cell : (Api.player != null ? Api.player.cell : "");
            if (Api.monster != null) {
                var list = Api.monster.getByCell(c);
                for (m in list) {
                    if (m != null && m.alive && m.hp > 0 && m.hasGraphic) return m;
                }
            }
            return null;
        });
        bind("getMapMonsters", function():Array<Dynamic> {
            return Api.monster != null ? Api.monster.getMapMonsters() : [];
        });
        bind("getMapMonsterNames", function():Array<String> {
            return Api.monster != null ? Api.monster.getMapMonsterNames() : [];
        });
    }

    /**
     * Network, Packets & Dungeons
     */
    private static function registerNetworkShortcuts():Void {
        bind("sendPacket", function(packet:String):Void {
            if (Api.game != null && Api.game.sfc != null) {
                Api.game.sfc.sendString(packet);
            }
        });
        bind("sendXt", function(cmd:String, args:Array<Dynamic> = null):Void {
            if (Api.transport != null) {
                Api.transport.sendExtensionCommand(cmd, args != null ? args : []);
            }
        });
        bind("dungeonQueue", function(mapName:String, roomNum:Int = -1):Void {
            if (Api.map != null) Api.map.dungeonQueue(mapName, roomNum);
        });
        bind("setPrivateRoom", function(enabled:Bool, roomNumber:Int = 100000):Void {
            if (Api.map != null) {
                Api.map.usePrivateRoom = enabled;
                if (roomNumber > 0) Api.map.privateRoomNumber = roomNumber;
            }
        });
        bind("isPrivateRoom", function():Bool {
            return Api.map != null && Api.map.usePrivateRoom;
        });
    }

    /**
     * Enhancement Shortcuts
     */
    private static function registerEnhancementShortcuts():Void {
        bind("smartEnhance", function(?a:Dynamic, ?b:Dynamic, ?c:Dynamic):Void {
            if (Api.enhancement != null) Api.enhancement.smartEnhance(a, b, c);
        });
        bind("enhanceEquipped", function(?a:Dynamic, ?b:Dynamic, ?c:Dynamic, ?d:Dynamic, ?e:Dynamic):Void {
            if (Api.enhancement != null) Api.enhancement.enhanceEquipped(a, b, c, d, e);
        });
        bind("enhanceItem", function(?a:Dynamic, ?b:Dynamic, ?c:Dynamic, ?d:Dynamic, ?e:Dynamic, ?f:Dynamic):Void {
            if (Api.enhancement != null) Api.enhancement.enhanceItem(a, b, c, d, e, f);
        });
        bind("isAweUnlocked", function():Bool {
            return Api.enhancement != null && Api.enhancement.isAweUnlocked();
        });
        bind("isForgeUnlocked", function(name:String):Bool {
            return Api.enhancement != null && Api.enhancement.isForgeUnlocked(name);
        });
        bind("isEnhancing", function():Bool {
            return Api.enhancement != null && Api.enhancement.isBusy;
        });
        bind("isEnhanceBusy", function():Bool {
            return Api.enhancement != null && Api.enhancement.isBusy;
        });
    }

    /**
     * Logging, Sleep & System Controls
     */
    private static function registerLoggingAndSystem(engine:HScriptEngine):Void {
        bind("log", function(msg:Dynamic):Void {
            ApiLogger.info("HScript", Std.string(msg));
        });
        bind("warn", function(msg:Dynamic):Void {
            ApiLogger.warn("HScript", Std.string(msg));
        });
        bind("error", function(msg:Dynamic):Void {
            ApiLogger.error("HScript", Std.string(msg));
        });
        bind("clearLog", function():Void {
            ApiLogger.clearLog();
        });
        bind("notify", function(msg:Dynamic):Void {
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, Std.string(msg)));
        });

        bind("sleep", function(ms:Float):Void {
            HScriptEngine.SINGLETON.sleep(ms);
        });
        bind("stop", function():Void {
            HScriptEngine.SINGLETON.stop();
        });
        bind("skipCutscene", function():Void {
            if (Api.game != null) {
                try {
                    var w:Dynamic = Api.game.world;
                    if (w != null) {
                        if (Reflect.hasField(w, "cHandle") && w.cHandle != null) {
                            try { w.cHandle.cancel(); } catch (e:Dynamic) {}
                        }
                        if (Reflect.hasField(w, "objSession") && w.objSession != null && w.strMapName != null) {
                            try {
                                var sName:String = Std.string(w.strMapName);
                                var sess:Dynamic = Reflect.field(w.objSession, sName);
                                if (sess != null) Reflect.setField(sess, "seenIt0", true);
                            } catch (e:Dynamic) {}
                        }
                    }
                } catch (e:Dynamic) {}
            }
        });
    }

    /**
     * Standard Libraries & Math Helpers
     */
    private static function registerStdLibraries(interp:ScriptInterp):Void {
        interp.variables.set("Math", Math);
        interp.variables.set("Std", Std);
        interp.variables.set("StringTools", StringTools);
        interp.variables.set("Date", Date);
        interp.variables.set("ApiTime", ApiTime);
        interp.variables.set("now", function():Float {
            return ApiTime.now();
        });
        interp.variables.set("time", function():Float {
            return ApiTime.now();
        });
        interp.variables.set("ApiUtils", ApiUtils);
        interp.variables.set("ApiJson", ApiJson);
        interp.variables.set("ApiStorage", ApiStorage);
        interp.variables.set("isNaN", function(v:Dynamic):Bool {
            return Math.isNaN(v);
        });
        interp.variables.set("parseInt", function(v:Dynamic):Null<Int> {
            return ApiUtils.parseInt(v, 0);
        });
        interp.variables.set("parseFloat", function(v:Dynamic):Float {
            return ApiUtils.parseFloat(v, 0.0);
        });
        interp.variables.set("delay", function(ms:Int, cb:Void->Void):Void {
            ApiTime.delay(ms, cb);
        });
    }
}
