package com.aqwapi.modules;

import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwUtils;
import com.aqwapi.utils.SkillDslParser;

class UserSkillsManager {
    private static var _userModesCache:Map<String, Array<String>> = null;

    /**
     * Ensures userSkills.txt is created on disk if not already present.
     */
    public static function ensureStorageInitialized():Void {
        com.aqwapi.utils.AqwStorage.ensureFiles();
    }

    /**
     * Reads userSkills content from the unified data directory (or embedded default template).
     */
    public static function readUserSkills():String {
        try {
            com.aqwapi.utils.AqwStorage.ensureFiles();
            var txt:String = com.aqwapi.utils.AqwStorage.readText("userSkills.txt");
            if (txt != null && StringTools.trim(txt).length > 0) {
                return txt;
            }
        } catch (_:Dynamic) {}

        // SharedObject backup
        try {
            var soClass:Dynamic = null;
            #if flash
            try { soClass = untyped __global__["flash.net.SharedObject"]; } catch (_:Dynamic) {}
            #end
            if (soClass == null) soClass = Type.resolveClass("flash.net.SharedObject");
            if (soClass != null) {
                var so = soClass.getLocal("aqw_user_skills");
                if (so != null && so.data != null && so.data.content != null) {
                    var soTxt:String = Std.string(so.data.content);
                    if (soTxt != null && StringTools.trim(soTxt).length > 0) {
                        try { com.aqwapi.utils.AqwStorage.writeText("userSkills.txt", soTxt); } catch (_:Dynamic) {}
                        return soTxt;
                    }
                }
            }
        } catch (_:Dynamic) {}

        return DefaultSkillsData.getDefaultUserSkills();
    }

    /**
     * Writes userSkills to the unified data directory.
     */
    public static function writeUserSkills(content:String):Bool {
        com.aqwapi.utils.AqwStorage.ensureFiles();
        var ok:Bool = com.aqwapi.utils.AqwStorage.writeText("userSkills.txt", content);
        if (ok) {
            ApiLogger.info("UserSkills", "Saved userSkills.txt to data folder");
        } else {
            ApiLogger.warn("UserSkills", "Failed to save userSkills.txt to data folder");
        }

        // SharedObject backup (guaranteed on all platforms, zero permissions needed)
        try {
            var soClass:Dynamic = null;
            #if flash
            try { soClass = untyped __global__["flash.net.SharedObject"]; } catch (_:Dynamic) {}
            #end
            if (soClass == null) soClass = Type.resolveClass("flash.net.SharedObject");
            if (soClass != null) {
                var so = soClass.getLocal("aqw_user_skills");
                if (so != null && so.data != null) {
                    so.data.content = content;
                    try { so.flush(); } catch (_:Dynamic) {}
                    ok = true;
                }
            }
        } catch (_:Dynamic) {}

        _userModesCache = null;
        return ok;
    }

    /**
     * Checks if a specific mode for a class was user-created in userSkills.txt.
     */
    public static function isUserMode(className:String, modeName:String):Bool {
        ensureCache();
        if (_userModesCache == null || className == null || modeName == null) return false;
        var cleanClass:String = CombatEngine.cleanClassName(className);
        var modes = _userModesCache.get(cleanClass);
        if (modes != null && modes.indexOf(modeName) != -1) return true;
        modes = _userModesCache.get(className);
        if (modes != null && modes.indexOf(modeName) != -1) return true;
        modes = _userModesCache.get(className.toLowerCase());
        return modes != null && modes.indexOf(modeName) != -1;
    }

    /**
     * Gets all user-created modes for a given class.
     */
    public static function getUserModesForClass(className:String):Array<String> {
        ensureCache();
        if (_userModesCache == null || className == null || className == "") return [];
        var cleanClass = CombatEngine.cleanClassName(className);
        var modes = _userModesCache.get(cleanClass);
        if (modes != null && modes.length > 0) return modes.copy();
        modes = _userModesCache.get(className);
        if (modes != null && modes.length > 0) return modes.copy();
        modes = _userModesCache.get(className.toLowerCase());
        if (modes != null && modes.length > 0) return modes.copy();
        return [];
    }

