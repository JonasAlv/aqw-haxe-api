package com.aqwapi.managers;

import flash.utils.Timer;
import flash.events.TimerEvent;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.Api;
import com.aqwapi.data.QuestDTO;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiUtils;
import com.aqwapi.Game;

class QuestManager {
    private var _game:Game;
    private var _timer:Timer;
    private var _questIDs:Array<Dynamic> = [];
    private var _lastTurnIns:Dynamic = {};
    private var _lastLoadRequests:Map<Int, Float> = new Map<Int, Float>();
    private var _lastAcceptTime:Float = 0;
    private var _lastCompleteTime:Float = 0;
    public static inline var ACTION_COOLDOWN_MS:Int = 1100; // 1000ms AQW server cooldown + 100ms lag compensation
    private var _actionQueue:Array<{type:String, questId:Int, itemId:Int}> = [];
    private var _queueTimer:Timer = null;
    private var _lastActionTime:Float = 0;

    public function new(gameReference:Game) {
        _game = gameReference;
    }

    // ==========================================
    // LIVE QUEST DATA LOOKUP
    // ==========================================

    public function get(questId:Int):QuestDTO {
        if (_game != null && _game.world != null && _game.world.questTree != null) {
            var liveData = Reflect.field(_game.world.questTree, Std.string(questId));
            if (liveData != null) {
                return new QuestDTO(liveData);
            }
        }
        return null;
    }

    public inline function getQuest(questId:Int):QuestDTO {
        return get(questId);
    }

    public function getName(questId:Int):String {
        var q = get(questId);
        return q != null ? q.name : "";
    }

    public function getRequirements(questId:Int):Array<Dynamic> {
        var q = get(questId);
        return q != null ? q.requirements : [];
    }

    public function getRewards(questId:Int):Array<Dynamic> {
        var q = get(questId);
        return q != null ? q.rewards : [];
    }

    public function getChoiceRewards(questId:Int):Array<Dynamic> {
        var q = get(questId);
        return q != null ? q.choiceRewards : [];
    }

    public function isChoiceQuest(questId:Int):Bool {
        var q = get(questId);
        return q != null && q.isChoice;
    }

    public function getUnownedRewards(questId:Int):Array<Dynamic> {
        var choices = getChoiceRewards(questId);
        if (choices == null || choices.length == 0) return [];
        var result:Array<Dynamic> = [];
        for (r in choices) {
            if (r == null) continue;
            var rName:String = (r.sName != null) ? Std.string(r.sName) : ((r.name != null) ? Std.string(r.name) : "");
            var rId:Int = (r.ItemID != null) ? Std.int(r.ItemID) : ((r.id != null) ? Std.int(r.id) : 0);
            var owned:Bool = false;
            if (Api.inventory != null) {
                if (rName != "" && (Api.inventory.hasItem(rName) || Api.inventory.isInBank(rName))) {
                    owned = true;
                } else if (rId > 0 && (Api.inventory.hasItemById(rId) || Api.inventory.isInBank(Std.string(rId)))) {
                    owned = true;
                }
            }
            if (!owned) {
                result.push(r);
            }
        }
        return result;
    }

    public function getNextUnownedReward(questId:Int, ?preferredItems:Dynamic):Dynamic {
        var unowned = getUnownedRewards(questId);
        if (unowned.length == 0) return null;

        if (preferredItems != null) {
            var prefs:Array<String> = [];
            if (Std.isOfType(preferredItems, Array)) {
                for (p in (cast preferredItems:Array<Dynamic>)) {
                    if (p != null) prefs.push(StringTools.trim(Std.string(p)).toLowerCase());
                }
            } else {
                var s = Std.string(preferredItems);
                for (p in s.split(",")) {
                    var pt = StringTools.trim(p).toLowerCase();
                    if (pt != "") prefs.push(pt);
                }
            }

            for (pref in prefs) {
                for (r in unowned) {
                    var rName:String = (r.sName != null) ? Std.string(r.sName).toLowerCase() : ((r.name != null) ? Std.string(r.name).toLowerCase() : "");
                    var rId:String = (r.ItemID != null) ? Std.string(r.ItemID) : ((r.id != null) ? Std.string(r.id) : "");
                    if (rName == pref || rId == pref) {
                        return r;
                    }
                }
            }
        }

        return unowned[0];
    }

