package com.aqwapi;

import flash.events.EventDispatcher;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.managers.*;
import com.aqwapi.net.TransportAdapter;
import com.aqwapi.scripting.HScriptEngine;
import com.aqwapi.utils.ApiLogger;

class Api {
    public static var dispatcher(default, null):EventDispatcher = new EventDispatcher();
    public static var logger:Class<ApiLogger> = ApiLogger;
    public static var game(default, null):Game;

    // All 8 Core Managers (Strictly Singular)
    public static var map(default, null):MapManager = new MapManager(null);
    public static var player(default, null):PlayerManager = new PlayerManager(null);
    public static var quest(default, null):QuestManager = new QuestManager(null);
    public static var combat(default, null):CombatManager = new CombatManager(null);
    public static var inventory(default, null):InventoryManager = new InventoryManager(null);
    public static var drop(default, null):DropManager = new DropManager(null);
    public static var shop(default, null):ShopManager = new ShopManager(null);
    public static var monster(default, null):MonsterManager = new MonsterManager(null);
    public static var enhancement(default, null):EnhancementManager = new EnhancementManager(null);

    // Plural aliases (Skua / RBot convention)
    public static var quests(get, never):QuestManager;
    @:getter(quests)
    public static function get_quests_prop():QuestManager { return quest; }
    public static function get_quests():QuestManager { return quest; }

    public static var drops(get, never):DropManager;
    @:getter(drops)
    public static function get_drops_prop():DropManager { return drop; }
    public static function get_drops():DropManager { return drop; }

    public static var monsters(get, never):MonsterManager;
    @:getter(monsters)
    public static function get_monsters_prop():MonsterManager { return monster; }
    public static function get_monsters():MonsterManager { return monster; }

    public static var shops(get, never):ShopManager;
    @:getter(shops)
    public static function get_shops_prop():ShopManager { return shop; }
    public static function get_shops():ShopManager { return shop; }

    public static var enhancements(get, never):EnhancementManager;
    @:getter(enhancements)
    public static function get_enhancements_prop():EnhancementManager { return enhancement; }
    public static function get_enhancements():EnhancementManager { return enhancement; }

    // Direct script helpers on bot / api
    public static inline function smartEnhance(?className:String, force:Bool = false):Void {
        enhancement.smartEnhance(className, force);
    }

    public static inline function enhanceEquipped(type:String, ?cSpecial:String, ?hSpecial:String, ?wSpecial:String):Void {
        enhancement.enhanceEquipped(type, cSpecial, hSpecial, wSpecial);
    }

    public static inline function sleep(ms:Float):Void {
        HScriptEngine.SINGLETON.sleep(ms);
    }

    public static inline function log(msg:Dynamic):Void {
        ApiLogger.info("Bot", Std.string(msg));
    }

    public static inline function warn(msg:Dynamic):Void {
        ApiLogger.warn("Bot", Std.string(msg));
    }

    public static inline function error(msg:Dynamic):Void {
        ApiLogger.error("Bot", Std.string(msg));
    }

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
        com.aqwapi.utils.ApiStorage.ensureFiles();
    }

    public static function preloadAssets():Void {
        ensureMathShims();
        ensureStorage();
        try {
            com.aqwapi.modules.CombatEngine.init();
        } catch (e:Dynamic) {
            var msg:String = Std.string(e);
            #if flash
            try {
                if (Std.isOfType(e, flash.errors.Error)) {
                    var fe:flash.errors.Error = cast e;
                    var st:String = fe.getStackTrace();
                    if (st != null && st != "") msg += " @ " + st;
                }
            } catch (_:Dynamic) {}
            #end
            ApiLogger.warn("Api", "CombatEngine preload error: " + msg);
        }
        try {
            com.aqwapi.modules.UserSkillsManager.ensureStorageInitialized();
            com.aqwapi.modules.UserSkillsManager.readUserSkillsObject();
        } catch (_:Dynamic) {}
    }

    public static function init(gameReference:Game):Void {
        ensureMathShims();
        preloadAssets();
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
        enhancement = new EnhancementManager(game);
        hscript = HScriptEngine.SINGLETON;

        if (transport != null) transport.start();
        if (drop != null) drop.start();
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
