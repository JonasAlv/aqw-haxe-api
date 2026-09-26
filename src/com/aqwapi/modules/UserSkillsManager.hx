package com.aqwapi.modules;

import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwUtils;
import com.aqwapi.utils.SkillDslParser;

class UserSkillsManager {
    private static var _userSkillsCache:Dynamic = null;

    /**
     * Ensures userSkills.json is created on disk if not already present.
     */
    public static function ensureStorageInitialized():Void {
        com.aqwapi.utils.AqwStorage.ensureFiles();
    }

    /**
     * Reads userSkills object from userSkills.json (with automatic SharedObject recovery & sync).
     */
    public static function readUserSkillsObject():Dynamic {
        if (_userSkillsCache != null) return _userSkillsCache;

        var rawJson:String = null;
        try {
            com.aqwapi.utils.AqwStorage.ensureFiles();
            rawJson = com.aqwapi.utils.AqwStorage.readText("userSkills.json");
        } catch (_:Dynamic) {}

        var parsedData:Dynamic = null;
        if (rawJson != null && StringTools.trim(rawJson).length > 0) {
            try {
                parsedData = haxe.Json.parse(rawJson);
            } catch (e:Dynamic) {
                ApiLogger.error("UserSkills", "JSON parse error: " + e);
            }
        }
        if (parsedData == null || !Reflect.isObject(parsedData) || Std.isOfType(parsedData, Array)) {
            parsedData = {};
        }

        // Recover custom modes from SharedObject ONLY if disk was empty or missing!
        if (Reflect.fields(parsedData).length == 0) {
            try {
                var so:Dynamic = null;
                #if flash
                so = flash.net.SharedObject.getLocal("aqw_user_skills_json");
                #else
                var soClass = Type.resolveClass("flash.net.SharedObject");
                if (soClass != null) so = Reflect.callMethod(soClass, Reflect.field(soClass, "getLocal"), ["aqw_user_skills_json"]);
                #end
                if (so != null && so.data != null && so.data.content != null) {
                    var soTxt:String = Std.string(so.data.content);
                    if (soTxt != null && StringTools.trim(soTxt).length > 0) {
                        var soObj:Dynamic = haxe.Json.parse(soTxt);
                        if (soObj != null && !Std.isOfType(soObj, Array) && Reflect.fields(soObj).length > 0) {
                            parsedData = soObj;
                            try {
                                com.aqwapi.utils.AqwStorage.writeText("userSkills.json", haxe.Json.stringify(parsedData, null, "  "));
                            } catch (_:Dynamic) {}
                        }
                    }
                }
            } catch (_:Dynamic) {}
        }

        // Fallback: Default embedded user skills if completely empty
        if (Reflect.fields(parsedData).length == 0) {
            try {
                var defJson = DefaultSkillsData.getDefaultUserSkills();
                if (defJson != null && StringTools.trim(defJson).length > 0) {
                    parsedData = haxe.Json.parse(defJson);
                }
            } catch (_:Dynamic) {}
        }

        _userSkillsCache = parsedData;
        return _userSkillsCache;
    }

    /**
     * Reads userSkills as JSON string (backwards compatibility).
     */
    public static function readUserSkills():String {
        var obj = readUserSkillsObject();
        try {
            return haxe.Json.stringify(obj, null, "  ");
        } catch (_:Dynamic) {}
        return "{}";
    }

