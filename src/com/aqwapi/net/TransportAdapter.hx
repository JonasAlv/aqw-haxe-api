package com.aqwapi.net;

import com.aqwapi.events.GameEvent;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiUtils;
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

        processInboundCombat(cmd, dataObj);

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

    // ---------------------------------------------------------------------------
    // Reactive combat tracking
    //
    // The server resolves every swing and ships the outcome back. It arrives as:
    //   "sar"  - one action, one result  (World.handleSAR)
    //   "sars" - one attacker, many targets (World.handleSARS)
    //   "ct"   - periodic combat tick that CARRIES both as `sara[]` / `sarsa[]`
    //
    // Payload shape differs between the two, and this is the trap:
    //   sar  -> dataObj.actionResult.a[0] is a COPY OF actionResult, so it carries cInf
    //   sars -> cInf lives on the PARENT (dataObj.cInf); the a[] entries only have
    //           {tInf, hp, type}
    // Hence cInf is threaded in as a parameter rather than read off each entry.
    //
    // `typ == "d"` marks aura/DoT damage, not a swing, so it is excluded - otherwise a
    // DoT tick would masquerade as a monster attack and fire reactive counters.
    //
    // Reading `dataObj` here is safe even though the game's own priority-0 handler already
    // ran: handleSAR/handleSARS only ever mutate `copyObj(...)` duplicates, never the
    // deserialized original.
    // ---------------------------------------------------------------------------

    private static function processInboundCombat(cmd:String, dataObj:Dynamic):Void {
        if (dataObj == null || Api.game == null || Api.game.sfc == null) return;
        if (cmd != "sar" && cmd != "sars" && cmd != "ct") return;

        var myUserId:String = Std.string(Api.game.sfc.myUserId);
        var myTargetInf:String = "p:" + myUserId;

        var handleActionList = function(actions:Dynamic, cInf:Dynamic):Void {
            if (actions == null || cInf == null || !Std.isOfType(actions, Array)) return;
            var cInfStr:String = Std.string(cInf);
            for (act in (cast actions : Array<Dynamic>)) {
                if (act == null) continue;
                var tInf:String = (act.tInf != null) ? Std.string(act.tInf) : "";
                if (tInf == "" || tInf != myTargetInf) continue;
                // Self-cast (own skill resolving back onto us) is not an incoming attack.
                if (cInfStr == myTargetInf) continue;

                Api.lastIncomingAttackAt = ApiTime.now();
                Api.lastIncomingAttackType = (act.type != null) ? Std.string(act.type).toLowerCase() : "";
                Api.lastIncomingAttackerMMID = StringTools.startsWith(cInfStr, "m:") ? cInfStr.substr(2) : "";
                // Wire `hp` is >= 0 for damage and NEGATIVE for healing. Clamp rather than
                // Math.abs, so a heal resolving on the player reads as 0 damage instead of
                // being mistaken for a hit worth reacting to.
                Api.lastIncomingAttackHp = (act.hp != null) ? Std.int(Math.max(0, ApiUtils.parseFloat(act.hp, 0))) : 0;

                // Feed the cadence learner, but only for monster swings - another player's
                // attack resolves on us through the same path and would pollute the rhythm.
                if (Api.lastIncomingAttackerMMID != "") {
                    com.aqwapi.combat.AttackCadence.record(Api.lastIncomingAttackAt);
                }
            }
        };

        if (cmd == "sar") {
            if (dataObj.iRes == 1 && dataObj.actionResult != null) {
                if (dataObj.actionResult.typ != "d") {
                    handleActionList(dataObj.actionResult.a, dataObj.actionResult.cInf);
                }
            }
        } else if (cmd == "sars") {
            if (dataObj.iRes == 1) {
                handleActionList(dataObj.a, dataObj.cInf);
            }
        } else {
            if (Std.isOfType(dataObj.sara, Array)) {
                for (subSar in (cast dataObj.sara : Array<Dynamic>)) {
                    if (subSar != null && subSar.iRes == 1 && subSar.actionResult != null && subSar.actionResult.typ != "d") {
                        handleActionList(subSar.actionResult.a, subSar.actionResult.cInf);
                    }
                }
            }
            if (Std.isOfType(dataObj.sarsa, Array)) {
                for (subSars in (cast dataObj.sarsa : Array<Dynamic>)) {
                    if (subSars != null && subSars.iRes == 1) {
                        handleActionList(subSars.a, subSars.cInf);
                    }
                }
            }
        }
    }
}
