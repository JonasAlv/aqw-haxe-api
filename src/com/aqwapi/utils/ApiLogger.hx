package com.aqwapi.utils;

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
                    #if flash
                    try { untyped __global__["trace"](str); } catch (_:Dynamic) {}
                    flash.Lib.trace(str);
                    #elseif sys
                    Sys.println(str);
                    #else
                    try { untyped console.log(str); } catch (_:Dynamic) {}
                    #end
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

        #if flash
        try {
            var fileCls:Dynamic = untyped __global__["flash.filesystem.File"];
            var fsCls:Dynamic = untyped __global__["flash.filesystem.FileStream"];
            if (fileCls == null || fsCls == null) return null;

            // Priority 1: applicationStorageDirectory/bot.log (guaranteed writable on all AIR desktop/mobile targets)
            try {
                if (fileCls.applicationStorageDirectory != null) {
                    var candidate = fileCls.applicationStorageDirectory.resolvePath("bot.log");
                    var fs:Dynamic = Type.createInstance(fsCls, []);
                    if (fs != null && Reflect.field(fs, "open") != null) {
                        fs.open(candidate, "append");
                        fs.writeUTFBytes("");
                        fs.close();
                        _logFile = candidate;
                        flash.Lib.trace("[ApiLogger] Logging to appStorage file: " + candidate.nativePath);
                        return _logFile;
                    }
                }
            } catch (_:Dynamic) {}

            // Priority 2: haxe-workspace/bot.log (applicationDirectory.parent.parent)
            try {
                if (fileCls.applicationDirectory != null && 
                    fileCls.applicationDirectory.parent != null && 
                    fileCls.applicationDirectory.parent.parent != null) {
                    var candidate = fileCls.applicationDirectory.parent.parent.resolvePath("bot.log");
                    var fs:Dynamic = Type.createInstance(fsCls, []);
                    if (fs != null && Reflect.field(fs, "open") != null) {
                        fs.open(candidate, "append");
                        fs.writeUTFBytes("");
                        fs.close();
                        _logFile = candidate;
                        flash.Lib.trace("[ApiLogger] Logging to workspace file: " + candidate.nativePath);
                        return _logFile;
                    }
                }
            } catch (_:Dynamic) {}

            // Priority 3: userDirectory/bot.log
            try {
                if (fileCls.userDirectory != null) {
                    var candidate = fileCls.userDirectory.resolvePath("bot.log");
                    var fs:Dynamic = Type.createInstance(fsCls, []);
                    if (fs != null && Reflect.field(fs, "open") != null) {
                        fs.open(candidate, "append");
                        fs.writeUTFBytes("");
                        fs.close();
                        _logFile = candidate;
                        flash.Lib.trace("[ApiLogger] Logging to userDir file: " + candidate.nativePath);
                        return _logFile;
                    }
                }
            } catch (_:Dynamic) {}
        } catch (_:Dynamic) {}
        #end

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

        var formatted:String = "[AqwApi:" + tag + ":" + levelStr + "] " + message;

        if (printToConsole) {
            try {
                #if flash
                flash.Lib.trace(formatted);
                #elseif sys
                Sys.println(formatted);
                #else
                try { untyped console.log(formatted); } catch (_:Dynamic) {}
                #end
            } catch (e:Dynamic) {}
        }

        if (printToFile) {
            try {
                var f = _resolveLogFile();
                if (f != null) {
                    #if flash
                    var fsCls:Dynamic = untyped __global__["flash.filesystem.FileStream"];
                    if (fsCls != null) {
                        var fs:Dynamic = Type.createInstance(fsCls, []);
                        if (fs != null && Reflect.field(fs, "open") != null) {
                            fs.open(f, "append");
                            fs.writeUTFBytes(formatted + "\n");
                            fs.close();
                        }
                    }
                    #end
                }
            } catch (_:Dynamic) {}
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
                #if flash
                var fsCls:Dynamic = untyped __global__["flash.filesystem.FileStream"];
                if (fsCls != null) {
                    var fs:Dynamic = Type.createInstance(fsCls, []);
                    if (fs != null && Reflect.field(fs, "open") != null) {
                        fs.open(f, "write");
                        fs.writeUTFBytes("");
                        fs.close();
                    }
                }
                #end
            }
        } catch (e:Dynamic) {}
    }

    public static function pushChat(type:String, text:String, sender:String = "API"):Void {
        try {
            var apiCls:Dynamic = Type.resolveClass("com.aqwapi.AqwApi");
            if (apiCls != null) {
                var g:Dynamic = Reflect.field(apiCls, "game");
                if (g != null && g.chatF != null && g.chatF.pushMsg != null) {
                    g.chatF.pushMsg(type, text, sender, "", 0);
                }
            }
        } catch (_:Dynamic) {}
    }
}
