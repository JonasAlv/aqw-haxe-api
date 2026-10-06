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
 * Normalized registry for HScript sandbox variables, shortcuts, and namespaces.
 *
 * Core Primitives: The ~40 high-frequency functions used in .hxs scripts (quest, hunt,
 * mapItem, complete, ensureMap, etc.) are available as clean top-level functions.
 *
 * Subsystems & Advanced APIs: Specialized properties and methods are accessible via
 * their first-class namespaces: player, combat, map, quests, inventory, bank, drop,
 * shop, monster, aura, enhancement, blacklist, api, bot.
 */
class ScriptBindings {

    public static var shortcuts(default, null):Map<String, Dynamic> = new Map();
    private static var _initialized:Bool = false;
    private static var _mapItemGrabCount:Map<String, Int> = new Map();
    private static var _reqToMonsterMap:Map<String, String> = new Map();

    public static function resetStoryData():Void {
        _mapItemGrabCount = new Map();
        _reqToMonsterMap = new Map();
    }

    /**
     * Clears the monster guesses recorded for one quest.
     *
     * `_mapItemGrabCount` is deliberately left alone: grab history is keyed by item and map, not by
     * quest, so completing an unrelated quest must not make `mapItem()` re-request items it already
     * counted. Clearing those is `resetMapItems()`' job, and `resetStoryData()` clears everything.
     */
    private static function _cleanQuestStoryData(questId:Dynamic):Void {
        var qid = ApiUtils.parseInt(questId, 0);
        var prefix = (qid > 0 ? Std.string(qid) : Std.string(questId)) + "_";
        var monsterKeys:Array<String> = [];
        for (k in _reqToMonsterMap.keys()) {
            if (StringTools.startsWith(k, prefix)) monsterKeys.push(k);
        }
        for (k in monsterKeys) _reqToMonsterMap.remove(k);
    }

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

    public static function ensureInitialized():Void {
        if (_initialized) return;
        _initialized = true;

        registerMapShortcuts();
        registerCombatShortcuts();
        registerQuestShortcuts();
        registerInventoryShortcuts();
        registerDropShortcuts();
        registerShopAndBankShortcuts();
        registerPlayerStatusShortcuts();
        registerLoggingAndSystem();
    }

    public static function registerAll(interp:ScriptInterp):Void {
        if (interp == null) return;
        ensureInitialized();

        // 1. All Top-Level Shortcuts (copied to interp.variables for fast direct resolution)
        for (key in shortcuts.keys()) {
            interp.variables.set(key, shortcuts.get(key));
        }

        // 2. Std Libraries & Classes
        //    Namespaces and utils are not registered here: ScriptInterp.resolve() answers them on
        //    every reference, so a snapshot taken now would be dead weight to keep in sync.
        registerStdLibraries(interp);
    }

    // -------------------------------------------------------------------------
    // 1. Map & Navigation Primitives
    // -------------------------------------------------------------------------

    private static function registerMapShortcuts():Void {
        bind("join", function(mapName:String, cell:String = null, pad:String = null):Void {
            if (Api.map != null) Api.map.join(mapName, cell, pad);
        });
        bind("joinHouse", function(username:String = ""):Void {
            if (Api.map != null) Api.map.joinHouse(username);
        });
        bind("ensureHouse", function():Bool {
            return Api.map != null ? Api.map.ensureHouse() : false;
        });
        bind("isHouse", function():Bool {
            return Api.map != null ? Api.map.isHouse() : false;
        });
        bind("jump", function(cell:String, pad:String = null, autoCorrect:Bool = true):Void {
            if (Api.map != null) Api.map.jump(cell, pad, false, autoCorrect);
        });
        bind("jumpCorrect", function(cell:String, pad:String = null):Void {
            if (Api.map != null) Api.map.jump(cell, pad, true, true);
        });
        bind("autoCorrectJump", function(enable:Dynamic = null):Dynamic {
            if (Api.map == null) return false;
            if (enable != null) {
                Api.map.autoCorrectJump = (enable == true);
            }
            return Api.map.autoCorrectJump;
        });
        bind("getValidCellPads", function():Array<String> {
            return Api.map != null ? Api.map.getValidCellPads() : [];
        });
        bind("getCellPads", function():Array<String> {
            return Api.map != null ? Api.map.getCellPads() : [];
        });
        bind("getMapCells", function():Array<String> {
            return Api.map != null ? Api.map.getMapCells() : [];
        });
        bind("ensureMap", function(mapName:String, cell:String = null, pad:String = null):Bool {
            return Api.map != null ? Api.map.ensure(mapName, cell, pad) : false;
        });
        bind("ensureCell", function(cell:String, pad:String = null):Bool {
            if (Api.map == null) return false;
            if (Api.map.isCell(cell)) return true;
            Api.map.jump(cell, pad);
            return false;
        });
        /**
         * Raw single-item map pickup. Never tracks quantities and never reroutes through the flexible
         * signature below - the tracked, ensure-style variant is `ensureMapItem`/`mapItem`, where the
         * second argument is a quantity. Kept argument-free so the meaning of a call can never depend
         * on how many arguments were passed.
         */
        bind("getMapItem", function(itemId:Int):Bool {
            return Api.map != null ? Api.map.getMapItem(itemId) : false;
        });
        bind("cell", function():String {
            return Api.player != null ? Api.player.cell : "";
        });
        bind("getCell", function():String {
            return Api.player != null ? Api.player.cell : "";
        });
        bind("pad", function():String {
            return Api.player != null ? Api.player.pad : "";
        });
        bind("getPad", function():String {
            return Api.player != null ? Api.player.pad : "";
        });
        bind("mapName", function():String {
            return Api.map != null ? Api.map.name : "";
        });
        bind("getMapName", function():String {
            return Api.map != null ? Api.map.name : "";
        });
        bind("isCell", function(cellName:String):Bool {
            return Api.map != null ? Api.map.isCell(cellName) : false;
        });
        bind("isMap", function(mapName:String):Bool {
            return Api.map != null ? Api.map.isMap(mapName) : false;
        });
        bind("isLoaded", function():Bool {
            return Api.map != null && Api.map.isLoaded;
        });
        bind("setSkipCutscenes", function(enabled:Bool = true):Void {
            if (Api.map != null) Api.map.skipCutscenes = enabled;
        });
        bind("isSkipCutscenes", function():Bool {
            return Api.map != null && Api.map.skipCutscenes;
        });
        bind("skipCutscenes", function():Bool {
            return Api.map != null ? Api.map.skipCutscenesNow() : false;
        });
        bind("skipCutscene", function():Bool {
            return Api.map != null ? Api.map.skipCutscenesNow() : false;
        });
        bind("autoSkipCutscenes", function(enabled:Bool = true):Void {
            if (Api.map != null) Api.map.skipCutscenes = enabled;
        });
        bind("walkThroughWalls", function(enabled:Bool = true):Void {
            if (Api.map != null) Api.map.walkThroughWalls(enabled);
        });
        bind("disableCollisions", function(enabled:Bool = true):Void {
            if (Api.map != null) Api.map.setDisableCollisions(enabled);
        });
        bind("isTercess", function():Bool {
            return Api.map != null ? Api.map.isTercess() : false;
        });
        bind("ensureTercess", function(destination:String = "nulgath", pad:String = null):Bool {
            return Api.map != null ? Api.map.ensureTercess(destination, pad) : false;
        });
        bind("joinTercess", function(destination:String = "nulgath", pad:String = null):Void {
            if (Api.map != null) Api.map.joinTercess(destination, pad);
        });
        bind("fastTravel", function(destination:String):Bool {
            return Api.map != null ? Api.map.fastTravel(destination) : false;
        });
    }

