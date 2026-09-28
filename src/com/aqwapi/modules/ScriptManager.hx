package com.aqwapi.modules;

import com.aqwapi.Api;
import com.aqwapi.scripting.HScriptEngine;
import com.aqwapi.utils.ApiStorage;

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
        var content = ApiStorage.readText("scripts/" + name + ".hxs");
        if ((content == null || StringTools.trim(content) == "") && name == "ShadowBattleon_Leveling") {
            return getDefaultShadowBattleonScript();
        }
        return (content != null) ? content : "";
    }

    public function saveScript(name:String, content:String):Bool {
        if (name == null || name == "") return false;
        return ApiStorage.writeText("scripts/" + name + ".hxs", content);
    }

    public function deleteScript(name:String):Bool {
        if (name == null || name == "") return false;
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

    public static function getDefaultShadowBattleonScript():String {
        return "// Auto Leveling Script - ShadowBattleon Doomed Trolls\n"
            + "// Automatically farms XP and quest items in shadowbattleon.\n\n"
            + "function onStart() {\n"
            + "    bot.log(\"[ShadowBattleon] Starting Auto Leveling farm...\");\n"
            + "    bot.drop.acceptAll = true;\n"
            + "    bot.combat.equipLoadout(\"farm\");\n"
            + "    bot.quest.loadMultiple([9421, 9422, 9423]);\n"
            + "    bot.map.join(\"shadowbattleon\", \"Enter\", \"Spawn\");\n"
            + "    bot.sleep(2500);\n"
            + "}\n\n"
            + "function onTick() {\n"
            + "    if (!bot.player.isAlive) {\n"
            + "        bot.sleep(1500);\n"
            + "        return;\n"
            + "    }\n\n"
            + "    if (bot.map.name.toLowerCase() != \"shadowbattleon\") {\n"
            + "        bot.map.join(\"shadowbattleon\", \"Enter\", \"Spawn\");\n"
            + "        bot.sleep(2500);\n"
            + "        return;\n"
            + "    }\n\n"
            + "    // Stay in Enter cell where Doomed Trolls spawn right in front of player\n"
            + "    if (bot.player.cell != \"Enter\") {\n"
            + "        bot.map.jump(\"Enter\", \"Spawn\");\n"
            + "        bot.sleep(800);\n"
            + "        return;\n"
            + "    }\n\n"
            + "    // Ensure combat is active\n"
            + "    if (!bot.combat.isRunning()) {\n"
            + "        bot.combat.start(true);\n"
            + "    }\n\n"
            + "    // Ensure quests are loaded\n"
            + "    if (!bot.quest.isLoaded(9421) || !bot.quest.isLoaded(9422) || !bot.quest.isLoaded(9423)) {\n"
            + "        bot.quest.loadMultiple([9421, 9422, 9423]);\n"
            + "    }\n\n"
            + "    // Check completion and turn-ins\n"
            + "    if (bot.quest.canComplete(9421) || bot.inventory.getItemCount(\"Shadow Hunt Medal\") >= 5) {\n"
            + "        bot.quest.turnIn(9421);\n"
            + "        bot.sleep(600);\n"
            + "    } else if (bot.quest.canComplete(9422) || bot.inventory.getItemCount(\"Mega Shadow Hunt Medal\") >= 3) {\n"
            + "        bot.quest.turnIn(9422);\n"
            + "        bot.sleep(600);\n"
            + "    } else if (bot.quest.canComplete(9423) || bot.inventory.getItemCount(\"Infested Flesh\") >= 6) {\n"
            + "        bot.quest.turnIn(9423);\n"
            + "        bot.sleep(600);\n"
            + "    }\n\n"
            + "    // Re-accept turned in quests\n"
            + "    if (!bot.quest.isAccepted(9421)) {\n"
            + "        bot.quest.accept(9421);\n"
            + "    }\n"
            + "    if (!bot.quest.isAccepted(9422)) {\n"
            + "        bot.quest.accept(9422);\n"
            + "    }\n"
            + "    if (!bot.quest.isAccepted(9423)) {\n"
            + "        bot.quest.accept(9423);\n"
            + "    }\n\n"
            + "    bot.sleep(500);\n"
            + "}\n\n"
            + "function onStop() {\n"
            + "    bot.log(\"[ShadowBattleon] Auto Leveling Stopped.\");\n"
            + "    bot.combat.stop();\n"
            + "}\n";
    }
}
