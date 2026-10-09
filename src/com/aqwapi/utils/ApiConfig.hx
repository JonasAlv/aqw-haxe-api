package com.aqwapi.utils;

import haxe.Json;
import com.aqwapi.Api;
import com.aqwapi.modules.CombatEngine;

/**
 * Enhanced Two-Tier Configuration System.
 *
 * Tier 1: Global Client Configuration (stored in 'global_config.json' in root user storage)
 *         - Shared across all accounts on this machine/device.
 *         - Holds client preferences: UI layouts, widget positions, CRT filters, FPS, themes, etc.
 *
 * Tier 2: Per-Account Configuration (stored in 'accounts/<username>/config.json')
 *         - Isolated per character/account.
 *         - Holds gameplay & combat preferences: auto-farm class, solo modes, presets, skill setups.
 */
class ApiConfig {
    private static var _globalCache:Map<String, Dynamic> = new Map();
    private static var _accountCache:Map<String, Dynamic> = new Map();
    private static var _loadedGlobal:Bool = false;
    private static var _loadedAccount:Bool = false;

    // =========================================================================
    // LOADING & SAVING
    // =========================================================================

    public static function loadGlobal():Void {
        _globalCache = new Map();
        var raw:String = null;
        try {
            raw = ApiStorage.readText("global_config.json");
        } catch (_:Dynamic) {}

        if (raw != null && raw != "") {
            try {
                var data:Dynamic = Json.parse(raw);
                if (data != null) {
                    for (f in Reflect.fields(data)) {
                        _globalCache.set(f, Reflect.field(data, f));
                    }
                }
            } catch (e:Dynamic) {
                ApiLogger.warn("Config", "Error parsing global_config.json: " + e);
            }
        }
        _loadedGlobal = true;
    }

    public static function saveGlobal():Void {
        var obj:Dynamic = {};
        for (k in _globalCache.keys()) {
            Reflect.setField(obj, k, _globalCache.get(k));
        }
        try {
            ApiStorage.writeText("global_config.json", Json.stringify(obj, null, "  "));
        } catch (e:Dynamic) {
            ApiLogger.warn("Config", "Error saving global_config.json: " + e);
        }
    }

    public static function loadAccount():Void {
        _accountCache = new Map();
        var raw:String = null;
        try {
            // Because config.json is registered in ApiStorage.isAccountBoundFile,
            // this reads from accounts/<currentAccount>/config.json when logged in!
            raw = ApiStorage.readText("config.json");
        } catch (_:Dynamic) {}

        if (raw != null && raw != "") {
            try {
                var data:Dynamic = Json.parse(raw);
                if (data != null) {
                    for (f in Reflect.fields(data)) {
                        _accountCache.set(f, Reflect.field(data, f));
                    }
                }
            } catch (e:Dynamic) {
                ApiLogger.warn("Config", "Error parsing config.json: " + e);
            }
        }
        _loadedAccount = true;
    }

    public static function saveAccount():Void {
        var obj:Dynamic = {};
        for (k in _accountCache.keys()) {
            Reflect.setField(obj, k, _accountCache.get(k));
        }
        try {
            ApiStorage.writeText("config.json", Json.stringify(obj, null, "  "));
        } catch (e:Dynamic) {
            ApiLogger.warn("Config", "Error saving config.json: " + e);
        }
    }

    public static function load():Void {
        loadGlobal();
        loadAccount();
    }

    public static function save():Void {
        saveGlobal();
        saveAccount();
    }

    public static function reload():Void {
        load();
        applyToCombatEngine();
    }