    public function resolveRewardId(questId:Int, rewardChoice:Dynamic):Int {
        if (rewardChoice == null) {
            if (isChoiceQuest(questId)) {
                var next = getNextUnownedReward(questId);
                if (next != null) {
                    return (next.ItemID != null) ? Std.int(next.ItemID) : ((next.id != null) ? Std.int(next.id) : -1);
                }
            }
            return -1;
        }

        if (Std.isOfType(rewardChoice, Int) || Std.isOfType(rewardChoice, Float)) {
            var id = Std.int(rewardChoice);
            if (id > 0) return id;
            if (id == -1 && isChoiceQuest(questId)) {
                var next = getNextUnownedReward(questId);
                if (next != null) {
                    return (next.ItemID != null) ? Std.int(next.ItemID) : ((next.id != null) ? Std.int(next.id) : -1);
                }
            }
            return -1;
        }

        var sChoice = StringTools.trim(Std.string(rewardChoice));
        var sLower = sChoice.toLowerCase();

        if (sLower == "unowned" || sLower == "choose" || sLower == "next" || sLower == "any") {
            var next = getNextUnownedReward(questId);
            if (next != null) {
                return (next.ItemID != null) ? Std.int(next.ItemID) : ((next.id != null) ? Std.int(next.id) : -1);
            }
            return -1;
        }

        var parsedId = ApiUtils.parseInt(sChoice, 0);
        if (parsedId > 0) return parsedId;

        var allRewards = getChoiceRewards(questId);
        if (allRewards.length == 0) allRewards = getRewards(questId);
        for (r in allRewards) {
            if (r == null) continue;
            var rName:String = (r.sName != null) ? Std.string(r.sName) : ((r.name != null) ? Std.string(r.name) : "");
            if (rName.toLowerCase() == sLower) {
                return (r.ItemID != null) ? Std.int(r.ItemID) : ((r.id != null) ? Std.int(r.id) : -1);
            }
        }

        return -1;
    }

    public function getAcceptRequirements(questId:Int):Array<Dynamic> {
        var q = get(questId);
        return q != null ? q.acceptRequirements : [];
    }

    public function search(query:String, maxResults:Int = 50):Array<QuestDTO> {
        var results:Array<QuestDTO> = [];
        if (_game == null || _game.world == null || _game.world.questTree == null || query == null || query == "") return results;
        var qLower:String = query.toLowerCase();
        for (key in Reflect.fields(_game.world.questTree)) {
            var item:Dynamic = Reflect.field(_game.world.questTree, key);
            if (item != null) {
                var dto = new QuestDTO(item);
                if (dto.name != null && dto.name.toLowerCase().indexOf(qLower) != -1) {
                    results.push(dto);
                    if (results.length >= maxResults) break;
                }
            }
        }
        return results;
    }

    public function hasRequirements(questId:Int):Bool {
        var q = get(questId);
        if (q == null) return false;

        var reqs:Array<Dynamic> = q.requirements;
        // If quest genuinely has no requirements, it's considered met
        if (reqs == null || reqs.length == 0) return true;

        if (Api.inventory == null) return false;

        for (req in reqs) {
            if (req == null) continue;
            var itemId:Int = (req.ItemID != null) ? Std.int(req.ItemID) : ((req.id != null) ? Std.int(req.id) : 0);
            var itemName:String = (req.sName != null) ? Std.string(req.sName) : ((req.name != null) ? Std.string(req.name) : "");
            var reqQty:Int = (req.iQty != null) ? Std.int(req.iQty) : ((req.qty != null) ? Std.int(req.qty) : 1);

            var curQty:Int = 0;

            // 1. Check world.invTree directly by ItemID (Fastest & most accurate AQW dictionary)
            if (_game != null && _game.world != null && _game.world.invTree != null && itemId > 0) {
                var treeItem:Dynamic = Reflect.field(_game.world.invTree, Std.string(itemId));
                if (treeItem != null) {
                    curQty = (treeItem.iQty != null) ? Std.int(treeItem.iQty) : 1;
                }
            }

            // 2. Check by ItemName if not satisfied by ID
            if (curQty < reqQty && itemName != "") {
                var questQty = Api.inventory.getQuestQuantity(itemName);
                var invQty = Api.inventory.getQuantity(itemName);
                var bestQty = questQty > invQty ? questQty : invQty;
                if (bestQty > curQty) curQty = bestQty;
            }

            // 3. Fallback check by ID string
            if (curQty < reqQty && itemId > 0) {
                var questIdQty = Api.inventory.getQuestQuantity(Std.string(itemId));
                var idQty = Api.inventory.getQuantity(Std.string(itemId));
                var bestIdQty = questIdQty > idQty ? questIdQty : idQty;
                if (bestIdQty > curQty) curQty = bestIdQty;
            }

            if (curQty < reqQty) {
                return false;
            }
        }
        return true;
    }

