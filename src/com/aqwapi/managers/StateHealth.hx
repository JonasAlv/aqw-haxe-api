package com.aqwapi.managers;

import com.aqwapi.Api;
import com.aqwapi.events.GameEvent;
import com.aqwapi.utils.ApiTime;

/** Reports whether a live data source exists and how recently it emitted an update. */
class StateHealth {
    private static var _instance:StateHealth;
    private var _last:Map<String, Float> = new Map();

    public static function instance():StateHealth {
        if (_instance == null) _instance = new StateHealth();
        return _instance;
    }

    private function new() {
        Api.dispatcher.addEventListener(GameEvent.ZONE_ENTERED, function(_) {
            mark("map"); mark("player"); mark("target");
        });
        Api.dispatcher.addEventListener(GameEvent.INVENTORY_CHANGED, function(_) mark("inventory"));
        Api.dispatcher.addEventListener(GameEvent.QUEST_UPDATED, function(_) mark("quests"));
        Api.dispatcher.addEventListener(GameEvent.COMBAT_UPDATED, function(_) {
            mark("player"); mark("target"); mark("auras");
        });
    }

    private function mark(domain:String):Void _last.set(domain, ApiTime.epochMs());

    /**
     * Returns `unavailable` when the backing game data is missing, `unknown` before
     * the first update event, otherwise `fresh` or `stale` based on staleAfterMs.
     * Age is milliseconds since the last observed update, not proof of server truth.
     */
    public function get(domain:String, staleAfterMs:Float = 30000):Dynamic {
        var key = (domain == null) ? "" : StringTools.trim(domain).toLowerCase();
        var available = switch (key) {
            case "player": Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null;
            case "target": Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null && Api.game.world.myAvatar.target != null;
            case "auras": Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null;
            case "map": Api.game != null && Api.game.world != null && Api.game.world.map != null;
            case "inventory": Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null && Api.game.world.myAvatar.items != null;
            case "quests": Api.game != null && Api.game.world != null && Api.game.world.questTree != null;
            default: false;
        };
        var last = _last.exists(key) ? _last.get(key) : 0.0;
        var age = last > 0 ? ApiTime.epochMs() - last : -1.0;
        var status = !available ? "unavailable" : (last <= 0 ? "unknown" : (age > staleAfterMs ? "stale" : "fresh"));
        return { domain: key, available: available, status: status, ageMs: age, lastUpdatedAt: last, staleAfterMs: staleAfterMs };
    }
}
