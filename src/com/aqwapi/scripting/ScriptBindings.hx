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
 *
 * One canonical name per action. No aliases. No ambiguous short forms.
 * Every function registered here is directly callable by name in .hxs scripts.
 *
 * Namespaces (bot, api, map, combat, etc.) are available for advanced use
 * but are NOT part of the primary scripting API.
 */
class ScriptBindings {

    public static var shortcuts(default, null):Map<String, Dynamic> = new Map();
    private static var _initialized:Bool = false;
    private static var _mapItemGrabCount:Map<String, Int> = new Map();
    private static var _reqToMonsterMap:Map<String, String> = new Map();

    private static function _cleanQuestStoryData(questId:Int):Void {
        var prefix = questId + "_";
        var grabKeys:Array<String> = [];
        for (k in _mapItemGrabCount.keys()) {
            if (StringTools.startsWith(k, prefix)) grabKeys.push(k);
        }
        for (k in grabKeys) _mapItemGrabCount.remove(k);

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
     * These are available for advanced use but scripts should prefer top-level functions.
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

    // -------------------------------------------------------------------------
    // Map & Navigation
    // -------------------------------------------------------------------------

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
        bind("setPrivateRoom", function(enabled:Bool, roomNumber:Int = 100000):Void {
            if (Api.map != null) {
                Api.map.usePrivateRoom = enabled;
                if (roomNumber > 0) Api.map.privateRoomNumber = roomNumber;
            }
        });
        bind("isPrivateRoom", function():Bool {
            return Api.map != null && Api.map.usePrivateRoom;
        });
        bind("dungeonQueue", function(mapName:String, roomNum:Int = -1):Void {
            if (Api.map != null) Api.map.dungeonQueue(mapName, roomNum);
        });
        bind("setSkipCutscenes", function(enabled:Bool = true):Void {
            if (Api.map != null) Api.map.skipCutscenes = enabled;
        });
        bind("isSkipCutscenes", function():Bool {
            return Api.map != null && Api.map.skipCutscenes;
        });
        bind("mapRoom", function():Int {
            return Api.map != null ? Api.map.roomId : 0;
        });
        bind("isHouse", function():Bool {
            return Api.map != null ? Api.map.isHouse() : false;
        });
    }

    // -------------------------------------------------------------------------
    // Combat & Targeting
    // -------------------------------------------------------------------------