    // -------------------------------------------------------------------------
    // 2. Combat & Loadouts Primitives
    // -------------------------------------------------------------------------

    private static function registerCombatShortcuts():Void {
        bind("hunt", function(monster:Dynamic, itemOrCount:Dynamic = null, qtyOrCallback:Dynamic = null, mmidOrCallback:Dynamic = null, onComplete:Dynamic = null):Bool {
            return Api.combat != null ? Api.combat.hunt(monster, itemOrCount, qtyOrCallback, mmidOrCallback, onComplete) : false;
        });
        bind("kill", function(monster:Dynamic, itemOrCount:Dynamic = null, qtyOrCallback:Dynamic = null, mmidOrCallback:Dynamic = null, onComplete:Dynamic = null):Bool {
            return Api.combat != null ? Api.combat.hunt(monster, itemOrCount, qtyOrCallback, mmidOrCallback, onComplete) : false;
        });
        bind("resetHunt", function():Void {
            if (Api.combat != null) Api.combat.resetHunt();
        });
        bind("huntItem", function(monster:Dynamic, item:Dynamic, quantity:Int = 1, ?mapName:String):Bool {
            if (Api.combat == null) return false;
            if (mapName != null && mapName != "" && Api.map != null) {
                if (!Api.map.ensure(mapName)) return false;
            }
            if (Api.inventory != null) {
                if (Api.inventory.hasItem(item, quantity) || Api.inventory.getQuestQuantity(item) >= quantity) {
                    return true;
                }
            }
            Api.combat.hunt(monster);
            return false;
        });
        bind("huntMonster", function(monster:Dynamic, kills:Int = 1, ?mapName:String):Bool {
            if (Api.combat == null) return false;
            if (mapName != null && mapName != "" && Api.map != null) {
                if (!Api.map.ensure(mapName)) return false;
            }
            return Api.combat.hunt(monster, kills);
        });
        bind("attack", function(monster:Dynamic):Void {
            if (Api.combat != null) Api.combat.attack(Std.string(monster));
        });
        bind("stopCombat", function():Void {
            if (Api.combat != null) Api.combat.stopCombat();
        });
        bind("counterHandler", function(enabled:Bool = true):Void {
            if (Api.combat != null) Api.combat.enableCounterHandler(enabled);
        });
        bind("enableCounterHandler", function(enabled:Bool = true):Void {
            if (Api.combat != null) Api.combat.enableCounterHandler(enabled);
        });
        bind("pauseOnAuras", function(auras:Dynamic):Void {
            if (Api.combat != null) Api.combat.pauseOnAuras(auras);
        });
        bind("clearPauseAuras", function():Void {
            if (Api.combat != null) Api.combat.clearPauseAuras();
        });
        bind("setTargetPriority", function(targets:Dynamic):Void {
            if (Api.combat != null) Api.combat.setTargetPriority(targets);
        });
        bind("setHuntPriority", function(priority:String):Void {
            if (Api.combat != null) Api.combat.setHuntPriority(priority);
        });
        bind("isPausedByAura", function():Bool {
            return Api.combat != null ? Api.combat.isPausedByAura : false;
        });
        bind("ensureCombat", function(smart:Bool = true):Void {
            if (Api.combat != null) Api.combat.ensure(smart);
        });
        bind("equipLoadout", function(type:String):Bool {
            return Api.combat != null ? Api.combat.equipLoadout(type) : false;
        });
        bind("getBestTarget", function(nameOrId:Dynamic = "*"):Dynamic {
            return Api.monster != null ? Api.monster.getBestMonsterTargetInCell(null, nameOrId) : null;
        });
        bind("getBestMonsterTarget", function(cell:String = null, nameOrId:Dynamic = "*"):Dynamic {
            return Api.monster != null ? Api.monster.getBestMonsterTargetInCell(cell, nameOrId) : null;
        });
        bind("sortByLowestHp", function(monsters:Array<Dynamic>):Array<Dynamic> {
            return Api.monster != null ? cast Api.monster.sortByLowestHp(cast monsters) : monsters;
        });
    }

    // -------------------------------------------------------------------------
    // 3. Quest & Story Progression Primitives
    // -------------------------------------------------------------------------

