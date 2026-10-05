package com.aqwapi.modules;

import com.aqwapi.Api;
import com.aqwapi.scripting.HScriptEngine;
import com.aqwapi.utils.ApiStorage;

/**
 * High-level script file manager handling script enumeration, reading, saving, and execution.
 *
 * Architecture:
 *  - Script Discovery: Scans both bundled scripts and user-created scripts via `ApiStorage`.
 *  - Script Execution: Delegates parsing and running of `.hxs` scripts to `HScriptEngine.SINGLETON`.
 *  - Save/Delete Guard: Protects bundled read-only scripts by cloning edits to `_Edited` files.
 */
class ScriptManager {
    private static var _instance:ScriptManager;
    public static var SINGLETON(get, never):ScriptManager;
    @:getter(SINGLETON)
    public static function get_SINGLETON_prop():ScriptManager {
        if (_instance == null) _instance = new ScriptManager();
        return _instance;
    }
    public static function get_SINGLETON():ScriptManager {
        if (_instance == null) _instance = new ScriptManager();
        return _instance;
    }

    public var activeScriptName:String = null;

    public function new() {}

    public static function isHScript(text:String):Bool {
        return true; // All scripts are now powered by HScriptEngine
    }

    public function listScripts():Array<String> {
        return ApiStorage.listScripts();
    }

    public function isUserScript(name:String):Bool {
        return ApiStorage.isUserScript(name);
    }

    public function isBundledScript(name:String):Bool {
        return ApiStorage.isBundledScript(name);
    }

    public function getScriptContent(name:String):String {
        if (name == null || name == "") return "";
        var content = ApiStorage.readScript(name);
        return (content != null) ? content : "";
    }

    public function saveScript(name:String, content:String):Bool {
        if (name == null || name == "") return false;
        if (isBundledScript(name)) {
            name = name + "_Edited";
        }
        return ApiStorage.writeText("scripts/" + name + ".hxs", content);
    }

    public function deleteScript(name:String):Bool {
        if (name == null || name == "") return false;
        if (isBundledScript(name)) {
            return false;
        }
        if (activeScriptName == name) {
            stop();
        }
        return ApiStorage.deleteUserScript(name);
    }

    public function loadScript(scriptText:String):Void {
        if ((Api.game == null || Api.game.world == null) && Api.game != null) {
            Api.init(Api.game);
        }
        HScriptEngine.SINGLETON.loadScript(scriptText);
    }

    public function startScriptByName(name:String):Bool {
        var content = getScriptContent(name);
        if (content == null || StringTools.trim(content) == "") return false;
        loadScript(content);
        start();
        activeScriptName = name;
        return true;
    }

    public function reset():Void {
        HScriptEngine.SINGLETON.reset();
    }

    public function start():Void {
        if (Api.game == null || Api.game.world == null) {
            if (Api.game != null) Api.init(Api.game);
        }
        HScriptEngine.SINGLETON.start();
    }

    public function stop():Void {
        HScriptEngine.SINGLETON.stop();
        activeScriptName = null;
    }

    public var isRunning(get, set):Bool;
    @:getter(isRunning)
    public function get_isRunning_prop():Bool { return HScriptEngine.SINGLETON.isRunning; }
    @:setter(isRunning)
    public function set_isRunning_prop(v:Bool):Void { HScriptEngine.SINGLETON.isRunning = v; }
    public function get_isRunning():Bool { return HScriptEngine.SINGLETON.isRunning; }
    public function set_isRunning(v:Bool):Bool { HScriptEngine.SINGLETON.isRunning = v; return v; }

    public var statusText(get, set):String;
    @:getter(statusText)
    public function get_statusText_prop():String { return HScriptEngine.SINGLETON.statusText; }
    @:setter(statusText)
    public function set_statusText_prop(v:String):Void { HScriptEngine.SINGLETON.statusText = v; }
    public function get_statusText():String { return HScriptEngine.SINGLETON.statusText; }
    public function set_statusText(v:String):String { HScriptEngine.SINGLETON.statusText = v; return v; }

    public function getItemCount(searchName:String):Int {
        return (Api.inventory != null) ? Api.inventory.getQuestQuantity(searchName) : 0;
    }
}