    // ==========================================
    // SERVER INTERACTION & NETWORK LOADING
    // ==========================================

    public function load(questId:Int):Void {
        var now:Float = ApiTime.now();
        if (_lastLoadRequests.exists(questId) && (now - _lastLoadRequests.get(questId)) < 1500) {
            return;
        }
        _lastLoadRequests.set(questId, now);
        if (_game != null && _game.world != null && _game.world.getQuests != null) {
            try {
                _game.world.getQuests([questId]);
            } catch (e:Dynamic) {}
        } else if (_game != null && _game.sfc != null) {
            var rId:Dynamic = (_game.world != null && _game.world.curRoom != null) ? _game.world.curRoom : 1;
            try {
                _game.sfc.sendXtMessage("zm", "getQuests", [questId], "str", rId);
            } catch (e:Dynamic) {}
        }
    }

    public function loadMultiple(questIds:Array<Int>):Void {
        if (questIds == null || questIds.length == 0) return;
        var toLoad:Array<Dynamic> = [];
        var now:Float = ApiTime.now();
        for (qid in questIds) {
            if (qid > 0 && !isLoaded(qid)) {
                if (!_lastLoadRequests.exists(qid) || (now - _lastLoadRequests.get(qid)) >= 1500) {
                    _lastLoadRequests.set(qid, now);
                    toLoad.push(qid);
                }
            }
        }
        if (toLoad.length == 0) return;
        if (_game != null && _game.world != null && _game.world.getQuests != null) {
            try {
                _game.world.getQuests(toLoad);
            } catch (e:Dynamic) {}
        } else if (_game != null && _game.sfc != null) {
            var rId:Dynamic = (_game.world != null && _game.world.curRoom != null) ? _game.world.curRoom : 1;
            try {
                _game.sfc.sendXtMessage("zm", "getQuests", toLoad, "str", rId);
            } catch (e:Dynamic) {}
        }
    }

    public function isLoaded(questId:Int):Bool {
        if (_game == null || _game.world == null || _game.world.questTree == null) return false;
        return Reflect.field(_game.world.questTree, Std.string(questId)) != null;
    }

    public function showQuests(questIds:String):Void {
        if (_game == null || _game.world == null) return;
        try {
            if (_game.world.showQuests != null) {
                _game.world.showQuests(questIds, "q");
            }
        } catch (e:Dynamic) {}
    }

    public function isInProgress(questId:Int):Bool {
        if (_game == null || _game.world == null || questId <= 0) return false;
        if (_game.world.questTree != null) {
            var qData:Dynamic = Reflect.field(_game.world.questTree, Std.string(questId));
            if (qData != null) {
                var s:Dynamic = qData.status;
                if (s == "p" || s == "c") return true;
                if (s == null || s == "" || s == "null") return false;
            }
        }
        if (_game.world.isQuestInProgress != null) {
            try {
                return _game.world.isQuestInProgress(questId);
            } catch (e:Dynamic) {}
        }
        return false;
    }

    public function accept(questId:Int):Void {
        if (_game == null || _game.world == null || questId <= 0) return;
        if (isInProgress(questId)) return;

        for (task in _actionQueue) {
            if (task.type == "accept" && task.questId == questId) return;
        }

        _actionQueue.push({type: "accept", questId: questId, itemId: -1});
        _pauseScriptIfRunning();
        processQueue();
    }

    public function acceptMultiple(questIds:Array<Int>):Void {
        if (questIds == null || questIds.length == 0) return;
        for (qid in questIds) {
            if (qid > 0) accept(qid);
        }
    }

    public function ensureAccept(questId:Int):Void {
        if (!isAccepted(questId) && !isAcceptQueued(questId)) {
            if (!isLoaded(questId)) load(questId);
            accept(questId);
        }
    }