    public static function applyToCombatEngine():Void {
        CombatEngine.farmClass  = getString("api_farm_class", "Current");
        CombatEngine.farmMode   = getString("api_farm_mode", "Auto");
        CombatEngine.soloClass  = getString("api_solo_class", "Current");
        CombatEngine.soloMode   = getString("api_solo_mode", "Auto");
        CombatEngine.bossClass  = getString("api_boss_class", "Current");
        CombatEngine.bossMode   = getString("api_boss_mode", "Auto");
        CombatEngine.dodgeClass = getString("api_dodge_class", "Current");
        CombatEngine.dodgeMode  = getString("api_dodge_mode", "Auto");
        CombatEngine.smartClass = getString("api_smart_class", "Current");
        CombatEngine.skillMode  = getString("api_smart_mode", "Auto");

        if (Api.combat != null) {
            Api.combat.infiniteRange = getBool("api_infinite_range", false);
        }
        CombatEngine.counterHandler = getBool("api_counter_handler", false);
        if (Api.map != null) {
            Api.map.autoDeathSpawn = getBool("api_death_spawn", false);
            Api.map.usePrivateRoom = getBool("api_private_rooms", true);
            Api.map.skipCutscenes  = getBool("api_skip_cutscenes", false);
        }
    }

    // =========================================================================
    // KEY SCOPING LOGIC
    // =========================================================================

    /**
     * Determines whether a setting key belongs to Global Client storage
     * or Per-Account storage.
     */
    public static function isGlobalKey(key:String):Bool {
        if (key == null) return false;
        var k = key.toLowerCase();

        // UI & Widget screen positions, dimensions, and visual toggles
        if (StringTools.startsWith(k, "api_widget_")) return true;
        if (StringTools.startsWith(k, "api_unitframes_")) return true;
        if (StringTools.startsWith(k, "api_floating_")) return true;
        if (StringTools.startsWith(k, "api_crt_")) return true;
        if (StringTools.startsWith(k, "api_tool_") || StringTools.startsWith(k, "api_tools_")) return true;
        if (StringTools.startsWith(k, "api_hud_")) return true;
        if (StringTools.startsWith(k, "client_") || StringTools.startsWith(k, "ui_") || StringTools.startsWith(k, "global_")) return true;
        if (StringTools.startsWith(k, "option_") || StringTools.startsWith(k, "layout_") || StringTools.startsWith(k, "shortcut_")) return true;

        if (k == "api_screen_filter" || k == "api_fps" || k == "api_theme") return true;

        return false;
    }

    // =========================================================================
    // SMART GETTERS & SETTERS (AUTOMATIC ROUTING)
    // =========================================================================

    public static function get(key:String, defaultValue:Dynamic = null):Dynamic {
        if (!_loadedGlobal) loadGlobal();
        if (!_loadedAccount) loadAccount();

        var isGlob = isGlobalKey(key);

        // Check appropriate tier first
        if (isGlob) {
            if (_globalCache.exists(key)) return _globalCache.get(key);
        } else {
            if (_accountCache.exists(key)) return _accountCache.get(key);
        }

        // Cross-tier fallback if key was saved under other tier
        if (!isGlob && _globalCache.exists(key)) return _globalCache.get(key);
        if (isGlob && _accountCache.exists(key)) {
            var val = _accountCache.get(key);
            _globalCache.set(key, val);
            saveGlobal();
            return val;
        }

        // Fallback to HelperSetting (Flash SharedObject) for seamless backward migration
        try {
            var hsCls:Dynamic = Type.resolveClass("util.HelperSetting");
            if (hsCls != null) {
                var val:Dynamic = null;
                if (Std.isOfType(defaultValue, Bool)) {
                    val = Reflect.callMethod(hsCls, Reflect.field(hsCls, "getBool"), [key, defaultValue]);
                } else if (Std.isOfType(defaultValue, Int)) {
                    val = Reflect.callMethod(hsCls, Reflect.field(hsCls, "getInt"), [key, defaultValue]);
                } else if (Std.isOfType(defaultValue, String)) {
                    val = Reflect.callMethod(hsCls, Reflect.field(hsCls, "getString"), [key, defaultValue]);
                }
                if (val != null && val != defaultValue) {
                    if (isGlob) {
                        _globalCache.set(key, val);
                        saveGlobal();
                    } else {
                        _accountCache.set(key, val);
                        saveAccount();
                    }
                    return val;
                }
            }
        } catch (_:Dynamic) {}

        return defaultValue;
    }

