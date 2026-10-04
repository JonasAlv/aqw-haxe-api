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
    private static var _chatSettingChecked:Bool = false;

    public static function syncChatSetting():Void {
        try {
            var hsCls:Dynamic = Type.resolveClass("util.HelperSetting");
            if (hsCls != null && Reflect.field(hsCls, "getBool") != null) {
                printToChat = hsCls.getBool("api_chat_logging", true);
            }
        } catch (_:Dynamic) {}
    }

    public static function setChatLogging(enabled:Bool):Void {
        printToChat = enabled;
        try {
            var hsCls:Dynamic = Type.resolveClass("util.HelperSetting");
            if (hsCls != null && Reflect.field(hsCls, "setBool") != null) {
                hsCls.setBool("api_chat_logging", enabled);
            }
        } catch (_:Dynamic) {}
    }

    private static function _resolveLogFile():Dynamic {
        if (_logFileInitialized) return _logFile;
        _logFileInitialized = true;

        #if flash
        try {
            var fileCls:Dynamic = untyped __global__["flash.filesystem.File"];
            var fsCls:Dynamic = untyped __global__["flash.filesystem.FileStream"];
            if (fileCls == null || fsCls == null) return null;

            var testCandidate = function(candidate:Dynamic):Dynamic {
                if (candidate == null) return null;
                try {
                    if (candidate.parent != null && !candidate.parent.exists) {
                        try { candidate.parent.createDirectory(); } catch (_:Dynamic) {}
                    }
                    var fs:Dynamic = Type.createInstance(fsCls, []);
                    if (fs != null) {
                        fs.open(candidate, "append");
                        fs.writeUTFBytes("");
                        fs.close();
                        flash.Lib.trace("[ApiLogger] Logging to: " + candidate.nativePath);
                        return candidate;
                    }
                } catch (e:Dynamic) {}
                return null;
            };

            // Priority 1: Current working directory assets/api.log (Desktop ADL, build/, or game execution folder)
            try {
                if (fileCls.currentDirectory != null) {
                    var c = testCandidate(fileCls.currentDirectory.resolvePath("assets/api.log"));
                    if (c != null) { _logFile = c; return _logFile; }
                }
            } catch (_:Dynamic) {}

            // Priority 2: applicationDirectory nativePath assets/api.log (Desktop bypass for app:/ URI restriction)
            try {
                if (fileCls.applicationDirectory != null) {
                    var appNative:String = fileCls.applicationDirectory.nativePath;
                    if (appNative != null && appNative != "") {
                        var fileInst = Type.createInstance(fileCls, [appNative]);
                        if (fileInst != null) {
                            var c = testCandidate(fileInst.resolvePath("assets/api.log"));
                            if (c != null) { _logFile = c; return _logFile; }
                        }
                    }
                }
            } catch (_:Dynamic) {}

            // Priority 3: ApiStorage shared directory (Android Documents/AQWPocket/assets/api.log)
            try {
                var storageCls:Dynamic = Type.resolveClass("com.aqwapi.utils.ApiStorage");
                if (storageCls != null && Reflect.field(storageCls, "getDataDirectory") != null) {
                    var dataDir:Dynamic = storageCls.getDataDirectory();
                    if (dataDir != null) {
                        var c = testCandidate(dataDir.resolvePath("assets/api.log"));
                        if (c != null) { _logFile = c; return _logFile; }
                        var c2 = testCandidate(dataDir.resolvePath("api.log"));
                        if (c2 != null) { _logFile = c2; return _logFile; }
                    }
                }
            } catch (_:Dynamic) {}

            // Priority 4: applicationStorageDirectory assets/api.log or api.log (guaranteed writable)
            try {
                if (fileCls.applicationStorageDirectory != null) {
                    var c = testCandidate(fileCls.applicationStorageDirectory.resolvePath("assets/api.log"));
                    if (c != null) { _logFile = c; return _logFile; }
                    var c2 = testCandidate(fileCls.applicationStorageDirectory.resolvePath("api.log"));
                    if (c2 != null) { _logFile = c2; return _logFile; }
                }
            } catch (_:Dynamic) {}

            // Priority 5: userDirectory/AQWPocket/assets/api.log
            try {
                if (fileCls.userDirectory != null) {
                    var c = testCandidate(fileCls.userDirectory.resolvePath("AQWPocket/assets/api.log"));
                    if (c != null) { _logFile = c; return _logFile; }
                    var c2 = testCandidate(fileCls.userDirectory.resolvePath("api.log"));
                    if (c2 != null) { _logFile = c2; return _logFile; }
                }
            } catch (_:Dynamic) {}
        } catch (_:Dynamic) {}
        #end

        return null;
    }

    public static function getTimestamp(full:Bool = true):String {
        try {
            var d:Dynamic = ApiTime.currentDate();
            var h = StringTools.lpad(Std.string(d.getHours()), "0", 2);
            var m = StringTools.lpad(Std.string(d.getMinutes()), "0", 2);
            var s = StringTools.lpad(Std.string(d.getSeconds()), "0", 2);
            if (!full) return h + ":" + m + ":" + s;

            var y = Std.string(d.getFullYear());
            var mo = StringTools.lpad(Std.string(d.getMonth() + 1), "0", 2);
            var da = StringTools.lpad(Std.string(d.getDate()), "0", 2);
            return y + "-" + mo + "-" + da + " " + h + ":" + m + ":" + s;
        } catch (_:Dynamic) {
            return full ? "0000-00-00 00:00:00" : "00:00:00";
        }
    }

    /**
     * Identical consecutive entries collapse into one line plus a `(repeated N times)` summary.
     *
     * A script calling `log()` in a loop used to emit one file line, one console line and one chat
     * line per iteration. The first occurrence is written through unchanged, so nothing is lost for
     * normal one-shot logging; only the repeats inside `DEDUPE_WINDOW_MS` are swallowed, and they are
     * summarised once the burst goes quiet. The summary flushes lazily on the next distinct entry and
     * on a Flash timer, so a burst that ends as the last thing that happens still gets its count.
     */
    private static inline var DEDUPE_WINDOW_MS:Float = 2000.0;
    private static var _dedupeTag:String = null;
    private static var _dedupeLevel:Int = 0;
    private static var _dedupeMessage:String = null;
    private static var _dedupeCount:Int = 0;
    private static var _dedupeLastAt:Float = -10000;

    #if flash
    private static var _dedupeTimer:flash.utils.Timer = null;

    private static function armDedupeTimer():Void {
        try {
            if (_dedupeTimer == null) {
                _dedupeTimer = new flash.utils.Timer(DEDUPE_WINDOW_MS, 1);
                _dedupeTimer.addEventListener(flash.events.TimerEvent.TIMER, onDedupeTimer);
            }
            _dedupeTimer.stop();
            _dedupeTimer.start();
        } catch (_:Dynamic) {}
    }

    private static function onDedupeTimer(e:Dynamic):Void {
        flushDedupe();
    }
    #end

    private static function flushDedupe():Void {
        if (_dedupeCount <= 1) {
            _dedupeCount = 0;
            _dedupeTag = null;
            _dedupeMessage = null;
            return;
        }
        var n:Int = _dedupeCount;
        var tag:String = _dedupeTag;
        var lvl:Int = _dedupeLevel;
        var msg:String = _dedupeMessage;
        _dedupeCount = 0;
        _dedupeTag = null;
        _dedupeMessage = null;
        if (msg != null) write(tag, lvl, msg + " (repeated " + Std.string(n) + " times)");
    }

    public static function log(tag:String, msgLevel:Int, message:String):Void {
        if (!_chatSettingChecked) {
            _chatSettingChecked = true;
            syncChatSetting();
        }

        if (msgLevel < level) return;

        var now:Float = ApiTime.now();
        if (_dedupeCount > 0 && _dedupeTag == tag && _dedupeLevel == msgLevel && _dedupeMessage == message
            && (now - _dedupeLastAt) < DEDUPE_WINDOW_MS) {
            _dedupeCount++;
            _dedupeLastAt = now;
            #if flash
            armDedupeTimer();
            #end
            return;
        }

        flushDedupe();
        _dedupeTag = tag;
        _dedupeLevel = msgLevel;
        _dedupeMessage = message;
        _dedupeCount = 1;
        _dedupeLastAt = now;
        #if flash
        armDedupeTimer();
        #end

        write(tag, msgLevel, message);
    }

    private static function write(tag:String, msgLevel:Int, message:String):Void {
        var levelStr:String = switch (msgLevel) {
            case LEVEL_DEBUG: "DEBUG";
            case LEVEL_INFO:  "INFO";
            case LEVEL_WARN:  "WARN";
            case LEVEL_ERROR: "ERROR";
            default: "LOG";
        };

        var timeStamp:String = getTimestamp(true);
        var formatted:String = "[" + timeStamp + "] [Api:" + tag + ":" + levelStr + "] " + message;

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
            var chatTime:String = getTimestamp(false);
            var chatFormatted:String = "[" + chatTime + "] [Api:" + tag + ":" + levelStr + "] " + message;
            pushChat(msgLevel >= LEVEL_WARN ? "warning" : "server", chatFormatted);
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

    public static function readLog(maxBytes:Int = 500000):String {
        try {
            var f = _resolveLogFile();
            if (f != null) {
                #if flash
                var fsCls:Dynamic = untyped __global__["flash.filesystem.FileStream"];
                if (fsCls != null) {
                    var fs:Dynamic = Type.createInstance(fsCls, []);
                    if (fs != null && Reflect.field(fs, "open") != null) {
                        fs.open(f, "read");
                        var len:Float = fs.bytesAvailable;
                        if (len <= 0) {
                            fs.close();
                            return "";
                        }
                        var toRead:Int = (len > maxBytes) ? maxBytes : Std.int(len);
                        if (len > maxBytes) {
                            fs.position = len - maxBytes;
                        }
                        var text:String = fs.readUTFBytes(toRead);
                        fs.close();
                        return text;
                    }
                }
                #end
            }
        } catch (e:Dynamic) {}
        return "";
    }

    public static function copyToClipboard():Bool {
        try {
            var content = readLog();
            if (content == null || content.length == 0) {
                return false;
            }
            #if flash
            flash.system.System.setClipboard(content);
            return true;
            #else
            return false;
            #end
        } catch (_:Dynamic) {}
        return false;
    }

    public static function pushChat(type:String, text:String, sender:String = "API"):Void {
        try {
            var apiCls:Dynamic = Type.resolveClass("com.aqwapi.Api");
            if (apiCls != null) {
                var g:Dynamic = Reflect.field(apiCls, "game");
                if (g != null && g.chatF != null && g.chatF.pushMsg != null) {
                    g.chatF.pushMsg(type, text, sender, "", 0);
                }
            }
        } catch (_:Dynamic) {}
    }
}
