package com.aqwapi.net;

import com.aqwapi.events.GameEvent;
import com.aqwapi.AqwApi;
import com.aqwapi.utils.ApiLogger;

class TransportAdapter {
    private var _game:AqwGame;

    public function new(gameReference:AqwGame) {
        _game = gameReference;
    }

    public function send(namespaceId:String, command:String, args:Array<Dynamic>):Void {
        if (_game == null || _game.sfc == null) return;
        var packet:String = "%xt%" + namespaceId + "%" + command + "%";
        packet += args.join("%") + "%";
        _game.sfc.sendString(packet);
        ApiLogger.debug("Transport", "Sent: " + packet);
    }

    public function sendExtensionCommand(command:String, args:Array<Dynamic>):Void {
        if (_game == null || _game.sfc == null) return;
        var roomId:Dynamic = (_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : _game.sfc.myUserId;
        var fullArgs:Array<Dynamic> = [roomId].concat(args);
        send("zm", command, fullArgs);
    }

    public function handleResponse(event:Dynamic):Void {
        if (event == null || event.params == null) return;
        var type:String = Std.string(event.params.type);
        var cmd:String = "";
        var dataObj:Dynamic = null;

        if (type == "json") {
            cmd = Std.string(event.params.dataObj.cmd);
            dataObj = event.params.dataObj;
        } else if (type == "str") {
            var resObj:Array<Dynamic> = cast event.params.dataObj;
            cmd = resObj[0];
            dataObj = resObj;
        } else if (type == "xml") {
            if (event.params.dataObj != null)
                cmd = Std.string(event.params.dataObj.name);
        }

        if (AqwApi.hscript != null) {
            AqwApi.hscript.handlePacket(type, cmd, dataObj);
        }

        switch (cmd) {
            case "moveToArea":
                AqwApi.dispatcher.dispatchEvent(new GameEvent(GameEvent.ZONE_ENTERED, dataObj));
            case "getQuests", "getQuests2", "getQuest":
                AqwApi.dispatcher.dispatchEvent(new GameEvent(GameEvent.QUEST_UPDATED, dataObj));
            case "equipItem", "unequipItem", "buyItem", "sellItem", "getDrop":
                AqwApi.dispatcher.dispatchEvent(new GameEvent(GameEvent.INVENTORY_CHANGED, dataObj));
            default:
        }

    }
}
