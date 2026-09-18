package com.aqwapi.utils;

import com.aqwapi.AqwApi;

class ApiLogger {
    public static inline var LEVEL_DEBUG:Int = 0;
    public static inline var LEVEL_INFO:Int = 1;
    public static inline var LEVEL_WARN:Int = 2;
    public static inline var LEVEL_ERROR:Int = 3;
    public static inline var LEVEL_OFF:Int = 4;

    public static var level:Int = LEVEL_INFO;
    public static var printToConsole:Bool = true;
    public static var printToChat:Bool = false;
    public static var chatMinLevel:Int = LEVEL_WARN;
    public static var onLog:String->Int->String->Void = null;

    private static var _traceInited:Bool = initTrace();
    private static function initTrace():Bool {
        try {
            haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos):Void {
                try {
                    var str:String = (infos != null ? infos.fileName + ":" + infos.lineNumber + ": " : "") + Std.string(v);
                    untyped __global__["trace"](str);
                } catch (e:Dynamic) {}
            };
        } catch (e:Dynamic) {}
        return true;
    }

    public static function debug(tag:String, message:String):Void {
        log(tag, LEVEL_DEBUG, message);
    }

    public static function info(tag:String, message:String):Void {
        log(tag, LEVEL_INFO, message);
    }

    public static function warn(tag:String, message:String):Void {
        log(tag, LEVEL_WARN, message);
    }

    public static function error(tag:String, message:String):Void {
        log(tag, LEVEL_ERROR, message);
    }

    public static function log(tag:String, msgLevel:Int, message:String):Void {
        if (msgLevel < level) return;

        var levelStr:String = switch (msgLevel) {
            case LEVEL_DEBUG: "DEBUG";
            case LEVEL_INFO:  "INFO";
            case LEVEL_WARN:  "WARN";
            case LEVEL_ERROR: "ERROR";
            default: "LOG";
        };

        var formatted:String = "[AqwApi:" + tag + "] " + message;

        if (printToConsole) {
            try {
                untyped __global__["trace"](formatted);
            } catch (e:Dynamic) {}
        }

        if (printToChat && msgLevel >= chatMinLevel) {
            pushChat(msgLevel >= LEVEL_WARN ? "warning" : "server", formatted);
        }

        if (onLog != null) {
            try {
                onLog(tag, msgLevel, message);
            } catch (e:Dynamic) {}
        }
    }

    public static function pushChat(type:String, text:String, sender:String = "API"):Void {
        if (AqwApi.game != null && AqwApi.game.chatF != null && AqwApi.game.chatF.pushMsg != null) {
            try {
                AqwApi.game.chatF.pushMsg(type, text, sender, "", 0);
            } catch (e:Dynamic) {}
        }
    }
}