    /**
     * Saves or updates a mode in userSkills.txt and registers it in memory.
     */
    public static function saveMode(className:String, modeName:String, skillUseMode:String, timeout:Int, combo:String):Bool {
        if (className == null || className == "" || modeName == null || modeName == "") return false;

        var raw = readUserSkills();
        var sections = parseRawSections(raw);

        // Normalize section key
        var cleanTargetClass = CombatEngine.cleanClassName(className);
        var foundSection:Dynamic = null;

        for (s in sections) {
            if (s != null && s.className != null && s.modeName != null &&
                CombatEngine.cleanClassName(s.className) == cleanTargetClass &&
                s.modeName.toLowerCase() == modeName.toLowerCase()) {
                foundSection = s;
                break;
            }
        }

        var effectiveMode = (skillUseMode != null && skillUseMode != "") ? skillUseMode : "WaitForCooldown";
        var effectiveTimeout = timeout > 0 ? timeout : 100;
        var effectiveCombo = (combo != null) ? combo : "";

        if (foundSection != null) {
            foundSection.className = className;
            foundSection.modeName = modeName;
            foundSection.mode = effectiveMode;
            foundSection.timeout = effectiveTimeout;
            foundSection.combo = effectiveCombo;
        } else {
            sections.push({
                className: className,
                modeName: modeName,
                mode: effectiveMode,
                timeout: effectiveTimeout,
                combo: effectiveCombo
            });
        }

        var rebuiltText = rebuildSectionsText(sections);
        var writeOk = writeUserSkills(rebuiltText);

        // Instant in-memory registration into CombatEngine
        try {
            CombatEngine.registerCustomMode(className, modeName, effectiveMode, effectiveTimeout, effectiveCombo);
        } catch (ce:Dynamic) {
            ApiLogger.error("UserSkills", "Error registering custom mode: " + ce);
        }

        try {
            ensureCache();
            if (_userModesCache != null) {
                var cleanC = CombatEngine.cleanClassName(className);
                var mList = _userModesCache.get(cleanC);
                if (mList == null) {
                    mList = [];
                    _userModesCache.set(cleanC, mList);
                }
                if (mList.indexOf(modeName) == -1) mList.push(modeName);

                var mListRaw = _userModesCache.get(className);
                if (mListRaw == null) {
                    mListRaw = [];
                    _userModesCache.set(className, mListRaw);
                }
                if (mListRaw.indexOf(modeName) == -1) mListRaw.push(modeName);

                var mListLower = _userModesCache.get(className.toLowerCase());
                if (mListLower == null) {
                    mListLower = [];
                    _userModesCache.set(className.toLowerCase(), mListLower);
                }
                if (mListLower.indexOf(modeName) == -1) mListLower.push(modeName);
            }
        } catch (ue:Dynamic) {
            ApiLogger.error("UserSkills", "Error updating modes cache: " + ue);
        }

        return true;
    }

    /**
     * Deletes a mode from userSkills.txt and unregisters it from memory.
     */
    public static function deleteMode(className:String, modeName:String):Bool {
        if (className == null || className == "" || modeName == null || modeName == "") return false;

        var raw = readUserSkills();
        var sections = parseRawSections(raw);

        var cleanTargetClass = CombatEngine.cleanClassName(className);
        var remaining:Array<Dynamic> = [];
        var removed:Bool = false;

        for (s in sections) {
            if (s != null && s.className != null && s.modeName != null &&
                CombatEngine.cleanClassName(s.className) == cleanTargetClass &&
                s.modeName.toLowerCase() == modeName.toLowerCase()) {
                removed = true;
                continue;
            }
            remaining.push(s);
        }

        if (removed) {
            var rebuiltText = rebuildSectionsText(remaining);
            writeUserSkills(rebuiltText);
            CombatEngine.unregisterCustomMode(className, modeName);
            ensureCache();
            if (_userModesCache != null) {
                var cleanC = CombatEngine.cleanClassName(className);
                var mList = _userModesCache.get(cleanC);
                if (mList != null) mList.remove(modeName);
                var mListRaw = _userModesCache.get(className);
                if (mListRaw != null) mListRaw.remove(modeName);
                var mListLower = _userModesCache.get(className.toLowerCase());
                if (mListLower != null) mListLower.remove(modeName);
            }
            return true;
        }
        return false;
    }

