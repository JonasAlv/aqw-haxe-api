package com.aqwapi.modules;

import com.aqwapi.AqwApi;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwTime;
import flash.events.TimerEvent;
import flash.utils.Timer;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.events.MouseEvent;

class QuestManager {
    private static var _timer:Timer;
    private static var _questIDs:Array<Dynamic> = [];
    private static var _lastTurnIns:Dynamic = {};
    private static var _promptContainer:Sprite;
    private static var _promptInput:TextField;

    public static function toggle():Void {
        if (_timer != null) stop(); else showPrompt();
    }

    public static function startWith(questString:String):Void {
        var input = new TextField();
        input.text = questString;
        if (input.text.length > 0) {
            var parts = input.text.split(",");
            _questIDs = [];
            for (raw in parts) {
                var subParts = raw.split(":");
                var val:Int = com.aqwapi.utils.AqwUtils.parseInt(subParts[0], 0);
                if (val > 0) {
                    var itemId:Int = -1;
                    if (subParts.length > 1) {
                        itemId = com.aqwapi.utils.AqwUtils.parseInt(subParts[1], -1);
                    }
                    _questIDs.push({ qid: val, itemId: itemId });
                }
            }
        }
        hidePrompt();
        if (_questIDs.length > 0) start();
    }

    public static function showPrompt():Void {
        if (_promptContainer != null) hidePrompt();

        ApiLogger.info("Quest", "Opening Auto-Quest Settings...");

        try {
            _promptContainer = new Sprite();
            _promptContainer.graphics.beginFill(0x222222, 0.95);
            _promptContainer.graphics.lineStyle(4, 0x00FF00);
            _promptContainer.graphics.drawRoundRect(0, 0, 400, 200, 20, 20);
            _promptContainer.graphics.endFill();
            _promptContainer.x = (960 - 400) / 2;
            _promptContainer.y = (550 - 200) / 2;

            var title = new TextField();
            var tfTitle = new TextFormat("_sans", 24, 0xFFFFFF, true);
            tfTitle.align = TextFormatAlign.CENTER;
            title.defaultTextFormat = tfTitle;
            title.text = "Enter Quest IDs (e.g. 123, 456:789)";
            title.width = 400;
            title.y = 30;
            title.selectable = false;

            _promptInput = new TextField();
            _promptInput.type = TextFieldType.INPUT;
            var tfInput = new TextFormat("_sans", 32, 0x000000, true);
            tfInput.align = TextFormatAlign.CENTER;
            _promptInput.defaultTextFormat = tfInput;
            _promptInput.background = true;
            _promptInput.backgroundColor = 0xFFFFFF;
            _promptInput.border = true;
            _promptInput.borderColor = 0x000000;
            _promptInput.width = 300;
            _promptInput.height = 50;
            _promptInput.x = 50;
            _promptInput.y = 80;
            _promptInput.maxChars = 30;
            _promptInput.restrict = "0-9, :";

            if (_questIDs.length > 0) {
                var strList:Array<String> = [];
                for (qObj in _questIDs) {
                    if (qObj.itemId > 0) strList.push(qObj.qid + ":" + qObj.itemId);
                    else strList.push(Std.string(qObj.qid));
                }
                _promptInput.text = strList.join(",");
            }

            var btnOK = new Sprite();
            btnOK.graphics.beginFill(0x00CC00, 1);
            btnOK.graphics.lineStyle(2, 0xFFFFFF);
            btnOK.graphics.drawRoundRect(0, 0, 150, 45, 10, 10);
            btnOK.graphics.endFill();
            btnOK.x = 125;
            btnOK.y = 140;
            btnOK.buttonMode = true;

            var txtOK = new TextField();
            var tfOK = new TextFormat("_sans", 20, 0xFFFFFF, true);
            tfOK.align = TextFormatAlign.CENTER;
            txtOK.defaultTextFormat = tfOK;
            txtOK.text = "START";
            txtOK.width = 150;
            txtOK.y = 10;
            txtOK.mouseEnabled = false;
            btnOK.addChild(txtOK);
            btnOK.addEventListener(MouseEvent.CLICK, onPromptOK);

            _promptContainer.addChild(title);
            _promptContainer.addChild(_promptInput);
            _promptContainer.addChild(btnOK);

            if (AqwApi.game != null && AqwApi.game.ui != null)
                AqwApi.game.ui.addChild(_promptContainer);
            else if (AqwApi.game != null)
                (cast AqwApi.game : Dynamic).addChild(_promptContainer);

        } catch (err:Dynamic) {
            ApiLogger.error("Quest", "Prompt error: " + Std.string(err));
        }
    }

