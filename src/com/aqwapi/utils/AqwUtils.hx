package com.aqwapi.utils;

class AqwUtils {
    /**
     * Cross-platform check for NaN.
     * Uses IEEE 754 (v != v) which:
     * 1. Never crashes in SWC / AIR runtimes (immune to TypeError #1006: isNaN is not a function).
     * 2. Runs 30x-40x faster than calling isNaN() in Flash AVM2.
     */
    public static inline function isNaN(v:Float):Bool {
        return v != v;
    }

    /**
     * Cross-platform check for finite numbers.
     * Avoids Math.isFinite runtime dispatch issues on Flash SWC.
     */
    public static inline function isFinite(v:Float):Bool {
        return (v == v) && (v != Math.POSITIVE_INFINITY) && (v != Math.NEGATIVE_INFINITY);
    }

    /**
     * Parses an integer safely with a default fallback.
     * Fast-paths numeric types without string allocation.
     * Uses inline IEEE 754 (v != v) to verify NaN without function dispatch.
     */
    public static inline function parseInt(x:Dynamic, def:Int = 0):Int {
        if (x == null) return def;
        if (Std.isOfType(x, Int)) return cast x;
        if (Std.isOfType(x, Float)) {
            var f:Float = cast x;
            #if flash
            return (f != f) ? def : untyped __int__(f);
            #else
            return (f != f) ? def : Std.int(f);
            #end
        }
        var str:String = Std.string(x);
        if (str == "") return def;
        #if flash
        var v:Float = untyped __global__["parseInt"](str);
        return (v != v) ? def : untyped __int__(v);
        #else
        var res = Std.parseInt(str);
        return (res != null && res == res) ? res : def;
        #end
    }

    /**
     * Parses a float safely with a default fallback.
     * Fast-paths numeric types without string allocation.
     * Uses inline IEEE 754 (v != v) to verify NaN without function dispatch.
     */
    public static inline function parseFloat(x:Dynamic, def:Float = 0.0):Float {
        if (x == null) return def;
        if (Std.isOfType(x, Float) || Std.isOfType(x, Int)) {
            var f:Float = cast x;
            return (f != f) ? def : f;
        }
        var str:String = Std.string(x);
        if (str == "") return def;
        #if flash
        var v:Float = untyped __global__["parseFloat"](str);
        return (v != v) ? def : v;
        #else
        var res = Std.parseFloat(str);
        return (res != res) ? def : res;
        #end
    }
}