    public function complete(questId:Int, itemId:Dynamic = -1):Void {
        if (_game == null || _game.world == null || questId <= 0) return;
        if (!isInProgress(questId)) return;

        var resolvedItemId:Int = resolveRewardId(questId, itemId);

        for (task in _actionQueue) {
            if (task.type == "complete" && task.questId == questId) return;
        }

        _actionQueue.push({type: "complete", questId: questId, itemId: resolvedItemId});
        _pauseScriptIfRunning();
        processQueue();
    }

    public function ensureComplete(questId:Int, itemIdOrCallback:Dynamic = -1, ?callback:Dynamic):Bool {
        if (!isInProgress(questId)) return true;
        if (canComplete(questId)) {
            var actualItemId:Dynamic = -1;
            var actualCallback:Dynamic = null;

            if (Reflect.isFunction(itemIdOrCallback)) {
                actualCallback = itemIdOrCallback;
            } else {
                actualItemId = itemIdOrCallback;
                actualCallback = callback;
            }

            complete(questId, actualItemId);
            if (actualCallback != null && Reflect.isFunction(actualCallback)) {
                haxe.Timer.delay(function() {
                    try { actualCallback(); } catch (e:Dynamic) {}
                }, 300);
            }
            return true;
        }
        return false;
    }

    public function ensureCompleteChoose(questId:Int, ?preferredItems:Dynamic):Bool {
        if (!isInProgress(questId)) return true;
        var next = getNextUnownedReward(questId, preferredItems);
        if (next == null) {
            ApiLogger.warn("Quest", "All choice rewards already owned for quest: " + questId);
            return false;
        }
        var nextId:Int = (next.ItemID != null) ? Std.int(next.ItemID) : ((next.id != null) ? Std.int(next.id) : -1);
        var nextName:String = (next.sName != null) ? Std.string(next.sName) : ((next.name != null) ? Std.string(next.name) : Std.string(nextId));
        ApiLogger.info("Quest", "Selected reward: " + nextName);
        return ensureComplete(questId, nextId);
    }

    public inline function turnIn(questId:Int, itemId:Dynamic = -1):Void {
        complete(questId, itemId);
    }

    public function completeMultiple(questIds:Array<Int>):Void {
        if (questIds == null || questIds.length == 0) return;
        for (qid in questIds) {
            if (qid > 0 && isAccepted(qid)) complete(qid);
        }
    }

    public function isActionQueued(type:String, questId:Int):Bool {
        for (task in _actionQueue) {
            if (task.type == type && task.questId == questId) return true;
        }
        return false;
    }

    public inline function isAcceptQueued(questId:Int):Bool {
        return isActionQueued("accept", questId);
    }

    public inline function isCompleteQueued(questId:Int):Bool {
        return isActionQueued("complete", questId);
    }

    public function clearQueue():Void {
        _actionQueue = [];
        if (_queueTimer != null) {
            _queueTimer.stop();
            _queueTimer.removeEventListener(TimerEvent.TIMER, onQueueTimer);
            _queueTimer = null;
        }
    }

    private function _pauseScriptIfRunning():Void {
        try {
            var engine = com.aqwapi.scripting.HScriptEngine.SINGLETON;
            if (engine != null && engine.isRunning) {
                engine.sleep(ACTION_COOLDOWN_MS);
            }
        } catch (_:Dynamic) {}
    }

    private function processQueue():Void {
        if (_actionQueue.length == 0) return;
        if (_queueTimer != null && _queueTimer.running) return;

        var now = ApiTime.now();
        var elapsed = now - _lastActionTime;
        if (elapsed < ACTION_COOLDOWN_MS) {
            var waitMs = Std.int(ACTION_COOLDOWN_MS - elapsed);
            if (waitMs < 20) waitMs = 20;
            if (_queueTimer != null) {
                _queueTimer.stop();
                _queueTimer.removeEventListener(TimerEvent.TIMER, onQueueTimer);
            }
            _queueTimer = new Timer(waitMs, 1);
            _queueTimer.addEventListener(TimerEvent.TIMER, onQueueTimer, false, 0, true);
            _queueTimer.start();
            return;
        }

        var task = _actionQueue.shift();
        if (task == null) return;

        _lastActionTime = ApiTime.now();

        if (task.type == "accept") {
            _executeAccept(task.questId);
        } else if (task.type == "complete") {
            _executeComplete(task.questId, task.itemId);
        }

        if (_actionQueue.length > 0) {
            if (_queueTimer != null) {
                _queueTimer.stop();
                _queueTimer.removeEventListener(TimerEvent.TIMER, onQueueTimer);
            }
            _queueTimer = new Timer(ACTION_COOLDOWN_MS, 1);
            _queueTimer.addEventListener(TimerEvent.TIMER, onQueueTimer, false, 0, true);
            _queueTimer.start();
        }
    }