    /**
     * Gets mode details (execution mode, timeout, combo string) for any class mode.
     */
    public static function getModeDetails(className:String, modeName:String):Dynamic {
        if (className == null || className == "" || modeName == null || modeName == "") return null;

        // 1. Direct check in UserSkillsManager sections (guarantees instant retrieval for user modes)
        try {
            var raw = readUserSkills();
            var sections = parseRawSections(raw);
            var cleanTarget = CombatEngine.cleanClassName(className);
            for (s in sections) {
                var cleanS = CombatEngine.cleanClassName(s.className);
                if ((cleanS == cleanTarget || s.className.toLowerCase() == className.toLowerCase()) && 
                    s.modeName != null && s.modeName.toLowerCase() == modeName.toLowerCase()) {
                    var mVal:String = (s.mode != null && s.mode != "") ? s.mode : ((s.execMode != null && s.execMode != "") ? s.execMode : "WaitForCooldown");
                    var toVal:Int = (s.timeout != null && s.timeout > 0) ? s.timeout : 100;
                    var cVal:String = (s.combo != null) ? s.combo : "";
                    return {
                        skillUseMode: mVal,
                        timeout: toVal,
                        combo: cVal,
                        isUser: true
                    };
                }
            }
        } catch (_:Dynamic) {}

        // 2. Check CombatEngine _skillsData (bundled modes)
        var classObj = CombatEngine.findClassConfig(className);
        if (classObj != null) {
            var modeObj:Dynamic = Reflect.field(classObj, modeName);
            if (modeObj == null) {
                for (f in Reflect.fields(classObj)) {
                    if (f.toLowerCase() == modeName.toLowerCase()) {
                        modeObj = Reflect.field(classObj, f);
                        break;
                    }
                }
            }
            if (modeObj != null) {
                var modeType:String = (modeObj.skillUseMode != null) ? Std.string(modeObj.skillUseMode) : "WaitForCooldown";
                var timeout:Int = (modeObj.skillTimeout != null) ? AqwUtils.parseInt(modeObj.skillTimeout, 100) : 100;
                var skills:Array<Dynamic> = (modeObj.skills != null && Std.isOfType(modeObj.skills, Array)) ? cast modeObj.skills : [];
                var comboStr:String = SkillDslParser.formatCombo(skills);
                return {
                    skillUseMode: modeType,
                    timeout: timeout,
                    combo: (comboStr != null) ? comboStr : "",
                    isUser: isUserMode(className, modeName)
                };
            }
        }

        return null;
    }

    private static function ensureCache():Void {
        if (_userModesCache != null) return;
        _userModesCache = new Map<String, Array<String>>();
        var raw = readUserSkills();
        var sections = parseRawSections(raw);
        for (s in sections) {
            if (s == null || s.className == null || s.modeName == null || s.modeName == "") continue;
            var cClean = CombatEngine.cleanClassName(s.className);
            var list = _userModesCache.get(cClean);
            if (list == null) {
                list = [];
                _userModesCache.set(cClean, list);
            }
            if (list.indexOf(s.modeName) == -1) list.push(s.modeName);

            var listRaw = _userModesCache.get(s.className);
            if (listRaw == null) {
                listRaw = [];
                _userModesCache.set(s.className, listRaw);
            }
            if (listRaw.indexOf(s.modeName) == -1) listRaw.push(s.modeName);

            var listLower = _userModesCache.get(s.className.toLowerCase());
            if (listLower == null) {
                listLower = [];
                _userModesCache.set(s.className.toLowerCase(), listLower);
            }
            if (listLower.indexOf(s.modeName) == -1) listLower.push(s.modeName);
        }
    }

    private static function parseRawSections(txt:String):Array<Dynamic> {
        var sections:Array<Dynamic> = [];
        if (txt == null || txt.length == 0) return sections;

        var current:Dynamic = null;
        var lines:Array<String> = txt.split("\n");

        for (rawLine in lines) {
            var line = StringTools.trim(rawLine);
            if (line.length == 0 || StringTools.startsWith(line, "#") || StringTools.startsWith(line, "//")) continue;

            if (StringTools.startsWith(line, "[") && StringTools.endsWith(line, "]")) {
                var inner = line.substring(1, line.length - 1);
                var colonIdx = inner.indexOf(":");
                var cName = "";
                var mName = "Base";
                if (colonIdx != -1) {
                    cName = StringTools.trim(inner.substring(0, colonIdx));
                    mName = StringTools.trim(inner.substring(colonIdx + 1));
                } else {
                    cName = StringTools.trim(inner);
                }

                current = {
                    className: cName,
                    modeName: mName,
                    mode: "WaitForCooldown",
                    timeout: 100,
                    combo: ""
                };
                sections.push(current);
                continue;
            }

            if (current == null) continue;

            var eqIdx = line.indexOf("=");
            if (eqIdx == -1) continue;

            var key = StringTools.trim(line.substring(0, eqIdx)).toLowerCase();
            var val = StringTools.trim(line.substring(eqIdx + 1));

            switch (key) {
                case "mode", "skillusemode":
                    current.mode = (val.toLowerCase() == "useifavailable" || val.toLowerCase() == "priority") ? "UseIfAvailable" : "WaitForCooldown";
                case "timeout", "skilltimeout":
                    current.timeout = AqwUtils.parseInt(val, 100);
                case "combo", "skills", "rotation":
                    current.combo = val;
            }
        }

        return sections;
    }

    private static function rebuildSectionsText(sections:Array<Dynamic>):String {
        var buf:StringBuf = new StringBuf();
        buf.add("# ==============================================================\n");
        buf.add("# User Custom Skills & Rotations (userSkills.txt)\n");
        buf.add("# ==============================================================\n\n");

        for (s in sections) {
            buf.add("[" + s.className + " : " + s.modeName + "]\n");
            buf.add("mode = " + s.mode + "\n");
            buf.add("timeout = " + s.timeout + "\n");
            buf.add("combo = " + s.combo + "\n\n");
        }

        return buf.toString();
    }
}
