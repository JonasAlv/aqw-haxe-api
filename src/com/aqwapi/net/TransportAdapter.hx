package com.aqwapi.net;

import com.aqwapi.events.GameEvent;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.Game;

class TransportAdapter {
    private var _game:Game;
    private var _isListening:Bool = false;
    private var _attachedSfc:Dynamic = null;

    public function new(gameReference:Game) {
        _game = gameReference;
        start();
    }

    public function ensureListening():Void {
        if (_game == null || _game.sfc == null) return;
        if (!_isListening || _attachedSfc != _game.sfc) {
            if (_attachedSfc != null && _attachedSfc != _game.sfc) {
                try {
                    _attachedSfc.removeEventListener("onExtensionResponse", handleResponse);
                } catch (_:Dynamic) {}
                _isListening = false;
                _attachedSfc = null;
            }
            start();
        }
    }

    public function start():Void {
        if (_game == null || _game.sfc == null) return;
        if (_isListening && _attachedSfc == _game.sfc) return;
        try {
            _game.sfc.addEventListener("onExtensionResponse", handleResponse, false, 0, true);
            _isListening = true;
            _attachedSfc = _game.sfc;
            ApiLogger.debug("Transport", "TransportAdapter listener attached to sfc");
        } catch (e:Dynamic) {
            ApiLogger.warn("Transport", "Failed to attach sfc listener: " + e);
        }
    }

    public function stop():Void {
        if (!_isListening) return;
        try {
            if (_attachedSfc != null) {
                _attachedSfc.removeEventListener("onExtensionResponse", handleResponse);
            } else if (_game != null && _game.sfc != null) {
                _game.sfc.removeEventListener("onExtensionResponse", handleResponse);
            }
        } catch (e:Dynamic) {}
        _isListening = false;
        _attachedSfc = null;
    }

    public function send(namespaceId:String, command:String, args:Array<Dynamic>):Void {
        ensureListening();
        if (_game == null || _game.sfc == null) return;
        var safeArgs:Array<Dynamic> = (args != null) ? args : [];
        var packet:String = "%xt%" + namespaceId + "%" + command + "%";
        packet += safeArgs.join("%") + "%";
        _game.sfc.sendString(packet);
        ApiLogger.debug("Transport", "Sent namespace=" + namespaceId + " command=" + command + " argCount=" + safeArgs.length);
    }

    public function sendXt(extName:String, command:String, args:Array<Dynamic>, type:String = "str", roomId:Int = 1):Void {
        ensureListening();
        if (_game == null || _game.sfc == null) return;
        var safeArgs:Array<Dynamic> = (args != null) ? args : [];
        try {
            if (_game.sfc.sendXtMessage != null) {
                _game.sfc.sendXtMessage(extName, command, safeArgs, type, roomId);
                return;
            }
        } catch (_:Dynamic) {}
        send(extName, command, ([roomId] : Array<Dynamic>).concat(safeArgs));
    }

    public function sendExtensionCommand(command:String, args:Array<Dynamic>):Void {
        ensureListening();
        if (_game == null || _game.sfc == null) return;
        // Extension commands use the active room id. A user id is not a valid fallback.
        if (_game.sfc.activeRoomId == null) {
            ApiLogger.warn("Transport", "Skipped extension command without an active room: " + command);
            return;
        }
        var roomId:Dynamic = _game.sfc.activeRoomId;
        var safeArgs:Array<Dynamic> = (args != null) ? args : [];
        var fullArgs:Array<Dynamic> = [roomId].concat(safeArgs);
        send("zm", command, fullArgs);
    }

    public function handleResponse(event:Dynamic):Void {
        if (event == null || event.params == null) return;
        var type:String = Std.string(event.params.type);
        var cmd:String = "";
        var dataObj:Dynamic = null;

        var payload:Dynamic = event.params.dataObj;
        if (type == "json") {
            if (payload != null && payload.cmd != null) cmd = Std.string(payload.cmd);
            dataObj = payload;
        } else if (type == "str") {
            if (payload != null) {
                var resObj:Array<Dynamic> = cast payload;
                if (resObj.length > 0 && resObj[0] != null) cmd = Std.string(resObj[0]);
                dataObj = resObj;
            }
        } else if (type == "xml") {
            // Preserve the legacy XML command extraction for existing HScript consumers.
            // Guard it because malformed/unexpected XML payloads must not break dispatch.
            dataObj = payload;
            try {
                if (payload != null && payload.name != null) cmd = Std.string(payload.name);
            } catch (_:Dynamic) {}
        }

        if (Api.hscript != null) {
            Api.hscript.handlePacket(type, cmd, dataObj);
        }

        switch (cmd) {
            // Keep combat responses available to script and UI consumers as a typed event. Payloads
            // remain raw because each command has a different, version-sensitive wire shape.
            case "ct":
                if (Api.combat != null && Api.combat.emitCombatTickEvents) {
                    Api.dispatcher.dispatchEvent(new GameEvent(GameEvent.COMBAT_UPDATED, {
                        command: cmd,
                        payload: dataObj
                    }));
                }
            case "cb", "sar", "sars", "showAuraResult", "anim", "sAct", "stu", "event", "initMonData":
                Api.dispatcher.dispatchEvent(new GameEvent(GameEvent.COMBAT_UPDATED, {
                    command: cmd,
                    payload: dataObj
                }));
            case "moveToArea":
                var curUser:String = (Api.player != null) ? Api.player.username : "";
                if (curUser == "" && _game != null && _game.sfc != null && _game.sfc.myUserName != null) {
                    curUser = Std.string(_game.sfc.myUserName);
                }
                if (curUser != "") {
                    com.aqwapi.utils.ApiStorage.setAccount(curUser);
                }
                if (Api.map != null) {
                    Api.map.recordJoinTime();
                }
                Api.dispatcher.dispatchEvent(new GameEvent(GameEvent.ZONE_ENTERED, dataObj));
            case "getQuests", "getQuests2", "getQuest", "acceptQuest", "updateQuest", "ccqr":
                if (cmd == "ccqr" && Api.quest != null) {
                    Api.quest.onCompleteQuestResult(dataObj);
                }
                Api.dispatcher.dispatchEvent(new GameEvent(GameEvent.QUEST_UPDATED, dataObj));
            case "initInventory", "loadInventoryBig", "balance", "addGoldExp", "equipItem", "unequipItem", "buyItem", "sellItem", "dropItem", "getDrop", "bankFromInv", "bankToInv", "bankSwapInv", "loadBank", "forceAddItem", "monsterDrops":
                if (cmd == "loadBank" && Api.inventory != null) {
                    Api.inventory.onBankLoaded();
                }
                Api.dispatcher.dispatchEvent(new GameEvent(GameEvent.INVENTORY_CHANGED, dataObj));
            case "gp", "uotls":
                Api.dispatcher.dispatchEvent(new com.aqwapi.events.ApiEvent(com.aqwapi.events.ApiEvent.PARTY_UPDATED, cmd, dataObj));
            default:
        }

    }
}
