package com.aqwapi.net;

import com.aqwapi.events.GameEvent;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.Game;

class TransportAdapter {
    private var _game:Game;
    private var _isListening:Bool = false;

    public function new(gameReference:Game) {
        _game = gameReference;
        start();
    }

    public function start():Void {
        if (_isListening || _game == null || _game.sfc == null) return;
        try {
            _game.sfc.addEventListener("onExtensionResponse", handleResponse, false, 0, true);
            _isListening = true;
            ApiLogger.debug("Transport", "TransportAdapter listener attached to sfc");
        } catch (e:Dynamic) {
            ApiLogger.warn("Transport", "Failed to attach sfc listener: " + e);
        }
    }

    public function stop():Void {
        if (!_isListening || _game == null || _game.sfc == null) return;
        try {
            _game.sfc.removeEventListener("onExtensionResponse", handleResponse);
            _isListening = false;
        } catch (e:Dynamic) {}
    }

    public function send(namespaceId:String, command:String, args:Array<Dynamic>):Void {
        if (!_isListening && _game != null && _game.sfc != null) start();
        if (_game == null || _game.sfc == null) return;
        var safeArgs:Array<Dynamic> = (args != null) ? args : [];
        var packet:String = "%xt%" + namespaceId + "%" + command + "%";
        packet += safeArgs.join("%") + "%";
        _game.sfc.sendString(packet);
        // Do not log complete frames: arguments may contain private chat or other user data.
        ApiLogger.debug("Transport", "Sent namespace=" + namespaceId + " command=" + command + " argCount=" + safeArgs.length);
    }

    public function sendExtensionCommand(command:String, args:Array<Dynamic>):Void {
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
            // XML response command extraction is not established as stable in AE_source;
            // keep the payload available to script listeners but don't guess a command.
            dataObj = payload;
        }

        if (Api.hscript != null) {
            Api.hscript.handlePacket(type, cmd, dataObj);
        }

        switch (cmd) {
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
            case "getQuests", "getQuests2", "getQuest", "acceptQuest":
                Api.dispatcher.dispatchEvent(new GameEvent(GameEvent.QUEST_UPDATED, dataObj));
            case "cc", "chatm", "whisper", "em":
                Api.dispatcher.dispatchEvent(new GameEvent(GameEvent.CHAT_MESSAGE, dataObj));
            case "friends", "getfriendlist", "loadFriendsList", "requestFriend", "addFriend", "declineFriend", "deleteFriend", "updateFriend":
                Api.dispatcher.dispatchEvent(new GameEvent(GameEvent.SOCIAL_UPDATED, dataObj));
            case "gi", "gd", "ga", "gr", "gMOTD", "updateGuild", "gc", "guildDelete":
                Api.dispatcher.dispatchEvent(new GameEvent(GameEvent.GUILD_UPDATED, dataObj));
            case "PVPQ", "PVPI", "PVPE", "PVPS", "PVPC", "di", "DuelEX", "dungeonMTC":
                Api.dispatcher.dispatchEvent(new GameEvent(GameEvent.PVP_UPDATED, dataObj));
            case "house", "loadHouseInventory", "interior", "guildhall", "guildinv":
                Api.dispatcher.dispatchEvent(new GameEvent(GameEvent.HOUSE_UPDATED, dataObj));
            case "equipItem", "unequipItem", "buyItem", "sellItem", "getDrop", "bankFromInv", "bankToInv", "loadBank":
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
