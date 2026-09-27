package com.aqwapi.modules;

import com.aqwapi.Api;
import com.aqwapi.scripting.HScriptEngine;

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

    public function new() {}

    public static function isHScript(text:String):Bool {
        return true; // All scripts are now powered by HScriptEngine
    }

    public function loadScript(scriptText:String):Void {
        if ((Api.game == null || Api.game.world == null) && Api.game != null) {
            Api.init(Api.game);
        }
        HScriptEngine.SINGLETON.loadScript(scriptText);
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