    private static function registerQuestShortcuts():Void {
        // High-level explicit step-by-step shortcuts
        bind("quest", function(questId:Dynamic, ?mapName:String):Bool {
            if (Api.quest == null) return false;
            if (Api.quest.hasBeenCompleted(questId)) return false;
            if (!Api.quest.isLoaded(questId)) {
                Api.quest.load(questId);
                return false;
            }
            if (mapName != null && mapName != "" && Api.map != null) {
                if (!Api.map.ensure(mapName)) return false;
            }
            if (!Api.quest.isAccepted(questId)) {
                Api.quest.accept(questId);
                return false;
            }
            return true;
        });

        bind("mapItem", function(itemId:Int, arg2:Dynamic = 1, arg3:Dynamic = null, arg4:Dynamic = null):Bool {
            var targetQuantity:Int = 1;
            var itemName:String = null;
            var targetMap:String = null;

            // Flexible signature detection:
            // 1. (id, "Item Name", qty?, map?) -> Matches hunt(mob, item, qty) convention
            if (Std.isOfType(arg2, String)) {
                itemName = cast(arg2, String);
                if (arg3 != null && (Std.isOfType(arg3, Int) || Std.isOfType(arg3, Float))) {
                    targetQuantity = Std.int(arg3);
                    if (arg4 != null && Std.isOfType(arg4, String)) targetMap = cast(arg4, String);
                } else if (arg3 != null && Std.isOfType(arg3, String)) {
                    targetMap = cast(arg3, String);
                }
            }
            // 2. (id, qty, "Item Name"?, map?) -> Matches count-first convention
            else if (Std.isOfType(arg2, Int) || Std.isOfType(arg2, Float)) {
                targetQuantity = Std.int(arg2);
                if (arg3 != null && Std.isOfType(arg3, String)) {
                    var s3:String = cast(arg3, String);
                    if (arg4 != null && Std.isOfType(arg4, String)) {
                        itemName = s3;
                        targetMap = cast(arg4, String);
                    } else {
                        if (Api.map != null && Api.map.name != null && Api.map.name.toLowerCase() == s3.toLowerCase()) {
                            targetMap = s3;
                        } else {
                            itemName = s3;
                        }
                    }
                }
            }

            if (targetMap != null && targetMap != "" && Api.map != null) {
                if (!Api.map.ensure(targetMap)) return false;
            }
            if (itemName != null && itemName != "" && Api.inventory != null) {
                if (Api.inventory.hasItem(itemName, targetQuantity) || Api.inventory.getQuestQuantity(itemName) >= targetQuantity) {
                    return true;
                }
            }
            var grabMap:String = (targetMap != null && targetMap != "") ? targetMap : (Api.map != null ? Api.map.name : "");
            var grabKey = "mi_" + itemId + "_" + grabMap.toLowerCase();
            var currentGrabs = _mapItemGrabCount.exists(grabKey) ? _mapItemGrabCount.get(grabKey) : 0;
            if (currentGrabs >= targetQuantity) return true;

            if (Api.map != null && Api.map.getMapItem(itemId)) {
                _mapItemGrabCount.set(grabKey, currentGrabs + 1);
            }
            return false;
        });

        bind("ensureMapItem", function(itemId:Int, arg2:Dynamic = 1, arg3:Dynamic = null, arg4:Dynamic = null):Bool {
            return getShortcut("mapItem")(itemId, arg2, arg3, arg4);
        });
        bind("resetStoryData", function():Void {
            resetStoryData();
        });
        bind("resetMapItems", function():Void {
            _mapItemGrabCount = new Map();
        });

        bind("complete", function(questId:Dynamic, ?rewardChoice:Dynamic):Bool {
            if (Api.quest == null) return false;
            if (Api.quest.hasBeenCompleted(questId)) {
                _cleanQuestStoryData(questId);
                return true;
            }
            if (Api.quest.canComplete(questId)) {
                if (Api.combat != null) Api.combat.stopCombat();
                Api.quest.ensureComplete(questId, rewardChoice);
            }
            var done = Api.quest.hasBeenCompleted(questId);
            if (done) _cleanQuestStoryData(questId);
            return done;
        });

        // Quest status & completion checks
        bind("hasBeenCompleted", function(questId:Dynamic):Bool {
            return Api.quest != null && Api.quest.hasBeenCompleted(questId);
        });
        bind("isCompletedBefore", function(questId:Dynamic):Bool {
            return Api.quest != null && Api.quest.hasBeenCompleted(questId);
        });
        bind("isQuestComplete", function(questId:Dynamic):Bool {
            return Api.quest != null ? Api.quest.canComplete(questId) : false;
        });
        bind("canComplete", function(questId:Dynamic):Bool {
            return Api.quest != null ? Api.quest.canComplete(questId) : false;
        });
        bind("isQuestUnlocked", function(questId:Dynamic):Bool {
            return Api.quest != null ? Api.quest.isUnlocked(questId) : false;
        });
        bind("isUnlocked", function(questId:Dynamic):Bool {
            return Api.quest != null ? Api.quest.isUnlocked(questId) : false;
        });

        // Acceptance & completion helpers
        bind("ensureAccept", function(questId:Dynamic):Bool {
            if (Api.quest == null) return false;
            // A completed quest can never be accepted again. Reporting "done" here is what keeps an
            // ensure-style script loop from spinning on accept() forever.
            if (Api.quest.hasBeenCompleted(questId)) return true;
            if (Api.quest.isAccepted(questId)) return true;
            if (!Api.quest.isLoaded(questId)) {
                Api.quest.load(questId);
                return false;
            }
            Api.quest.accept(questId);
            return Api.quest.isAccepted(questId);
        });
        bind("ensureQuest", function(questId:Dynamic):Bool {
            return getShortcut("ensureAccept")(questId);
        });
        bind("acceptQuest", function(questId:Dynamic):Void {
            if (Api.quest != null) Api.quest.accept(questId);
        });
        bind("ensureComplete", function(questId:Dynamic, ?choice:Dynamic):Bool {
            return getShortcut("complete")(questId, choice);
        });
        bind("completeQuest", function(questId:Dynamic, ?choice:Dynamic):Void {
            if (Api.quest != null) Api.quest.complete(questId, choice);
        });

        // Quest loading & multi-load
        bind("loadQuest", function(questId:Dynamic):Void {
            if (Api.quest != null) Api.quest.load(questId);
        });
        bind("loadQuests", function(questIds:Dynamic):Void {
            if (Api.quest == null) return;
            var intArr:Array<Int> = [];
            if (Std.isOfType(questIds, Array)) {
                for (item in (cast questIds:Array<Dynamic>)) {
                    var qid = Api.quest.resolveQuestId(item);
                    if (qid > 0) intArr.push(qid);
                }
            } else if (questIds != null) {
                var qid = Api.quest.resolveQuestId(questIds);
                if (qid > 0) intArr.push(qid);
            }
            if (intArr.length > 0) Api.quest.loadMultiple(intArr);
        });
        bind("ensureQuestsLoaded", function(questIds:Dynamic):Bool {
            if (Api.quest == null) return false;
            var intArr:Array<Int> = [];
            if (Std.isOfType(questIds, Array)) {
                for (item in (cast questIds:Array<Dynamic>)) {
                    var qid = Api.quest.resolveQuestId(item);
                    if (qid > 0) intArr.push(qid);
                }
            } else if (questIds != null) {
                var qid = Api.quest.resolveQuestId(questIds);
                if (qid > 0) intArr.push(qid);
            }
            return Api.quest.ensureLoaded(intArr);
        });
        bind("areQuestsLoaded", function(questIds:Dynamic):Bool {
            if (Api.quest == null) return false;
            var intArr:Array<Int> = [];
            if (Std.isOfType(questIds, Array)) {
                for (item in (cast questIds:Array<Dynamic>)) {
                    var qid = Api.quest.resolveQuestId(item);
                    if (qid > 0) intArr.push(qid);
                }
            } else if (questIds != null) {
                var qid = Api.quest.resolveQuestId(questIds);
                if (qid > 0) intArr.push(qid);
            }
            return Api.quest.areAllLoaded(intArr);
        });
        bind("getMissingRequirements", function(questId:Dynamic):Array<Dynamic> {
            return Api.quest != null ? Api.quest.getMissingRequirements(questId) : [];
        });

        // Legacy / Macro Story Quest Functions
        bind("storyKillQuest", function(questId:Dynamic, mapName:String, monster:Dynamic):Bool {
            if (Api.quest == null || Api.map == null || Api.combat == null) return false;
            if (!Api.quest.isLoaded(questId)) {
                Api.quest.load(questId);
                return false;
            }
            if (Api.quest.hasBeenCompleted(questId)) {
                _cleanQuestStoryData(questId);
                return true;
            }
            if (!Api.map.ensure(mapName)) return false;
            if (!Api.quest.isAccepted(questId)) {
                Api.quest.accept(questId);
                return false;
            }
            if (!Api.quest.canComplete(questId)) {
                var targetMonster:String = "*";
                if (Std.isOfType(monster, Array)) {
                    var arr:Array<Dynamic> = cast monster;
                    if (arr.length == 0) {
                        targetMonster = "*";
                    } else if (arr.length == 1) {
                        targetMonster = Std.string(arr[0]);
                    } else {
                        var q = Api.quest.get(questId);
                        var missingReqs = Api.quest.getMissingRequirements(questId);
                        var foundMonster:String = null;

                        if (missingReqs.length > 0) {
                            var firstMissing = missingReqs[0];
                            var missingId:Int = (firstMissing.ItemID != null) ? Std.int(firstMissing.ItemID) : ((firstMissing.id != null) ? Std.int(firstMissing.id) : 0);
                            var rawMissingName:String = (firstMissing.sName != null) ? Std.string(firstMissing.sName) : ((firstMissing.name != null) ? Std.string(firstMissing.name) : "");
                            var missingName = StringTools.trim(rawMissingName).toLowerCase();
                            var qid = Api.quest.resolveQuestId(questId);
                            var qKey = (qid > 0 ? Std.string(qid) : Std.string(questId));
                            var rMapKey = qKey + "_" + (missingId > 0 ? Std.string(missingId) : missingName);

                            if (_reqToMonsterMap.exists(rMapKey)) {
                                foundMonster = _reqToMonsterMap.get(rMapKey);
                            } else {
                                var getTokens = function(s:String):Array<String> {
                                    var clean = "";
                                    for (ci in 0...s.length) {
                                        var c = s.charAt(ci);
                                        if ((c >= "a" && c <= "z") || (c >= "0" && c <= "9")) clean += c;
                                        else clean += " ";
                                    }
                                    var rawWords = clean.split(" ");
                                    var tokens:Array<String> = [];
                                    for (w in rawWords) {
                                        var wt = StringTools.trim(w);
                                        if (wt.length >= 3 && wt != "the" && wt != "and" && wt != "for" && wt != "with") tokens.push(wt);
                                    }
                                    return tokens;
                                };
                                var reqTokens = getTokens(missingName);
                                if (missingName.indexOf("frigid") != -1 || missingName.indexOf("frost") != -1 || missingName.indexOf("frozen") != -1) reqTokens.push("ice");
                                if (missingName.indexOf("lava") != -1 || missingName.indexOf("flame") != -1 || missingName.indexOf("burn") != -1) reqTokens.push("fire");
                                if (missingName.indexOf("liquid") != -1 || missingName.indexOf("tear") != -1) reqTokens.push("water");
                                if (missingName.indexOf("spark") != -1 || missingName.indexOf("shine") != -1) reqTokens.push("light");
                                if (missingName.indexOf("dark") != -1 || missingName.indexOf("dusk") != -1) reqTokens.push("shadow");
                                if (missingName.indexOf("rock") != -1 || missingName.indexOf("stone") != -1 || missingName.indexOf("ore") != -1) reqTokens.push("earth");
                                if (missingName.indexOf("breeze") != -1 || missingName.indexOf("gale") != -1) reqTokens.push("wind");

                                var bestScore:Int = 0;
                                var bestCandidate:String = null;
                                for (m in arr) {
                                    if (m == null) continue;
                                    var mStr = StringTools.trim(Std.string(m)).toLowerCase();
                                    var mTokens = getTokens(mStr);
                                    var score:Int = 0;
                                    for (rt in reqTokens) {
                                        if (mTokens.indexOf(rt) != -1) score += 10;
                                        else if (mStr.indexOf(rt) != -1) score += 8;
                                    }
                                    for (mt in mTokens) {
                                        if (missingName.indexOf(mt) != -1) score += 8;
                                    }
                                    if (score > bestScore) {
                                        bestScore = score;
                                        bestCandidate = Std.string(m);
                                    }
                                }
                                if (bestScore > 0 && bestCandidate != null) {
                                    foundMonster = bestCandidate;
                                } else {
                                    var usedMonsters:Array<String> = [];
                                    for (k in _reqToMonsterMap.keys()) {
                                        if (StringTools.startsWith(k, qKey + "_")) usedMonsters.push(_reqToMonsterMap.get(k));
                                    }
                                    for (m in arr) {
                                        var mStr = Std.string(m);
                                        if (usedMonsters.indexOf(mStr) == -1) {
                                            foundMonster = mStr;
                                            break;
                                        }
                                    }
                                    if (foundMonster == null) foundMonster = Std.string(arr[0]);
                                }
                                _reqToMonsterMap.set(rMapKey, foundMonster);
                            }
                        }
                        targetMonster = (foundMonster != null) ? foundMonster : Std.string(arr[0]);
                    }
                } else if (monster != null) {
                    targetMonster = Std.string(monster);
                }
                Api.combat.hunt(targetMonster);
                return false;
            }
            Api.combat.stopCombat();
            Api.quest.ensureComplete(questId);
            var done = Api.quest.hasBeenCompleted(questId);
            if (done) _cleanQuestStoryData(questId);
            return done;
        });

        bind("storyMapItemQuest", function(questId:Dynamic, mapName:String, itemIds:Dynamic, amount:Int = 1):Bool {
            if (Api.quest == null || Api.map == null) return false;
            if (!Api.quest.isLoaded(questId)) {
                Api.quest.load(questId);
                return false;
            }
            if (Api.quest.hasBeenCompleted(questId)) {
                _cleanQuestStoryData(questId);
                return true;
            }
            if (!Api.map.ensure(mapName)) return false;
            if (!Api.quest.isAccepted(questId)) {
                Api.quest.accept(questId);
                return false;
            }
            if (Api.quest.canComplete(questId)) {
                Api.quest.ensureComplete(questId);
                var done = Api.quest.hasBeenCompleted(questId);
                if (done) _cleanQuestStoryData(questId);
                return done;
            }

            var targetMids:Array<Int> = [];
            if (Std.isOfType(itemIds, Array)) {
                for (m in (cast itemIds:Array<Dynamic>)) {
                    var mid = ApiUtils.parseInt(m, 0);
                    if (mid > 0 && targetMids.indexOf(mid) == -1) targetMids.push(mid);
                }
            } else {
                var mid = ApiUtils.parseInt(itemIds, 0);
                if (mid > 0) targetMids.push(mid);
            }
            if (targetMids.length == 0) return true;

            var qid = Api.quest.resolveQuestId(questId);
            var qKey = (qid > 0 ? Std.string(qid) : Std.string(questId));

            var allMidsDone:Bool = true;
            var nextMidToGrab:Int = 0;
            for (mid in targetMids) {
                var grabKey = qKey + "_" + mid;
                var grabs = _mapItemGrabCount.exists(grabKey) ? _mapItemGrabCount.get(grabKey) : 0;
                if (grabs < amount) {
                    allMidsDone = false;
                    if (nextMidToGrab == 0) nextMidToGrab = mid;
                }
            }

            if (allMidsDone) {
                if (Api.quest.canComplete(questId)) {
                    Api.quest.ensureComplete(questId);
                    var done = Api.quest.hasBeenCompleted(questId);
                    if (done) _cleanQuestStoryData(questId);
                    return done;
                }
                return true;
            }

            if (nextMidToGrab > 0) {
                var grabKey = qKey + "_" + nextMidToGrab;
                var grabs = _mapItemGrabCount.exists(grabKey) ? _mapItemGrabCount.get(grabKey) : 0;
                if (Api.map.getMapItem(nextMidToGrab)) {
                    _mapItemGrabCount.set(grabKey, grabs + 1);
                }
            }
            return false;
        });

        bind("storyChainQuest", function(questId:Dynamic, mapName:String = null):Bool {
            if (Api.quest == null) return false;
            if (!Api.quest.isLoaded(questId)) {
                Api.quest.load(questId);
                return false;
            }
            if (Api.quest.hasBeenCompleted(questId)) {
                _cleanQuestStoryData(questId);
                return true;
            }
            if (mapName != null && mapName != "" && Api.map != null) {
                if (!Api.map.ensure(mapName)) return false;
            }
            if (!Api.quest.isAccepted(questId)) {
                Api.quest.accept(questId);
                return false;
            }
            Api.quest.ensureComplete(questId);
            var done = Api.quest.hasBeenCompleted(questId);
            if (done) _cleanQuestStoryData(questId);
            return done;
        });

        // Auto quest automation
        bind("autoQuest", function(quests:Dynamic):Void {
            if (Api.quest != null) Api.quest.startAuto(quests);
        });
        bind("stopAutoQuest", function():Void {
            if (Api.quest != null) Api.quest.stopAuto();
        });
        bind("isAutoQuestRunning", function():Bool {
            return Api.quest != null && Api.quest.isAutoRunning;
        });
    }

