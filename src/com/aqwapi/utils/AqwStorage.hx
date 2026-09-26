package com.aqwapi.utils;

class AqwStorage {
    private static var _dataDir:Dynamic = null;
    private static var _provisioned:Bool = false;

    public static inline function cleanFileName(name:String):String {
        if (name == null) return "";
        var n = StringTools.replace(name, "\\", "/");
        if (n.indexOf("assets/") == 0) return n.substring(7);
        if (n.indexOf("/") == 0) return n.substring(1);
        return n;
    }

    public static function isBundledAsset(fileName:String):Bool {
        if (fileName == null) return false;
        var clean = cleanFileName(fileName).toLowerCase();
        return (clean == "skills.json" || clean == "skills.txt" ||
                clean == "quests.json" || clean == "quests.txt");
    }

    public static function readFileStream(file:Dynamic):String {
        if (file == null) return null;
        try {
            var fsCls:Dynamic = getFileStreamClass();
            if (fsCls == null) return null;
            var stream:Dynamic = Type.createInstance(fsCls, []);
            if (stream != null) {
                stream.open(file, "read");
                var txt:String = stream.readUTFBytes(stream.bytesAvailable);
                stream.close();
                return txt;
            }
        } catch (e:Dynamic) {
            ApiLogger.debug("Storage", "readFileStream error: " + e);
        }
        return null;
    }

    public static function writeFileStream(file:Dynamic, content:String):Bool {
        if (file == null || content == null) return false;
        try {
            var fsCls:Dynamic = getFileStreamClass();
            if (fsCls == null) return false;
            var stream:Dynamic = Type.createInstance(fsCls, []);
            if (stream != null) {
                stream.open(file, "write");
                stream.writeUTFBytes(content);
                stream.close();
                return true;
            }
        } catch (e:Dynamic) {
            ApiLogger.debug("Storage", "writeFileStream error: " + e);
        }
        return false;
    }

    public static function writeBytesStream(file:Dynamic, bytes:Dynamic):Bool {
        if (file == null || bytes == null) return false;
        try {
            var fsCls:Dynamic = getFileStreamClass();
            if (fsCls == null) return false;
            var stream:Dynamic = Type.createInstance(fsCls, []);
            if (stream != null) {
                stream.open(file, "write");
                stream.writeBytes(bytes);
                stream.close();
                return true;
            }
        } catch (e:Dynamic) {
            ApiLogger.debug("Storage", "writeBytesStream error: " + e);
        }
        return false;
    }

    public static function getFileClass():Dynamic {
        var cls:Dynamic = null;
        #if flash
        try { cls = untyped __global__["flash.filesystem.File"]; } catch (_:Dynamic) {}
        if (cls == null) {
            try {
                var appDom = flash.system.ApplicationDomain.currentDomain;
                if (appDom != null && appDom.hasDefinition("flash.filesystem.File")) {
                    cls = appDom.getDefinition("flash.filesystem.File");
                }
            } catch (_:Dynamic) {}
        }
        #end
        if (cls == null) {
            try { cls = Type.resolveClass("flash.filesystem.File"); } catch (_:Dynamic) {}
        }
        return cls;
    }

    public static function getFileStreamClass():Dynamic {
        var cls:Dynamic = null;
        #if flash
        try { cls = untyped __global__["flash.filesystem.FileStream"]; } catch (_:Dynamic) {}
        if (cls == null) {
            try {
                var appDom = flash.system.ApplicationDomain.currentDomain;
                if (appDom != null && appDom.hasDefinition("flash.filesystem.FileStream")) {
                    cls = appDom.getDefinition("flash.filesystem.FileStream");
                }
            } catch (_:Dynamic) {}
        }
        #end
        if (cls == null) {
            try { cls = Type.resolveClass("flash.filesystem.FileStream"); } catch (_:Dynamic) {}
        }
        return cls;
    }