    private function onQueueTimer(e:TimerEvent):Void {
        if (_queueTimer != null) {
            _queueTimer.stop();
            _queueTimer.removeEventListener(TimerEvent.TIMER, onQueueTimer);
            _queueTimer = null;
        }
        processQueue();
    }

    private function _executeAccept(questId:Int):Void {
        if (_game == null || _game.world == null || questId <= 0) return;
        if (isInProgress(questId)) return;

        _lastAcceptTime = ApiTime.now();

        if (_game.world.lock != null) {
            try {
                var lObj:Dynamic = Reflect.field(_game.world.lock, "acceptQuest");
                if (lObj != null) lObj.ts = Date.now().getTime();
            } catch (e:Dynamic) {}
        }

        var accepted:Bool = false;
        if (_game.world.acceptQuest != null) {
            try {
                _game.world.acceptQuest(questId);
                accepted = true;
            } catch (e:Dynamic) {}
        }

        if (!accepted && _game.sfc != null) {
            try {
                var curRoom:Dynamic = _game.world.curRoom;
                _game.sfc.sendXtMessage("zm", "acceptQuest", [questId], "str", curRoom);
                if (_game.world.questTree != null) {
                    var qData:Dynamic = Reflect.field(_game.world.questTree, Std.string(questId));
                    if (qData != null) qData.status = "p";
                }
            } catch (e:Dynamic) {}
        }
    }

    private function _executeComplete(questId:Int, itemId:Int = -1):Void {
        if (_game == null || _game.world == null || questId <= 0) return;
        if (!isInProgress(questId)) return;

        var now = ApiTime.now();
        var lastQTurnIn:Float = Reflect.hasField(_lastTurnIns, Std.string(questId)) ? Reflect.field(_lastTurnIns, Std.string(questId)) : 0.0;
        if (now - lastQTurnIn < ACTION_COOLDOWN_MS) return;
        Reflect.setField(_lastTurnIns, Std.string(questId), now);

        _lastCompleteTime = now;

        if (_game.world.lock != null) {
            try {
                var lObj:Dynamic = Reflect.field(_game.world.lock, "tryQuestComplete");
                if (lObj != null) lObj.ts = Date.now().getTime();
            } catch (e:Dynamic) {}
        }

        if (_game.world != null && _game.world.questTree != null) {
            try {
                var qData:Dynamic = Reflect.field(_game.world.questTree, Std.string(questId));
                if (qData != null) qData.status = null;
            } catch (e:Dynamic) {}
        }

        if (_game.world.tryQuestComplete != null) {
            try {
                if (itemId > 0) {
                    _game.world.tryQuestComplete(questId, itemId);
                } else {
                    _game.world.tryQuestComplete(questId);
                }
            } catch (e:Dynamic) {}
        }
    }

    public function getQuestValue(slot:Int):Int {
        if (_game == null || _game.world == null) return 0;
        try {
            if (_game.world.getQuestValue != null) {
                var val:Dynamic = _game.world.getQuestValue(slot);
                if (val != null) return Std.int(val);
            }
        } catch (e:Dynamic) {}
        try {
            if (_game.world.questSlots != null && Reflect.field(_game.world.questSlots, Std.string(slot)) != null) {
                var qsVal:Dynamic = Reflect.field(_game.world.questSlots, Std.string(slot));
                if (qsVal != null) return Std.int(qsVal);
            }
        } catch (e:Dynamic) {}
        return 0;
    }

    // ==========================================
    // STATUS & PROGRESS CHECKS
    // ==========================================

