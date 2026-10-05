package com.aqwapi.managers;

import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiStorage;
import haxe.Json;

/**
 * Manages named collections of inventory items (e.g. "Nulgath", "Legion", "Dailies").
 *
 * Persistence & Resolution:
 *  - Primary Source: User-defined presets stored in LocalStorage (`item_presets.json`).
 *  - Fallback: Pre-bundled defaults compiled into the SWF via `haxe.Resource`.
 *  - Case-Insensitive Lookup: Normalizes preset names while preserving original display labels.
 *  - Used by `InventoryManager` for batch banking/unbanking (`bankPreset`, `unbankPreset`).
 */
class PresetManager {
    public static var instance(get, null):PresetManager;
    private static var _instance:PresetManager = null;

    public static function get_instance():PresetManager {
        if (_instance == null) _instance = new PresetManager();
        return _instance;
    }

    private var _presets:Map<String, Array<String>> = new Map();
    private var _displayNames:Map<String, String> = new Map();
    private var _loaded:Bool = false;

    public function new() {
        loadPresets();
    }

    public function loadPresets():Void {
        var raw:String = null;
        try {
            raw = ApiStorage.readText("item_presets.json");
        } catch (_:Dynamic) {}

        if (raw == null || raw.length == 0) {
            try {
                raw = haxe.Resource.getString("default_item_presets");
            } catch (_:Dynamic) {}
        }

        if (raw == null || raw.length == 0) return;

        try {
            var data:Dynamic = Json.parse(raw);
            _presets = new Map();
            _displayNames = new Map();
            for (key in Reflect.fields(data)) {
                var entry:Dynamic = Reflect.field(data, key);
                if (entry == null) continue;
                var lk = key.toLowerCase();
                var items:Array<String> = [];
                if (Std.isOfType(entry, Array)) {
                    var arr:Array<Dynamic> = cast entry;
                    for (it in arr) if (it != null) items.push(Std.string(it));
                } else if (Reflect.hasField(entry, "items")) {
                    var arr:Array<Dynamic> = cast Reflect.field(entry, "items");
                    if (arr != null) {
                        for (it in arr) if (it != null) items.push(Std.string(it));
                    }
                    if (Reflect.hasField(entry, "name")) {
                        var dName = Std.string(Reflect.field(entry, "name"));
                        _displayNames.set(lk, dName);
                        _presets.set(dName.toLowerCase(), items);
                    }
                }
                _presets.set(lk, items);
            }
            _loaded = true;
            ApiLogger.debug("Presets", "Loaded " + Lambda.count(_presets) + " item presets successfully.");
        } catch (e:Dynamic) {
            ApiLogger.error("Presets", "Error parsing item_presets.json: " + e);
        }
    }

    public function hasPreset(presetName:String):Bool {
        if (!_loaded) loadPresets();
        if (presetName == null) return false;
        return _presets.exists(presetName.toLowerCase());
    }

    public function getPresetItems(presetName:String):Array<String> {
        if (!_loaded) loadPresets();
        if (presetName == null) return [];
        var k = presetName.toLowerCase();
        if (_presets.exists(k)) return _presets.get(k).copy();
        return [];
    }

    public function resolveItems(input:Dynamic):Array<String> {
        if (input == null) return [];
        if (!_loaded) loadPresets();
        var result:Array<String> = [];
        var seen:Map<String, Bool> = new Map();

        var addList = function(list:Array<String>) {
            for (it in list) {
                var lk = it.toLowerCase();
                if (!seen.exists(lk)) {
                    seen.set(lk, true);
                    result.push(it);
                }
            }
        };

        if (Std.isOfType(input, Array)) {
            var arr:Array<Dynamic> = cast input;
            for (elem in arr) {
                if (elem == null) continue;
                var s = StringTools.trim(Std.string(elem));
                if (hasPreset(s)) {
                    addList(getPresetItems(s));
                } else if (s != "") {
                    var lk = s.toLowerCase();
                    if (!seen.exists(lk)) {
                        seen.set(lk, true);
                        result.push(s);
                    }
                }
            }
        } else {
            var s = StringTools.trim(Std.string(input));
            if (s.indexOf(",") != -1) {
                for (part in s.split(",")) {
                    var p = StringTools.trim(part);
                    if (hasPreset(p)) {
                        addList(getPresetItems(p));
                    } else if (p != "") {
                        var lk = p.toLowerCase();
                        if (!seen.exists(lk)) {
                            seen.set(lk, true);
                            result.push(p);
                        }
                    }
                }
            } else if (hasPreset(s)) {
                addList(getPresetItems(s));
            } else if (s != "") {
                result.push(s);
            }
        }
        return result;
    }

    public function getPresetNames():Array<String> {
        if (!_loaded) loadPresets();
        var keys:Array<String> = [];
        for (k in _displayNames.keys()) {
            keys.push(_displayNames.get(k));
        }
        return keys;
    }
}
