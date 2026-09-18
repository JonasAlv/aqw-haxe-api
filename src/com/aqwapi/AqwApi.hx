package com.aqwapi;

import flash.events.EventDispatcher;
import com.aqwapi.interfaces.*;
import com.aqwapi.managers.*;
import com.aqwapi.net.TransportAdapter;
import com.aqwapi.scripting.HScriptEngine;
import com.aqwapi.utils.ApiLogger;

class AqwApi {
    public static var dispatcher(default, null):EventDispatcher = new EventDispatcher();
    public static var logger:Class<ApiLogger> = ApiLogger;
    public static var game(default, null):AQWGame;
    public static var map(default, null):ScriptMap;
    public static var player(default, null):ScriptPlayer;
    public static var quest(default, null):ScriptQuest;
    public static var combat(default, null):ScriptCombat;
    public static var inventory(default, null):ScriptInventory;
    public static var drops(default, null):ScriptDrops;
    public static var shop(default, null):ScriptShop;
    public static var monsters(default, null):ScriptMonster;
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
        drops = new ScriptDrops(game);
        shop = new ScriptShop(game);
        monsters = new ScriptMonster(game);
        hscript = HScriptEngine.SINGLETON;
    }

    public static var isReady(get, never):Bool;
    public static function get_isReady():Bool {
        return game != null && game.world != null;
    }
}