    // -------------------------------------------------------------------------
    // 4. Inventory, Items & Drops Primitives
    // -------------------------------------------------------------------------

    private static function registerInventoryShortcuts():Void {
        bind("hasItem", function(itemName:Dynamic, quantity:Int = 1):Bool {
            return Api.inventory != null ? Api.inventory.hasItem(itemName, quantity) : false;
        });
        bind("getItemCount", function(itemName:Dynamic):Int {
            return Api.inventory != null ? Api.inventory.getItemCount(itemName) : 0;
        });
        bind("getQuestQuantity", function(itemName:Dynamic):Int {
            return Api.inventory != null ? Api.inventory.getQuestQuantity(itemName) : 0;
        });
        bind("getInventory", function():Array<Dynamic> {
            return Api.inventory != null ? cast Api.inventory.getItems() : [];
        });
        bind("getBankItems", function():Array<Dynamic> {
            return Api.inventory != null ? cast Api.inventory.getBankItems() : [];
        });
        bind("equip", function(itemName:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.equip(itemName);
        });
        bind("ensureEquipped", function(itemName:Dynamic):Bool {
            if (Api.inventory == null) return false;
            if (Api.inventory.isEquipped(itemName)) return true;
            Api.inventory.equip(itemName);
            return false;
        });
        bind("isEquipped", function(itemName:Dynamic):Bool {
            return Api.inventory != null ? Api.inventory.isEquipped(itemName) : false;
        });

        // Gear Snapshot & Restoration
        bind("storeGear", function(?items:Dynamic):Array<Dynamic> {
            return Api.storeGear(items);
        });
        bind("restoreGear", function(?onComplete:Dynamic):Void {
            var cb:Void->Void = null;
            if (Reflect.isFunction(onComplete)) cb = cast onComplete;
            Api.restoreGear(cb);
        });
        bind("isGearRestored", function():Bool {
            return Api.isGearRestored();
        });
        bind("ensureRestored", function():Bool {
            return Api.ensureRestored();
        });
        bind("ensureRestoreGear", function():Bool {
            return Api.ensureRestoreGear();
        });
        bind("hasGearSnapshot", function():Bool {
            return Api.hasGearSnapshot();
        });
        bind("getGearSnapshot", function():Array<Dynamic> {
            return Api.getGearSnapshot();
        });
        bind("clearGearSnapshot", function():Void {
            Api.clearGearSnapshot();
        });
        bind("cancelRestoreGear", function():Void {
            Api.cancelRestoreGear();
        });

        // Enhancement operations
        bind("enhanceEquipped", function(?type:Dynamic, ?cSpecial:Dynamic, ?hSpecial:Dynamic, ?wSpecial:Dynamic, ?onComplete:Dynamic):Void {
            Api.enhanceEquipped(type, cSpecial, hSpecial, wSpecial, onComplete);
        });
        bind("smartEnhance", function(?className:Dynamic, ?force:Dynamic, ?onComplete:Dynamic):Void {
            Api.smartEnhance(className, force, onComplete);
        });
        bind("enhanceItem", function(?itemOrName:Dynamic, ?type:Dynamic, ?cSpecial:Dynamic, ?hSpecial:Dynamic, ?wSpecial:Dynamic, ?onComplete:Dynamic):Void {
            Api.enhanceItem(itemOrName, type, cSpecial, hSpecial, wSpecial, onComplete);
        });
    }

