package com.aqwapi.modules;

class DefaultSkillsData {
    private static var _skillsCache:String = null;
    private static var _userSkillsCache:String = null;

    public static function getDefaultSkills():String {
        if (_skillsCache != null && _skillsCache.length > 0) return _skillsCache;
        try {
            var embedded = getSkillsConst();
            if (embedded != null && embedded.length > 0) {
                _skillsCache = embedded;
                return _skillsCache;
            }
        } catch (_:Dynamic) {}
        try {
            var res = haxe.Resource.getString("default_skills");
            if (res != null && res.length > 0) {
                _skillsCache = res;
                return _skillsCache;
            }
        } catch (_:Dynamic) {}
        return "";
    }

    public static function getDefaultUserSkills():String {
        if (_userSkillsCache != null && _userSkillsCache.length > 0) return _userSkillsCache;
        try {
            var embedded = getUserSkillsConst();
            if (embedded != null && embedded.length > 0) {
                _userSkillsCache = embedded;
                return _userSkillsCache;
            }
        } catch (_:Dynamic) {}
        try {
            var res = haxe.Resource.getString("default_user_skills");
            if (res != null && res.length > 0) {
                _userSkillsCache = res;
                return _userSkillsCache;
            }
        } catch (_:Dynamic) {}
        return "";
    }

    public static macro function getSkillsConst():haxe.macro.Expr {
        return com.aqwapi.utils.MacroAssets.loadAsset("skills.txt");
    }

    public static macro function getUserSkillsConst():haxe.macro.Expr {
        return com.aqwapi.utils.MacroAssets.loadAsset("userSkills.txt");
    }
}