    public static function set(key:String, value:Dynamic):Void {
        if (!_loadedGlobal) loadGlobal();
        if (!_loadedAccount) loadAccount();

        if (isGlobalKey(key)) {
            _globalCache.set(key, value);
            saveGlobal();
        } else {
            _accountCache.set(key, value);
            saveAccount();
        }

        // Optional bridge to HelperSetting so legacy Flash code gets updates
        try {
            var hsCls:Dynamic = Type.resolveClass("util.HelperSetting");
            if (hsCls != null) {
                if (Std.isOfType(value, Bool)) {
                    Reflect.callMethod(hsCls, Reflect.field(hsCls, "setBool"), [key, value]);
                } else if (Std.isOfType(value, Int)) {
                    Reflect.callMethod(hsCls, Reflect.field(hsCls, "setInt"), [key, value]);
                } else if (Std.isOfType(value, String)) {
                    Reflect.callMethod(hsCls, Reflect.field(hsCls, "setString"), [key, value]);
                }
            }
        } catch (_:Dynamic) {}
    }

    public static function getString(key:String, defaultValue:String = ""):String {
        var v = get(key, defaultValue);
        return (v != null) ? Std.string(v) : defaultValue;
    }

    public static function setString(key:String, value:String):Void {
        set(key, value);
    }

    public static function getBool(key:String, defaultValue:Bool = false):Bool {
        var v = get(key, defaultValue);
        if (v == null) return defaultValue;
        if (Std.isOfType(v, Bool)) return cast v;
        var s = Std.string(v).toLowerCase();
        return s == "true" || s == "1";
    }

    public static function setBool(key:String, value:Bool):Void {
        set(key, value);
    }

    public static function getInt(key:String, defaultValue:Int = 0):Int {
        var v = get(key, defaultValue);
        if (v == null) return defaultValue;
        return ApiUtils.parseInt(v, defaultValue);
    }

    public static function setInt(key:String, value:Int):Void {
        set(key, value);
    }

    public static function getFloat(key:String, defaultValue:Float = 0.0):Float {
        var v = get(key, defaultValue);
        if (v == null) return defaultValue;
        if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) return cast v;
        var f = Std.parseFloat(Std.string(v));
        return Math.isNaN(f) ? defaultValue : f;
    }

    public static function setFloat(key:String, value:Float):Void {
        set(key, value);
    }

    public static function has(key:String):Bool {
        if (!_loadedGlobal) loadGlobal();
        if (!_loadedAccount) loadAccount();
        return _globalCache.exists(key) || _accountCache.exists(key);
    }

    public static function delete(key:String):Void {
        if (!_loadedGlobal) loadGlobal();
        if (!_loadedAccount) loadAccount();
        if (_globalCache.exists(key)) {
            _globalCache.remove(key);
            saveGlobal();
        }
        if (_accountCache.exists(key)) {
            _accountCache.remove(key);
            saveAccount();
        }
    }

    // =========================================================================
    // EXPLICIT TIER ACCESSORS
    // =========================================================================

    public static function getGlobal(key:String, defaultValue:Dynamic = null):Dynamic {
        if (!_loadedGlobal) loadGlobal();
        if (_globalCache.exists(key)) return _globalCache.get(key);
        return defaultValue;
    }

    public static function setGlobal(key:String, value:Dynamic):Void {
        if (!_loadedGlobal) loadGlobal();
        _globalCache.set(key, value);
        saveGlobal();
    }

    public static function getAccount(key:String, defaultValue:Dynamic = null):Dynamic {
        if (!_loadedAccount) loadAccount();
        if (_accountCache.exists(key)) return _accountCache.get(key);
        return defaultValue;
    }

    public static function setAccount(key:String, value:Dynamic):Void {
        if (!_loadedAccount) loadAccount();
        _accountCache.set(key, value);
        saveAccount();
    }
}
