package com.aqwapi;

import flash.events.EventDispatcher;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.managers.*;
import com.aqwapi.net.TransportAdapter;
import com.aqwapi.scripting.HScriptEngine;
import com.aqwapi.utils.ApiLogger;

/**
 * Global static facade and primary entry point for the AQW Haxe API.
 *
 * Architecture and Runtime Lifecycle:
 *  - Injection & Boot: `Api.init(gameReference)` is invoked by `Pocket.as` / `ModBootstrap.as`
 *    once the Flash ApplicationDomain has loaded and the main root `Game.as` instance is live.
 *  - Subsystem Registration: Centralizes and exposes specialized domain managers:
 *      * player: Local avatar state, vital stats (HP, MP), combat state, coordinates.
 *      * map: World travel, room/cell jumping, zone load verification, stealth combat drop.
 *      * combat: Hunting loops, target acquisition, kill quotas, skill rotation coordination.
 *      * quest: Quest accept/complete queues, objective tree parsing, reward handling.
 *      * monster: Entity discovery, cell population queries, live Avatar vs monTree resolution.
 *      * inventory: Bank/bag transfers, item equipping, cosmetic swapping, house items.
 *      * drop: SmartFox packet interception, priority drop filtering, auto-looting.
 *      * shop: Shop loading, rate-limited purchases, buy/sell queues.
 *      * skills: Class config management, auto-mode selection, rule parsing.
 *      * aura: Player and monster buff/debuff inspection across uoTree and monTree.
 *      * enhancement: Automated Forge and standard item enhancement workflows.
 *      * script: HScript runtime integration and user automation scripts.
 *
 * Dual Accessors Pattern:
 *  - In Haxe compiled to ActionScript 3 bytecode (SWC), Flash properties are exposed
 *    using `@:getter(...)` for native AS3 property syntax (`api.player.hp`), while
 *    explicit `get_*()` methods are maintained for HScript and dynamic reflection (`Reflect.field`).
 *
 * Subsystem Startup Sequence:
 *  1. `ensureMathShims()`: Patches global AS3 `Math.isNaN` and `Math.isFinite` if absent.
 *  2. `preloadAssets()`: Preloads embedded skill rotations, Forge quest metadata, and LocalStorage.
 *  3. `ActionFeed.install()`: Hooks into SmartFoxClient `onExtensionResponse` at priority 100
 *     to capture combat action resolutions (`sar`/`sars`) before the game client processes them.
 *  4. Manager instantiation with the root `Game` reference.
 *  5. Background adapters (`TransportAdapter`, `DropManager`) are started.
 */
class Api {
    public static var dispatcher(default, null):EventDispatcher = new EventDispatcher();
    public static var logger:Class<ApiLogger> = ApiLogger;
    public static var game(default, null):Game;

    public static var map(default, null):MapManager = new MapManager(null);
    public static var player(default, null):PlayerManager = new PlayerManager(null);
    public static var quest(default, null):QuestManager = new QuestManager(null);
    public static var combat(default, null):CombatManager = new CombatManager(null);
    public static var aura(default, null):AuraManager = new AuraManager(null);
    public static var skills(default, null):SkillManager = new SkillManager(null);
    public static var inventory(default, null):InventoryManager = new InventoryManager(null);
    public static var drop(default, null):DropManager = new DropManager(null);
    public static var shop(default, null):ShopManager = new ShopManager(null);
    public static var monster(default, null):MonsterManager = new MonsterManager(null);
    public static var enhancement(default, null):EnhancementManager = new EnhancementManager(null);
    public static var presets(default, null):PresetManager = PresetManager.instance;
    public static var blacklist(default, null):BlacklistManager = BlacklistManager.instance;
    public static var script(default, null):com.aqwapi.modules.ScriptManager = com.aqwapi.modules.ScriptManager.SINGLETON;

    // Plural aliases
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

    // Direct script helpers and forwarders on bot / api
    public static var cell(get, never):String;
    @:getter(cell)
    public static function get_cell_prop():String { return player != null ? player.cell : ""; }
    public static function get_cell():String { return player != null ? player.cell : ""; }

    public static var pad(get, never):String;
    @:getter(pad)
    public static function get_pad_prop():String { return player != null ? player.pad : ""; }
    public static function get_pad():String { return player != null ? player.pad : ""; }

    public static var isAlive(get, never):Bool;
    @:getter(isAlive)
    public static function get_isAlive_prop():Bool { return player != null && player.isAlive; }
    public static function get_isAlive():Bool { return player != null && player.isAlive; }

    public static var isInCombat(get, never):Bool;
    @:getter(isInCombat)
    public static function get_isInCombat_prop():Bool { return player != null && player.isInCombat; }
    public static function get_isInCombat():Bool { return player != null && player.isInCombat; }

    public static inline function jump(c:String, p:String = null):Void {
        if (map != null) map.jump(c, p);
    }

