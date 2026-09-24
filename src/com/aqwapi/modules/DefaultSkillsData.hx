package com.aqwapi.modules;

class DefaultSkillsData {
    public static function getDefaultSkills():String {
        try {
            var res = haxe.Resource.getString("default_skills");
            if (res != null && res.length > 0) return res;
        } catch (_:Dynamic) {}
        return "";
    }

    public static function getDefaultUserSkills():String {
        try {
            var res = haxe.Resource.getString("default_user_skills");
            if (res != null && res.length > 0) return res;
        } catch (_:Dynamic) {}
        return "";
    }
}


