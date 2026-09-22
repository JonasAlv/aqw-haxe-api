package com.aqwapi.utils;

#if flash
import flash.Lib;
#end

class AqwTime {
    /**
     * Milliseconds elapsed since the application started.
     * Monotonic, high precision.
     * Zero-cost native opcode on Flash, performance.now() on JS/Electron, haxe.Timer.stamp() elsewhere.
     */
    public static inline function now():Float {
        #if flash
        return Lib.getTimer();
        #elseif js
        return (js.Browser.window != null && js.Browser.window.performance != null)
            ? js.Browser.window.performance.now()
            : Date.now().getTime();
        #else
        return haxe.Timer.stamp() * 1000.0;
        #end
    }

    public static inline function getTimer():Int {
        #if flash
        return Lib.getTimer();
        #else
        return Std.int(now());
        #end
    }

    /**
     * Milliseconds elapsed since a previous timestamp.
     */
    public static inline function since(startTime:Float):Float {
        return now() - startTime;
    }

    /**
     * Delays function execution by ms using pure Haxe Timer.
     */
    public static inline function delay(ms:Int, callback:Void->Void):Void {
        haxe.Timer.delay(callback, ms);
    }

    /**
     * Formats milliseconds into a readable "mm:ss" or "hh:mm:ss" string.
     */
    public static function format(ms:Float):String {
        var totalSec = Std.int(ms / 1000);
        var sec = totalSec % 60;
        var min = Std.int(totalSec / 60) % 60;
        var hrs = Std.int(totalSec / 3600);
        var sSec = (sec < 10 ? "0" : "") + sec;
        var sMin = (min < 10 ? "0" : "") + min;
        if (hrs > 0) {
            var sHrs = (hrs < 10 ? "0" : "") + hrs;
            return sHrs + ":" + sMin + ":" + sSec;
        }
        return sMin + ":" + sSec;
    }
}
