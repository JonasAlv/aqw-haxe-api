package com.aqwapi.modules;

import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwUtils;
import com.aqwapi.utils.SkillDslParser;

class UserSkillsManager {
    private static var _userModesCache:Map<String, Array<String>> = null;

    /**
     * Returns candidate storage locations on Android and Desktop.
     * Includes Android/data/air.com.aqw.pocket/files/userSkills.txt so users can see/edit files directly.
     */
    /**
     * Returns candidate storage locations on Android and Desktop.
     * Includes Android/data/air.com.aqw.pocket/files/userSkills.txt so users can see/edit files directly.
     */
    private static function getStorageFiles():Array<Dynamic> {
        var files:Array<Dynamic> = [];
        var seenPaths:Map<String, Bool> = new Map<String, Bool>();

        var addFile = function(f:Dynamic):Void {
            if (f == null) return;
            try {
                var path:String = null;
                try { path = f.nativePath; } catch (_:Dynamic) {}
                if (path == null || path == "") {
                    try { path = f.url; } catch (_:Dynamic) {}
                }
                if (path != null && path != "") {
                    if (!seenPaths.exists(path)) {
                        seenPaths.set(path, true);
                        files.push(f);
                    }
                } else {
                    files.push(f);
                }
            } catch (_:Dynamic) {
                files.push(f);
            }
        };

        try {
            var FileClass:Dynamic = Type.resolveClass("flash.filesystem.File");
            if (FileClass == null) return files;

            // 1. Android/data/<app-id>/files/userSkills.txt (via documentsDirectory)
            try {
                var docDir:Dynamic = Reflect.getProperty(FileClass, "documentsDirectory");
                if (docDir != null) {
                    addFile(docDir.resolvePath("userSkills.txt"));
                }
            } catch (_:Dynamic) {}

            // 2. Direct external Android/data paths (/storage/emulated/0/Android/data/air.com.aqw.pocket/files)
            try {
                var userDir:Dynamic = Reflect.getProperty(FileClass, "userDirectory");
                if (userDir != null) {
                    addFile(userDir.resolvePath("Android/data/air.com.aqw.pocket/files/userSkills.txt"));
                    addFile(userDir.resolvePath("Android/data/com.aqw.pocket/files/userSkills.txt"));
                }
            } catch (_:Dynamic) {}

            // 3. applicationStorageDirectory (sandboxed local store)
            try {
                var storageDir:Dynamic = Reflect.getProperty(FileClass, "applicationStorageDirectory");
                if (storageDir != null) {
                    addFile(storageDir.resolvePath("userSkills.txt"));
                }
            } catch (_:Dynamic) {}
        } catch (_:Dynamic) {}
        return files;
    }

    /**
     * Ensures userSkills.txt is created on disk if not already present.
     */
    public static function ensureStorageInitialized():Void {
        try {
            var existsOnDisk:Bool = false;
            for (sFile in getStorageFiles()) {
                if (sFile != null && sFile.exists) {
                    existsOnDisk = true;
                    break;
                }
            }
            if (!existsOnDisk) {
                var def = DefaultSkillsData.getDefaultUserSkills();
                if (def != null && def.length > 0) {
                    writeUserSkills(def);
                }
            }
        } catch (_:Dynamic) {}
    }

    /**
     * Reads userSkills content from external/app storage, falling back to SharedObject or embedded template.
     */
    public static function readUserSkills():String {
        try {
            var FileStreamClass:Dynamic = Type.resolveClass("flash.filesystem.FileStream");
            var FileModeClass:Dynamic = Type.resolveClass("flash.filesystem.FileMode");

            // 1. First pass: look for a file that contains actual user-saved combos (not just empty comments)
            if (FileStreamClass != null && FileModeClass != null) {
                var readMode:String = Reflect.getProperty(FileModeClass, "READ");
                for (sFile in getStorageFiles()) {
                    if (sFile != null && sFile.exists) {
                        try {
                            var stream:Dynamic = Type.createInstance(FileStreamClass, []);
                            stream.open(sFile, readMode);
                            var txt:String = stream.readUTFBytes(stream.bytesAvailable);
                            stream.close();
                            if (txt != null && StringTools.trim(txt).length > 0) {
                                var trimmed = StringTools.trim(txt);
                                if (trimmed.indexOf("[") != -1 && trimmed.indexOf("combo") != -1) {
                                    return txt;
                                }
                            }
                        } catch (e:Dynamic) {}
                    }
                }
            }

            // 2. SharedObject backup (if it has user-saved combos)
            try {
                var soClass:Dynamic = Type.resolveClass("flash.net.SharedObject");
                if (soClass != null) {
                    var so = soClass.getLocal("aqw_user_skills");
                    if (so != null && so.data != null && so.data.content != null) {
                        var soTxt:String = Std.string(so.data.content);
                        if (soTxt != null && StringTools.trim(soTxt).length > 0) {
                            var trimmedSO = StringTools.trim(soTxt);
                            if (trimmedSO.indexOf("[") != -1 && trimmedSO.indexOf("combo") != -1) {
                                return soTxt;
                            }
                        }
                    }
                }
            } catch (_:Dynamic) {}

            // 3. Second pass: return any file that exists even if only template
            if (FileStreamClass != null && FileModeClass != null) {
                var readMode:String = Reflect.getProperty(FileModeClass, "READ");
                for (sFile in getStorageFiles()) {
                    if (sFile != null && sFile.exists) {
                        try {
                            var stream:Dynamic = Type.createInstance(FileStreamClass, []);
                            stream.open(sFile, readMode);
                            var txt:String = stream.readUTFBytes(stream.bytesAvailable);
                            stream.close();
                            if (txt != null && StringTools.trim(txt).length > 0) {
                                return txt;
                            }
                        } catch (e:Dynamic) {}
                    }
                }
            }

            // 4. Any content in SharedObject
            try {
                var soClass:Dynamic = Type.resolveClass("flash.net.SharedObject");
                if (soClass != null) {
                    var so = soClass.getLocal("aqw_user_skills");
                    if (so != null && so.data != null && so.data.content != null) {
                        var soTxt:String = Std.string(so.data.content);
                        if (soTxt != null && StringTools.trim(soTxt).length > 0) return soTxt;
                    }
                }
            } catch (_:Dynamic) {}

            // 5. Default bundled fallback
            try {
                var def = DefaultSkillsData.getDefaultUserSkills();
                if (def != null && def.length > 0) return def;
            } catch (_:Dynamic) {}

        } catch (e:Dynamic) {}
        return "";
    }

