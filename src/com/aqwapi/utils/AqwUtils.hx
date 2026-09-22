package com.aqwapi.utils;

class AqwUtils {
    /**
     * Parses an integer safely with a default fallback.
     * Fast-paths numeric types without string allocation.
     * Cross-platform: uses native Flash AVM2 opcodes on Flash, stdlib on other targets.
     */
    public static inline function parseInt(x:Dynamic, def:Int = 0):Int {
        if (x == null) return def;
        if (Std.isOfType(x, Int)) return cast x;
        if (Std.isOfType(x, Float)) {
            var f:Float = cast x;
            #if flash
            return untyped __global__["isNaN"](f) ? def : untyped __int__(f);
            #else
            return Math.isNaN(f) ? def : Std.int(f);
            #end
        }
        var str:String = Std.string(x);
        if (str == "") return def;
        #if flash
        var v:Float = untyped __global__["parseInt"](str);
        return untyped __global__["isNaN"](v) ? def : untyped __int__(v);
        #else
        var res = Std.parseInt(str);
        return res != null ? res : def;
        #end
    }

    /**
     * Parses a float safely with a default fallback.
     * Fast-paths numeric types without string allocation.
     * Cross-platform.
     */
    public static inline function parseFloat(x:Dynamic, def:Float = 0.0):Float {
        if (x == null) return def;
        if (Std.isOfType(x, Float) || Std.isOfType(x, Int)) {
            var f:Float = cast x;
            #if flash
            return untyped __global__["isNaN"](f) ? def : f;
            #else
            return Math.isNaN(f) ? def : f;
            #end
        }
        var str:String = Std.string(x);
        if (str == "") return def;
        #if flash
        var v:Float = untyped __global__["parseFloat"](str);
        return untyped __global__["isNaN"](v) ? def : v;
        #else
        var res = Std.parseFloat(str);
        return Math.isNaN(res) ? def : res;
        #end
    }

    /**
     * Cross-platform check for NaN.
     * Safe on Flash AVM2 where Math.isNaN is undefined.
     */
    public static inline function isNaN(v:Float):Bool {
        #if flash
        return untyped __global__["isNaN"](v);
        #else
        return Math.isNaN(v);
        #end
    }
}
