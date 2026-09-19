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
    public static var printToFile:Bool = true;
    public static var printToChat:Bool = true;
    public static var chatMinLevel:Int = LEVEL_INFO;

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

    private static var _logFile:Dynamic = null;
    private static var _logFileInitialized:Bool = false;

    private static function _resolveLogFile():Dynamic {
        if (_logFileInitialized) return _logFile;
        _logFileInitialized = true;

        try {
            var fileCls:Dynamic = untyped __global__["flash.filesystem.File"];
            var fsCls:Dynamic = untyped __global__["flash.filesystem.FileStream"];
            var fmCls:Dynamic = untyped __global__["flash.filesystem.FileMode"];
            if (fileCls == null || fsCls == null || fmCls == null) return null;

            // Priority 1: applicationStorageDirectory/bot.log (guaranteed writable on all AIR desktop/mobile targets)
            try {
                if (fileCls.applicationStorageDirectory != null) {
                    var candidate = fileCls.applicationStorageDirectory.resolvePath("bot.log");
                    var fs = Type.createInstance(fsCls, []);
                    fs.open(candidate, fmCls.APPEND);
                    fs.writeUTFBytes("");
                    fs.close();
                    _logFile = candidate;
                    flash.Lib.trace("[ApiLogger] Logging to appStorage file: " + candidate.nativePath);
                    return _logFile;
                }
            } catch (e:Dynamic) {}

            // Priority 2: haxe-workspace/bot.log (applicationDirectory.parent.parent)
            try {
                if (fileCls.applicationDirectory != null && 
                    fileCls.applicationDirectory.parent != null && 
                    fileCls.applicationDirectory.parent.parent != null) {
                    var candidate = fileCls.applicationDirectory.parent.parent.resolvePath("bot.log");
                    var fs = Type.createInstance(fsCls, []);
                    fs.open(candidate, fmCls.APPEND);
                    fs.writeUTFBytes("");
                    fs.close();
                    _logFile = candidate;
                    flash.Lib.trace("[ApiLogger] Logging to workspace file: " + candidate.nativePath);
                    return _logFile;
                }
            } catch (e:Dynamic) {}

            // Priority 3: userDirectory/bot.log
            try {
                if (fileCls.userDirectory != null) {
                    var candidate = fileCls.userDirectory.resolvePath("bot.log");
                    var fs = Type.createInstance(fsCls, []);
                    fs.open(candidate, fmCls.APPEND);
                    fs.writeUTFBytes("");
                    fs.close();
                    _logFile = candidate;
                    flash.Lib.trace("[ApiLogger] Logging to userDir file: " + candidate.nativePath);
                    return _logFile;
                }
            } catch (e:Dynamic) {}
        } catch (e:Dynamic) {}

        return null;
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
                flash.Lib.trace(formatted);
            } catch (e:Dynamic) {}
        }

        if (printToFile) {
            try {
                var f = _resolveLogFile();
                if (f != null) {
                    var fsCls:Dynamic = untyped __global__["flash.filesystem.FileStream"];
                    var fmCls:Dynamic = untyped __global__["flash.filesystem.FileMode"];
                    var fs = Type.createInstance(fsCls, []);
                    fs.open(f, fmCls.APPEND);
                    fs.writeUTFBytes(formatted + "\n");
                    fs.close();
                }
            } catch (e:Dynamic) {
                _logFileInitialized = false;
                _logFile = null;
            }
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

    public static function clearLog():Void {
        try {
            var f = _resolveLogFile();
            if (f != null) {
                var fsCls:Dynamic = untyped __global__["flash.filesystem.FileStream"];
                var fmCls:Dynamic = untyped __global__["flash.filesystem.FileMode"];
                if (fsCls != null && fmCls != null) {
                    var fs = Type.createInstance(fsCls, []);
                    fs.open(f, fmCls.WRITE);
                    fs.writeUTFBytes("");
                    fs.close();
                }
            }
        } catch (e:Dynamic) {}
    }

    public static function pushChat(type:String, text:String, sender:String = "API"):Void {
        if (AqwApi.game != null && AqwApi.game.chatF != null && AqwApi.game.chatF.pushMsg != null) {
            try {
                AqwApi.game.chatF.pushMsg(type, text, sender, "", 0);
            } catch (e:Dynamic) {}
        }
    }
}
