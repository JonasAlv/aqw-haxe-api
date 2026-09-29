package com.aqwapi.scripting;

import com.aqwapi.Api;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.events.GameEvent;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiUtils;
import flash.events.TimerEvent;
import flash.utils.Timer;
import hscript.Expr;
import hscript.Interp;
import hscript.Parser;
import hscript.Printer;

class HScriptEngine {
    private var _parser:Parser;
    private var _interp:Interp;
    private var _program:Expr;
    private var _timer:Timer;

    public var isRunning:Bool = false;
    public var waitTimer:Float = 0;
    public var statusText:String = "Stopped";
    public var tickInterval:Int = 100;

    public function sleep(ms:Float):Void {
        waitTimer = ApiTime.now() + ms;
    }

    private var _hasOnStart:Bool = false;
    private var _hasOnTick:Bool = false;
    private var _hasOnStop:Bool = false;
    private var _hasOnPacket:Bool = false;
    private var _hasOnZoneEntered:Bool = false;
    private var _hasOnQuestUpdated:Bool = false;
    private var _hasOnInventoryChanged:Bool = false;

    private static var _instance:HScriptEngine;
    public static var SINGLETON(get, never):HScriptEngine;
    @:getter(SINGLETON)
    public static function get_SINGLETON_prop():HScriptEngine {
        if (_instance == null) _instance = new HScriptEngine();
        return _instance;
    }
    public static function get_SINGLETON():HScriptEngine {
        if (_instance == null) _instance = new HScriptEngine();
        return _instance;
    }

    public function new() {
        _parser = new Parser();
        _parser.allowTypes = true;
        _parser.allowJSON = true;
        _parser.allowMetadata = true;
        _interp = new ScriptInterp();

        _timer = new Timer(tickInterval);
        _timer.addEventListener(TimerEvent.TIMER, onTimerTick, false, 0, true);

        Api.dispatcher.addEventListener(GameEvent.ZONE_ENTERED, onGameZoneEntered);
        Api.dispatcher.addEventListener(GameEvent.QUEST_UPDATED, onGameQuestUpdated);
        Api.dispatcher.addEventListener(GameEvent.INVENTORY_CHANGED, onGameInventoryChanged);

        _resetSandbox();
    }

    public function reset():Void {
        if (isRunning) stop();
        waitTimer = 0;
        statusText = (_program != null) ? "Ready." : "Stopped.";

        if (_program != null) {
            _resetSandbox();
            try {
                _interp.execute(_program);
                _hasOnStart = _interp.variables.exists("onStart") && Reflect.isFunction(_interp.variables.get("onStart"));
                _hasOnTick = _interp.variables.exists("onTick") && Reflect.isFunction(_interp.variables.get("onTick"));
                _hasOnStop = _interp.variables.exists("onStop") && Reflect.isFunction(_interp.variables.get("onStop"));
                _hasOnPacket = _interp.variables.exists("onPacket") && Reflect.isFunction(_interp.variables.get("onPacket"));
                _hasOnZoneEntered = _interp.variables.exists("onZoneEntered") && Reflect.isFunction(_interp.variables.get("onZoneEntered"));
                _hasOnQuestUpdated = _interp.variables.exists("onQuestUpdated") && Reflect.isFunction(_interp.variables.get("onQuestUpdated"));
                _hasOnInventoryChanged = _interp.variables.exists("onInventoryChanged") && Reflect.isFunction(_interp.variables.get("onInventoryChanged"));
            } catch (e:Dynamic) {
                ApiLogger.error("HScript", "Reset error: " + Std.string(e));
            }
        }
    }

    public function clear():Void {
        if (isRunning) stop();
        _program = null;
        _hasOnStart = false;
        _hasOnTick = false;
        _hasOnStop = false;
        _hasOnPacket = false;
        _hasOnZoneEntered = false;
        _hasOnQuestUpdated = false;
        _hasOnInventoryChanged = false;
        waitTimer = 0;
        statusText = "No script loaded.";
        _resetSandbox();
    }

    private function _resetSandbox():Void {
        _interp = new ScriptInterp();
        ScriptBindings.registerAll(cast _interp, this);
    }

