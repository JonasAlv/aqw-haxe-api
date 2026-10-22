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

typedef HScriptCallback = {
    var name:String;
    var args:Array<Dynamic>;
    var runToken:Int;
};

class HScriptEngine {
    private var _parser:Parser;
    private var _interp:Interp;
    private var _program:Expr;
    private var _timer:Timer;

    private var _isRunning:Bool = false;
    public var isRunning(get, never):Bool;
    public function get_isRunning():Bool return _isRunning;

    private var _lifecycleState:String = "idle";
    public var lifecycleState(get, never):String;
    public function get_lifecycleState():String return _lifecycleState;

    public var waitTimer:Float = 0;
    public var statusText:String = "Stopped";
    /** Script callbacks are deliberately slower than combat; combat has its own packet wakeups. */
    public var tickInterval:Int = Std.int(com.aqwapi.utils.ApiTimings.SCRIPT_TICK_MS);

    public function sleep(ms:Float):Void {
        waitTimer = ApiTime.now() + Math.max(0, ms);
    }

    private var _hasOnStart:Bool = false;
    private var _hasOnTick:Bool = false;
    private var _hasOnStop:Bool = false;
    private var _hasOnPacket:Bool = false;
    private var _hasOnZoneEntered:Bool = false;
    private var _hasOnQuestUpdated:Bool = false;
    private var _hasOnInventoryChanged:Bool = false;
    private var _hasOnCombatUpdated:Bool = false;
    private var _pendingZoneData:Dynamic = null;
    private var _zoneWaitStartedAt:Float = 0;
    private var _zoneWaitQueued:Bool = false;
    private var _runToken:Int = 0;
    private var _stopping:Bool = false;
    private var _callbackDepth:Int = 0;
    private var _pendingCallbacks:Array<HScriptCallback> = [];
    private var _lastSlowCallbackAt:Float = -100000;
    private var _lastCallbackOverflowAt:Float = -100000;

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
        Api.dispatcher.addEventListener(GameEvent.COMBAT_UPDATED, onGameCombatUpdated);