    private static function registerDropShortcuts():Void {
        bind("acceptAllDrops", function(enabled:Bool = true):Void {
            if (Api.drop != null) Api.drop.acceptAllDrops(enabled);
        });
        bind("acceptAcDrops", function(enabled:Bool = true):Void {
            if (Api.drop != null) Api.drop.acceptAcDrops(enabled);
        });
        bind("getDrop", function(itemName:Dynamic):Void {
            if (Api.drop != null) Api.drop.getDrop(itemName);
        });
        bind("getDrops", function(drops:Dynamic = "all"):Void {
            if (Api.drop == null) return;
            if (drops == null || drops == "all" || drops == "any" || drops == "*") {
                Api.drop.acceptPendingDrops(["all"]);
            } else if (Std.isOfType(drops, Array)) {
                Api.drop.acceptPendingDrops(cast drops);
            } else {
                Api.drop.getDrop(Std.string(drops));
            }
        });
    }

    // -------------------------------------------------------------------------
    // 5. Shop & Bank Primitives
    // -------------------------------------------------------------------------

    private static function registerShopAndBankShortcuts():Void {
        bind("buyItem", function(shopId:Dynamic, itemNameOrId:Dynamic = null, quantity:Int = 1):Void {
            if (Api.shop == null) return;
            if (itemNameOrId == null) {
                Api.shop.buyItem(shopId, quantity);
            } else {
                var sId:Int = ApiUtils.parseInt(shopId, 0);
                if (sId > 0 && !Api.shop.isShopLoaded) Api.shop.loadShop(sId);
                Api.shop.buyItem(itemNameOrId, quantity);
            }
        });
        bind("sellItem", function(itemNameOrId:Dynamic, quantity:Int = 1):Void {
            if (Api.shop != null) Api.shop.sellItem(itemNameOrId, quantity);
        });

        // Bank operations
        bind("bankAll", function(?exclude:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.bankAll(exclude);
        });
        bind("bankAllAcItems", function(?exclude:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.bankAllAc(exclude);
        });
        bind("unbankPreset", function(presetName:String):Void {
            if (Api.inventory != null) Api.inventory.unbankPreset(presetName);
        });
        bind("unbankAllNonAcItems", function(?exclude:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.unbankAllNonAc(exclude);
        });
        bind("bankAcAndUnbankNonAc", function(?exclude:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.bankAcAndUnbankNonAc(exclude);
        });
        bind("isBanking", function():Bool {
            return Api.inventory != null && Api.inventory.isBanking;
        });
        bind("isUnbanking", function():Bool {
            return Api.inventory != null && Api.inventory.isUnbanking;
        });

        // Temp items (quest items) live in avatar.tempitems, a separate array from both the
        // inventory and the bank, so the inventory readers above never see them.
        bind("getTempItems", function():Array<Dynamic> {
            return Api.inventory != null ? cast Api.inventory.getTempItems() : [];
        });
        bind("getTempQuantity", function(itemNameOrId:Dynamic):Int {
            return Api.inventory != null ? Api.inventory.getTempQuantity(itemNameOrId) : 0;
        });
        bind("hasTempItem", function(itemNameOrId:Dynamic, quantity:Int = 1):Bool {
            return Api.inventory != null && Api.inventory.hasTempItem(itemNameOrId, quantity);
        });

        // Container lookup across temp / inventory / house / bank.
        bind("getItemLocation", function(itemNameOrId:Dynamic):String {
            return Api.inventory != null ? Api.inventory.getItemLocation(itemNameOrId) : "";
        });
        bind("findItem", function(itemNameOrId:Dynamic):Dynamic {
            return Api.inventory != null ? Api.inventory.findItem(itemNameOrId) : null;
        });
        bind("getBankQuantity", function(itemNameOrId:Dynamic):Int {
            return Api.inventory != null ? Api.inventory.getBankQuantity(itemNameOrId) : 0;
        });
        // Backpack-only counterpart to getTempQuantity/getBankQuantity. Deliberately NOT a total:
        // getQuestQuantity is the de-duplicated cross-container reading.
        bind("getInventoryQuantity", function(itemNameOrId:Dynamic):Int {
            return Api.inventory != null ? Api.inventory.getQuantity(itemNameOrId) : 0;
        });
        bind("isQuestAccepted", function(questId:Dynamic):Bool {
            return Api.quest != null && Api.quest.isAccepted(questId);
        });

        // Rate limits, read straight from ApiTimings so scripts cannot drift from what the engine
        // enforces. These are NOT tuning knobs for scripts - the SERVER-LIMITED ones encode AQW's
        // cooldowns plus a lag margin, and calling faster than that makes the server drop the action.
        // Change a value in utils/ApiTimings.hx and it applies everywhere, including here.
        bind("questActionCooldownMs", function():Int {
            return Std.int(com.aqwapi.utils.ApiTimings.QUEST_ACTION_MS);
        });
        bind("rateLimit", function():Dynamic {
            return com.aqwapi.utils.ApiTimings.all();
        });
        bind("rateLimitDump", function():String {
            return com.aqwapi.utils.ApiTimings.describe();
        });

        // Verbose diagnostics for the packet hit feed. Off by default - see ApiLogger.diagnostics for
        // why they exist. Turn on when a [counter] rule seems to be silently failing.
        bind("setDiagnostics", function(enabled:Bool = true):Bool {
            com.aqwapi.utils.ApiLogger.diagnostics = enabled;
            if (enabled) {
                ApiLogger.info("HScript", "Diagnostics ON: packet-shape probes, hit-feed counters and"
                    + " hard-lock notices will be logged every few seconds.");
            }
            return com.aqwapi.utils.ApiLogger.diagnostics;
        });
        bind("getDiagnostics", function():Bool {
            return com.aqwapi.utils.ApiLogger.diagnostics;
        });

        // Reset-on-target-change, readable at runtime. The UI writes it, but a script that suspects
        // the rotation is resuming instead of restarting needs to confirm the mode actually has it on.
        bind("getResetOnTargetChange", function(className:String = null, modeName:String = null):Dynamic {
            if (Api.quest == null && Api.combat == null) return null;
            var cls = (className != null && className != "") ? className : com.aqwapi.managers.SkillManager.getCurrentClassName();
            var mode = (modeName != null && modeName != "" && modeName != "Auto") ? modeName : com.aqwapi.modules.CombatEngine.skillMode;
            if (cls == null || cls == "" || mode == null || mode == "") return null;
            var d = com.aqwapi.managers.SkillManager.getModeDetails(cls, mode);
            if (d == null) return null;
            return (d.resetComboOnTargetChange == true);
        });

        // Bulk purchasing. buyItem() drops calls made within 1s of each other, so buying several
        // different items in one tick would silently lose all but the first; buyItems() queues them.
        bind("buyItems", function(items:Array<Dynamic>, gapMs:Int = 1000):Int {
            return Api.shop != null ? Api.shop.buyItems(items, gapMs) : 0;
        });
        bind("getPendingBuyCount", function():Int {
            return Api.shop != null ? Api.shop.getPendingBuyCount() : 0;
        });
        bind("clearBuyQueue", function():Void {
            if (Api.shop != null) Api.shop.clearBuyQueue();
        });
    }

