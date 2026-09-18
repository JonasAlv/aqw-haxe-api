package com.aqwapi.managers;

import com.aqwapi.interfaces.IScriptQuest;
import flash.utils.Timer;
import flash.events.TimerEvent;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.AqwApi;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwTime;

class ScriptQuest implements IScriptQuest {
    private var _game:AQWGame;
    private var _timer:Timer;
    private var _questIDs:Array<Dynamic> = [];
    private var _lastTurnIns:Dynamic = {};

    public function new(gameReference:AQWGame) {
        _game = gameReference;
    }

    public function load(questId:Int):Void {
        if (_game != null && _game.world != null && _game.world.getQuests != null) {
            _game.world.getQuests([questId]);
        }
    }

    public function isInProgress(questId:Int):Bool {
        if (_game != null && _game.world != null && _game.world.isQuestInProgress != null) {
            return _game.world.isQuestInProgress(questId);
        }
        return false;
    }

    public function accept(questId:Int):Void {
        if (_game != null && _game.world != null && _game.world.acceptQuest != null) {
            if (_game.world.questTree != null && Reflect.field(_game.world.questTree, Std.string(questId)) != null) {
                _game.world.acceptQuest(questId);
            } else {
                AqwApi.dispatcher.dispatchEvent(new ApiEvent(
                    ApiEvent.NOTIFICATION,
                    "Quest " + questId + " not loaded! Skipping accept."
                ));
            }
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

    public function isCompleted(questId:Int):Bool {
        if (_game == null || _game.world == null || _game.world.questTree == null) return false;

        var qData:Dynamic = Reflect.field(_game.world.questTree, Std.string(questId));
        if (qData == null) return false;

        var qslot:Int = (qData.iSlot != null) ? Std.int(qData.iSlot) : -1;
        var qval:Int = (qData.iValue != null) ? Std.int(qData.iValue) : 0;

        if (qslot >= 0) {
            try {
                if (_game.world.getQuestValue != null) {
                    var slotVal:Dynamic = _game.world.getQuestValue(qslot);
                    if (slotVal != null && Std.int(slotVal) >= qval) {
                        return true;
                    }
                }
            } catch (e:Dynamic) {}

            try {
                if (_game.world.questSlots != null && Reflect.field(_game.world.questSlots, Std.string(qslot)) != null) {
                    var qsVal:Dynamic = Reflect.field(_game.world.questSlots, Std.string(qslot));
                    if (Std.int(qsVal) >= qval) {
                        return true;
                    }
                }
            } catch (e:Dynamic) {}
        }

        return false;
    }

    public inline function isComplete(questId:Int):Bool {
        return isCompleted(questId);
    }

    public inline function isAccepted(questId:Int):Bool {
        return isInProgress(questId);
    }

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
        for (raw in parts) {
            var subParts:Array<String> = raw.split(":");
            var val:Int = com.aqwapi.utils.AqwUtils.parseInt(subParts[0], 0);
            if (val > 0) {
                var itemId:Int = -1;
                if (subParts.length > 1) {
                    itemId = com.aqwapi.utils.AqwUtils.parseInt(subParts[1], -1);
                }
                _questIDs.push({ qid: val, itemId: itemId });
            }
        }

        if (_questIDs.length > 0) {
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
            if (_game.world.questTree != null) {
                var now:Float = AqwTime.now();
                for (qObj in _questIDs) {
                    var qid:Int = qObj.qid;
                    var itemId:Int = qObj.itemId;
                    var qKey:String = Std.string(qid);

                    var lastAttempt:Float = 0;
                    var la:Null<Float> = Reflect.field(_lastTurnIns, qKey);
                    if (la != null) lastAttempt = la;

                    if (now - lastAttempt < 2000) continue;

                    var quest:Dynamic = Reflect.field(_game.world.questTree, qKey);
                    if (quest != null) {
                        if (quest.status == "c") {
                            Reflect.setField(_lastTurnIns, qKey, now);
                            complete(qid, itemId);
                            break;
                        } else if (quest.status == null || quest.status == "") {
                            Reflect.setField(_lastTurnIns, qKey, now);
                            accept(qid);
                            break;
                        }
                    } else {
                        Reflect.setField(_lastTurnIns, qKey, now);
                        accept(qid);
                        break;
                    }
                }
            }
        } catch (err:Dynamic) {
            ApiLogger.error("Quest", "AutoQuest Error: " + Std.string(err));
        }
    }
}
