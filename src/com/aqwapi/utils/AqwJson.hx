package com.aqwapi.utils;

class AqwJson {
    /**
     * Parse JSON string safely.
     * Tries native Flash JSON.parse first for top performance,
     * with graceful fallback to haxe.format.JsonParser.
     */
    public static function parse(text:String):Dynamic {
        if (text == null || text == "") return null;
        #if flash
        try {
            var jsonCls:Dynamic = untyped __global__["flash.utils.getDefinitionByName"]("JSON");
            if (jsonCls != null && jsonCls.parse != null) {
                return jsonCls.parse(text);
            }
        } catch (_:Dynamic) {}
        #end
        try {
            return haxe.format.JsonParser.parse(text);
        } catch (e:Dynamic) {
            throw e;
        }
    }

    /**
     * Stringify object safely.
     */
    public static function stringify(value:Dynamic):String {
        if (value == null) return "null";
        #if flash
        try {
            var jsonCls:Dynamic = untyped __global__["flash.utils.getDefinitionByName"]("JSON");
            if (jsonCls != null && jsonCls.stringify != null) {
                return jsonCls.stringify(value);
            }
        } catch (_:Dynamic) {}
        #end
        return haxe.format.JsonPrinter.print(value);
    }
}