    public function isCompleted(questId:Int):Bool {
        var qslot:Int = -1;
        var qval:Int = 0;

        if (_game != null && _game.world != null && _game.world.questTree != null) {
            var qData:Dynamic = Reflect.field(_game.world.questTree, Std.string(questId));
            if (qData != null) {
                qslot = (qData.iSlot != null) ? Std.int(qData.iSlot) : -1;
                qval = (qData.iValue != null) ? Std.int(qData.iValue) : 0;
            }
        }

        if (qslot >= 0) {
            return getQuestValue(qslot) >= qval;
        }

        return false;
    }

    public inline function isComplete(questId:Int):Bool {
        return isCompleted(questId);
    }

    public inline function hasBeenCompleted(questId:Int):Bool {
        return isCompleted(questId);
    }

    public function isUnlocked(questId:Int):Bool {
        var qslot:Int = -1;
        var qval:Int = 0;

        if (_game != null && _game.world != null && _game.world.questTree != null) {
            var qData:Dynamic = Reflect.field(_game.world.questTree, Std.string(questId));
            if (qData != null) {
                qslot = (qData.iSlot != null) ? Std.int(qData.iSlot) : -1;
                qval = (qData.iValue != null) ? Std.int(qData.iValue) : 0;
            }
        }

        if (qslot < 0) return true;
        return getQuestValue(qslot) >= (qval - 1);
    }

    public function isDailyComplete(questId:Int):Bool {
        var sField:String = null;
        var iIndex:Int = 0;

        if (_game != null && _game.world != null && _game.world.questTree != null) {
            var qData:Dynamic = Reflect.field(_game.world.questTree, Std.string(questId));
            if (qData != null) {
                sField = qData.sField;
                iIndex = (qData.iIndex != null) ? Std.int(qData.iIndex) : 0;
            }
        }

        if (sField != null && _game != null && _game.world != null && _game.world.getAchievement != null) {
            try {
                var ach = _game.world.getAchievement(sField, iIndex);
                return ach != null && Std.int(ach) > 0;
            } catch (e:Dynamic) {}
        }
        return false;
    }

    public function canComplete(questId:Int):Bool {
        if (_game == null || _game.world == null) return false;
        if (isCompleteQueued(questId)) return false;

        // Must be currently in progress
        if (!isInProgress(questId)) return false;

        // Must strictly satisfy all required items in inventory/temp inventory
        return hasRequirements(questId);
    }

    public inline function isAccepted(questId:Int):Bool {
        return isInProgress(questId) || isAcceptQueued(questId);
    }

    public inline function hasActive(questId:Int):Bool {
        return isInProgress(questId);
    }

    public inline function isActive(questId:Int):Bool {
        return isInProgress(questId);
    }

    public function isAvailable(questId:Int):Bool {
        var q = get(questId);
        if (q == null) return false;

        var world = _game != null ? _game.world : null;
        if (world == null) return false;
        var myAvatar = world.myAvatar;
        if (myAvatar == null || myAvatar.objData == null) return false;

        // 1. One-time quest already done
        if (q.once && q.slot >= 0) {
            if (getQuestValue(q.slot) >= q.value) return false;
        }

        // 2. Member / Upgrade requirement
        if (q.upgrade) {
            var isUpgraded:Bool = (myAvatar.isUpgraded != null) ? myAvatar.isUpgraded() : false;
            if (!isUpgraded) return false;
        }

        // 3. Level requirement
        var pLvl:Int = (myAvatar.objData.intLevel != null) ? Std.int(myAvatar.objData.intLevel) : 0;
        if (q.level > pLvl) return false;

        // 4. Prerequisite slot requirement
        if (q.slot >= 0 && q.value > 0) {
            var curVal:Int = getQuestValue(q.slot);
            var reqVal:Int = Std.int(Math.abs(q.value)) - 1;
            if (curVal < reqVal) return false;
        }

        // 5. Daily or Special Achievement Flag
        if (isDailyComplete(questId)) return false;

        return true;
    }

    // ==========================================
    // AUTO QUEST BACKGROUND LOOP
    // ==========================================

    public var isAutoRunning(get, never):Bool;

    @:getter(isAutoRunning)
    public function get_isAutoRunning_prop():Bool {
        return _timer != null && _timer.running;
    }
    public function get_isAutoRunning():Bool {
        return _timer != null && _timer.running;
    }

    public var autoQuestString(get, never):String;