    public static function getByteArrayClass():Dynamic {
        var cls:Dynamic = null;
        #if flash
        try { cls = untyped __global__["flash.utils.ByteArray"]; } catch (_:Dynamic) {}
        #end
        if (cls == null) {
            try { cls = Type.resolveClass("flash.utils.ByteArray"); } catch (_:Dynamic) {}
        }
        return cls;
    }

    public static function getStaticProp(cls:Dynamic, prop:String):Dynamic {
        if (cls == null) return null;
        #if flash
        try {
            var val:Dynamic = untyped cls[prop];
            if (val != null) return val;
        } catch (_:Dynamic) {}
        #end
        try {
            var val:Dynamic = Reflect.field(cls, prop);
            if (val != null) return val;
        } catch (_:Dynamic) {}
        try {
            var val:Dynamic = Reflect.getProperty(cls, prop);
            if (val != null) return val;
        } catch (_:Dynamic) {}
        return null;
    }

    /**
     * Default writable storage directory (app-storage:/).
     * Guaranteed writable across Android and Desktop.
     */
    public static function getDataDirectory():Dynamic {
        if (_dataDir != null) return _dataDir;
        try {
            var FileClass:Dynamic = getFileClass();
            if (FileClass != null) {
                #if flash
                try {
                    var direct:Dynamic = untyped FileClass.applicationStorageDirectory;
                    if (direct != null) {
                        _dataDir = direct;
                        return _dataDir;
                    }
                } catch (_:Dynamic) {}
                #end
                var appStorage:Dynamic = getStaticProp(FileClass, "applicationStorageDirectory");
                if (appStorage != null) {
                    _dataDir = appStorage;
                    return _dataDir;
                }
            }
        } catch (e:Dynamic) {
            ApiLogger.error("Storage", "Failed to resolve applicationStorageDirectory: " + e);
        }
        return null;
    }

    public static function getFile(fileName:String):Dynamic {
        var clean = cleanFileName(fileName);
        var dir = getDataDirectory();
        if (dir == null) return null;
        try {
            return dir.resolvePath(clean);
        } catch (_:Dynamic) {}
        return null;
    }

