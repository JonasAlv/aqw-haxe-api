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
    public static var visual(default, null):VisualManager = new VisualManager(null);
    public static var party(default, null):PartyManager = new PartyManager(null);

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

    public static var lagKiller(get, set):Bool;
    @:getter(lagKiller)
    public static function get_lagKiller_prop():Bool { return visual != null ? visual.lagKiller : false; }
    public static function get_lagKiller():Bool { return visual != null ? visual.lagKiller : false; }
    @:setter(lagKiller)
    public static function set_lagKiller_prop(v:Bool):Void { if (visual != null) visual.lagKiller = v; }
    public static function set_lagKiller(v:Bool):Bool { if (visual != null) visual.lagKiller = v; return v; }

    public static var hidePlayers(get, set):Bool;
    @:getter(hidePlayers)
    public static function get_hidePlayers_prop():Bool { return visual != null ? visual.hidePlayers : false; }
    public static function get_hidePlayers():Bool { return visual != null ? visual.hidePlayers : false; }
    @:setter(hidePlayers)
    public static function set_hidePlayers_prop(v:Bool):Void { if (visual != null) visual.hidePlayers = v; }
    public static function set_hidePlayers(v:Bool):Bool { if (visual != null) visual.hidePlayers = v; return v; }

    public static var disableSkillAnims(get, set):Bool;
    @:getter(disableSkillAnims)
    public static function get_disableSkillAnims_prop():Bool { return visual != null ? visual.disableSkillAnims : false; }
    public static function get_disableSkillAnims():Bool { return visual != null ? visual.disableSkillAnims : false; }
    @:setter(disableSkillAnims)
    public static function set_disableSkillAnims_prop(v:Bool):Void { if (visual != null) visual.disableSkillAnims = v; }
    public static function set_disableSkillAnims(v:Bool):Bool { if (visual != null) visual.disableSkillAnims = v; return v; }

    public static var skillAnimMode(get, set):Int;
    @:getter(skillAnimMode)
    public static function get_skillAnimMode_prop():Int { return visual != null ? visual.skillAnimMode : 0; }
    public static function get_skillAnimMode():Int { return visual != null ? visual.skillAnimMode : 0; }
    @:setter(skillAnimMode)
    public static function set_skillAnimMode_prop(v:Int):Void { if (visual != null) visual.skillAnimMode = v; }
    public static function set_skillAnimMode(v:Int):Int { if (visual != null) visual.skillAnimMode = v; return v; }

    public static var optimizeSpellFX(get, set):Bool;
    @:getter(optimizeSpellFX)
    public static function get_optimizeSpellFX_prop():Bool { return visual != null ? visual.optimizeSpellFX : true; }
    public static function get_optimizeSpellFX():Bool { return visual != null ? visual.optimizeSpellFX : true; }
    @:setter(optimizeSpellFX)
    public static function set_optimizeSpellFX_prop(v:Bool):Void { if (visual != null) visual.optimizeSpellFX = v; }
    public static function set_optimizeSpellFX(v:Bool):Bool { if (visual != null) visual.optimizeSpellFX = v; return v; }

    public static var disableSpellFilters(get, set):Bool;
    @:getter(disableSpellFilters)
    public static function get_disableSpellFilters_prop():Bool { return visual != null ? visual.disableSpellFilters : false; }
    public static function get_disableSpellFilters():Bool { return visual != null ? visual.disableSpellFilters : false; }
    @:setter(disableSpellFilters)
    public static function set_disableSpellFilters_prop(v:Bool):Void { if (visual != null) visual.disableSpellFilters = v; }
    public static function set_disableSpellFilters(v:Bool):Bool { if (visual != null) visual.disableSpellFilters = v; return v; }

    public static var friendlySelfOnlyFX(get, set):Bool;
    @:getter(friendlySelfOnlyFX)
    public static function get_friendlySelfOnlyFX_prop():Bool { return visual != null ? visual.friendlySelfOnlyFX : false; }
    public static function get_friendlySelfOnlyFX():Bool { return visual != null ? visual.friendlySelfOnlyFX : false; }
    @:setter(friendlySelfOnlyFX)
    public static function set_friendlySelfOnlyFX_prop(v:Bool):Void { if (visual != null) visual.friendlySelfOnlyFX = v; }
    public static function set_friendlySelfOnlyFX(v:Bool):Bool { if (visual != null) visual.friendlySelfOnlyFX = v; return v; }

    public static var hostilePrimaryOnlyFX(get, set):Bool;
    @:getter(hostilePrimaryOnlyFX)
    public static function get_hostilePrimaryOnlyFX_prop():Bool { return visual != null ? visual.hostilePrimaryOnlyFX : false; }
    public static function get_hostilePrimaryOnlyFX():Bool { return visual != null ? visual.hostilePrimaryOnlyFX : false; }
    @:setter(hostilePrimaryOnlyFX)
    public static function set_hostilePrimaryOnlyFX_prop(v:Bool):Void { if (visual != null) visual.hostilePrimaryOnlyFX = v; }
    public static function set_hostilePrimaryOnlyFX(v:Bool):Bool { if (visual != null) visual.hostilePrimaryOnlyFX = v; return v; }

    public static var maxConcurrentSpells(get, set):Int;
    @:getter(maxConcurrentSpells)
    public static function get_maxConcurrentSpells_prop():Int { return visual != null ? visual.maxConcurrentSpells : 6; }
    public static function get_maxConcurrentSpells():Int { return visual != null ? visual.maxConcurrentSpells : 6; }
    @:setter(maxConcurrentSpells)
    public static function set_maxConcurrentSpells_prop(v:Int):Void { if (visual != null) visual.maxConcurrentSpells = v; }
    public static function set_maxConcurrentSpells(v:Int):Int { if (visual != null) visual.maxConcurrentSpells = v; return v; }

    public static var disableMonsterAnims(get, set):Bool;
    @:getter(disableMonsterAnims)
    public static function get_disableMonsterAnims_prop():Bool { return visual != null ? visual.disableMonsterAnims : false; }
    public static function get_disableMonsterAnims():Bool { return visual != null ? visual.disableMonsterAnims : false; }
    @:setter(disableMonsterAnims)
    public static function set_disableMonsterAnims_prop(v:Bool):Void { if (visual != null) visual.disableMonsterAnims = v; }
    public static function set_disableMonsterAnims(v:Bool):Bool { if (visual != null) visual.disableMonsterAnims = v; return v; }

    public static var cleanArena(get, set):Bool;
    @:getter(cleanArena)
    public static function get_cleanArena_prop():Bool { return visual != null ? visual.cleanArena : false; }
    public static function get_cleanArena():Bool { return visual != null ? visual.cleanArena : false; }
    @:setter(cleanArena)
    public static function set_cleanArena_prop(v:Bool):Void { if (visual != null) visual.cleanArena = v; }
    public static function set_cleanArena(v:Bool):Bool { if (visual != null) visual.cleanArena = v; return v; }

    public static var hideMonsters(get, set):Bool;
    @:getter(hideMonsters)
    public static function get_hideMonsters_prop():Bool { return visual != null ? visual.hideMonsters : false; }
    public static function get_hideMonsters():Bool { return visual != null ? visual.hideMonsters : false; }
    @:setter(hideMonsters)
    public static function set_hideMonsters_prop(v:Bool):Void { if (visual != null) visual.hideMonsters = v; }
    public static function set_hideMonsters(v:Bool):Bool { if (visual != null) visual.hideMonsters = v; return v; }

    public static var cachePlayers(get, set):Bool;
    @:getter(cachePlayers)
    public static function get_cachePlayers_prop():Bool { return visual != null ? visual.cachePlayers : false; }
    public static function get_cachePlayers():Bool { return visual != null ? visual.cachePlayers : false; }
    @:setter(cachePlayers)
    public static function set_cachePlayers_prop(v:Bool):Void { if (visual != null) visual.cachePlayers = v; }
    public static function set_cachePlayers(v:Bool):Bool { if (visual != null) visual.cachePlayers = v; return v; }

    public static var cacheMonsters(get, set):Bool;
    @:getter(cacheMonsters)
    public static function get_cacheMonsters_prop():Bool { return visual != null ? visual.cacheMonsters : false; }
    public static function get_cacheMonsters():Bool { return visual != null ? visual.cacheMonsters : false; }
    @:setter(cacheMonsters)
    public static function set_cacheMonsters_prop(v:Bool):Void { if (visual != null) visual.cacheMonsters = v; }
    public static function set_cacheMonsters(v:Bool):Bool { if (visual != null) visual.cacheMonsters = v; return v; }

    public static var suppressTargetGlow(get, set):Bool;
    @:getter(suppressTargetGlow)
    public static function get_suppressTargetGlow_prop():Bool { return visual != null ? visual.suppressTargetGlow : false; }
    public static function get_suppressTargetGlow():Bool { return visual != null ? visual.suppressTargetGlow : false; }
    @:setter(suppressTargetGlow)
    public static function set_suppressTargetGlow_prop(v:Bool):Void { if (visual != null) visual.suppressTargetGlow = v; }
    public static function set_suppressTargetGlow(v:Bool):Bool { if (visual != null) visual.suppressTargetGlow = v; return v; }


    public static var freezeAllAnimations(get, set):Bool;
    @:getter(freezeAllAnimations)
    public static function get_freezeAllAnimations_prop():Bool { return visual != null ? visual.freezeAllAnimations : false; }
    public static function get_freezeAllAnimations():Bool { return visual != null ? visual.freezeAllAnimations : false; }
    @:setter(freezeAllAnimations)
    public static function set_freezeAllAnimations_prop(v:Bool):Void { if (visual != null) visual.freezeAllAnimations = v; }
    public static function set_freezeAllAnimations(v:Bool):Bool { if (visual != null) visual.freezeAllAnimations = v; return v; }

    public static inline function toggleLagKiller():Bool {
        if (visual != null) {
            visual.lagKiller = !visual.lagKiller;
            return visual.lagKiller;
        }
        return false;
    }

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

    public static inline function jump(c:String, p:String = null, force:Bool = false, autoCorrect:Bool = true):Void {
        if (map != null) map.jump(c, p, force, autoCorrect);
    }

    public static inline function getValidCellPads():Array<String> {
        return map != null ? map.getValidCellPads() : [];
    }

    public static inline function getCellPads():Array<String> {
        return map != null ? map.getCellPads() : [];
    }

    public static inline function join(m:String, c:String = null, p:String = null):Void {
        if (map != null) map.join(m, c, p);
    }

    public static function hunt(monsterName:Dynamic, itemOrCount:Dynamic = null, quantity:Int = 1, mmid:Dynamic = null):Bool {
        return combat != null ? combat.hunt(monsterName, itemOrCount, quantity, mmid) : false;
    }

    public static function kill(monsterName:Dynamic, itemOrCount:Dynamic = null, quantity:Int = 1, mmid:Dynamic = null):Bool {
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

    public static inline function cleanExpiredAuras():Int {
        return (aura != null) ? aura.cleanExpiredAuras() : 0;
    }

    public static inline function walkThroughWalls(enabled:Bool = true):Void {
        if (map != null) map.walkThroughWalls(enabled);
    }

    public static inline function skipCutscenes():Bool {
        return (map != null) ? map.skipCutscenesNow() : false;
    }

    public static inline function autoSkipCutscenes(enabled:Bool = true):Void {
        if (map != null) map.skipCutscenes = enabled;
    }

    public static inline function isTercess():Bool {
        return (map != null) ? map.isTercess() : false;
    }

    public static inline function ensureTercess(destination:String = "nulgath", ?pad:String):Bool {
        return (map != null) ? map.ensureTercess(destination, pad) : false;
    }

    public static inline function joinTercess(destination:String = "nulgath", ?pad:String):Void {
        if (map != null) map.joinTercess(destination, pad);
    }

    public static inline function fastTravel(destination:String):Bool {
        return (map != null) ? map.fastTravel(destination) : false;
    }

    public static inline function isBoostActive(boostType:String):Bool {
        return (player != null) ? player.isBoostActive(boostType) : false;
    }

    public static inline function getBoostRemaining(boostType:String):Int {
        return (player != null) ? player.getBoostRemaining(boostType) : 0;
    }

    public static inline function useBoost(itemNameOrId:Dynamic):Bool {
        return (player != null) ? player.useBoost(itemNameOrId) : false;
    }

    public static inline function autoBoost(boostType:String, enabled:Bool = true):Void {
        if (player != null) player.setAutoBoost(boostType, enabled);
    }

    public static inline function getBestMonsterTargetInCell(cell:String = null, nameOrId:Dynamic = "*"):com.aqwapi.data.EntityDTO {
        return (monster != null) ? monster.getBestMonsterTargetInCell(cell, nameOrId) : null;
    }

    public static inline function storeGear(?items:Dynamic):Array<Dynamic> {
        return (inventory != null) ? cast inventory.storeGear(items) : [];
    }

    public static inline function restoreGear(?onComplete:Void->Void):Void {
        if (inventory != null) inventory.restoreGear(onComplete);
    }

    public static inline function isGearRestored():Bool {
        return (inventory != null) ? inventory.isGearRestored() : true;
    }

    public static inline function ensureRestored():Bool {
        return (inventory != null) ? inventory.ensureRestored() : true;
    }

    public static inline function ensureRestoreGear():Bool {
        return (inventory != null) ? inventory.ensureRestored() : true;
    }

    public static inline function hasGearSnapshot():Bool {
        return (inventory != null) ? inventory.hasGearSnapshot() : false;
    }

    public static inline function getGearSnapshot():Array<Dynamic> {
        return (inventory != null) ? cast inventory.getGearSnapshot() : [];
    }

    public static inline function clearGearSnapshot():Void {
        if (inventory != null) inventory.clearGearSnapshot();
    }

    public static inline function cancelRestoreGear():Void {
        if (inventory != null) inventory.cancelRestoreGear();
    }

    public static inline function isDaily(questId:Dynamic):Bool {
        return (quest != null) ? quest.isDaily(questId) : false;
    }

    public static inline function isDailyComplete(questId:Dynamic):Bool {
        return (quest != null) ? quest.isDailyComplete(questId) : false;
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
        party = new PartyManager(game);
        hscript = HScriptEngine.SINGLETON;

        if (visual != null) {
            visual.setGame(game);
        } else {
            visual = new VisualManager(game);
        }
        visual.apply();

        if (transport != null) transport.start();
        if (drop != null) drop.start();
        if (aura != null) aura.startAutoClean(5000);

        var curUser:String = (player != null) ? player.username : "";
        if (curUser == "" && game != null && game.sfc != null && game.sfc.myUserName != null) {
            curUser = Std.string(game.sfc.myUserName);
        }
        if (curUser != "") {
            com.aqwapi.utils.ApiStorage.setAccount(curUser);
        }
    }



    public static inline function setAccount(username:String):Void {
        com.aqwapi.utils.ApiStorage.setAccount(username);
    }

    public static var currentAccount(get, never):String;
    public static function get_currentAccount():String {
        return com.aqwapi.utils.ApiStorage.currentAccount;
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
