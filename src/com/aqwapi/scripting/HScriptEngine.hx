package com.aqwapi.scripting;

import com.aqwapi.AqwApi;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.events.GameEvent;
import com.aqwapi.modules.CombatManager;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwTime;
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
        _interp = new Interp();

        _timer = new Timer(tickInterval);
        _timer.addEventListener(TimerEvent.TIMER, onTimerTick, false, 0, true);

        AqwApi.dispatcher.addEventListener(GameEvent.ZONE_ENTERED, onGameZoneEntered);
        AqwApi.dispatcher.addEventListener(GameEvent.QUEST_UPDATED, onGameQuestUpdated);
        AqwApi.dispatcher.addEventListener(GameEvent.INVENTORY_CHANGED, onGameInventoryChanged);

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
        _interp = new Interp();

        // Core API
        _interp.variables.set("api", AqwApi);
        _interp.variables.set("bot", AqwApi);
        _interp.variables.set("player", AqwApi.player);
        _interp.variables.set("combat", AqwApi.combat);
        _interp.variables.set("map", AqwApi.map);
        _interp.variables.set("quest", AqwApi.quest);
        _interp.variables.set("inventory", AqwApi.inventory);
        _interp.variables.set("drops", AqwApi.drops);
        _interp.variables.set("shop", AqwApi.shop);
        _interp.variables.set("monsters", AqwApi.monsters);
        _interp.variables.set("events", AqwApi.dispatcher);

        // Logging & Notifications
        _interp.variables.set("log", function(msg:Dynamic):Void {
            ApiLogger.info("HScript", Std.string(msg));
        });
        _interp.variables.set("warn", function(msg:Dynamic):Void {
            ApiLogger.warn("HScript", Std.string(msg));
        });
        _interp.variables.set("error", function(msg:Dynamic):Void {
            ApiLogger.error("HScript", Std.string(msg));
        });
        _interp.variables.set("notify", function(msg:Dynamic):Void {
            AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, Std.string(msg)));
        });

        // Async Delay
        _interp.variables.set("sleep", function(ms:Float):Void {
            waitTimer = AqwTime.now() + ms;
        });

        // Common API Shortcuts
        _interp.variables.set("join", function(mapName:String, cell:String = "Enter", pad:String = "Spawn"):Void {
            AqwApi.map.join(mapName, cell, pad);
        });
        _interp.variables.set("jump", function(cell:String, pad:String = "Enter"):Void {
            AqwApi.map.jump(cell, pad);
        });
        _interp.variables.set("attack", function(monster:Dynamic):Void {
            AqwApi.combat.attack(Std.string(monster));
        });
        _interp.variables.set("hasItem", function(itemName:String, quantity:Int = 1):Bool {
            return AqwApi.inventory.hasItem(itemName, quantity);
        });
        _interp.variables.set("getItemCount", function(itemName:String):Int {
            return AqwApi.inventory.getQuestQuantity(itemName);
        });
        _interp.variables.set("getDrop", function(itemName:String):Void {
            AqwApi.drops.getDrop(itemName);
        });
        _interp.variables.set("acceptQuest", function(questId:Int):Void {
            AqwApi.quest.accept(questId);
        });
        _interp.variables.set("completeQuest", function(questId:Int, itemId:Int = -1):Void {
            AqwApi.quest.complete(questId, itemId);
        });
        _interp.variables.set("isQuestComplete", function(questId:Int):Bool {
            return AqwApi.quest.isComplete(questId);
        });
        _interp.variables.set("isQuestAccepted", function(questId:Int):Bool {
            return AqwApi.quest.isAccepted(questId);
        });
        _interp.variables.set("dropCombat", function():Void {
            AqwApi.combat.dropCombat();
        });
        _interp.variables.set("equip", function(itemName:String):Void {
            AqwApi.inventory.equip(itemName);
        });
        _interp.variables.set("stop", function():Void {
            stop();
        });

        // Utilities
        _interp.variables.set("Math", Math);
        _interp.variables.set("Std", Std);
        _interp.variables.set("StringTools", StringTools);
        _interp.variables.set("Date", Date);
        _interp.variables.set("AqwTime", AqwTime);
    }

    public function loadScript(scriptCode:String):Bool {
        if ((AqwApi.game == null || AqwApi.game.world == null) && AqwApi.game != null) {
            AqwApi.init(AqwApi.game);
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
            AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, msg));
            return false;
        } catch (e:Dynamic) {
            var msg = "Parse error: " + Std.string(e);
            ApiLogger.error("HScript", msg);
            statusText = msg;
            AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, msg));
            return false;
        }

        try {
            _interp.execute(_program);
        } catch (e:Dynamic) {
            var msg = "Execution error on load: " + Std.string(e);
            ApiLogger.error("HScript", msg);
            statusText = msg;
            AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, msg));
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
        if ((AqwApi.game == null || AqwApi.game.world == null) && AqwApi.game != null) {
            AqwApi.init(AqwApi.game);
        }
        if (_program == null) {
            ApiLogger.warn("HScript", "Cannot start: no script loaded.");
            return;
        }

        isRunning = true;
        waitTimer = 0;

        _timer.delay = tickInterval;
        _timer.start();
        statusText = "Running HScript...";
        AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.SCRIPT_STARTED, "HScript Started!"));
        ApiLogger.info("HScript", "HScript Started!");

        try {
            com.aqwapi.modules.ScriptManager.SINGLETON.isRunning = true;
            com.aqwapi.modules.ScriptManager.SINGLETON.statusText = statusText;
        } catch (e:Dynamic) {}

        if (_hasOnStart) {
            try {
                var fn = _interp.variables.get("onStart");
                fn();
            } catch (e:Dynamic) {
                _handleScriptError("onStart error: " + Std.string(e));
            }
        }
    }

    public function stop():Void {
        if (!isRunning) return;
        isRunning = false;
        _timer.stop();
        statusText = "Stopped.";

        try {
            com.aqwapi.modules.ScriptManager.SINGLETON.isRunning = false;
            com.aqwapi.modules.ScriptManager.SINGLETON.statusText = statusText;
        } catch (e:Dynamic) {}

        if (_hasOnStop) {
            try {
                var fn = _interp.variables.get("onStop");
                fn();
            } catch (e:Dynamic) {
                ApiLogger.error("HScript", "onStop error: " + Std.string(e));
            }
        }

        AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.SCRIPT_STOPPED, "HScript Stopped!"));
        ApiLogger.info("HScript", "HScript Stopped!");

        if (AqwApi.quest != null) AqwApi.quest.stopAuto();
        if (AqwApi.combat != null) AqwApi.combat.stopAuto();
        else CombatManager.stop();
    }


    private function onTimerTick(e:TimerEvent):Void {
        if (!isRunning) return;
        if (AqwApi.game == null || AqwApi.game.world == null) return;

        var world = AqwApi.game.world;
        if (world.myAvatar != null && world.myAvatar.dataLeaf != null && world.myAvatar.dataLeaf.intState == 0) {
            statusText = "Waiting for respawn...";
            return;
        }

        var now = AqwTime.now();
        if (waitTimer > 0 && now < waitTimer) return;

        if (_hasOnTick) {
            try {
                var fn = _interp.variables.get("onTick");
                fn();
            } catch (err:Dynamic) {
                _handleScriptError("onTick error: " + Std.string(err));
            }
        } else {
            var bgCombat = CombatManager.IS_ON;
            var bgQuest = AqwApi.quest != null && AqwApi.quest.isAutoRunning;
            if (bgCombat || bgQuest) {
                statusText = bgCombat ? "Auto-combat running" : "Auto-quest running";
                return;
            }
            stop();
            statusText = "Script Finished!";
            AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "Script Finished!"));
            ApiLogger.info("HScript", "Script Finished!");
        }
    }

    private function onGameZoneEntered(e:GameEvent):Void {
        if (isRunning && _hasOnZoneEntered) {
            try { _interp.variables.get("onZoneEntered")(e.data); } catch(err:Dynamic) { _handleScriptError("onZoneEntered: " + err); }
        }
    }

    private function onGameQuestUpdated(e:GameEvent):Void {
        if (isRunning && _hasOnQuestUpdated) {
            try { _interp.variables.get("onQuestUpdated")(e.data); } catch(err:Dynamic) { _handleScriptError("onQuestUpdated: " + err); }
        }
    }

    private function onGameInventoryChanged(e:GameEvent):Void {
        if (isRunning && _hasOnInventoryChanged) {
            try { _interp.variables.get("onInventoryChanged")(e.data); } catch(err:Dynamic) { _handleScriptError("onInventoryChanged: " + err); }
        }
    }

    public function handlePacket(type:String, cmd:String, data:Dynamic):Void {
        if (isRunning && _hasOnPacket) {
            try { _interp.variables.get("onPacket")(type, cmd, data); } catch(err:Dynamic) { _handleScriptError("onPacket: " + err); }
        }
    }

    private function _handleScriptError(msg:String):Void {
        ApiLogger.error("HScript", msg);
        statusText = "Error: " + msg;
        AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "HScript Error: " + msg));
        stop();
    }
}
