package com.aqwapi.utils;

class AqwUtils {
    public static inline function parseInt(x:Dynamic, def:Int = 0):Int {
        if (x == null) return def;
        var str:String = Std.string(x);
        if (str == "") return def;
        var v:Float = untyped __global__["parseInt"](str);
        return untyped __global__["isNaN"](v) ? def : untyped __int__(v);
    }

    public static inline function parseFloat(x:Dynamic, def:Float = 0.0):Float {
        if (x == null) return def;
        var str:String = Std.string(x);
        if (str == "") return def;
        var v:Float = untyped __global__["parseFloat"](str);
        return untyped __global__["isNaN"](v) ? def : v;
    }
}

