package com.aqwapi.modules;

class DefaultEnhancementsData {
    private static var _cache:String = null;

    public static function getDefaultEnhancements():String {
        if (_cache != null && _cache.length > 0) return _cache;
        try {
            var embedded = getEnhancementsConst();
            if (embedded != null && embedded.length > 0) {
                _cache = embedded;
                return _cache;
            }
        } catch (_:Dynamic) {}
        try {
            var res = haxe.Resource.getString("default_enhancements");
            if (res != null && res.length > 0) {
                _cache = res;
                return _cache;
            }
        } catch (_:Dynamic) {}
        return "{}";
    }

    public static macro function getEnhancementsConst():haxe.macro.Expr {
        return com.aqwapi.utils.MacroAssets.loadAsset("enhancements.json");
    }
}