    private static function hidePrompt():Void {
        if (_promptContainer != null && _promptContainer.parent != null)
            _promptContainer.parent.removeChild(_promptContainer);
        _promptContainer = null;
        _promptInput = null;
    }

    private static function onPromptOK(e:MouseEvent):Void {
        if (_promptInput != null && _promptInput.text.length > 0) {
            var parts = _promptInput.text.split(",");
            _questIDs = [];
            for (raw in parts) {
                var subParts = raw.split(":");
                var val:Int = com.aqwapi.utils.AqwUtils.parseInt(subParts[0], 0);
                if (val > 0) {
                    var itemId:Int = -1;
                    if (subParts.length > 1) {
                        itemId = com.aqwapi.utils.AqwUtils.parseInt(subParts[1], -1);
                    }
                    _questIDs.push({ qid: val, itemId: itemId });
                }
            }
        }
        hidePrompt();
        if (_questIDs.length > 0) start();
    }

    public static function stopSilent():Void {
        if (_timer != null) {
            _timer.stop();
            _timer.removeEventListener(TimerEvent.TIMER, onTick);
            _timer = null;
        }
    }

    private static function stop():Void {
        if (_timer != null) {
            _timer.stop();
            _timer.removeEventListener(TimerEvent.TIMER, onTick);
            _timer = null;
            ApiLogger.info("Quest", "Auto-Quest Disabled");
        }
    }

    private static function start():Void {
        stop();
        _lastTurnIns = {};
        _timer = new Timer(1500);
        _timer.addEventListener(TimerEvent.TIMER, onTick, false, 0, true);
        _timer.start();

        var strList:Array<String> = [];
        for (q in _questIDs) {
            if (q.itemId > 0) strList.push(q.qid + ":" + q.itemId);
            else strList.push(Std.string(q.qid));
        }
        ApiLogger.info("Quest", "Auto-Quest Enabled: " + strList.join(","));
    }

    private static function onTick(e:TimerEvent):Void {
        if (AqwApi.game == null || AqwApi.game.world == null) return;
        var world:Dynamic = AqwApi.game.world;
        try {
            if (world.questTree != null) {
                var now:Float = AqwTime.now();
                for (q in _questIDs) {
                    var qid:Int = q.qid;
                    var qKey:String = Std.string(qid);
                    var qData:Dynamic = Reflect.field(world.questTree, qKey);
                    if (qData == null) continue;

                    var status:String = (qData.status != null) ? Std.string(qData.status) : "";
                    var lastAction:Float = Reflect.hasField(_lastTurnIns, qKey) ? Reflect.field(_lastTurnIns, qKey) : 0.0;
                    if (now - lastAction < 2000) continue;

                    if (status == "c") {
                        if (world.tryQuestComplete != null) {
                            Reflect.setField(_lastTurnIns, qKey, now);
                            if (q.itemId > 0) world.tryQuestComplete(qid, q.itemId);
                            else world.tryQuestComplete(qid);
                            break;
                        }
                    } else if (status != "a") {
                        if (world.acceptQuest != null) {
                            Reflect.setField(_lastTurnIns, qKey, now);
                            world.acceptQuest(qid);
                            break;
                        }
                    }
                }
            }
        } catch (err:Dynamic) {
            ApiLogger.error("Quest", "AutoQuest Error: " + Std.string(err));
        }
    }
}