    public function loadScript(scriptCode:String):Bool {
        if ((Api.game == null || Api.game.world == null) && Api.game != null) {
            Api.init(Api.game);
        }

        reset();

        // Strip //hscript or #hscript header line if present
        var cleanCode = scriptCode;
        if (cleanCode.indexOf("//hscript") == 0) cleanCode = cleanCode.substring(9);
        else if (cleanCode.indexOf("#hscript") == 0) cleanCode = cleanCode.substring(8);

        try {
            _program = _parser.parseString(cleanCode);
        } catch (e:hscript.Expr.Error) {
            var msg = "Parse error at line " + _parser.line + ": " + Printer.errorToString(e);
            ApiLogger.error("HScript", msg);
            statusText = msg;
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, msg));
            return false;
        } catch (e:Dynamic) {
            var msg = "Parse error: " + Std.string(e);
            ApiLogger.error("HScript", msg);
            statusText = msg;
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, msg));
            return false;
        }

        _resetSandbox();

        try {
            _interp.execute(_program);
        } catch (e:Dynamic) {
            var msg = "Execution error on load: " + Std.string(e);
            ApiLogger.error("HScript", msg);
            statusText = msg;
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, msg));
            return false;
        }

        _hasOnStart = _interp.variables.exists("onStart") && Reflect.isFunction(_interp.variables.get("onStart"));
        _hasOnTick = _interp.variables.exists("onTick") && Reflect.isFunction(_interp.variables.get("onTick"));
        _hasOnStop = _interp.variables.exists("onStop") && Reflect.isFunction(_interp.variables.get("onStop"));
        _hasOnPacket = _interp.variables.exists("onPacket") && Reflect.isFunction(_interp.variables.get("onPacket"));
        _hasOnZoneEntered = _interp.variables.exists("onZoneEntered") && Reflect.isFunction(_interp.variables.get("onZoneEntered"));
        _hasOnQuestUpdated = _interp.variables.exists("onQuestUpdated") && Reflect.isFunction(_interp.variables.get("onQuestUpdated"));
        _hasOnInventoryChanged = _interp.variables.exists("onInventoryChanged") && Reflect.isFunction(_interp.variables.get("onInventoryChanged"));

        statusText = "Loaded HScript (" + (_hasOnTick ? "tick-loop" : "exec-once") + ")";
        ApiLogger.info("HScript", statusText);
        return true;
    }

    public function start():Void {
        if ((Api.game == null || Api.game.world == null) && Api.game != null) {
            Api.init(Api.game);
        }
        if (_program == null) {
            ApiLogger.warn("HScript", "Cannot start: no script loaded.");
            return;
        }

        // Truncate bot.log to start fresh on every script run
        ApiLogger.clearLog();

        isRunning = true;
        waitTimer = 0;

        // Scripting ergonomics: Infinite Range and Death Spawn are always ON by default during scripts
        if (Api.combat != null) Api.combat.setInfiniteRange(true);
        if (Api.map != null) Api.map.autoDeathSpawn = true;

        _timer.delay = tickInterval;
        _timer.start();
        statusText = "Running HScript...";
        Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.SCRIPT_STARTED, "HScript Started!"));
        ApiLogger.info("HScript", "HScript Started!");

        if (_hasOnStart) {
            try {
                var fn = _interp.variables.get("onStart");
                fn();
            } catch (e:Dynamic) {
                _handleScriptError("onStart error: " + Std.string(e), e);
            }
        }
    }

    public function stop():Void {
        if (!isRunning) return;
        isRunning = false;
        _timer.stop();
        statusText = "Stopped.";

        if (_hasOnStop) {
            try {
                var fn = _interp.variables.get("onStop");
                fn();
            } catch (e:Dynamic) {
                ApiLogger.error("HScript", "onStop error: " + Std.string(e));
            }
        }

        Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.SCRIPT_STOPPED, "HScript Stopped!"));
        ApiLogger.info("HScript", "HScript Stopped!");

        if (Api.quest != null) {
            Api.quest.stopAuto();
            Api.quest.clearQueue();
        }
        if (Api.inventory != null) {
            Api.inventory.clearBankQueue();
        }
        if (Api.combat != null) {
            Api.combat.stopAuto();
            Api.combat.dropCombat();
            Api.combat.resetHunt();
        } else {
            CombatEngine.stop();
        }
    }

    private function onTimerTick(e:TimerEvent):Void {
        if (!isRunning) return;
        if (Api.game == null || Api.game.world == null) return;

        var world = Api.game.world;
        if (world.myAvatar != null && world.myAvatar.dataLeaf != null && world.myAvatar.dataLeaf.intState == 0) {
            statusText = "Waiting for respawn...";
            return;
        }

        if (Api.map != null && !Api.map.isLoaded) {
            statusText = "Loading map...";
            return;
        }

        var now = ApiTime.now();
        if (waitTimer > 0 && now < waitTimer) return;

        if (_hasOnTick) {
            try {
                var fn = _interp.variables.get("onTick");
                fn();
            } catch (err:Dynamic) {
                _handleScriptError("onTick error: " + Std.string(err), err);
            }
        } else {
            var bgCombat = CombatEngine.IS_ON;
            var bgQuest = Api.quest != null && Api.quest.isAutoRunning;
            if (bgCombat || bgQuest) {
                statusText = bgCombat ? "Auto-combat running" : "Auto-quest running";
                return;
            }
            stop();
            statusText = "Script Finished!";
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "Script Finished!"));
            ApiLogger.info("HScript", "Script Finished!");
        }
    }

    private function onGameZoneEntered(e:GameEvent):Void {
        if (isRunning && _hasOnZoneEntered) {
            try { _interp.variables.get("onZoneEntered")(e.data); } catch(err:Dynamic) { _handleScriptError("onZoneEntered: " + err, err); }
        }
    }

    private function onGameQuestUpdated(e:GameEvent):Void {
        if (isRunning && _hasOnQuestUpdated) {
            try { _interp.variables.get("onQuestUpdated")(e.data); } catch(err:Dynamic) { _handleScriptError("onQuestUpdated: " + err, err); }
        }
    }

    private function onGameInventoryChanged(e:GameEvent):Void {
        if (isRunning && _hasOnInventoryChanged) {
            try { _interp.variables.get("onInventoryChanged")(e.data); } catch(err:Dynamic) { _handleScriptError("onInventoryChanged: " + err, err); }
        }
    }

    public function handlePacket(type:String, cmd:String, data:Dynamic):Void {
        if (isRunning && _hasOnPacket) {
            try { _interp.variables.get("onPacket")(type, cmd, data); } catch(err:Dynamic) { _handleScriptError("onPacket: " + err, err); }
        }
    }

    private function _handleScriptError(msg:String, err:Dynamic = null):Void {
        var fullMsg = msg;
        if (err != null) {
            try {
                var stack:String = (Reflect.field(err, "getStackTrace") != null) ? (untyped err).getStackTrace() : "";
                if (stack != null && stack != "") fullMsg += "\n" + stack;
            } catch (e:Dynamic) {}
        }
        ApiLogger.error("HScript", fullMsg);
        statusText = "Error: " + msg;
        Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "HScript Error: " + msg));
        stop();
    }
}
