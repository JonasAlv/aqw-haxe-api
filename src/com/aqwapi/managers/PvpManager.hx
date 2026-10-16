package com.aqwapi.managers;

import com.aqwapi.Api;
import com.aqwapi.Game;
import com.aqwapi.utils.ApiLogger;

/**
 * Thin, source-backed facade for AQW PvP queue requests.
 *
 * AE_source/docs/GAME_SYSTEMS.md identifies World.requestPVPQueue as the
 * game's queue entry point. This manager intentionally calls that entry point
 * instead of guessing transport arguments.
 *
 * A true return means the client method was invoked, not that the server
 * accepted the queue request. Observe GameEvent.PVP_UPDATED for responses.
 */
class PvpManager {
    private var _game:Game;

    public function new(gameReference:Game) {
        _game = gameReference;
    }

    private inline function _g():Game {
        return (_game != null) ? _game : Api.game;
    }

    private inline function _world():Dynamic {
        var g = _g();
        return (g != null) ? g.world : null;
    }

    /**
     * Requests the selected PvP queue/warzone through the game's own API.
     * The queue identifier must match the value understood by the current client.
     */
    public function requestQueue(queueName:String):Bool {
        var name = (queueName != null) ? StringTools.trim(queueName) : "";
        if (name == "" || name.toLowerCase() == "none") return false;
        return requestNativeQueue(name);
    }

    /** Leaves the current PvP queue using the game's documented "none" value. */
    public function leaveQueue():Bool {
        return requestNativeQueue("none");
    }

    private function requestNativeQueue(queueName:String):Bool {
        var w = _world();
        if (w == null || !Reflect.isFunction(w.requestPVPQueue)) return false;
        try {
            w.requestPVPQueue(queueName);
            ApiLogger.debug("PvP", "Dispatched requestPVPQueue");
            return true;
        } catch (e:Dynamic) {
            ApiLogger.warn("PvP", "Could not dispatch requestPVPQueue: " + Std.string(e));
            return false;
        }
    }
}
