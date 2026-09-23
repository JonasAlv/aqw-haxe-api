package com.aqwapi.managers;

import flash.utils.Timer;
import flash.events.TimerEvent;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.AqwApi;
import com.aqwapi.data.QuestDTO;
import com.aqwapi.modules.QuestDataLoader;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwTime;

class ScriptQuest {
    private var _game:AqwGame;
    private var _timer:Timer;
    private var _questIDs:Array<Dynamic> = [];
    private var _lastTurnIns:Dynamic = {};
    private var _lastLoadRequests:Map<Int, Float> = new Map<Int, Float>();

    public function new(gameReference:AqwGame) {
        _game = gameReference;
    }

    // ==========================================
    // OFFLINE & ONLINE QUEST DATA LOOKUP
    // ==========================================

    public function get(questId:Int):QuestDTO {
        if (_game != null && _game.world != null && _game.world.questTree != null) {
            var liveData = Reflect.field(_game.world.questTree, Std.string(questId));
            if (liveData != null) {
                return new QuestDTO(liveData);
            }
        }
        return QuestDataLoader.get(questId);
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

    public function getAcceptRequirements(questId:Int):Array<Dynamic> {
        var q = get(questId);
        return q != null ? q.acceptRequirements : [];
    }

    public function search(query:String, maxResults:Int = 50):Array<QuestDTO> {
        return QuestDataLoader.search(query, maxResults);
    }

    public function hasRequirements(questId:Int):Bool {
        var q = get(questId);
        if (q == null) return false;

        var reqs:Array<Dynamic> = q.requirements;
        if ((reqs == null || reqs.length == 0) && questId > 0) {
            var offQ = QuestDataLoader.get(questId);
            if (offQ != null && offQ.requirements != null && offQ.requirements.length > 0) {
                reqs = offQ.requirements;
            }
        }

        // If quest genuinely has no requirements, it's considered met
        if (reqs == null || reqs.length == 0) return true;

        if (AqwApi.inventory == null) return false;

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
                var questQty = AqwApi.inventory.getQuestQuantity(itemName);
                var invQty = AqwApi.inventory.getQuantity(itemName);
                var bestQty = questQty > invQty ? questQty : invQty;
                if (bestQty > curQty) curQty = bestQty;
            }

            // 3. Fallback check by ID string
            if (curQty < reqQty && itemId > 0) {
                var idQty = AqwApi.inventory.getQuantity(Std.string(itemId));
                if (idQty > curQty) curQty = idQty;
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
        var now:Float = AqwTime.now();
        if (_lastLoadRequests.exists(questId) && (now - _lastLoadRequests.get(questId)) < 1500) {
            return;
        }
        _lastLoadRequests.set(questId, now);
        if (_game != null && _game.world != null && _game.world.getQuests != null) {
            try {
                _game.world.getQuests([questId]);
            } catch (e:Dynamic) {}
        } else if (_game != null && _game.sfc != null) {
            var rId:Dynamic = (_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : 1;
            _game.sfc.sendString("%xt%zm%getQuests%" + rId + "%" + questId + "%");
        }
    }

    public function loadMultiple(questIds:Array<Int>):Void {
        if (questIds == null || questIds.length == 0) return;
        var toLoad:Array<Dynamic> = [];
        var now:Float = AqwTime.now();
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
            var rId:Dynamic = (_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : 1;
            _game.sfc.sendString("%xt%zm%getQuests%" + rId + "%" + toLoad.join("%") + "%");
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
        if (_game != null && _game.world != null) {
            if (_game.world.isQuestInProgress != null) {
                try {
                    return _game.world.isQuestInProgress(questId);
                } catch (e:Dynamic) {}
            }
            if (_game.world.questTree != null) {
                var qData:Dynamic = Reflect.field(_game.world.questTree, Std.string(questId));
                if (qData != null && qData.status != null && qData.status != "") {
                    return true;
                }
            }
        }
        return false;
    }

    public function accept(questId:Int):Void {
        if (_game == null || _game.world == null) return;
        if (isLoaded(questId)) {
            var accepted:Bool = false;
            if (_game.world.acceptQuest != null) {
                try {
                    _game.world.acceptQuest(questId);
                    accepted = true;
                } catch (e:Dynamic) {}
            }
            if (!accepted && _game.sfc != null) {
                try {
                    var rId:Dynamic = (_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : _game.world.curRoom;
                    _game.sfc.sendString("%xt%zm%acceptQuest%" + rId + "%" + questId + "%");
                } catch (e:Dynamic) {}
            }
        } else {
            // Automatically request quest data from server if not yet loaded
            load(questId);
        }
    }

    public function acceptMultiple(questIds:Array<Int>):Void {
        if (questIds == null || questIds.length == 0) return;
        for (qid in questIds) {
            if (qid > 0) accept(qid);
        }
    }

    public function complete(questId:Int, itemId:Int = -1):Void {
        if (_game != null && _game.world != null && _game.world.tryQuestComplete != null) {
            if (itemId > 0) {
                _game.world.tryQuestComplete(questId, itemId);
            } else {
                _game.world.tryQuestComplete(questId);
            }
        }
    }

    public function completeMultiple(questIds:Array<Int>):Void {
        if (questIds == null || questIds.length == 0) return;
        for (qid in questIds) {
            if (qid > 0 && isAccepted(qid)) complete(qid);
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
    // STATUS & PROGRESS CHECKS (WITH OFFLINE FALLBACK)
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

        // Offline fallback to QuestData.json
        if (qslot < 0) {
            var offlineQ = QuestDataLoader.get(questId);
            if (offlineQ != null) {
                qslot = offlineQ.slot;
                qval = offlineQ.value;
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

        // Offline fallback to QuestData.json
        if (qslot < 0) {
            var offlineQ = QuestDataLoader.get(questId);
            if (offlineQ != null) {
                qslot = offlineQ.slot;
                qval = offlineQ.value;
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

        // Offline fallback to QuestData.json
        if (sField == null) {
            var offlineQ = QuestDataLoader.get(questId);
            if (offlineQ != null && offlineQ.field != null) {
                sField = offlineQ.field;
                iIndex = offlineQ.index;
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

        // Must be currently in progress
        if (!isInProgress(questId)) return false;

        // If Flash client marked it complete ("c")
        if (_game.world.questTree != null) {
            var qData:Dynamic = Reflect.field(_game.world.questTree, Std.string(questId));
            if (qData != null && qData.status != null && Std.string(qData.status) == "c") {
                return true;
            }
        }

        // Native AQW check
        if (_game.world.canTurnInQuest != null) {
            try {
                if (_game.world.canTurnInQuest(questId)) {
                    return true;
                }
            } catch (e:Dynamic) {}
        }

        return hasRequirements(questId);
    }

    public inline function isAccepted(questId:Int):Bool {
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

    public function startAuto(questString:String):Void {
        stopAuto();

        if (questString == null || questString.length == 0) return;

        var parts:Array<String> = questString.split(",");
        _questIDs = [];
        var qidsToLoad:Array<Int> = [];
        for (raw in parts) {
            var subParts:Array<String> = raw.split(":");
            var val:Int = com.aqwapi.utils.AqwUtils.parseInt(subParts[0], 0);
            if (val > 0) {
                var itemId:Int = -1;
                if (subParts.length > 1) {
                    itemId = com.aqwapi.utils.AqwUtils.parseInt(subParts[1], -1);
                }
                _questIDs.push({ qid: val, itemId: itemId });
                qidsToLoad.push(val);
            }
        }

        if (_questIDs.length > 0) {
            // Preload all quest definitions immediately so world.questTree has them
            loadMultiple(qidsToLoad);

            _lastTurnIns = {};
            _timer = new Timer(1500);
            _timer.addEventListener(TimerEvent.TIMER, onAutoTick, false, 0, true);
            _timer.start();
            AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "Auto Quest started: " + parts.join(", ")));
            ApiLogger.info("Quest", "Auto Quest started: " + parts.join(", "));
        }
    }

    public function stopAuto():Void {
        if (_timer != null) {
            _timer.stop();
            _timer.removeEventListener(TimerEvent.TIMER, onAutoTick);
            _timer = null;
            AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "Quests Stopped!"));
            ApiLogger.info("Quest", "Quests Stopped!");
        }
    }

    private function onAutoTick(e:TimerEvent):Void {
        if (_game == null || _game.world == null) return;

        try {
            var now:Float = AqwTime.now();

            // First: ensure all quests in _questIDs are loaded into questTree
            var unloaded:Array<Int> = [];
            for (qObj in _questIDs) {
                var qid:Int = qObj.qid;
                if (!isLoaded(qid)) unloaded.push(qid);
            }
            if (unloaded.length > 0) {
                loadMultiple(unloaded);
            }

            // Second: check each quest
            for (qObj in _questIDs) {
                var qid:Int = qObj.qid;
                var itemId:Int = qObj.itemId;
                var qKey:String = Std.string(qid);

                var lastAttempt:Float = 0;
                var la:Null<Float> = Reflect.field(_lastTurnIns, qKey);
                if (la != null) lastAttempt = la;

                if (now - lastAttempt < 2000) continue;

                var inProgress:Bool = isInProgress(qid);

                if (inProgress) {
                    // Check if ready to turn in
                    if (canComplete(qid)) {
                        Reflect.setField(_lastTurnIns, qKey, now);
                        ApiLogger.info("Quest", "Completing quest " + qid);
                        complete(qid, itemId);
                        break; // Only complete one per tick to prevent server packet flood
                    }
                    // Quest is in progress but requirements not yet met -> continue loop to process/accept other quests!
                } else {
                    // Quest not in progress -> accept it!
                    if (isLoaded(qid)) {
                        Reflect.setField(_lastTurnIns, qKey, now);
                        ApiLogger.info("Quest", "Accepting quest " + qid);
                        accept(qid);
                        break; // Accept one per tick for clean server handshake
                    }
                }
            }
        } catch (err:Dynamic) {
            ApiLogger.error("Quest", "AutoQuest Error: " + Std.string(err));
        }
    }
}