    public static inline function join(m:String, c:String = null, p:String = null):Void {
        if (map != null) map.join(m, c, p);
    }

    public static function hunt(monsterName:String, itemOrCount:Dynamic = null, quantity:Int = 1, mmid:Dynamic = null):Bool {
        return combat != null ? combat.hunt(monsterName, itemOrCount, quantity, mmid) : false;
    }

    public static function kill(monsterName:String, itemOrCount:Dynamic = null, quantity:Int = 1, mmid:Dynamic = null):Bool {
        return combat != null ? combat.hunt(monsterName, itemOrCount, quantity, mmid) : false;
    }

    // Direct script helpers on bot / api
    public static function smartEnhance(?className:Dynamic, ?force:Dynamic, ?onComplete:Dynamic):Void {
        if (enhancement == null) return;
        var cName:String = null;
        var f:Bool = false;
        var cb:Void->Void = null;

        if (Reflect.isFunction(className)) {
            cb = className;
        } else if (Reflect.isFunction(force)) {
            cName = (className != null) ? Std.string(className) : null;
            cb = force;
        } else {
            cName = (className != null) ? Std.string(className) : null;
            f = (force == true || force == 1 || force == "true");
            if (Reflect.isFunction(onComplete)) cb = onComplete;
        }

        enhancement.smartEnhance(cName, f, cb);
    }

    public static function enhanceEquipped(?type:Dynamic, ?cSpecial:Dynamic, ?hSpecial:Dynamic, ?wSpecial:Dynamic, ?onComplete:Dynamic):Void {
        if (enhancement == null) return;
        var t:String = (type != null && !Reflect.isFunction(type)) ? Std.string(type) : "Lucky";
        var c:String = (cSpecial != null && !Reflect.isFunction(cSpecial)) ? Std.string(cSpecial) : null;
        var h:String = (hSpecial != null && !Reflect.isFunction(hSpecial)) ? Std.string(hSpecial) : null;
        var w:String = (wSpecial != null && !Reflect.isFunction(wSpecial)) ? Std.string(wSpecial) : null;
        var cb:Void->Void = null;
        if (Reflect.isFunction(onComplete)) cb = onComplete;
        else if (Reflect.isFunction(wSpecial)) cb = wSpecial;
        else if (Reflect.isFunction(hSpecial)) cb = hSpecial;
        else if (Reflect.isFunction(cSpecial)) cb = cSpecial;
        else if (Reflect.isFunction(type)) cb = type;

        enhancement.enhanceEquipped(t, c, h, w, cb);
    }

    public static function enhanceItem(?itemOrName:Dynamic, ?type:Dynamic, ?cSpecial:Dynamic, ?hSpecial:Dynamic, ?wSpecial:Dynamic, ?onComplete:Dynamic):Void {
        if (enhancement == null) return;
        enhancement.enhanceItem(itemOrName, type, cSpecial, hSpecial, wSpecial, onComplete);
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

    public static inline function stopAttack():Void {
        if (combat != null) combat.stopAttack();
    }

    public static inline function stopCombat():Void {
        if (combat != null) combat.stopCombat();
    }

    public static inline function dropCombat():Void {
        if (combat != null) combat.dropCombat();
    }

    public static inline function endCombat():Void {
        if (combat != null) combat.endCombat();
    }

    public static inline function reload(pad:String = null):Void {
        if (map != null) map.reload(pad);
    }

    public static var transport(default, null):TransportAdapter;
    public static var hscript(default, null):HScriptEngine;

    static function __init__():Void {
        ensureMathShims();
    }

    /**
     * Patches global ActionScript 3 Math object with standard ES5 isNaN and isFinite shims.
     * Required because some Flash runtimes lack Math.isNaN/Math.isFinite, which causes
     * subtle runtime reference exceptions in Haxe-generated numerical validations.
     */
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

    /**
     * Preloads persistent local storage, skill rotation datasets, and initializes
     * the CombatEngine before game interaction begins.
     */
    public static function preloadAssets():Void {
        ensureMathShims();
        ensureStorage();
        try {
            com.aqwapi.managers.SkillManager.ensureStorageInitialized();
            com.aqwapi.managers.SkillManager.reload(true);
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
            ApiLogger.warn("Api", "SkillManager / CombatEngine preload error: " + msg);
        }
    }

    /**
     * Master initialization entry point called by the mod loader when Game.as is ready.
     * Hooks packet listeners, wires all domain managers, and starts background adapters.
     */
    public static function init(gameReference:Game):Void {
        ensureMathShims();
        preloadAssets();
        game = cast gameReference;
        // Passive packet listener for `[counter]`. Installed here rather than only on the combat tick
        // so it is live even before combat starts; the tick re-checks it in case the socket changed.
        com.aqwapi.modules.ActionFeed.install();
        transport = new TransportAdapter(game);
        map = new MapManager(game);
        quest = new QuestManager(game);
        combat = new CombatManager(game);
        aura = new AuraManager(game);
        skills = new SkillManager(game);
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