    @:getter(autoQuestString)
    public function get_autoQuestString_prop():String {
        return get_autoQuestString();
    }
    public function get_autoQuestString():String {
        if (_questIDs == null || _questIDs.length == 0) return "";
        var arr:Array<String> = [];
        for (q in _questIDs) {
            if (q.itemId > 0) arr.push(q.qid + ":" + q.itemId);
            else arr.push(Std.string(q.qid));
        }
        return arr.join(", ");
    }

    public inline function auto(quests:Dynamic):Void {
        startAuto(quests);
    }

    public inline function autoQuest(quests:Dynamic):Void {
        startAuto(quests);
    }

    public function startAuto(quests:Dynamic):Void {
        stopAuto();

        if (quests == null) return;

        var qList:Array<String> = [];
        if (Std.isOfType(quests, Array)) {
            var rawArr:Array<Dynamic> = cast quests;
            for (item in rawArr) {
                if (item != null) qList.push(Std.string(item));
            }
        } else {
            var str:String = Std.string(quests);
            if (str.length == 0) return;
            qList = str.split(",");
        }

        _questIDs = [];
        var qidsToLoad:Array<Int> = [];
        for (raw in qList) {
            var rawTrimmed = StringTools.trim(raw);
            var subParts:Array<String> = rawTrimmed.split(":");
            var val:Int = ApiUtils.parseInt(subParts[0], 0);
            if (val > 0) {
                var itemId:Int = -1;
                if (subParts.length > 1) {
                    itemId = ApiUtils.parseInt(subParts[1], -1);
                }
                _questIDs.push({ qid: val, itemId: itemId });
                qidsToLoad.push(val);
            }
        }

        if (_questIDs.length > 0) {
            // Preload all quest definitions immediately so world.questTree has them
            loadMultiple(qidsToLoad);

            _lastTurnIns = {};
            _timer = new Timer(800);
            _timer.addEventListener(TimerEvent.TIMER, onAutoTick, false, 0, true);
            _timer.start();
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "Auto Quest started: " + autoQuestString));
            ApiLogger.info("Quest", "Auto Quest started: " + autoQuestString);
        }
    }

    public function stopAuto():Void {
        if (_timer != null) {
            _timer.stop();
            _timer.removeEventListener(TimerEvent.TIMER, onAutoTick);
            _timer = null;
            clearQueue();
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "Quests Stopped!"));
            ApiLogger.info("Quest", "AutoQuest Stopped!");
        }
    }

    private function onAutoTick(e:TimerEvent):Void {
        if (_game == null || _game.world == null) return;

        // If the built-in action queue is currently busy executing an accept or complete, wait for it
        if (_actionQueue.length > 0 || (_queueTimer != null && _queueTimer.running)) return;

        try {
            // First: ensure all configured quests are loaded into questTree
            var unloaded:Array<Int> = [];
            for (qObj in _questIDs) {
                var qid:Int = qObj.qid;
                if (!isLoaded(qid)) unloaded.push(qid);
            }
            if (unloaded.length > 0) {
                loadMultiple(unloaded);
                return;
            }

            // Second: check each quest in order
            for (qObj in _questIDs) {
                var qid:Int = qObj.qid;
                var itemId:Int = qObj.itemId;

                if (isAcceptQueued(qid) || isCompleteQueued(qid)) continue;

                var inProgress:Bool = isInProgress(qid);

                if (inProgress) {
                    // Check if ready to turn in
                    if (canComplete(qid)) {
                        ApiLogger.info("Quest", "[AutoQuest] Turning in completed quest " + qid);
                        complete(qid, itemId);
                        return; // Paced by action queue (1100ms cooldown)
                    }
                    // Quest is in progress but requirements not yet met -> continue loop to process/accept other quests!
                } else {
                    // Quest not in progress -> accept it!
                    if (isLoaded(qid)) {
                        ApiLogger.info("Quest", "[AutoQuest] Accepting quest " + qid);
                        accept(qid);
                        return; // Paced by action queue (1100ms cooldown)
                    }
                }
            }
        } catch (err:Dynamic) {
            var msg:String = Std.string(err);
            #if flash
            try {
                if (Std.isOfType(err, flash.errors.Error)) {
                    var flashErr:flash.errors.Error = cast err;
                    var st:String = flashErr.getStackTrace();
                    if (st != null && st != "") msg += " @ " + st;
                }
            } catch (_:Dynamic) {}
            #end
            ApiLogger.error("Quest", "AutoQuest Error: " + msg);
        }
    }
}