    /**
     * Writes userSkills to all accessible storage locations (Android/data/..., app storage, SharedObject).
     */
    public static function writeUserSkills(content:String):Bool {
        var wrote:Bool = false;
        try {
            var FileStreamClass:Dynamic = Type.resolveClass("flash.filesystem.FileStream");
            var FileModeClass:Dynamic = Type.resolveClass("flash.filesystem.FileMode");

            if (FileStreamClass != null && FileModeClass != null) {
                var writeMode:String = Reflect.getProperty(FileModeClass, "WRITE");
                for (sFile in getStorageFiles()) {
                    if (sFile == null) continue;
                    try {
                        if (sFile.parent != null && !sFile.parent.exists) {
                            try { sFile.parent.createDirectory(); } catch (_:Dynamic) {}
                        }
                        var stream:Dynamic = Type.createInstance(FileStreamClass, []);
                        stream.open(sFile, writeMode);
                        stream.writeUTFBytes(content);
                        stream.close();
                        wrote = true;
                        var pName:String = null;
                        try { pName = sFile.nativePath; } catch (_:Dynamic) {}
                        if (pName == null || pName == "") {
                            try { pName = sFile.url; } catch (_:Dynamic) {}
                        }
                        ApiLogger.info("UserSkills", "Saved userSkills.txt to: " + (pName != null ? pName : "storage"));
                    } catch (fe:Dynamic) {
                        var pName:String = null;
                        try { pName = sFile.nativePath; } catch (_:Dynamic) {}
                        if (pName == null || pName == "") {
                            try { pName = sFile.url; } catch (_:Dynamic) {}
                        }
                        ApiLogger.warn("UserSkills", "File write failed for " + (pName != null ? pName : "storage") + ": " + fe);
                    }
                }
            }

            // SharedObject backup (guaranteed on all platforms, zero permissions needed)
            try {
                var soClass:Dynamic = Type.resolveClass("flash.net.SharedObject");
                if (soClass != null) {
                    var so = soClass.getLocal("aqw_user_skills");
                    if (so != null && so.data != null) {
                        so.data.content = content;
                        try { so.flush(); } catch (_:Dynamic) {}
                        wrote = true;
                        ApiLogger.info("UserSkills", "Saved userSkills to SharedObject backup!");
                    }
                }
            } catch (soe:Dynamic) {
                ApiLogger.warn("UserSkills", "SharedObject write failed: " + soe);
            }

            _userModesCache = null;
            return wrote;
        } catch (e:Dynamic) {
            ApiLogger.error("UserSkills", "Error writing userSkills.txt: " + e);
            return false;
        }
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
            if (CombatEngine.cleanClassName(s.className) == cleanTargetClass && s.modeName.toLowerCase() == modeName.toLowerCase()) {
                foundSection = s;
                break;
            }
        }

        if (foundSection != null) {
            foundSection.className = className;
            foundSection.modeName = modeName;
            foundSection.mode = skillUseMode;
            foundSection.timeout = timeout;
            foundSection.combo = combo;
        } else {
            sections.push({
                className: className,
                modeName: modeName,
                mode: skillUseMode,
                timeout: timeout,
                combo: combo
            });
        }

        var rebuiltText = rebuildSectionsText(sections);
        writeUserSkills(rebuiltText);

        // Instant in-memory registration into CombatEngine
        CombatEngine.registerCustomMode(className, modeName, skillUseMode, timeout, combo);
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
            if (CombatEngine.cleanClassName(s.className) == cleanTargetClass && s.modeName.toLowerCase() == modeName.toLowerCase()) {
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

        // 1. Try CombatEngine _skillsData
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
                    combo: comboStr,
                    isUser: isUserMode(className, modeName)
                };
            }
        }

        // 2. Direct fallback to UserSkillsManager sections (guarantees retrieval even before CombatEngine reload)
        var raw = readUserSkills();
        var sections = parseRawSections(raw);
        var cleanTarget = CombatEngine.cleanClassName(className);
        for (s in sections) {
            if (CombatEngine.cleanClassName(s.className) == cleanTarget && s.modeName.toLowerCase() == modeName.toLowerCase()) {
                return {
                    skillUseMode: s.mode,
                    timeout: s.timeout,
                    combo: s.combo,
                    isUser: true
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
