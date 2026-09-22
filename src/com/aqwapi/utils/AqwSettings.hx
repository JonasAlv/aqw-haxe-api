package com.aqwapi.utils;

#if flash
import flash.net.SharedObject;
#end

class AqwSettings {
    private static inline var SAVE_KEY:String = "aqw_pocket_settings";

    public static inline var OPTION_SHOW_JOYSTICK_MOUSE:String = "option_show_joystick";
    public static inline var OPTION_SHOW_JOYSTICK_KEYBOARD:String = "option_show_joystick_keyboard";
    public static inline var OPTION_JOYSTICK_DASH:String = "option_joystick_dash";

    public static inline var OPTION_SHOW_SKILL_BAR:String = "option_show_skill_bar";
    public static inline var OPTION_SNAP_TO_GRID:String = "option_snap_to_grid";
    public static inline var OPTION_FPS:String = "option_fps";
    public static inline var OPTION_LANGUAGE:String = "option_language";
    public static inline var OPTION_LOCK_ORIENTATION:String = "option_lock_orientation";
    public static inline var OPTION_DISCORD_RPC:String = "option_discord_rpc";

    public static inline var OPTION_PAGINATION:String = "option_pagination";
    public static inline var OPTION_EQUIPPED_ON_TOP:String = "option_equipped_on_top";

    public static inline var OPTION_SKILL_TOOLTIPS:String = "option_skill_tooltips";
    public static inline var OPTION_DISABLE_CUTSCENES:String = "option_disable_cutscenes";
    public static inline var OPTION_SLOW_WALK:String = "option_slow_walk";

    public static inline var OPTION_PLAYER_ANIMATION_SKILL:String = "option_player_animation_skill";
    public static inline var OPTION_PLAYER_ANIMATION_AURA:String = "option_player_animation_aura";

    public static inline var OPTION_MONSTER_ANIMATION_SKILL:String = "option_monster_animation_skill";
    public static inline var OPTION_MONSTER_ANIMATION_AURA:String = "option_monster_animation_aura";

    public static inline var OPTION_SELF_ANIMATION_SKILL:String = "option_self_animation_skill";
    public static inline var OPTION_SELF_ANIMATION_AURA:String = "option_self_animation_aura";

    public static inline var OPTION_SHORTCUTS:String = "shortcut_buttons";

    public static inline var OPTION_RASTERIZER:String = "option_rasterizer";
    public static inline var OPTION_RASTERIZER_LEVELS:String = "option_rasterizer_levels";

    public static inline var OPTION_ANIMATION_MONSTER:String = "option_animation_monster";
    public static inline var OPTION_ANIMATION_HELM:String = "option_animation_helm";
    public static inline var OPTION_ANIMATION_ARMOR:String = "option_animation_armor";
    public static inline var OPTION_ANIMATION_CAPE:String = "option_animation_cape";
    public static inline var OPTION_ANIMATION_HAIR:String = "option_animation_hair";
    public static inline var OPTION_ANIMATION_PET:String = "option_animation_pet";
    public static inline var OPTION_ANIMATION_MISC:String = "option_animation_misc";
    public static inline var OPTION_ANIMATION_WEAPON:String = "option_animation_weapon";
    public static inline var OPTION_ANIMATION_MAP:String = "option_animation_map";

    public static inline var OPTION_SWF_CACHE:String = "option_swf_cache";
    public static inline var OPTION_FILTER:String = "option_filter";

    public static inline var LAYOUT_JOYSTICK_MOUSE:String = "layout_joystick";
    public static inline var LAYOUT_JOYSTICK_KEYBOARD:String = "layout_joystick_keyboard";
    public static inline var LAYOUT_SKILL_BAR:String = "layout_skill_bar";

    #if flash
    private static var _so:SharedObject;

    private static function get_so():SharedObject {
        if (_so == null) {
            try {
                _so = SharedObject.getLocal(SAVE_KEY);
            } catch (e:Dynamic) {}
        }
        return _so;
    }
    #else
    private static var _memoryStore:Map<String, Dynamic> = new Map<String, Dynamic>();
    #end

    public static function get(key:String, defaultValue:Dynamic = null):Dynamic {
        #if flash
        var s = get_so();
        if (s != null && s.data != null && Reflect.hasField(s.data, key)) {
            return Reflect.field(s.data, key);
        }
        set(key, defaultValue);
        return defaultValue;
        #else
        if (_memoryStore.exists(key)) return _memoryStore.get(key);
        _memoryStore.set(key, defaultValue);
        return defaultValue;
        #end
    }

    public static function set(key:String, value:Dynamic):Void {
        #if flash
        var s = get_so();
        if (s != null && s.data != null) {
            Reflect.setField(s.data, key, value);
            try {
                s.flush();
            } catch (e:Dynamic) {}
        }
        #else
        _memoryStore.set(key, value);
        #end
    }

    public static function delete(key:String):Void {
        #if flash
        var s = get_so();
        if (s != null && s.data != null) {
            Reflect.deleteField(s.data, key);
            try {
                s.flush();
            } catch (e:Dynamic) {}
        }
        #else
        _memoryStore.remove(key);
        #end
    }

    public static function getBool(key:String, defaultValue:Bool = false):Bool {
        var v:Dynamic = get(key, defaultValue);
        if (v == null) return defaultValue;
        if (Std.isOfType(v, Bool)) return (cast v : Bool);
        if (Std.isOfType(v, String)) {
            var s:String = cast v;
            return s == "true" || s == "1";
        }
        if (Std.isOfType(v, Int) || Std.isOfType(v, Float)) {
            return (cast v : Float) != 0;
        }
        return defaultValue;
    }

    public static function setBool(key:String, value:Bool):Void {
        set(key, value);
    }

    public static function getInt(key:String, defaultValue:Int = 0):Int {
        var v = get(key, defaultValue);
        return AqwUtils.parseInt(v, defaultValue);
    }

    public static function setInt(key:String, value:Int):Void {
        set(key, value);
    }

    public static function getString(key:String, defaultValue:String = ""):String {
        var v = get(key, defaultValue);
        return v != null ? Std.string(v) : defaultValue;
    }

    public static function setString(key:String, value:String):Void {
        set(key, value);
    }
}