        _resetSandbox();
    }

    public function reset():Void {
        if (isRunning) stop();
        _pendingCallbacks = [];
        _pendingZoneData = null;
        _zoneWaitQueued = false;
        _runToken++;
        waitTimer = 0;
        _lifecycleState = (_program != null) ? "ready" : "idle";
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
                _hasOnCombatUpdated = _interp.variables.exists("onCombatUpdated") && Reflect.isFunction(_interp.variables.get("onCombatUpdated"));
            } catch (e:Dynamic) {
                ApiLogger.error("HScript", "Reset error: " + Std.string(e));
            }
        }
    }

    public function clear():Void {
        if (isRunning) stop();
        _program = null;
        _pendingCallbacks = [];
        _pendingZoneData = null;
        _zoneWaitQueued = false;
        _runToken++;
        _hasOnStart = false;
        _hasOnTick = false;
        _hasOnStop = false;
        _hasOnPacket = false;
        _hasOnZoneEntered = false;
        _hasOnQuestUpdated = false;
        _hasOnInventoryChanged = false;
        _hasOnCombatUpdated = false;
        waitTimer = 0;
        _lifecycleState = "idle";
        statusText = "No script loaded.";
        _resetSandbox();
    }

    private function _resetSandbox():Void {
        _interp = new ScriptInterp();
        ScriptBindings.registerAll(cast _interp);
    }

    public function loadScript(scriptCode:String):Bool {
        if ((Api.game == null || Api.game.world == null) && Api.game != null) {
            Api.init(Api.game);
        }

        // Loading is transactional: a malformed/new script must never leave the previous program
        // executable. reset() stops the old program, but intentionally preserves its parsed AST for
        // a normal restart, so clear the loaded program explicitly for this replacement operation.
        reset();
        _program = null;
        _pendingCallbacks = [];
        _pendingZoneData = null;
        _zoneWaitQueued = false;
        _runToken++;
        _hasOnStart = false;
        _hasOnTick = false;
        _hasOnStop = false;
        _hasOnPacket = false;
        _hasOnZoneEntered = false;
        _hasOnQuestUpdated = false;
        _hasOnInventoryChanged = false;
        _hasOnCombatUpdated = false;
        statusText = "Loading HScript...";

        // Strip //hscript or #hscript header line if present
        var cleanCode = scriptCode;
        if (cleanCode.indexOf("//hscript") == 0) cleanCode = cleanCode.substring(9);
        else if (cleanCode.indexOf("#hscript") == 0) cleanCode = cleanCode.substring(8);

        var parsedProgram:Expr = null;
        try {
            parsedProgram = _parser.parseString(cleanCode);
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
            _interp.execute(parsedProgram);
        } catch (e:Dynamic) {
            var msg = "Execution error on load: " + Std.string(e);
            ApiLogger.error("HScript", msg);
            statusText = msg;
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, msg));
            return false;
        }

        _program = parsedProgram;

        _hasOnStart = _interp.variables.exists("onStart") && Reflect.isFunction(_interp.variables.get("onStart"));
        _hasOnTick = _interp.variables.exists("onTick") && Reflect.isFunction(_interp.variables.get("onTick"));
        _hasOnStop = _interp.variables.exists("onStop") && Reflect.isFunction(_interp.variables.get("onStop"));
        _hasOnPacket = _interp.variables.exists("onPacket") && Reflect.isFunction(_interp.variables.get("onPacket"));
        _hasOnZoneEntered = _interp.variables.exists("onZoneEntered") && Reflect.isFunction(_interp.variables.get("onZoneEntered"));
        _hasOnQuestUpdated = _interp.variables.exists("onQuestUpdated") && Reflect.isFunction(_interp.variables.get("onQuestUpdated"));
        _hasOnInventoryChanged = _interp.variables.exists("onInventoryChanged") && Reflect.isFunction(_interp.variables.get("onInventoryChanged"));
        _hasOnCombatUpdated = _interp.variables.exists("onCombatUpdated") && Reflect.isFunction(_interp.variables.get("onCombatUpdated"));

        var mode = _hasOnTick ? "tick-loop" : (_hasEventHandlers() ? "event-driven" : "exec-once");
        _lifecycleState = "ready";
        statusText = "Loaded HScript (" + mode + ")";
        ApiLogger.info("HScript", statusText);
        return true;
    }

    // Values saved before script forces globals on, restored when script stops.
    private var _savedInfiniteRange:Bool = false;
    private var _savedDeathSpawn:Bool = false;
    private var _savedSkipCutscenes:Bool = false;
    private var _savedSmartClass:String = "Current";
    private var _savedSkillMode:String = "Auto";

    public function start():Void {
        if ((Api.game == null || Api.game.world == null) && Api.game != null) {
            Api.init(Api.game);
        }
        if (_program == null) {
            ApiLogger.warn("HScript", "Cannot start: no script loaded.");
            return;
        }
        if (_isRunning || _lifecycleState == "starting" || _lifecycleState == "stopping") {
            ApiLogger.warn("HScript", "Cannot start: a script run is already active.");
            return;
        }

        // Truncate api.log to start fresh on every script run
        ApiLogger.clearLog();

        _runToken++;
        _pendingCallbacks = [];
        _pendingZoneData = null;
        _zoneWaitQueued = false;
        _stopping = false;
        _lifecycleState = "starting";
        _isRunning = true;
        waitTimer = 0;
        ScriptBindings.resetStoryData();

        // Save current user settings before overriding
        _savedInfiniteRange = (Api.combat != null) ? Api.combat.infiniteRange : false;
        _savedDeathSpawn    = (Api.map != null)    ? Api.map.autoDeathSpawn   : false;
        _savedSkipCutscenes = (Api.map != null)    ? Api.map.skipCutscenes    : false;
        _savedSmartClass    = com.aqwapi.modules.CombatEngine.smartClass;
        _savedSkillMode     = com.aqwapi.modules.CombatEngine.skillMode;

        // Reset to clean state for script execution so scripts detect their own equipped class
        com.aqwapi.modules.CombatEngine.smartClass = "Current";
        com.aqwapi.modules.CombatEngine.skillMode  = "Auto";

        // Force scripting ergonomics: Infinite Range, Death Spawn, Skip Cutscenes always ON
        if (Api.combat != null) Api.combat.setInfiniteRange(true);
        if (Api.map != null) {
            Api.map.autoDeathSpawn = true;
            Api.map.skipCutscenes  = true;
        }

        _timer.delay = Std.int(Math.max(Std.int(com.aqwapi.utils.ApiTimings.MIN_POLL_INTERVAL_MS), tickInterval));
        statusText = "Starting HScript...";
        Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.SCRIPT_STARTED, "HScript Started!"));
        ApiLogger.info("HScript", "HScript Started!");

        if (!_isRunning) return;

        if (_hasOnStart) {
            try {
                var fn = _interp.variables.get("onStart");
                _invokeCallback("onStart", fn, []);
            } catch (e:Dynamic) {
                _handleScriptError("onStart error: " + Std.string(e), e);
            }
        }

        if (!_isRunning) return;
        _lifecycleState = "running";
        _timer.start();
        statusText = "Running HScript...";
    }

    public function stop():Void {
        if ((!_isRunning && _lifecycleState != "starting") || _stopping) return;
        _stopping = true;
        _isRunning = false;
        _lifecycleState = "stopping";
        _runToken++;
        _timer.stop();
        waitTimer = 0;
        _pendingCallbacks = [];
        _pendingZoneData = null;
        _zoneWaitQueued = false;
        statusText = "Stopped.";

        try {
            if (Api.combat != null) {
                Api.combat.stopAuto();
                Api.combat.dropCombat();
                Api.combat.resetHunt();
            } else {
                CombatEngine.stop();
            }
            com.aqwapi.modules.CombatEngine.targetName = null;
            com.aqwapi.modules.CombatEngine.lockedMMID = null;
            if (Api.quest != null) {
                Api.quest.stopAuto();
                Api.quest.clearQueue();
            }
            if (Api.inventory != null) {
                Api.inventory.clearBankQueue();
                Api.inventory.cancelRestoreGear();
            }
            ScriptBindings.resetStoryData();
        } catch (e:Dynamic) {
            ApiLogger.error("HScript", "Script cleanup error: " + Std.string(e));
        }

        if (_hasOnStop) {
            try {
                var fn = _interp.variables.get("onStop");
                _invokeCallback("onStop", fn, [], false);
            } catch (e:Dynamic) {
                ApiLogger.error("HScript", "onStop error: " + Std.string(e));
            }
        }

        // Restore user settings to what they were before the script ran, even if cleanup or onStop failed.
        try {
            if (Api.combat != null) Api.combat.setInfiniteRange(_savedInfiniteRange);
            if (Api.map != null) {
                Api.map.autoDeathSpawn = _savedDeathSpawn;
                Api.map.skipCutscenes  = _savedSkipCutscenes;
            }
            com.aqwapi.modules.CombatEngine.smartClass = _savedSmartClass;
            com.aqwapi.modules.CombatEngine.skillMode  = _savedSkillMode;
        } catch (e:Dynamic) {
            ApiLogger.error("HScript", "Script setting restore error: " + Std.string(e));
        }

        _lifecycleState = "stopped";
        try {
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.SCRIPT_STOPPED, "HScript Stopped!"));
        } catch (e:Dynamic) {
            ApiLogger.error("HScript", "SCRIPT_STOPPED event error: " + Std.string(e));
        }
        ApiLogger.info("HScript", "HScript Stopped!");
        _stopping = false;
    }

    private function onTimerTick(e:TimerEvent):Void {
        if (!_isRunning || _lifecycleState != "running") return;
        if (Api.game == null || Api.game.world == null) return;

        // Always run skip-cutscenes check and collision state when enabled
        if (Api.map != null) {
            Api.map.checkSkipCutscenes();
            if (Api.map.disableCollisions) Api.map.applyCollisionState();
        }

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
        waitTimer = 0;

        _processPendingCallbacks();
        if (!_isRunning) return;

        if (_hasOnTick) {
            try {
                var fn = _interp.variables.get("onTick");
                _invokeCallback("onTick", fn, []);
            } catch (err:Dynamic) {
                _handleScriptError("onTick error: " + Std.string(err), err);
            }
            if (!_isRunning) return;
        } else {
            var bgCombat = CombatEngine.IS_ON;
            var bgQuest = Api.quest != null && Api.quest.isAutoRunning;
            if (bgCombat || bgQuest || _hasEventHandlers()) {
                statusText = bgCombat ? "Auto-combat running" : "Auto-quest running";
                if (!bgCombat && !bgQuest) statusText = "Waiting for script events...";
                return;
            }
            stop();
            statusText = "Script Finished!";
            Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "Script Finished!"));
            ApiLogger.info("HScript", "Script Finished!");
        }
    }

    private function onGameZoneEntered(e:GameEvent):Void {
        // Always cancel cutscenes on zone entry when enabled (script running or not)
        if (Api.map != null) {
            Api.map.checkSkipCutscenes();
            if (Api.map.disableCollisions) Api.map.applyCollisionState();
        }
        if (!isRunning || !_hasOnZoneEntered) return;
        if (Api.map == null || Api.map.isLoaded) {
            _enqueueCallback("onZoneEntered", [e.data]);
        } else {
            _pendingZoneData = e.data;
            if (!_zoneWaitQueued) {
                _zoneWaitQueued = true;
                _zoneWaitStartedAt = ApiTime.now();
                var token = _runToken;
                haxe.Timer.delay(function() waitForZoneReady(token), 0);
            }
        }
    }

    private function waitForZoneReady(token:Int):Void {
        if (!_zoneWaitQueued || token != _runToken) return;
        if (!isRunning) {
            _zoneWaitQueued = false;
            _pendingZoneData = null;
            return;
        }
        if (Api.map != null && Api.map.isLoaded) {
            var data = _pendingZoneData;
            _zoneWaitQueued = false;
            _pendingZoneData = null;
            _enqueueCallback("onZoneEntered", [data]);
            return;
        }
        if (ApiTime.now() - _zoneWaitStartedAt >= com.aqwapi.utils.ApiTimings.ZONE_READY_TIMEOUT_MS) {
            _zoneWaitQueued = false;
            _pendingZoneData = null;
            ApiLogger.warn("HScript", "Discarded zone callback because the map did not become ready in time.");
            return;
        }
        haxe.Timer.delay(function() waitForZoneReady(token), Std.int(com.aqwapi.utils.ApiTimings.ZONE_READY_POLL_MS));
    }

    private function onGameQuestUpdated(e:GameEvent):Void {
        if (isRunning && _hasOnQuestUpdated) {
            _enqueueCallback("onQuestUpdated", [e.data]);
        }
    }

    private function onGameInventoryChanged(e:GameEvent):Void {
        if (isRunning && _hasOnInventoryChanged) {
            _enqueueCallback("onInventoryChanged", [e.data]);
        }
    }

    private function onGameCombatUpdated(e:GameEvent):Void {
        if (isRunning && _hasOnCombatUpdated) {
            _enqueueCallback("onCombatUpdated", [e.data], true);
        }
    }

    public function handlePacket(type:String, cmd:String, data:Dynamic):Void {
        if (isRunning && _hasOnPacket) {
            _enqueueCallback("onPacket", [type, cmd, data]);
        }
    }

    private function _hasEventHandlers():Bool {
        return _hasOnPacket
            || _hasOnZoneEntered
            || _hasOnQuestUpdated
            || _hasOnInventoryChanged
            || _hasOnCombatUpdated;
    }

    /**
     * Game events are deferred until the scheduler turn instead of invoking HScript reentrantly
     * from inside an AQW action or packet handler. Combat updates are coalesced because only the
     * newest state is useful; packets and lifecycle events retain their ordering.
     */
    private function _enqueueCallback(name:String, args:Array<Dynamic>, coalesce:Bool = false):Void {
        if (!_isRunning) return;

        if (coalesce) {
            for (callback in _pendingCallbacks) {
                if (callback.runToken == _runToken && callback.name == name) {
                    callback.args = args;
                    return;
                }
            }
        }

        if (_pendingCallbacks.length >= com.aqwapi.utils.ApiTimings.SCRIPT_CALLBACK_QUEUE_CAPACITY) {
            var now = ApiTime.now();
            if (now - _lastCallbackOverflowAt >= com.aqwapi.utils.ApiTimings.SCRIPT_CALLBACK_WARN_DEDUPE_MS) {
                _lastCallbackOverflowAt = now;
                ApiLogger.warn("HScript", "Callback queue full; deferred " + name + " callback was dropped.");
            }
            return;
        }

        _pendingCallbacks.push({
            name: name,
            args: args,
            runToken: _runToken
        });
    }

    private function _processPendingCallbacks():Void {
        var processed = 0;
        while (_isRunning
            && _pendingCallbacks.length > 0
            && processed < com.aqwapi.utils.ApiTimings.SCRIPT_MAX_CALLBACKS_PER_TICK) {
            var callback = _pendingCallbacks.shift();
            if (callback == null || callback.runToken != _runToken) continue;

            var fn = _interp.variables.get(callback.name);
            if (!Reflect.isFunction(fn)) continue;
            _invokeCallback(callback.name, fn, callback.args);
            processed++;
        }
    }

    private function _invokeCallback(name:String, fn:Dynamic, args:Array<Dynamic>, handleError:Bool = true):Void {
        if (!Reflect.isFunction(fn)) return;

        var startedAt = ApiTime.now();
        _callbackDepth++;
        try {
            Reflect.callMethod(null, fn, args);
        } catch (err:Dynamic) {
            if (handleError) {
                _handleScriptError(name + " error: " + Std.string(err), err);
            } else {
                ApiLogger.error("HScript", name + " error: " + Std.string(err));
            }
        }

        _callbackDepth--;
        var elapsed = ApiTime.now() - startedAt;
        if (elapsed >= com.aqwapi.utils.ApiTimings.SCRIPT_CALLBACK_WARN_MS
            && startedAt - _lastSlowCallbackAt >= com.aqwapi.utils.ApiTimings.SCRIPT_CALLBACK_WARN_DEDUPE_MS) {
            _lastSlowCallbackAt = startedAt;
            ApiLogger.warn("HScript", name + " callback took " + Std.int(elapsed) + "ms.");
        }
    }

    private function _handleScriptError(msg:String, err:Dynamic = null):Void {
        var scriptName = (Api.script != null && Api.script.activeScriptName != null && Api.script.activeScriptName != "")
            ? " [" + Api.script.activeScriptName + "]" : "";
        msg = "script" + scriptName + ": " + msg;
        var fullMsg = msg;
        if (err != null) {
            try {
                var stack:String = "";
                var getStack = Reflect.field(err, "getStackTrace");
                if (Reflect.isFunction(getStack)) stack = Std.string(Reflect.callMethod(err, getStack, []));
                if ((stack == null || stack == "" || stack == "null") && Reflect.field(err, "stackTrace") != null) stack = Std.string(Reflect.field(err, "stackTrace"));
                if ((stack == null || stack == "" || stack == "null") && Reflect.field(err, "stack") != null) stack = Std.string(Reflect.field(err, "stack"));
                if (stack != null && stack != "") fullMsg += "\n" + stack;
            } catch (e:Dynamic) {}
            try {
                var line = Reflect.field(err, "lineNumber");
                if (line == null) line = Reflect.field(err, "line");
                if (line != null) fullMsg += " (line " + Std.string(line) + ")";
            } catch (_:Dynamic) {}
        }
        ApiLogger.error("HScript", fullMsg);
        Api.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "HScript Error: " + msg));
        stop();
        statusText = "Error: " + msg;
    }
}
