package com.aqwapi;

import flash.events.EventDispatcher;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.managers.*;
import com.aqwapi.net.TransportAdapter;
import com.aqwapi.scripting.HScriptEngine;
import com.aqwapi.utils.ApiLogger;

class AqwApi {
    public static var dispatcher(default, null):EventDispatcher = new EventDispatcher();
    public static var logger:Class<ApiLogger> = ApiLogger;
    public static var game(default, null):AqwGame;

    // All 8 Core Managers (Strictly Singular)
    public static var map(default, null):MapManager;
    public static var player(default, null):PlayerManager;
    public static var quest(default, null):QuestManager;
    public static var combat(default, null):CombatManager;
    public static var inventory(default, null):InventoryManager;
    public static var drop(default, null):DropManager;
    public static var shop(default, null):ShopManager;
    public static var monster(default, null):MonsterManager;

    public static var transport(default, null):TransportAdapter;
    public static var hscript(default, null):HScriptEngine;

    static function __init__():Void {
        ensureMathShims();
    }

    public static function ensureMathShims():Void {
        #if flash
        try {
            var m:Dynamic = untyped __global__["Math"];
            if (m != null) {
                if (m.isNaN == null) {
                    m.isNaN = function(v:Float):Bool { return v != v; };
                }
                if (m.isFinite == null) {
                    m.isFinite = function(v:Float):Bool {
                        return (v == v) && v != Math.POSITIVE_INFINITY && v != Math.NEGATIVE_INFINITY;
                    };
                }
            }
        } catch (_:Dynamic) {}
        #end
    }

    public static function ensureStorage():Void {
        com.aqwapi.utils.AqwStorage.ensureFiles();
    }

    public static function init(gameReference:Dynamic):Void {
        ensureMathShims();
        ensureStorage();
        game = cast gameReference;
        transport = new TransportAdapter(game);
        map = new MapManager(game);
        quest = new QuestManager(game);
        combat = new CombatManager(game);
        inventory = new InventoryManager(game);
        player = new PlayerManager(game);
        drop = new DropManager(game);
        shop = new ShopManager(game);
        monster = new MonsterManager(game);
        hscript = HScriptEngine.SINGLETON;
    }

    public static function notify(message:String):Void {
        if (message == null || message == "") return;
        if (dispatcher != null) {
            dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, message));
        }
    }

    public static var isReady(get, never):Bool;
    @:getter(isReady)
    public static function get_isReady_prop():Bool { return get_isReady(); }
    public static function get_isReady():Bool {
        return game != null && game.world != null;
    }
}
