package com.aqwapi.utils;

class ApiUtils {
    /**
     * Cross-platform check for NaN without calling Math.isNaN (avoids Flash #1006).
     */
    public static function isNaN(v:Float):Bool {
        return v != v;
    }

    /**
     * Cross-platform check for finite numbers without calling Math.isFinite.
     */
    public static function isFinite(v:Float):Bool {
        return !(v != v) && v != Math.POSITIVE_INFINITY && v != Math.NEGATIVE_INFINITY;
    }

    /**
     * Parses an integer safely with a default fallback.
     */
    public static function parseInt(x:Dynamic, def:Int = 0):Int {
        if (x == null) return def;
        if (Std.isOfType(x, Int)) return cast x;
        if (Std.isOfType(x, Float)) {
            var f:Float = cast x;
            return (f != f) ? def : Std.int(f);
        }
        var str:String = StringTools.trim(Std.string(x));
        if (str == "") return def;
        #if flash
        try {
            var num:Float = untyped __global__["parseInt"](str, 10);
            if (num != num) return def;
            return Std.int(num);
        } catch (_:Dynamic) {}
        #end
        var res:Null<Int> = Std.parseInt(str);
        return (res != null) ? res : def;
    }

    /**
     * Parses a float safely with a default fallback.
     */
    public static function parseFloat(x:Dynamic, def:Float = 0.0):Float {
        if (x == null) return def;
        if (Std.isOfType(x, Float) || Std.isOfType(x, Int)) {
            var f:Float = cast x;
            return (f != f) ? def : f;
        }
        var str:String = StringTools.trim(Std.string(x));
        if (str == "") return def;
        #if flash
        try {
            var num:Float = untyped __global__["parseFloat"](str);
            if (num != num) return def;
            return num;
        } catch (_:Dynamic) {}
        #end
        var res:Float = Std.parseFloat(str);
        return (res != res) ? def : res;
    }
}

typedef AqwUtils = ApiUtils;