    // -------------------------------------------------------------------------
    // 6. Player Status & Factions Primitives
    // -------------------------------------------------------------------------

    private static function registerPlayerStatusShortcuts():Void {
        // Level & Identity
        bind("level", function():Int {
            return Api.player != null ? Api.player.level : 0;
        });
        bind("getLevel", function():Int {
            return Api.player != null ? Api.player.level : 0;
        });
        bind("username", function():String {
            return Api.player != null ? Api.player.username : "";
        });
        bind("getUsername", function():String {
            return Api.player != null ? Api.player.username : "";
        });
        bind("isMember", function():Bool {
            return Api.player != null && Api.player.isMember;
        });

        // Health & Vitality
        bind("hp", function():Int {
            return Api.player != null ? Api.player.hp : 0;
        });
        bind("getHp", function():Int {
            return Api.player != null ? Api.player.hp : 0;
        });
        bind("maxHp", function():Int {
            return Api.player != null ? Api.player.maxHp : 100;
        });
        bind("getMaxHp", function():Int {
            return Api.player != null ? Api.player.maxHp : 100;
        });
        bind("isAlive", function():Bool {
            return Api.player != null && Api.player.isAlive;
        });

        // Mana
        bind("mp", function():Int {
            return Api.player != null ? Api.player.mp : 0;
        });
        bind("getMp", function():Int {
            return Api.player != null ? Api.player.mp : 0;
        });
        bind("maxMp", function():Int {
            return Api.player != null ? Api.player.maxMp : 100;
        });
        bind("getMaxMp", function():Int {
            return Api.player != null ? Api.player.maxMp : 100;
        });

        // Gold & Economy
        bind("gold", function():Int {
            return Api.player != null ? Api.player.gold : 0;
        });
        bind("getGold", function():Int {
            return Api.player != null ? Api.player.gold : 0;
        });

        // Combat State
        bind("isInCombat", function():Bool {
            return Api.player != null && Api.player.isInCombat;
        });

        // Factions
        bind("factionRank", function(name:String):Int {
            return Api.player != null ? Api.player.getFactionRank(name) : 0;
        });
        bind("getFactionRank", function(name:String):Int {
            return Api.player != null ? Api.player.getFactionRank(name) : 0;
        });

        // Auras on Player
        bind("hasAura", function(name:String):Bool {
            return Api.player != null && Api.player.hasAura(name);
        });
        bind("getAuraStacks", function(name:String):Float {
            return Api.player != null ? Api.player.getAuraStacks(name) : 0.0;
        });
        bind("getAuraRemaining", function(name:String):Float {
            return Api.player != null ? Api.player.getAuraRemaining(name) : 0.0;
        });

        // Server Boosts (Gold, CP, Rep, XP)
        bind("isBoostActive", function(boostType:String):Bool {
            return Api.player != null && Api.player.isBoostActive(boostType);
        });
        bind("getBoostRemaining", function(boostType:String):Int {
            return Api.player != null ? Api.player.getBoostRemaining(boostType) : 0;
        });
        bind("useBoost", function(nameOrId:Dynamic):Bool {
            return Api.player != null && Api.player.useBoost(nameOrId);
        });
        bind("autoBoost", function(boostType:String, enabled:Bool = true):Void {
            if (Api.player != null) Api.player.setAutoBoost(boostType, enabled);
        });

        // Aura Garbage Collection
        bind("cleanExpiredAuras", function():Int {
            return Api.aura != null ? Api.aura.cleanExpiredAuras() : 0;
        });
        bind("cleanAuras", function():Int {
            return Api.aura != null ? Api.aura.cleanExpiredAuras() : 0;
        });
        bind("autoCleanAuras", function(enabled:Bool = true):Void {
            if (Api.aura != null) {
                if (enabled) Api.aura.startAutoClean(5000);
                else Api.aura.stopAutoClean();
            }
        });
    }

