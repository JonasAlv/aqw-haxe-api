package com.aqwapi.utils;

class AqwUtils {
    /**
     * Cross-platform check for NaN.
     * Uses IEEE 754 (v != v).
     */
    public static inline function isNaN(v:Float):Bool {
        return v != v;
    }

    /**
     * Cross-platform check for finite numbers.
     */
    public static inline function isFinite(v:Float):Bool {
        return (v == v) && (v > Math.NEGATIVE_INFINITY) && (v < Math.POSITIVE_INFINITY);
    }

    /**
     * Parses an integer safely with a default fallback.
     * Fast-paths numeric types without string allocation.
     */
    public static inline function parseInt(x:Dynamic, def:Int = 0):Int {
        if (x == null) return def;
        if (Std.isOfType(x, Int)) return cast x;
        if (Std.isOfType(x, Float)) {
            var f:Float = cast x;
            return (f != f) ? def : Std.int(f);
        }
        var str:String = StringTools.trim(Std.string(x));
        if (str == "") return def;
        var res = Std.parseInt(str);
        return (res != null && res == res) ? res : def;
    }

    /**
     * Parses a float safely with a default fallback.
     * Fast-paths numeric types without string allocation.
     */
    public static inline function parseFloat(x:Dynamic, def:Float = 0.0):Float {
        if (x == null) return def;
        if (Std.isOfType(x, Float) || Std.isOfType(x, Int)) {
            var f:Float = cast x;
            return (f != f) ? def : f;
        }
        var str:String = StringTools.trim(Std.string(x));
        if (str == "") return def;
        var res = Std.parseFloat(str);
        return (res != res || Math.isNaN(res)) ? def : res;
    }
}
