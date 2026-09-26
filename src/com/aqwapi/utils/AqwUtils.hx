package com.aqwapi.utils;

class AqwUtils {
    /**
     * Cross-platform check for NaN using standard Haxe Math.isNaN.
     */
    public static function isNaN(v:Float):Bool {
        return Math.isNaN(v);
    }

    /**
     * Cross-platform check for finite numbers using standard Haxe Math.isFinite.
     */
    public static function isFinite(v:Float):Bool {
        return Math.isFinite(v);
    }

    /**
     * Parses an integer safely with a default fallback using standard Haxe Std.parseInt.
     */
    public static function parseInt(x:Dynamic, def:Int = 0):Int {
        if (x == null) return def;
        if (Std.isOfType(x, Int)) return cast x;
        if (Std.isOfType(x, Float)) {
            var f:Float = cast x;
            return Math.isNaN(f) ? def : Std.int(f);
        }
        var str:String = StringTools.trim(Std.string(x));
        if (str == "") return def;
        var res:Null<Int> = Std.parseInt(str);
        return (res != null) ? res : def;
    }

    /**
     * Parses a float safely with a default fallback using standard Haxe Std.parseFloat.
     */
    public static function parseFloat(x:Dynamic, def:Float = 0.0):Float {
        if (x == null) return def;
        if (Std.isOfType(x, Float) || Std.isOfType(x, Int)) {
            var f:Float = cast x;
            return Math.isNaN(f) ? def : f;
        }
        var str:String = StringTools.trim(Std.string(x));
        if (str == "") return def;
        var res:Float = Std.parseFloat(str);
        return Math.isNaN(res) ? def : res;
    }
}
