package com.aqwapi;

import flash.events.EventDispatcher;
import com.aqwapi.managers.*;
import com.aqwapi.net.TransportAdapter;
import com.aqwapi.scripting.HScriptEngine;
import com.aqwapi.utils.ApiLogger;

class AqwApi {
    public static var dispatcher(default, null):EventDispatcher = new EventDispatcher();
    public static var logger:Class<ApiLogger> = ApiLogger;
    public static var game(default, null):AqwGame;

    // All 8 Core Managers (Strictly Singular)
    public static var map(default, null):ScriptMap;
    public static var player(default, null):ScriptPlayer;
    public static var quest(default, null):ScriptQuest;
    public static var combat(default, null):ScriptCombat;
    public static var inventory(default, null):ScriptInventory;
    public static var drop(default, null):ScriptDrop;
    public static var shop(default, null):ScriptShop;
    public static var monster(default, null):ScriptMonster;

    public static var transport(default, null):TransportAdapter;
    public static var hscript(default, null):HScriptEngine;

    public static function init(gameReference:Dynamic):Void {
        game = cast gameReference;
        transport = new TransportAdapter(game);
        map = new ScriptMap(game);
        quest = new ScriptQuest(game);
        combat = new ScriptCombat(game);
        inventory = new ScriptInventory(game);
        player = new ScriptPlayer(game);
        drop = new ScriptDrop(game);
        shop = new ScriptShop(game);
        monster = new ScriptMonster(game);

        #if flash
        try {
            if ((untyped Math).isNaN == null) {
                (untyped Math).isNaN = untyped __global__["isNaN"];
            }
            if ((untyped Math).isFinite == null) {
                (untyped Math).isFinite = untyped __global__["isFinite"];
            }
        } catch (e:Dynamic) {}
        #end
        hscript = HScriptEngine.SINGLETON;
    }

    public static var isReady(get, never):Bool;
    @:getter(isReady)
    public static function get_isReady_prop():Bool { return get_isReady(); }
    public static function get_isReady():Bool {
        return game != null && game.world != null;
    }
}
