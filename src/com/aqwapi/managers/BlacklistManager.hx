package com.aqwapi.managers;

import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiStorage;

class BlacklistManager {
    private static var _instance:BlacklistManager;
    public static var instance(get, never):BlacklistManager;
    public static function get_instance():BlacklistManager {
        if (_instance == null) _instance = new BlacklistManager();
        return _instance;
    }

    private static inline var STORAGE_KEY:String = "api_blacklist";

    private var _list:Map<String, Bool> = new Map();
    private var _loaded:Bool = false;

    public function new() {
        load();
    }

    // -------------------------------------------------------------------------
    // Persistence
    // -------------------------------------------------------------------------

    public function load():Void {
        _list = new Map();
        var raw = ApiStorage.readText(STORAGE_KEY + ".json");
        if (raw != null && raw != "") {
            try {
                var arr:Array<Dynamic> = haxe.Json.parse(raw);
                if (arr != null) {
                    for (entry in arr) {
                        var name:String = StringTools.trim(Std.string(entry)).toLowerCase();
                        if (name != "") _list.set(name, true);
                    }
                }
            } catch (e:Dynamic) {}
        }
        _loaded = true;
        ApiLogger.debug("Blacklist", "Loaded " + Lambda.count(_list) + " blacklisted items.");
    }

    public function save():Void {
        var arr:Array<String> = [];
        for (k in _list.keys()) arr.push(k);
        arr.sort(function(a, b) return a < b ? -1 : 1);
        try {
            ApiStorage.writeText(STORAGE_KEY + ".json", haxe.Json.stringify(arr));
        } catch (e:Dynamic) {}
    }

    // -------------------------------------------------------------------------
    // Core API
    // -------------------------------------------------------------------------

    public function add(name:String):Void {
        var n = StringTools.trim(name).toLowerCase();
        if (n == "") return;
        if (_list.exists(n)) return;
        _list.set(n, true);
        save();
        ApiLogger.info("Blacklist", "Added: " + name);
    }

    public function remove(name:String):Void {
        var n = StringTools.trim(name).toLowerCase();
        if (!_list.exists(n)) return;
        _list.remove(n);
        save();
        ApiLogger.info("Blacklist", "Removed: " + name);
    }

    public function isBlacklisted(name:String):Bool {
        if (name == null || name == "") return false;
        return _list.exists(StringTools.trim(name).toLowerCase());
    }

    public function getList():Array<String> {
        var arr:Array<String> = [];
        for (k in _list.keys()) arr.push(k);
        arr.sort(function(a, b) return a < b ? -1 : 1);
        return arr;
    }

    public function clear():Void {
        _list = new Map();
        save();
        ApiLogger.info("Blacklist", "Cleared.");
    }

    // -------------------------------------------------------------------------
    // Sell all blacklisted items currently in inventory (not equipped/cosmetic)
    // -------------------------------------------------------------------------

    public function sellBlacklist():Void {
        var api = com.aqwapi.Api;
        if (api.inventory == null || api.shop == null) return;
        if (Lambda.count(_list) == 0) {
            ApiLogger.info("Blacklist", "Nothing to sell - blacklist is empty.");
            return;
        }
        var rawItems:Array<Dynamic> = cast api.inventory.getItems();
        var sold:Int = 0;
        for (item in rawItems) {
            if (item == null) continue;
            var name:String = item.sName != null ? StringTools.trim(Std.string(item.sName)) : "";
            if (name == "") continue;
            var isEquipped:Bool = (item.bEquip == 1 || item.bEquip == "1" || item.bEquip == true);
            var isWorn:Bool = (item.bWear == 1 || item.bWear == "1" || item.bWear == true);
            var isTemp:Bool = (item.bTemp == 1 || item.bTemp == "1" || item.bTemp == true);
            if (isEquipped || isWorn || isTemp) continue;
            if (isBlacklisted(name)) {
                api.shop.sellItem(name, 9999);
                sold++;
            }
        }
        if (sold > 0) {
            ApiLogger.info("Blacklist", "Selling " + sold + " blacklisted item type(s).");
        } else {
            ApiLogger.info("Blacklist", "No blacklisted items found in inventory.");
        }
    }
}
