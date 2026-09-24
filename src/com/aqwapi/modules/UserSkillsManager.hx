package com.aqwapi.modules;

import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwUtils;
import com.aqwapi.utils.SkillDslParser;

class UserSkillsManager {
    private static var _userModesCache:Map<String, Array<String>> = null;

    /**
     * Reads the raw content of userSkills.txt.
     * Looks in applicationStorageDirectory first; if not present, reads the bundled template in assets.
     */
    public static function readUserSkills():String {
        try {
            var FileClass:Dynamic = Type.resolveClass("flash.filesystem.File");
            var FileStreamClass:Dynamic = Type.resolveClass("flash.filesystem.FileStream");
            var FileModeClass:Dynamic = Type.resolveClass("flash.filesystem.FileMode");

            if (FileClass == null || FileStreamClass == null) return "";

            var storageDir:Dynamic = Reflect.getProperty(FileClass, "applicationStorageDirectory");
            var appDir:Dynamic = Reflect.getProperty(FileClass, "applicationDirectory");
            var readMode:String = (FileModeClass != null) ? Reflect.getProperty(FileModeClass, "READ") : "read";

            var readFile = function(file:Dynamic):String {
                if (file == null || !file.exists) return null;
                try {
                    var stream:Dynamic = Type.createInstance(FileStreamClass, []);
                    stream.open(file, readMode);
                    var txt:String = stream.readUTFBytes(stream.bytesAvailable);
                    stream.close();
                    return txt;
                } catch (e:Dynamic) {
                    return null;
                }
            };

            // 1. Storage dir (writable user file)
            if (storageDir != null) {
                var sFile = storageDir.resolvePath("userSkills.txt");
                var content = readFile(sFile);
                if (content != null) return content;
            }

            // 2. Bundled app assets fallback (default empty template)
            if (appDir != null) {
                var aFile = appDir.resolvePath("assets/userSkills.txt");
                var content = readFile(aFile);
                if (content != null) return content;
                aFile = appDir.resolvePath("userSkills.txt");
                content = readFile(aFile);
                if (content != null) return content;
            }
        } catch (e:Dynamic) {}
        return "";
    }

    /**
     * Writes content to userSkills.txt in applicationStorageDirectory.
     */
    public static function writeUserSkills(content:String):Bool {
        try {
            var FileClass:Dynamic = Type.resolveClass("flash.filesystem.File");
            var FileStreamClass:Dynamic = Type.resolveClass("flash.filesystem.FileStream");
            var FileModeClass:Dynamic = Type.resolveClass("flash.filesystem.FileMode");

            if (FileClass == null || FileStreamClass == null) return false;

            var storageDir:Dynamic = Reflect.getProperty(FileClass, "applicationStorageDirectory");
            var appDir:Dynamic = Reflect.getProperty(FileClass, "applicationDirectory");
            var writeMode:String = (FileModeClass != null) ? Reflect.getProperty(FileModeClass, "WRITE") : "write";

            var wrote:Bool = false;

            // 1. Write to storage directory (always writable on mobile & desktop)
            if (storageDir != null) {
                try {
                    var sFile = storageDir.resolvePath("userSkills.txt");
                    var stream:Dynamic = Type.createInstance(FileStreamClass, []);
                    stream.open(sFile, writeMode);
                    stream.writeUTFBytes(content);
                    stream.close();
                    wrote = true;
                } catch (se:Dynamic) {}
            }

            // 2. Also try appDir/assets if desktop has write access
            if (appDir != null) {
                try {
                    var aFile = appDir.resolvePath("assets/userSkills.txt");
                    var aStream:Dynamic = Type.createInstance(FileStreamClass, []);
                    aStream.open(aFile, writeMode);
                    aStream.writeUTFBytes(content);
                    aStream.close();
                } catch (ae:Dynamic) {}
            }

            // Invalidate cache
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
        if (_userModesCache == null) return false;
        var cleanClass:String = CombatEngine.cleanClassName(className);
        var modes = _userModesCache.get(cleanClass);
        if (modes != null && modes.indexOf(modeName) != -1) return true;
        // Direct match
        modes = _userModesCache.get(className);
        return modes != null && modes.indexOf(modeName) != -1;
    }

    /**
     * Saves or updates a mode in userSkills.txt and reloads CombatEngine.
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
            // Update existing section
            foundSection.className = className;
            foundSection.modeName = modeName;
            foundSection.mode = skillUseMode;
            foundSection.timeout = timeout;
            foundSection.combo = combo;
        } else {
            // Add new section
            sections.push({
                className: className,
                modeName: modeName,
                mode: skillUseMode,
                timeout: timeout,
                combo: combo
            });
        }

        var rebuiltText = rebuildSectionsText(sections);
        var ok = writeUserSkills(rebuiltText);
        if (ok) {
            CombatEngine.reloadSkills(true);
        }
        return ok;
    }

    /**
     * Deletes a mode from userSkills.txt and reloads CombatEngine.
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
            CombatEngine.reloadSkills(true);
            return true;
        }
        return false;
    }

    /**
     * Gets mode details (execution mode, timeout, combo string) for any class mode.
     */
    public static function getModeDetails(className:String, modeName:String):Dynamic {
        if (className == null || className == "" || modeName == null || modeName == "") return null;

        var classObj = CombatEngine.findClassConfig(className);
        if (classObj == null) return null;

        var modeObj:Dynamic = Reflect.field(classObj, modeName);
        if (modeObj == null) {
            for (f in Reflect.fields(classObj)) {
                if (f.toLowerCase() == modeName.toLowerCase()) {
                    modeObj = Reflect.field(classObj, f);
                    break;
                }
            }
        }
        if (modeObj == null) return null;

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
            list.push(s.modeName);
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