    public static function ensureFiles():Void {
        if (_provisioned) return;
        _provisioned = true;

        var dir = getDataDirectory();
        if (dir == null) return;
        try {
            if (!dir.exists) {
                dir.createDirectory();
            }
        } catch (_:Dynamic) {}

        // Ensure userSkills.json exists in applicationStorageDirectory
        try {
            var userFile = dir.resolvePath("userSkills.json");
            var exists = false;
            try { exists = (userFile != null && userFile.exists); } catch (_:Dynamic) {}
            if (!exists) {
                var bundled = readBundledAsset("userSkills.json");
                if (bundled != null && StringTools.trim(bundled).length > 0) {
                    writeFileStream(userFile, bundled);
                    ApiLogger.info("Storage", "Provisioned userSkills.json from bundled asset");
                }
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("Storage", "Failed to ensure userSkills.json: " + e);
        }
    }

    public static function getDefaultSkillsResource():String {
        try {
            var def = com.aqwapi.modules.DefaultSkillsData.getDefaultSkills();
            if (def != null && def.length > 0) return def;
        } catch (_:Dynamic) {}
        try {
            var res = haxe.Resource.getString("default_skills");
            if (res != null && res.length > 0) return res;
        } catch (_:Dynamic) {}
        return "";
    }

    public static function getDefaultUserSkillsResource():String {
        try {
            var def = com.aqwapi.modules.DefaultSkillsData.getDefaultUserSkills();
            if (def != null && def.length > 0) return def;
        } catch (_:Dynamic) {}
        try {
            var res = haxe.Resource.getString("default_user_skills");
            if (res != null && res.length > 0) return res;
        } catch (_:Dynamic) {}
        return "";
    }

    /**
     * Reads a bundled read-only asset from File.applicationDirectory (app:/assets/<fileName>).
     */
    public static function readBundledAsset(fileName:String):String {
        var clean = cleanFileName(fileName);
        try {
            var FileClass:Dynamic = getFileClass();
            if (FileClass != null) {
                var appDir:Dynamic = null;
                #if flash
                try {
                    appDir = untyped FileClass.applicationDirectory;
                } catch (_:Dynamic) {}
                #end
                if (appDir == null) {
                    appDir = getStaticProp(FileClass, "applicationDirectory");
                }
                if (appDir != null) {
                    var f1 = appDir.resolvePath("assets/" + clean);
                    var txt1 = readFileStream(f1);
                    if (txt1 != null && StringTools.trim(txt1).length > 0) return txt1;

                    var f2 = appDir.resolvePath(clean);
                    var txt2 = readFileStream(f2);
                    if (txt2 != null && StringTools.trim(txt2).length > 0) return txt2;
                }
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("Storage", "Error reading bundled asset " + clean + ": " + e);
        }

        if (clean == "skills.json" || clean == "skills.txt") {
            var def = getDefaultSkillsResource();
            if (def != null && StringTools.trim(def).length > 0) return def;
        } else if (clean == "userSkills.json" || clean == "userSkills.txt") {
            var defU = getDefaultUserSkillsResource();
            if (defU != null && StringTools.trim(defU).length > 0) return defU;
        }

        return null;
    }

    /**
     * Reads text for an asset.
     * - Bundled assets (skills.json, quests.json): File.applicationDirectory.resolvePath("assets/" + fileName)
     * - User writable assets (userSkills.json): File.applicationStorageDirectory.resolvePath("userSkills.json")
     */
    public static function readText(fileName:String):String {
        var clean = cleanFileName(fileName);
        if (clean == "") return null;

        if (isBundledAsset(clean)) {
            return readBundledAsset(clean);
        }

        // User data: applicationStorageDirectory
        var dir = getDataDirectory();
        if (dir != null) {
            try {
                var f = dir.resolvePath(clean);
                var txt = readFileStream(f);
                if (txt != null && StringTools.trim(txt).length > 0) return txt;
            } catch (e:Dynamic) {
                ApiLogger.warn("Storage", "Error reading user asset " + clean + ": " + e);
            }
        }

        // First run fallback: read bundled seed asset and write to user storage
        var bundled = readBundledAsset(clean);
        if (bundled != null && StringTools.trim(bundled).length > 0) {
            writeText(clean, bundled);
            return bundled;
        }

        return null;
    }

    /**
     * Writes text to File.applicationStorageDirectory.
     */
    public static function writeText(fileName:String, content:String):Bool {
        var clean = cleanFileName(fileName);
        if (content == null) return false;

        var dir = getDataDirectory();
        if (dir != null) {
            try {
                var target = dir.resolvePath(clean);
                if (target != null) {
                    if (target.parent != null && !target.parent.exists) {
                        try { target.parent.createDirectory(); } catch (_:Dynamic) {}
                    }
                    if (writeFileStream(target, content)) {
                        ApiLogger.info("Storage", "Saved " + clean + " to applicationStorageDirectory");
                        return true;
                    }
                }
            } catch (e:Dynamic) {
                ApiLogger.warn("Storage", "Error writing to storage: " + e);
            }
        }

        ApiLogger.error("Storage", "writeText failed for " + clean);
        return false;
    }

    public static function writeBytes(fileName:String, bytes:Dynamic):Bool {
        var clean = cleanFileName(fileName);
        if (bytes == null) return false;

        var dir = getDataDirectory();
        if (dir != null) {
            try {
                var target = dir.resolvePath(clean);
                if (target != null) {
                    if (target.parent != null && !target.parent.exists) {
                        try { target.parent.createDirectory(); } catch (_:Dynamic) {}
                    }
                    if (writeBytesStream(target, bytes)) {
                        return true;
                    }
                }
            } catch (e:Dynamic) {
                ApiLogger.warn("Storage", "Error writing bytes to storage: " + e);
            }
        }
        return false;
    }
}
