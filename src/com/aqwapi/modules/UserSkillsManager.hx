package com.aqwapi.modules;

import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwStorage;
import com.aqwapi.utils.AqwUtils;
import com.aqwapi.utils.SkillDslParser;

class UserSkillsManager {
    private static var _userSkillsCache:Dynamic = null;

    /**
     * Ensures userSkills.json is created on disk if not already present.
     */
    public static function ensureStorageInitialized():Void {
        AqwStorage.ensureFiles();
    }

    /**
     * Reads userSkills object from userSkills.json.
     */
    public static function readUserSkillsObject():Dynamic {
        if (_userSkillsCache != null) return _userSkillsCache;

        var rawJson:String = null;
        try {
            AqwStorage.ensureFiles();
            rawJson = AqwStorage.readText("userSkills.json");
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

        // Recover from SharedObject ONLY if storage was empty or missing
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
                                AqwStorage.writeText("userSkills.json", haxe.Json.stringify(parsedData, null, "  "));
                            } catch (_:Dynamic) {}
                        }
                    }
                }
            } catch (_:Dynamic) {}
        }

        // Fallback: Default embedded user skills if still completely empty
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
     * Reads userSkills as JSON string.
     */
    public static function readUserSkills():String {
        var obj = readUserSkillsObject();
        try {
            return haxe.Json.stringify(obj, null, "  ");
        } catch (_:Dynamic) {}
        return "{}";
    }

    /**
     * Writes userSkills object to userSkills.json and SharedObject backup.
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
            AqwStorage.ensureFiles();
            ok = AqwStorage.writeText("userSkills.json", jsonStr);
            if (ok) {
                ApiLogger.info("UserSkills", "Saved userSkills.json to applicationStorageDirectory");
            } else {
                ApiLogger.warn("UserSkills", "Failed to save userSkills.json");
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
     * Retains exact in-game class names and mode names.
     */
    public static function isUserMode(className:String, modeName:String):Bool {
        if (className == null || modeName == null) return false;
        var resolvedClass = resolveClassName(className);
        var trimmedClass = StringTools.trim(resolvedClass);
        var trimmedMode = StringTools.trim(modeName);
        if (trimmedClass == "" || trimmedMode == "" || trimmedMode == "[+ New Mode]") return false;

        var data = readUserSkillsObject();
        if (data == null) return false;

        // 1. Exact match
        var classObj:Dynamic = Reflect.field(data, trimmedClass);
        if (classObj == null) {
            // 2. Case-insensitive fallback (no stripping of spaces or characters)
            var lowerClass = trimmedClass.toLowerCase();
            for (cKey in Reflect.fields(data)) {
                if (cKey.toLowerCase() == lowerClass) {
                    classObj = Reflect.field(data, cKey);
                    break;
                }
            }
        }

        if (classObj != null && !Std.isOfType(classObj, Array)) {
            if (Reflect.hasField(classObj, trimmedMode)) return true;
            var lowerMode = trimmedMode.toLowerCase();
            for (mKey in Reflect.fields(classObj)) {
                if (mKey.toLowerCase() == lowerMode) return true;
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
        var trimmedClass = StringTools.trim(resolvedClass);
        if (trimmedClass == "") return [];

        var data = readUserSkillsObject();
        if (data == null) return [];

        var classObj:Dynamic = Reflect.field(data, trimmedClass);
        if (classObj == null) {
            var lowerClass = trimmedClass.toLowerCase();
            for (cKey in Reflect.fields(data)) {
                if (cKey.toLowerCase() == lowerClass) {
                    classObj = Reflect.field(data, cKey);
                    break;
                }
            }
        }

        var modes:Array<String> = [];
        if (classObj != null && !Std.isOfType(classObj, Array)) {
            for (mKey in Reflect.fields(classObj)) {
                if (mKey != null && mKey != "" && modes.indexOf(mKey) == -1) {
                    modes.push(mKey);
                }
            }
        }
        return modes;
    }

    /**
     * Saves or updates a mode in userSkills.json and registers it in memory.
     * Retains exact in-game names with spaces and capital letters.
     * Mode properties are strictly lowercase: mode, timeout, combo.
     */
    public static function saveMode(className:String, modeName:String, skillUseMode:String, timeout:Int, combo:String):Bool {
        if (className == null || className == "" || modeName == null || modeName == "") return false;
        var resolvedClass = resolveClassName(className);
        var trimmedClass = StringTools.trim(resolvedClass);
        var trimmedMode = StringTools.trim(modeName);
        if (trimmedClass == "" || trimmedClass.toLowerCase() == "current") return false;
        if (trimmedMode == "" || trimmedMode == "[+ New Mode]") return false;

        try {
            var data:Dynamic = readUserSkillsObject();
            if (data == null) data = {};

            // Exact key first, then case-insensitive
            var targetClassKey:String = trimmedClass;
            var lowerClass = trimmedClass.toLowerCase();
            for (cKey in Reflect.fields(data)) {
                if (cKey.toLowerCase() == lowerClass) {
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
            Reflect.setField(classObj, trimmedMode, modeEntry);

            writeUserSkillsObject(data);

            // Instant in-memory registration into CombatEngine
            try {
                CombatEngine.registerCustomMode(targetClassKey, trimmedMode, effectiveMode, effectiveTimeout, effectiveCombo);
                if (targetClassKey != trimmedClass) {
                    CombatEngine.registerCustomMode(trimmedClass, trimmedMode, effectiveMode, effectiveTimeout, effectiveCombo);
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
        var trimmedClass = StringTools.trim(resolvedClass);
        var trimmedMode = StringTools.trim(modeName);
        if (trimmedClass == "" || trimmedMode == "") return false;

        var removed:Bool = false;
        var targetClassKey:String = null;

        // 1. Delete from in-memory cache and userSkills.json
        try {
            var data:Dynamic = readUserSkillsObject();
            if (data != null) {
                if (Reflect.hasField(data, trimmedClass)) {
                    targetClassKey = trimmedClass;
                } else {
                    var lowerClass = trimmedClass.toLowerCase();
                    for (cKey in Reflect.fields(data)) {
                        if (cKey.toLowerCase() == lowerClass) {
                            targetClassKey = cKey;
                            break;
                        }
                    }
                }

                if (targetClassKey != null) {
                    var classObj:Dynamic = Reflect.field(data, targetClassKey);
                    if (classObj != null && !Std.isOfType(classObj, Array)) {
                        var targetModeKey:String = null;
                        if (Reflect.hasField(classObj, trimmedMode)) {
                            targetModeKey = trimmedMode;
                        } else {
                            var lowerMode = trimmedMode.toLowerCase();
                            for (mKey in Reflect.fields(classObj)) {
                                if (mKey.toLowerCase() == lowerMode) {
                                    targetModeKey = mKey;
                                    break;
                                }
                            }
                        }

                        if (targetModeKey != null) {
                            Reflect.deleteField(classObj, targetModeKey);
                            removed = true;
                        }

                        if (Reflect.fields(classObj).length == 0) {
                            Reflect.deleteField(data, targetClassKey);
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

        // 2. Also ensure deleted from SharedObject backup
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
                        var soTargetClass:String = targetClassKey != null ? targetClassKey : trimmedClass;
                        var soClassObj:Dynamic = Reflect.field(soObj, soTargetClass);
                        if (soClassObj == null) {
                            var lowerClass = trimmedClass.toLowerCase();
                            for (cKey in Reflect.fields(soObj)) {
                                if (cKey.toLowerCase() == lowerClass) {
                                    soTargetClass = cKey;
                                    soClassObj = Reflect.field(soObj, cKey);
                                    break;
                                }
                            }
                        }
                        if (soClassObj != null && !Std.isOfType(soClassObj, Array)) {
                            var soModeKey:String = null;
                            if (Reflect.hasField(soClassObj, trimmedMode)) {
                                soModeKey = trimmedMode;
                            } else {
                                var lowerMode = trimmedMode.toLowerCase();
                                for (mKey in Reflect.fields(soClassObj)) {
                                    if (mKey.toLowerCase() == lowerMode) {
                                        soModeKey = mKey;
                                        break;
                                    }
                                }
                            }
                            if (soModeKey != null) {
                                Reflect.deleteField(soClassObj, soModeKey);
                                soRemoved = true;
                                removed = true;
                            }
                            if (Reflect.fields(soClassObj).length == 0) {
                                Reflect.deleteField(soObj, soTargetClass);
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

        // 3. Unregister from CombatEngine in-memory registry
        try {
            var ceRemoved1 = CombatEngine.unregisterCustomMode(trimmedClass, trimmedMode);
            var ceRemoved2 = false;
            if (targetClassKey != null && targetClassKey != trimmedClass) {
                ceRemoved2 = CombatEngine.unregisterCustomMode(targetClassKey, trimmedMode);
            }
            if (ceRemoved1 || ceRemoved2) {
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
        var trimmedClass = StringTools.trim(resolvedClass);
        var trimmedMode = StringTools.trim(modeName);

        // 1. Direct check in userSkills.json
        try {
            var data:Dynamic = readUserSkillsObject();
            if (data != null) {
                var classObj:Dynamic = Reflect.field(data, trimmedClass);
                if (classObj == null) {
                    var lowerClass = trimmedClass.toLowerCase();
                    for (cKey in Reflect.fields(data)) {
                        if (cKey.toLowerCase() == lowerClass) {
                            classObj = Reflect.field(data, cKey);
                            break;
                        }
                    }
                }
                if (classObj != null && !Std.isOfType(classObj, Array)) {
                    var mObj:Dynamic = Reflect.field(classObj, trimmedMode);
                    if (mObj == null) {
                        var lowerMode = trimmedMode.toLowerCase();
                        for (mKey in Reflect.fields(classObj)) {
                            if (mKey.toLowerCase() == lowerMode) {
                                mObj = Reflect.field(classObj, mKey);
                                break;
                            }
                        }
                    }
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
        } catch (_:Dynamic) {}

        // 2. Check CombatEngine _skillsData (bundled modes from skills.json)
        var classObj = CombatEngine.findClassConfig(trimmedClass);
        if (classObj != null && !Std.isOfType(classObj, Array)) {
            var modeObj:Dynamic = Reflect.field(classObj, trimmedMode);
            if (modeObj == null) {
                var lowerMode = trimmedMode.toLowerCase();
                for (f in Reflect.fields(classObj)) {
                    if (f.toLowerCase() == lowerMode) {
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
                    isUser: isUserMode(trimmedClass, trimmedMode)
                };
            }
        }

        return null;
    }
}