    /**
     * Writes userSkills object to userSkills.json and SharedObject.
     */
    public static function writeUserSkillsObject(data:Dynamic):Bool {
        if (data == null) data = {};
        _userSkillsCache = data;

        var jsonStr:String = "";
        try {
            jsonStr = haxe.Json.stringify(data, null, "  ");
        } catch (je:Dynamic) {
            ApiLogger.error("UserSkills", "JSON stringify error: " + je);
            return false;
        }

        var ok:Bool = false;
        try {
            com.aqwapi.utils.AqwStorage.ensureFiles();
            ok = com.aqwapi.utils.AqwStorage.writeText("userSkills.json", jsonStr);
            if (ok) {
                ApiLogger.info("UserSkills", "Saved userSkills.json to data folder");
            } else {
                ApiLogger.warn("UserSkills", "Failed to save userSkills.json to data folder");
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("UserSkills", "Storage write error: " + e);
        }

        // SharedObject backup
        try {
            var so:Dynamic = null;
            #if flash
            so = flash.net.SharedObject.getLocal("aqw_user_skills_json");
            #else
            var soClass = Type.resolveClass("flash.net.SharedObject");
            if (soClass != null) so = Reflect.callMethod(soClass, Reflect.field(soClass, "getLocal"), ["aqw_user_skills_json"]);
            #end
            if (so != null && so.data != null) {
                so.data.content = jsonStr;
                try { so.flush(); } catch (_:Dynamic) {}
                ok = true;
            }
        } catch (_:Dynamic) {}

        return ok;
    }

    /**
     * Writes userSkills JSON string to storage.
     */
    public static function writeUserSkills(content:String):Bool {
        if (content == null || content == "") return false;
        try {
            var parsed = haxe.Json.parse(content);
            return writeUserSkillsObject(parsed);
        } catch (e:Dynamic) {
            ApiLogger.error("UserSkills", "Invalid JSON in writeUserSkills: " + e);
            return false;
        }
    }

    /**
     * Resolves 'Current' or empty class name to the player's active equipped class.
     */
    public static function resolveClassName(className:String):String {
        if (className == null || className == "") {
            var cur = CombatEngine.getCurrentClassName();
            if (cur != null && cur != "" && cur.toLowerCase() != "current") return cur;
            if (CombatEngine.smartClass != null && CombatEngine.smartClass != "" && CombatEngine.smartClass.toLowerCase() != "current") return CombatEngine.smartClass;
            return className != null ? className : "";
        }
        if (className.toLowerCase() == "current") {
            var cur = CombatEngine.getCurrentClassName();
            if (cur != null && cur != "" && cur.toLowerCase() != "current") return cur;
            if (CombatEngine.smartClass != null && CombatEngine.smartClass != "" && CombatEngine.smartClass.toLowerCase() != "current") return CombatEngine.smartClass;
        }
        return className;
    }

    /**
     * Checks if a specific mode for a class was user-created in userSkills.json.
     */
    public static function isUserMode(className:String, modeName:String):Bool {
        if (className == null || modeName == null) return false;
        var resolvedClass = resolveClassName(className);
        var data = readUserSkillsObject();
        if (data == null) return false;

        var cleanClass:String = CombatEngine.cleanClassName(resolvedClass);
        for (cKey in Reflect.fields(data)) {
            if (cKey.toLowerCase() == resolvedClass.toLowerCase() || cKey.toLowerCase() == className.toLowerCase() || (cleanClass != "" && CombatEngine.cleanClassName(cKey) == cleanClass)) {
                var cObj:Dynamic = Reflect.field(data, cKey);
                if (cObj != null && !Std.isOfType(cObj, Array)) {
                    for (mKey in Reflect.fields(cObj)) {
                        if (mKey.toLowerCase() == modeName.toLowerCase() || StringTools.trim(mKey).toLowerCase() == StringTools.trim(modeName).toLowerCase()) return true;
                    }
                }
            }
        }
        return false;
    }

    /**
     * Gets all user-created modes for a given class.
     */
    public static function getUserModesForClass(className:String):Array<String> {
        if (className == null || className == "") return [];
        var resolvedClass = resolveClassName(className);
        var data = readUserSkillsObject();
        if (data == null) return [];

        var modes:Array<String> = [];
        var cleanClass = CombatEngine.cleanClassName(resolvedClass);

        for (cKey in Reflect.fields(data)) {
            if (cKey.toLowerCase() == resolvedClass.toLowerCase() || cKey.toLowerCase() == className.toLowerCase() || (cleanClass != "" && CombatEngine.cleanClassName(cKey) == cleanClass)) {
                var cObj:Dynamic = Reflect.field(data, cKey);
                if (cObj != null && !Std.isOfType(cObj, Array)) {
                    for (mKey in Reflect.fields(cObj)) {
                        if (mKey != null && mKey != "" && modes.indexOf(mKey) == -1) {
                            modes.push(mKey);
                        }
                    }
                }
            }
        }
        return modes;
    }

    /**
     * Saves or updates a mode in userSkills.json and registers it in memory.
     */
    public static function saveMode(className:String, modeName:String, skillUseMode:String, timeout:Int, combo:String):Bool {
        if (className == null || className == "" || modeName == null || modeName == "") return false;
        var resolvedClass = resolveClassName(className);
        if (resolvedClass == null || resolvedClass == "" || resolvedClass.toLowerCase() == "current") return false;

        try {
            var data:Dynamic = readUserSkillsObject();
            if (data == null) data = {};

            var cleanTargetClass = CombatEngine.cleanClassName(resolvedClass);
            var targetClassKey = resolvedClass;

            for (cKey in Reflect.fields(data)) {
                if (cKey.toLowerCase() == resolvedClass.toLowerCase() || (cleanTargetClass != "" && CombatEngine.cleanClassName(cKey) == cleanTargetClass)) {
                    targetClassKey = cKey;
                    break;
                }
            }

            var classObj:Dynamic = Reflect.field(data, targetClassKey);
            if (classObj == null) {
                classObj = {};
                Reflect.setField(data, targetClassKey, classObj);
            }

            var effectiveMode = (skillUseMode != null && skillUseMode != "") ? skillUseMode : "WaitForCooldown";
            var effectiveTimeout = timeout > 0 ? timeout : 100;
            var effectiveCombo = (combo != null) ? combo : "";

            var modeEntry:Dynamic = {
                mode: effectiveMode,
                timeout: effectiveTimeout,
                combo: effectiveCombo
            };
            Reflect.setField(classObj, modeName, modeEntry);

            writeUserSkillsObject(data);

            // Instant in-memory registration into CombatEngine
            try {
                CombatEngine.registerCustomMode(targetClassKey, modeName, effectiveMode, effectiveTimeout, effectiveCombo);
                if (targetClassKey != resolvedClass) {
                    CombatEngine.registerCustomMode(resolvedClass, modeName, effectiveMode, effectiveTimeout, effectiveCombo);
                }
                if (resolvedClass != className) {
                    CombatEngine.registerCustomMode(className, modeName, effectiveMode, effectiveTimeout, effectiveCombo);
                }
            } catch (ce:Dynamic) {
                ApiLogger.error("UserSkills", "Error registering custom mode: " + ce);
            }

            return true;
        } catch (e:Dynamic) {
            ApiLogger.error("UserSkills", "saveMode exception: " + e);
            return false;
        }
    }

    /**
     * Deletes a mode from userSkills.json, SharedObject, and unregisters it from memory.
     */
    public static function deleteMode(className:String, modeName:String):Bool {
        if (className == null || className == "" || modeName == null || modeName == "") return false;
        var resolvedClass = resolveClassName(className);
        if (resolvedClass == null || resolvedClass == "") resolvedClass = className;
        var cleanTargetClass = CombatEngine.cleanClassName(resolvedClass);
        var cleanOrigClass = CombatEngine.cleanClassName(className);
        var targetModeClean = StringTools.trim(modeName).toLowerCase();

        var removed:Bool = false;

        // 1. Delete from in-memory cache and disk object
        try {
            var data:Dynamic = readUserSkillsObject();
            if (data != null) {
                for (cKey in Reflect.fields(data)) {
                    var cClean = CombatEngine.cleanClassName(cKey);
                    var cLower = cKey.toLowerCase();
                    if (cLower == resolvedClass.toLowerCase() || cLower == className.toLowerCase() ||
                        (cleanTargetClass != "" && cClean == cleanTargetClass) ||
                        (cleanOrigClass != "" && cClean == cleanOrigClass)) {
                        var classObj:Dynamic = Reflect.field(data, cKey);
                        if (classObj != null && !Std.isOfType(classObj, Array)) {
                            for (mKey in Reflect.fields(classObj)) {
                                if (mKey.toLowerCase() == targetModeClean || StringTools.trim(mKey).toLowerCase() == targetModeClean) {
                                    Reflect.deleteField(classObj, mKey);
                                    removed = true;
                                }
                            }
                            if (Reflect.fields(classObj).length == 0) {
                                Reflect.deleteField(data, cKey);
                            }
                        }
                    }
                }
                if (removed) {
                    writeUserSkillsObject(data);
                }
            }
        } catch (e:Dynamic) {
            ApiLogger.error("UserSkills", "deleteMode data removal error: " + e);
        }

        // 2. Also ensure deleted from SharedObject directly (in case disk and SO differed)
        try {
            var so:Dynamic = null;
            #if flash
            so = flash.net.SharedObject.getLocal("aqw_user_skills_json");
            #else
            var soClass = Type.resolveClass("flash.net.SharedObject");
            if (soClass != null) so = Reflect.callMethod(soClass, Reflect.field(soClass, "getLocal"), ["aqw_user_skills_json"]);
            #end
            if (so != null && so.data != null && so.data.content != null) {
                var soTxt:String = Std.string(so.data.content);
                if (soTxt != null && soTxt.length > 0) {
                    var soObj:Dynamic = haxe.Json.parse(soTxt);
                    if (soObj != null && !Std.isOfType(soObj, Array)) {
                        var soRemoved:Bool = false;
                        for (cKey in Reflect.fields(soObj)) {
                            var cClean = CombatEngine.cleanClassName(cKey);
                            var cLower = cKey.toLowerCase();
                            if (cLower == resolvedClass.toLowerCase() || cLower == className.toLowerCase() ||
                                (cleanTargetClass != "" && cClean == cleanTargetClass) ||
                                (cleanOrigClass != "" && cClean == cleanOrigClass)) {
                                var cObj:Dynamic = Reflect.field(soObj, cKey);
                                if (cObj != null && !Std.isOfType(cObj, Array)) {
                                    for (mKey in Reflect.fields(cObj)) {
                                        if (mKey.toLowerCase() == targetModeClean || StringTools.trim(mKey).toLowerCase() == targetModeClean) {
                                            Reflect.deleteField(cObj, mKey);
                                            soRemoved = true;
                                            removed = true;
                                        }
                                    }
                                    if (Reflect.fields(cObj).length == 0) {
                                        Reflect.deleteField(soObj, cKey);
                                    }
                                }
                            }
                        }
                        if (soRemoved) {
                            so.data.content = haxe.Json.stringify(soObj, null, "  ");
                            try { so.flush(); } catch (_:Dynamic) {}
                        }
                    }
                }
            }
        } catch (e2:Dynamic) {
            ApiLogger.error("UserSkills", "deleteMode SharedObject removal error: " + e2);
        }

        // 3. Unregister from CombatEngine in-memory registry across all matching keys
        try {
            var ceRemoved1 = CombatEngine.unregisterCustomMode(resolvedClass, modeName);
            var ceRemoved2 = false;
            if (resolvedClass != className) {
                ceRemoved2 = CombatEngine.unregisterCustomMode(className, modeName);
            }
            var ceRemoved3 = false;
            if (cleanTargetClass != "") {
                ceRemoved3 = CombatEngine.unregisterCustomMode(cleanTargetClass, modeName);
            }
            if (cleanOrigClass != "" && cleanOrigClass != cleanTargetClass) {
                CombatEngine.unregisterCustomMode(cleanOrigClass, modeName);
            }
            if (ceRemoved1 || ceRemoved2 || ceRemoved3) {
                removed = true;
            }
        } catch (_:Dynamic) {}

        return removed;
    }

    /**
     * Gets mode details (execution mode, timeout, combo string) for any class mode.
     */
    public static function getModeDetails(className:String, modeName:String):Dynamic {
        if (className == null || className == "" || modeName == null || modeName == "") return null;

        var resolvedClass = resolveClassName(className);

        // 1. Direct check in userSkills.json
        try {
            var data:Dynamic = readUserSkillsObject();
            if (data != null) {
                var cleanTarget = CombatEngine.cleanClassName(resolvedClass);
                for (cKey in Reflect.fields(data)) {
                    if (cKey.toLowerCase() == resolvedClass.toLowerCase() || cKey.toLowerCase() == className.toLowerCase() || (cleanTarget != "" && CombatEngine.cleanClassName(cKey) == cleanTarget)) {
                        var classObj:Dynamic = Reflect.field(data, cKey);
                        if (classObj != null) {
                            for (mKey in Reflect.fields(classObj)) {
                                if (mKey.toLowerCase() == modeName.toLowerCase() || StringTools.trim(mKey).toLowerCase() == StringTools.trim(modeName).toLowerCase()) {
                                    var mObj:Dynamic = Reflect.field(classObj, mKey);
                                    if (mObj != null) {
                                        var mVal:String = (mObj.mode != null && mObj.mode != "") ? Std.string(mObj.mode) : ((mObj.skillUseMode != null) ? Std.string(mObj.skillUseMode) : "WaitForCooldown");
                                        var toVal:Int = (mObj.timeout != null) ? AqwUtils.parseInt(mObj.timeout, 100) : (mObj.skillTimeout != null ? AqwUtils.parseInt(mObj.skillTimeout, 100) : 100);
                                        var cVal:String = (mObj.combo != null) ? Std.string(mObj.combo) : "";
                                        return {
                                            skillUseMode: mVal,
                                            timeout: toVal,
                                            combo: cVal,
                                            isUser: true
                                        };
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}

        // 2. Check CombatEngine _skillsData (bundled modes from skills.json)
        var classObj = CombatEngine.findClassConfig(resolvedClass);
        if (classObj != null) {
            var modeObj:Dynamic = Reflect.field(classObj, modeName);
            if (modeObj == null) {
                for (f in Reflect.fields(classObj)) {
                    if (f.toLowerCase() == modeName.toLowerCase() || StringTools.trim(f).toLowerCase() == StringTools.trim(modeName).toLowerCase()) {
                        modeObj = Reflect.field(classObj, f);
                        break;
                    }
                }
            }
            if (modeObj != null) {
                var modeType:String = (modeObj.mode != null) ? Std.string(modeObj.mode) : ((modeObj.skillUseMode != null) ? Std.string(modeObj.skillUseMode) : "WaitForCooldown");
                var timeout:Int = (modeObj.timeout != null) ? AqwUtils.parseInt(modeObj.timeout, 100) : ((modeObj.skillTimeout != null) ? AqwUtils.parseInt(modeObj.skillTimeout, 100) : 100);
                var comboStr:String = "";
                if (modeObj.combo != null && Std.string(modeObj.combo) != "") {
                    comboStr = Std.string(modeObj.combo);
                } else if (modeObj.skills != null && Std.isOfType(modeObj.skills, Array)) {
                    comboStr = SkillDslParser.formatCombo(cast modeObj.skills);
                }
                return {
                    skillUseMode: modeType,
                    timeout: timeout,
                    combo: (comboStr != null) ? comboStr : "",
                    isUser: isUserMode(resolvedClass, modeName)
                };
            }
        }

        return null;
    }
}
