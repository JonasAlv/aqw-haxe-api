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
        var res:Float = Std.parseFloat(str);
        return (res != res) ? def : res;
    }

    /**
     * Safely retrieves a field on any dynamic or sealed AS3 object without throwing Error #1069.
     */
    public static function safeField(obj:Dynamic, field:String):Dynamic {
        if (obj == null) return null;
        try {
            if (untyped obj.hasOwnProperty(field)) return untyped obj[field];
        } catch (_:Dynamic) {}
        try {
            var val:Dynamic = Reflect.field(obj, field);
            if (val != null) return val;
        } catch (_:Dynamic) {}
        try {
            if (untyped obj.getChildByName != null) {
                var child:Dynamic = untyped obj.getChildByName(field);
                if (child != null) return child;
            }
        } catch (_:Dynamic) {}
        return null;
    }

    /**
     * Retrieves the visual character MovieClip from AvatarMC (mcChar) or MonsterMC (mc).
     * Guaranteed safe on sealed AS3 classes across Flash Player, AIR, and Ruffle.
     */
    public static function getCharClip(pMC:Dynamic):Dynamic {
        if (pMC == null) return null;
        try {
            if (untyped pMC.hasOwnProperty("mcChar")) return untyped pMC["mcChar"];
        } catch (_:Dynamic) {}
        try {
            if (untyped pMC.hasOwnProperty("mc")) return untyped pMC["mc"];
        } catch (_:Dynamic) {}
        return null;
    }
}


