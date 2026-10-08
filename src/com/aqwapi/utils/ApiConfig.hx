package com.aqwapi.utils;

import haxe.Json;
import com.aqwapi.Api;
import com.aqwapi.modules.CombatEngine;

class ApiConfig {
    private static var _cache:Map<String, Dynamic> = new Map();
    private static var _loaded:Bool = false;

    public static function load():Void {
        _cache = new Map();
        var raw:String = null;
        try {
            raw = ApiStorage.readText("config.json");
        } catch (_:Dynamic) {}

        if (raw != null && raw != "") {
            try {
                var data:Dynamic = Json.parse(raw);
                if (data != null) {
                    for (f in Reflect.fields(data)) {
                        _cache.set(f, Reflect.field(data, f));
                    }
                }
            } catch (e:Dynamic) {
                ApiLogger.warn("Config", "Error parsing config.json: " + e);
            }
        }
        _loaded = true;
    }

    public static function save():Void {
        var obj:Dynamic = {};
        for (k in _cache.keys()) {
            Reflect.setField(obj, k, _cache.get(k));
        }
        try {
            ApiStorage.writeText("config.json", Json.stringify(obj, null, "  "));
        } catch (e:Dynamic) {
            ApiLogger.warn("Config", "Error saving config.json: " + e);
        }
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

    public static function get(key:String, defaultValue:Dynamic = null):Dynamic {
        if (!_loaded) load();
        if (_cache.exists(key)) return _cache.get(key);

        // Fallback to HelperSetting for initial migration
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
                    _cache.set(key, val);
                    save();
                    return val;
                }
            }
        } catch (_:Dynamic) {}

        return defaultValue;
    }

    public static function set(key:String, value:Dynamic):Void {
        if (!_loaded) load();
        _cache.set(key, value);
        save();

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

    public static function has(key:String):Bool {
        if (!_loaded) load();
        return _cache.exists(key);
    }

    public static function delete(key:String):Void {
        if (!_loaded) load();
        if (_cache.exists(key)) {
            _cache.remove(key);
            save();
        }
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
}