    // -------------------------------------------------------------------------
    // 7. Logging, Sleep, Blacklist & Execution Control
    // -------------------------------------------------------------------------

    private static function registerLoggingAndSystem():Void {
        bind("log", function(msg:Dynamic):Void {
            ApiLogger.info("HScript", Std.string(msg));
        });
        bind("warn", function(msg:Dynamic):Void {
            ApiLogger.warn("HScript", Std.string(msg));
        });
        bind("error", function(msg:Dynamic):Void {
            ApiLogger.error("HScript", Std.string(msg));
        });
        bind("msg", function(msg:Dynamic):Void {
            var str = Std.string(msg);
            ApiLogger.info("Script", str);
            com.aqwapi.feedback.ApiFeedback.card(str);
        });
        // Routed through ApiFeedback so a notification is always accompanied by a log line, making
        // on-screen cards traceable in api.log instead of being a separate stream.
        bind("notify", function(msg:Dynamic):Void {
            com.aqwapi.feedback.ApiFeedback.notify(Std.string(msg));
        });
        bind("notifyCard", function(msg:Dynamic):Void {
            com.aqwapi.feedback.ApiFeedback.card(Std.string(msg));
        });
        bind("notifySticky", function(id:String, msg:Dynamic):Void {
            com.aqwapi.feedback.ApiFeedback.sticky(id, Std.string(msg));
        });
        bind("removeStickyNotification", function(id:String):Void {
            com.aqwapi.feedback.ApiFeedback.removeSticky(id);
        });
        bind("logToScreen", function(msg:Dynamic):Void {
            com.aqwapi.feedback.ApiFeedback.logToScreen(com.aqwapi.utils.ApiLogger.LEVEL_INFO, "Script", Std.string(msg));
        });
        bind("setMirrorLogs", function(enabled:Bool = true):Bool {
            com.aqwapi.feedback.ApiFeedback.mirrorLogs = enabled;
            return com.aqwapi.feedback.ApiFeedback.mirrorLogs;
        });
        bind("clearStickyNotifications", function():Void {
            com.aqwapi.feedback.ApiFeedback.clearSticky();
        });
        bind("getStickyNotifications", function():Array<Dynamic> {
            return com.aqwapi.feedback.ApiFeedback.stickyIds();
        });
        bind("feedbackConfig", function():Dynamic {
            return com.aqwapi.feedback.ApiFeedback.config();
        });
        bind("clearLog", function():Void {
            ApiLogger.clearLog();
        });
        bind("setChatLogging", function(enabled:Bool):Void {
            ApiLogger.setChatLogging(enabled);
        });
        bind("isChatLogging", function():Bool {
            return ApiLogger.printToChat;
        });
        bind("sleep", function(ms:Float):Void {
            HScriptEngine.SINGLETON.sleep(ms);
        });
        bind("stop", function():Void {
            HScriptEngine.SINGLETON.stop();
        });
        bind("sendPacket", function(packet:String):Void {
            if (Api.game != null && Api.game.sfc != null) {
                Api.game.sfc.sendString(packet);
            }
        });

        // Blacklist operations
        bind("addBlacklist", function(nameOrId:Dynamic):Void {
            Api.blacklist.add(nameOrId);
        });
        bind("removeBlacklist", function(nameOrId:Dynamic):Void {
            Api.blacklist.remove(nameOrId);
        });
        bind("isBlacklisted", function(nameOrId:Dynamic):Bool {
            return Api.blacklist.isBlacklisted(nameOrId);
        });
        bind("clearBlacklist", function():Void {
            Api.blacklist.clear();
        });
        bind("sellBlacklist", function():Void {
            Api.blacklist.sellBlacklist();
        });
    }

    // -------------------------------------------------------------------------
    // 8. Standard Libraries & Helpers
    // -------------------------------------------------------------------------

    private static function registerStdLibraries(interp:ScriptInterp):Void {
        interp.variables.set("Math", Math);
        interp.variables.set("Std", Std);
        interp.variables.set("StringTools", StringTools);
        interp.variables.set("Date", Date);
        interp.variables.set("now", function():Float {
            return ApiTime.now();
        });
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