    private static function registerCombatShortcuts():Void {
        // High-level hunt & kill
        bind("hunt", function(monster:String, itemOrCount:Dynamic = null, qtyOrCallback:Dynamic = 1, mmidOrCallback:Dynamic = null, onComplete:Dynamic = null):Bool {
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
        bind("cancelAutoAttack", function():Void {
            if (Api.combat != null) Api.combat.cancelAutoAttack();
        });
        bind("cancelTarget", function():Void {
            if (Api.combat != null) Api.combat.cancelTarget();
        });
        bind("pauseCombat", function():Void {
            if (Api.combat != null) Api.combat.pauseCombat();
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
                else Api.combat.startAuto();
            }
        });
        bind("startAuto", function():Void {
            if (Api.combat != null) Api.combat.startAuto();
        });
        bind("startCustom", function(rotation:String, mode:String = "auto"):Void {
            if (Api.combat != null) Api.combat.startCustom(rotation, mode);
        });
        bind("isCombatMode", function(mode:String):Bool {
            if (Api.combat == null) return false;
            var m = (mode != null) ? mode.toLowerCase() : "";
            if (m == "smart") return Api.combat.isSmartRunning;
            if (m == "custom") return Api.combat.isCustomRunning;
            if (m == "auto") return Api.combat.isAutoRunning && !Api.combat.isSmartRunning;
            return Api.combat.isAutoRunning;
        });
        bind("stopCombat", function():Void {
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
        bind("equipLoadout", function(type:String):Bool {
            return Api.combat != null ? Api.combat.equipLoadout(type) : false;
        });

        // Infinite Range & Magnetize
        bind("setInfiniteRange", function(enabled:Bool = true):Void {
            if (Api.combat != null) Api.combat.setInfiniteRange(enabled);
        });
        bind("magnetize", function():Void {
            if (Api.combat != null) Api.combat.magnetize();
        });
    }

    // -------------------------------------------------------------------------
    // Quests
    // -------------------------------------------------------------------------

    private static function registerQuestShortcuts():Void {
        bind("autoQuest", function(quests:Dynamic):Void {
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
        bind("isCompletedBefore", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.hasBeenCompleted(questId) : false;
        });
        bind("isDailyComplete", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.isDailyComplete(questId) : false;
        });
        bind("canCompleteQuest", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.canComplete(questId) : false;
        });
        bind("canComplete", function(questId:Int):Bool {
            return Api.quest != null ? Api.quest.canComplete(questId) : false;
        });
        bind("getQuestValue", function(slot:Int):Int {
            return Api.quest != null ? Api.quest.getQuestValue(slot) : 0;
        });
        bind("searchQuest", function(query:String, max:Int = 10):Array<Dynamic> {
            return Api.quest != null ? cast Api.quest.search(query, max) : [];
        });
        bind("getMissingRequirements", function(questId:Int):Array<Dynamic> {
            return Api.quest != null ? Api.quest.getMissingRequirements(questId) : [];
        });

        bind("areQuestsLoaded", function(questIds:Dynamic):Bool {
            if (Api.quest == null) return false;
            var intArr:Array<Int> = [];
            if (Std.isOfType(questIds, Array)) {
                for (item in (cast questIds:Array<Dynamic>)) {
                    var qid = ApiUtils.parseInt(item, 0);
                    if (qid > 0) intArr.push(qid);
                }
            } else if (questIds != null) {
                var qid = ApiUtils.parseInt(questIds, 0);
                if (qid > 0) intArr.push(qid);
            }
            return Api.quest.areAllLoaded(intArr);
        });
        bind("ensureQuestsLoaded", function(questIds:Dynamic):Bool {
            if (Api.quest == null) return false;
            var intArr:Array<Int> = [];
            if (Std.isOfType(questIds, Array)) {
                for (item in (cast questIds:Array<Dynamic>)) {
                    var qid = ApiUtils.parseInt(item, 0);
                    if (qid > 0) intArr.push(qid);
                }
            } else if (questIds != null) {
                var qid = ApiUtils.parseInt(questIds, 0);
                if (qid > 0) intArr.push(qid);
            }
            return Api.quest.ensureLoaded(intArr);
        });

        // High-level story quest progression
        bind("storyKillQuest", function(questId:Int, mapName:String, monster:Dynamic):Bool {
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
                        var allReqs:Array<Dynamic> = (q != null && q.requirements != null) ? q.requirements : [];
                        var missingReqs = Api.quest.getMissingRequirements(questId);
                        var foundMonster:String = null;

                        if (missingReqs.length > 0) {
                            var firstMissing = missingReqs[0];
                            var missingId:Int = (firstMissing.ItemID != null) ? Std.int(firstMissing.ItemID) : ((firstMissing.id != null) ? Std.int(firstMissing.id) : 0);
                            var rawMissingName:String = (firstMissing.sName != null) ? Std.string(firstMissing.sName) : ((firstMissing.name != null) ? Std.string(firstMissing.name) : "");
                            var missingName = StringTools.trim(rawMissingName).toLowerCase();
                            var rMapKey = questId + "_" + (missingId > 0 ? Std.string(missingId) : missingName);

                            if (_reqToMonsterMap.exists(rMapKey)) {
                                foundMonster = _reqToMonsterMap.get(rMapKey);
                            } else {
                                // Token extraction helper (length >= 3, skipping stop words)
                                var getTokens = function(s:String):Array<String> {
                                    var clean = "";
                                    for (ci in 0...s.length) {
                                        var c = s.charAt(ci);
                                        if ((c >= "a" && c <= "z") || (c >= "0" && c <= "9")) {
                                            clean += c;
                                        } else {
                                            clean += " ";
                                        }
                                    }
                                    var rawWords = clean.split(" ");
                                    var tokens:Array<String> = [];
                                    for (w in rawWords) {
                                        var wt = StringTools.trim(w);
                                        if (wt.length >= 3 && wt != "the" && wt != "and" && wt != "for" && wt != "with") {
                                            tokens.push(wt);
                                        }
                                    }
                                    return tokens;
                                };

                                var reqTokens = getTokens(missingName);

                                // Thematic synonyms to map elemental monster drops reliably
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

                                    // Prefix/stem match (length >= 4)
                                    for (rt in reqTokens) {
                                        for (mt in mTokens) {
                                            if (rt.length >= 4 && mt.length >= 4) {
                                                var minL = rt.length < mt.length ? rt.length : mt.length;
                                                var pLen = minL >= 6 ? 6 : (minL >= 5 ? 5 : 4);
                                                if (rt.substr(0, pLen) == mt.substr(0, pLen)) {
                                                    score += 5;
                                                }
                                            }
                                        }
                                    }

                                    if (score > bestScore) {
                                        bestScore = score;
                                        bestCandidate = Std.string(m);
                                    }
                                }

                                if (bestScore > 0 && bestCandidate != null) {
                                    foundMonster = bestCandidate;
                                } else {
                                    // 1-to-1 requirement to monster fallback (like Skua)
                                    var usedMonsters:Array<String> = [];
                                    for (k in _reqToMonsterMap.keys()) {
                                        if (StringTools.startsWith(k, questId + "_")) {
                                            usedMonsters.push(_reqToMonsterMap.get(k));
                                        }
                                    }
                                    for (m in arr) {
                                        var mStr = Std.string(m);
                                        if (usedMonsters.indexOf(mStr) == -1) {
                                            foundMonster = mStr;
                                            break;
                                        }
                                    }
                                    if (foundMonster == null) {
                                        foundMonster = Std.string(arr[0]);
                                    }
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

        bind("storyMapItemQuest", function(questId:Int, mapName:String, itemIds:Dynamic, amount:Int = 1):Bool {
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

            // Normalize target map item IDs
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

            var q = Api.quest.get(questId);
            var allReqs:Array<Dynamic> = (q != null && q.requirements != null) ? q.requirements : [];
            var missingReqs = Api.quest.getMissingRequirements(questId);

            var getReqCurQty = function(req:Dynamic):Int {
                if (req == null || Api.inventory == null) return 0;
                var rId:Int = (req.ItemID != null) ? Std.int(req.ItemID) : ((req.id != null) ? Std.int(req.id) : 0);
                var rName:String = (req.sName != null) ? Std.string(req.sName) : ((req.name != null) ? Std.string(req.name) : "");
                var cur:Int = 0;
                if (rName != "") {
                    var nq = Api.inventory.getQuestQuantity(rName);
                    if (nq > cur) cur = nq;
                }
                if (rId > 0) {
                    var iq = Api.inventory.getQuestQuantity(Std.string(rId));
                    if (iq > cur) cur = iq;
                }
                return cur;
            };

            var isReqSatisfied = function(req:Dynamic):Bool {
                if (req == null) return true;
                var reqQty:Int = (req.iQty != null) ? Std.int(req.iQty) : ((req.qty != null) ? Std.int(req.qty) : 1);
                return getReqCurQty(req) >= reqQty;
            };

            var satisfiedReqsCount:Int = 0;
            for (req in allReqs) {
                if (isReqSatisfied(req)) satisfiedReqsCount++;
            }

            var allMidsDone:Bool = true;
            var nextMidToGrab:Int = 0;

            for (mid in targetMids) {
                var grabKey = questId + "_" + mid;
                var grabs = _mapItemGrabCount.exists(grabKey) ? _mapItemGrabCount.get(grabKey) : 0;
                if (grabs < amount) {
                    allMidsDone = false;
                    if (nextMidToGrab == 0) {
                        nextMidToGrab = mid;
                    }
                }
            }

            // Recovery checks if bot restarted and temp inventory already holds the items:
            // 1. Single map item with exact requirement quantity match (e.g. quest 2378, reqQty = 8)
            if (!allMidsDone && targetMids.length == 1 && allReqs.length > 0) {
                for (req in allReqs) {
                    var rQty:Int = (req.iQty != null) ? Std.int(req.iQty) : ((req.qty != null) ? Std.int(req.qty) : 1);
                    if (rQty == amount && isReqSatisfied(req)) {
                        allMidsDone = true;
                        break;
                    }
                }
            }

            // 2. Hybrid quest where number of satisfied requirements in quest covers targetMids
            if (!allMidsDone && allReqs.length > targetMids.length && satisfiedReqsCount >= targetMids.length) {
                allMidsDone = true;
            }

            if (allMidsDone) {
                if (Api.quest.canComplete(questId)) {
                    Api.quest.ensureComplete(questId);
                    var done = Api.quest.hasBeenCompleted(questId);
                    if (done) _cleanQuestStoryData(questId);
                    return done;
                }
                // Hybrid quest: all map items for this step satisfied, proceed to kill quest
                return true;
            }

            if (nextMidToGrab > 0) {
                var grabKey = questId + "_" + nextMidToGrab;
                var grabs = _mapItemGrabCount.exists(grabKey) ? _mapItemGrabCount.get(grabKey) : 0;
                _mapItemGrabCount.set(grabKey, grabs + 1);

                ApiLogger.info("Story", "Grabbing map item " + nextMidToGrab + " (" + (grabs + 1) + "/" + amount + ") for quest " + questId + " (" + missingReqs.length + "/" + allReqs.length + " missing)");
                Api.map.getMapItem(nextMidToGrab);
            }

            return false;
        });

        bind("storyChainQuest", function(questId:Int, mapName:String = null):Bool {
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
    }

    // -------------------------------------------------------------------------
    // Inventory & Items
    // -------------------------------------------------------------------------

    private static function registerInventoryShortcuts():Void {
        bind("hasItem", function(itemName:String, quantity:Int = 1):Bool {
            return Api.inventory != null ? Api.inventory.hasItem(itemName, quantity) : false;
        });
        bind("getItemCount", function(itemName:String):Int {
            return Api.inventory != null ? Api.inventory.getItemCount(itemName) : 0;
        });
        bind("getQuestQuantity", function(itemName:String):Int {
            return Api.inventory != null ? Api.inventory.getQuestQuantity(itemName) : 0;
        });
        bind("getInventory", function():Array<Dynamic> {
            return Api.inventory != null ? cast Api.inventory.getItems() : [];
        });
        bind("getBankItems", function():Array<Dynamic> {
            return Api.inventory != null ? cast Api.inventory.getBankItems() : [];
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
        bind("isEquipped", function(itemName:String):Bool {
            return Api.inventory != null ? Api.inventory.isEquipped(itemName) : false;
        });
        bind("isWorn", function(itemName:String):Bool {
            return Api.inventory != null ? Api.inventory.isWorn(itemName) : false;
        });
        bind("isCosmetic", function(itemName:String):Bool {
            return Api.inventory != null ? Api.inventory.isCosmetic(itemName) : false;
        });
        bind("equipUsable", function(itemName:String):Void {
            if (Api.inventory != null) Api.inventory.equipUsable(itemName);
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

        // Inventory & Bank Capacity
        bind("isInventoryFull", function():Bool {
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
        bind("maxBankSlots", function():Int {
            return Api.inventory != null ? Api.inventory.maxBankSlots : 0;
        });
        bind("usedBankSlots", function():Int {
            return Api.inventory != null ? Api.inventory.usedBankSlots : 0;
        });
        bind("freeBankSlots", function():Int {
            return Api.inventory != null ? Api.inventory.freeBankSlots : 0;
        });
    }

    // -------------------------------------------------------------------------
    // Drops
    // -------------------------------------------------------------------------

    private static function registerDropShortcuts():Void {
        bind("acceptAllDrops", function(?enabled:Dynamic):Void {
            var b:Bool = (enabled == null || enabled == true || enabled == 1 || enabled == "true");
            if (enabled == false || enabled == 0 || enabled == "false") b = false;
            if (Api.drop != null) Api.drop.acceptAllDrops(b);
        });
        bind("acceptAcDrops", function(?enabled:Dynamic):Void {
            var b:Bool = (enabled == null || enabled == true || enabled == 1 || enabled == "true");
            if (enabled == false || enabled == 0 || enabled == "false") b = false;
            if (Api.drop != null) Api.drop.acceptACDrops(b);
        });
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

    // -------------------------------------------------------------------------
    // Shop & Bank
    // -------------------------------------------------------------------------

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
        bind("loadedShopId", function():Int {
            return Api.shop != null ? Api.shop.loadedShopId : 0;
        });

        // Bank
        bind("loadBank", function():Void {
            if (Api.inventory != null) Api.inventory.loadBank();
        });
        bind("toggleBank", function():Void {
            if (Api.inventory != null) Api.inventory.toggleBank();
        });
        bind("closeBank", function():Void {
            if (Api.inventory != null) Api.inventory.closeBank();
        });
        bind("bankItem", function(items:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.bank(items);
        });
        bind("bankAll", function(?exclude:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.bankAll(exclude);
        });
        bind("bankAllAcItems", function(?exclude:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.bankAllAc(exclude);
        });
        bind("getBankableItems", function(?exclude:Dynamic):Array<String> {
            return Api.inventory != null ? Api.inventory.getBankableItems(exclude) : [];
        });
        bind("getBankableAcItems", function(?exclude:Dynamic):Array<String> {
            return Api.inventory != null ? Api.inventory.getBankableAcItems(exclude) : [];
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
        bind("unbankAllNonAcItems", function(?exclude:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.unbankAllNonAc(exclude);
        });
        bind("getBankNonAcItems", function(?exclude:Dynamic):Array<String> {
            return Api.inventory != null ? Api.inventory.getBankNonAcItems(exclude) : [];
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
        bind("isInBank", function(itemNameOrId:String):Bool {
            return Api.inventory != null ? Api.inventory.isInBank(itemNameOrId) : false;
        });
        bind("isBankLoaded", function():Bool {
            return Api.inventory != null && Api.inventory.isBankLoaded;
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
    }

    // -------------------------------------------------------------------------
    // Player Status & Auras
    // -------------------------------------------------------------------------

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
        bind("className", function():String {
            return Api.player != null ? Api.player.className : "";
        });
        bind("playerX", function():Float {
            return Api.player != null ? Api.player.x : 0.0;
        });
        bind("playerY", function():Float {
            return Api.player != null ? Api.player.y : 0.0;
        });

        // Factions & Reputation
        bind("factionRank", function(name:String):Int {
            return Api.player != null ? Api.player.getFactionRank(name) : 0;
        });
        bind("getFactionRank", function(name:String):Int {
            return Api.player != null ? Api.player.getFactionRank(name) : 0;
        });
        bind("factionRep", function(name:String):Int {
            return Api.player != null ? Api.player.getFactionRep(name) : 0;
        });
        bind("getFactionRep", function(name:String):Int {
            return Api.player != null ? Api.player.getFactionRep(name) : 0;
        });

        // Target & Auras
        bind("getTarget", function():Dynamic {
            return Api.player != null ? Api.player.target : null;
        });
        bind("hasPlayerAura", function(auraName:String):Bool {
            return Api.player != null ? Api.player.hasAura(auraName) : false;
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
        bind("getAuraStacks", function(auraName:String, target:String = "player"):Float {
            return Api.aura != null ? Api.aura.getStacks(auraName, target) : 0.0;
        });
        bind("getAuraRemaining", function(auraName:String, target:String = "player"):Float {
            return Api.aura != null ? Api.aura.getRemaining(auraName, target) : 0.0;
        });
    }

    // -------------------------------------------------------------------------
    // Monster & Cell Queries
    // -------------------------------------------------------------------------

    private static function registerMonsterQueryShortcuts():Void {
        bind("isMonsterAliveInCell", function(cell:String):Bool {
            return Api.monster != null ? Api.monster.isMonsterAliveInCell(cell) : false;
        });
        bind("getLivingMonstersInCell", function(cell:String):Array<Dynamic> {
            return Api.monster != null ? cast Api.monster.getLivingMonstersInCell(cell) : [];
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

    // -------------------------------------------------------------------------
    // Network & Packets
    // -------------------------------------------------------------------------

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
    }

    // -------------------------------------------------------------------------
    // Enhancements
    // -------------------------------------------------------------------------

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
    }

    // -------------------------------------------------------------------------
    // Logging, Sleep & System Controls
    // -------------------------------------------------------------------------

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
        bind("msg", function(msg:Dynamic):Void {
            var str = Std.string(msg);
            ApiLogger.info("Script", str);
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, str));
        });

        bind("sleep", function(ms:Float):Void {
            HScriptEngine.SINGLETON.sleep(ms);
        });
        bind("stop", function():Void {
            HScriptEngine.SINGLETON.stop();
        });
        bind("skipCutscene", function():Void {
            if (Api.map != null) {
                Api.map.skipCutscenes = true;
                Api.map.checkSkipCutscenes();
            }
        });

        // Blacklist
        bind("addBlacklist", function(name:String):Void {
            Api.blacklist.add(name);
        });
        bind("removeBlacklist", function(name:String):Void {
            Api.blacklist.remove(name);
        });
        bind("isBlacklisted", function(name:String):Bool {
            return Api.blacklist.isBlacklisted(name);
        });
        bind("getBlacklist", function():Array<String> {
            return Api.blacklist.getList();
        });
        bind("clearBlacklist", function():Void {
            Api.blacklist.clear();
        });
        bind("sellBlacklist", function():Void {
            Api.blacklist.sellBlacklist();
        });
    }

    // -------------------------------------------------------------------------
    // Standard Libraries & Math Helpers
    // -------------------------------------------------------------------------

    private static function registerStdLibraries(interp:ScriptInterp):Void {
        interp.variables.set("Math", Math);
        interp.variables.set("Std", Std);
        interp.variables.set("StringTools", StringTools);
        interp.variables.set("Date", Date);
        interp.variables.set("ApiTime", ApiTime);
        interp.variables.set("now", function():Float {
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
