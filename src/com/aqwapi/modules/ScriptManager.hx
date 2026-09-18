package com.aqwapi.modules;

import com.aqwapi.AqwApi;
import com.aqwapi.commands.ScriptCommands;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwTime;
import flash.events.TimerEvent;
import flash.utils.Timer;

class ScriptManager {
    private var _timer:Timer;

    public var commands:Array<Dynamic>  = [];
    public var currentIndex:Int         = 0;
    public var isRunning:Bool           = false;
    public var waitTimer:Float          = 0;
    public var labels:Dynamic           = {};
    public var unbankedItems:Dynamic    = {};
    public var completedThisSession:Dynamic = {};
    public var statusText:String        = "Stopped";
    public var isHScriptMode:Bool       = false;

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

    public function new() {
        _timer = new Timer(500);
        _timer.addEventListener(TimerEvent.TIMER, onTick, false, 0, true);
    }

    public static function isHScript(text:String):Bool {
        if (text == null) return false;
        var trimmed = StringTools.trim(text);
        if (trimmed.indexOf("//hscript") == 0 || trimmed.indexOf("#hscript") == 0) return true;
        if (trimmed.indexOf("function ") != -1 || trimmed.indexOf("function(") != -1) return true;
        if (trimmed.indexOf("var ") != -1 && (trimmed.indexOf(";") != -1 || trimmed.indexOf("=") != -1)) return true;
        if (trimmed.indexOf("class ") != -1) return true;
        return false;
    }

    public function loadScript(scriptText:String):Void {
        if ((AqwApi.game == null || AqwApi.game.world == null) && AqwApi.game != null) AqwApi.init(AqwApi.game);

        commands = [];
        currentIndex = 0;
        unbankedItems = {};

        if (isHScript(scriptText)) {
            isHScriptMode = true;
            reset();
            AqwApi.hscript.loadScript(scriptText);
            statusText = AqwApi.hscript.statusText;
            return;
        }

        isHScriptMode = false;

        scriptText = scriptText.split("\r\n").join("\n").split("\r").join("\n");
        var lines = scriptText.split("\n");
        for (line in lines) {
            line = StringTools.trim(line);
            if (line.length == 0 || line.indexOf("//") == 0 || line.indexOf("--") == 0) continue;

            var firstSpace = line.indexOf(" ");
            var action = line;
            var argsString = "";
            if (firstSpace != -1) {
                action = line.substring(0, firstSpace);
                argsString = StringTools.trim(line.substring(firstSpace + 1));
            }

            var args:Array<String> = [];
            if (argsString.length > 0) {
                var rawArgs = argsString.split(",");
                for (a in rawArgs) args.push(StringTools.trim(a));
            }

            commands.push({ action: action.toUpperCase(), args: args, raw: line });
        }

        reset();
        statusText = "Loaded " + commands.length + " commands.";
    }

    public function reset():Void {
        currentIndex = 0;
        waitTimer = 0;
        labels = {};
        for (k in 0...commands.length) {
            if (commands[k].action == "LABEL" && (cast commands[k].args : Array<String>).length > 0) {
                Reflect.setField(labels, (cast commands[k].args[0] : String).toLowerCase(), k);
            }
        }
        unbankedItems = {};
        completedThisSession = {};
        statusText = "Stopped";
        if (isHScriptMode && AqwApi.hscript != null) {
            AqwApi.hscript.reset();
        }
    }

    public function start():Void {
        if (AqwApi.game == null || AqwApi.game.world == null) {
            if (AqwApi.game != null) AqwApi.init(AqwApi.game);
        }

        if (isHScriptMode) {
            AqwApi.hscript.start();
            isRunning = AqwApi.hscript.isRunning;
            statusText = AqwApi.hscript.statusText;
            return;
        }


        if (commands.length == 0) return;

        if (currentIndex >= commands.length) {
            currentIndex = 0;
            unbankedItems = {};
            completedThisSession = {};
        }

        isRunning = true;
        waitTimer = 0;

        CombatManager.init();
        if (CombatManager.IS_ON) CombatManager.stop();

        _timer.start();
        statusText = "Running...";
        AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.SCRIPT_STARTED, "Script Started!"));
        ApiLogger.info("Script", "Script Started!");
    }

    public function stop():Void {
        if (isHScriptMode) {
            isRunning = false;
            AqwApi.hscript.stop();
            statusText = AqwApi.hscript.statusText;
            return;
        }

        if (!isRunning) return;
        isRunning = false;
        _timer.stop();
        statusText = "Stopped.";
        AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.SCRIPT_STOPPED, "Script Stopped!"));
        ApiLogger.info("Script", "Script Stopped!");
        if (AqwApi.quest != null) {
            AqwApi.quest.stopAuto();
        }
        if (AqwApi.combat != null) {
            AqwApi.combat.stopAuto();
        } else if (AqwApi.game != null) {
            CombatManager.stop();
            try {
                var world = AqwApi.game.world;
                if (world != null && world.moveToCell != null && world.strFrame != null && world.strPad != null)
                    world.moveToCell(world.strFrame, world.strPad);
            } catch (e:Dynamic) {}
        }
    }

    public function getItemCount(searchName:String):Int {
        return AqwApi.inventory.getQuestQuantity(searchName);
    }

    private function onTick(e:TimerEvent):Void {
        if (!isRunning || AqwApi.game == null || AqwApi.game.world == null) return;
        var world = AqwApi.game.world;

        if (world.myAvatar != null && world.myAvatar.dataLeaf != null && world.myAvatar.dataLeaf.intState == 0) {
            statusText = "Waiting for respawn...";
            return;
        }

        if (currentIndex >= commands.length) {
            var bgCombat = CombatManager.IS_ON;
            var bgQuest = AqwApi.quest != null && AqwApi.quest.isAutoRunning;
            if (bgCombat || bgQuest) {
                statusText = bgCombat ? "Auto-combat running" : "Auto-quest running";
                waitTimer = AqwTime.now() + 10000;
                return;
            }
            stop();
            statusText = "Script Finished!";
            AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, "Script Finished!"));
            ApiLogger.info("Script", "Script Finished!");
            return;
        }

        var now = AqwTime.now();
        if (waitTimer > 0 && now < waitTimer) return;

        var cmd:Dynamic = commands[currentIndex];
        ScriptCommands.execute(cmd, this);
    }
}

