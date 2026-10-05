package com.aqwapi.net;

import com.aqwapi.events.GameEvent;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.Game;

/**
 * Network adapter bridging the AQW SmartFoxClient packet stream to high-level API events.
 *
 * Upstream AS3 Network Architecture:
 *  - Game communicates with the server via SmartFoxClient (`game.sfc`).
 *  - Inbound Packets: Received via the `"onExtensionResponse"` event on `sfc`.
 *      * Carries `event.params.type` ("json" or "str") and data payloads.
 *  - Outbound Packets: Sent via `sfc.sendString("%xt%...")` or `sendXtMessage(...)`.
 *
 * Event Translation:
 *  - Decodes low-level wire commands into strongly-typed `GameEvent` dispatches:
 *      * `dropItem` -> `GameEvent.DROP_RECEIVED`
 *      * `equipItem` -> `GameEvent.EQUIP_ITEM`
 *      * `loadBank` -> `GameEvent.LOAD_BANK`
 *      * `updateQuest` -> `GameEvent.UPDATE_QUEST`
 *      * `buyItem` -> `GameEvent.BUY_ITEM`
 */
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

        if (Api.hscript != null) {
            Api.hscript.handlePacket(type, cmd, dataObj);
        }

        switch (cmd) {
            case "moveToArea":
                Api.dispatcher.dispatchEvent(new GameEvent(GameEvent.ZONE_ENTERED, dataObj));
            case "getQuests", "getQuests2", "getQuest", "acceptQuest", "cc":
                Api.dispatcher.dispatchEvent(new GameEvent(GameEvent.QUEST_UPDATED, dataObj));
            case "equipItem", "unequipItem", "buyItem", "sellItem", "getDrop", "bankFromInv", "bankToInv", "loadBank":
                if (cmd == "loadBank" && Api.inventory != null) {
                    Api.inventory.onBankLoaded();
                }
                Api.dispatcher.dispatchEvent(new GameEvent(GameEvent.INVENTORY_CHANGED, dataObj));
            default:
        }

    }
}
