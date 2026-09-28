package com.aqwapi.utils;

class ApiStorage {
    private static var _dataDir:Dynamic = null;
    private static var _provisioned:Bool = false;

    public static inline function cleanFileName(name:String):String {
        if (name == null) return "";
        var n = StringTools.replace(name, "\\", "/");
        if (n.indexOf("assets/") == 0) return n.substring(7);
        if (n.indexOf("/") == 0) return n.substring(1);
        return n;
    }

    public static function isDesktop():Bool {
        #if flash
        try {
            var capCls = flash.system.Capabilities;
            if (capCls != null && capCls.os != null) {
                var os = capCls.os.toLowerCase();
                if (os.indexOf("windows") != -1 || os.indexOf("linux") != -1 || os.indexOf("mac") != -1) return true;
            }
        } catch (_:Dynamic) {}
        #end
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
        return null;
    }

    /**
     * Data directory for WRITES (user-editable files that persist):
     * - Desktop/ADL/Wine: File.applicationStorageDirectory (%APPDATA%/<appID>/Local Store/)
     * - Android: File.applicationStorageDirectory (/data/user/0/<appID>/app_storage/)
     *
     * For READS, readText() first tries applicationDirectory/assets/ on desktop (fast native path),
     * then falls back here for user-overridden files.
     */
    public static function getDataDirectory():Dynamic {
        if (_dataDir != null) return _dataDir;
        var FileClass:Dynamic = getFileClass();
        if (FileClass == null) return null;

        try {
            #if flash
            try {
                var direct:Dynamic = untyped FileClass.applicationStorageDirectory;
                if (direct != null) {
                    _dataDir = direct;
                    ApiLogger.info("Storage", "Storage path: " + _dataDir.nativePath);
                    return _dataDir;
                }
            } catch (_:Dynamic) {}
            #end
            var appStorage:Dynamic = getStaticProp(FileClass, "applicationStorageDirectory");
            if (appStorage != null) {
                _dataDir = appStorage;
                ApiLogger.info("Storage", "Storage path: " + _dataDir.nativePath);
                return _dataDir;
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

        // Copy seed user files from applicationDirectory/assets to applicationStorageDirectory if not present
        var FileClass:Dynamic = getFileClass();
        var appDir:Dynamic = (FileClass != null) ? getStaticProp(FileClass, "applicationDirectory") : null;
        if (appDir != null) {
            var seedFiles = ["userSkills.json", "userEnhancements.json"];
            for (fname in seedFiles) {
                try {
                    var target = dir.resolvePath(fname);
                    if (!target.exists) {
                        var src = appDir.resolvePath("assets/" + fname);
                        var content = readFileStream(src);
                        if (content != null && StringTools.trim(content).length > 0) {
                            writeFileStream(target, content);
                            ApiLogger.info("Storage", "Seeded " + fname + " to applicationStorageDirectory");
                        }
                    }
                } catch (e:Dynamic) {
                    ApiLogger.warn("Storage", "Failed to seed " + fname + ": " + e);
                }
            }
        }
    }

    public static function readFileStream(file:Dynamic):String {
        if (file == null) return null;
        try {
            var exists:Bool = false;
            try { exists = (file.exists == true); } catch (_:Dynamic) {}
            if (!exists) return null;

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
            ApiLogger.warn("Storage", "writeFileStream error: " + e);
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

    public static function readText(fileName:String):String {
        var clean = cleanFileName(fileName);
        if (clean == "") return null;

        // 1. On desktop (ADL/Wine): try bundled applicationDirectory/assets/ first — fast native path
        if (isDesktop()) {
            try {
                var FileClass:Dynamic = getFileClass();
                if (FileClass != null) {
                    var appDir:Dynamic = null;
                    #if flash
                    try { appDir = untyped FileClass.applicationDirectory; } catch (_:Dynamic) {}
                    #end
                    if (appDir == null) appDir = getStaticProp(FileClass, "applicationDirectory");
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
        }

        // 2. Try user storage (applicationStorageDirectory) — user-overridden files, or Android primary path
        var dir = getDataDirectory();
        if (dir != null) {
            try {
                var f = dir.resolvePath(clean);
                var txt = readFileStream(f);
                if (txt != null && StringTools.trim(txt).length > 0) {
                    return txt;
                }
            } catch (e:Dynamic) {
                ApiLogger.warn("Storage", "Error reading " + clean + " from storage: " + e);
            }
        }

        // 3. Fallback: bundled app directory for non-desktop platforms
        if (!isDesktop()) {
            try {
                var FileClass:Dynamic = getFileClass();
                if (FileClass != null) {
                    var appDir:Dynamic = null;
                    #if flash
                    try { appDir = untyped FileClass.applicationDirectory; } catch (_:Dynamic) {}
                    #end
                    if (appDir == null) appDir = getStaticProp(FileClass, "applicationDirectory");
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
        }

        return null;
    }

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
                        ApiLogger.info("Storage", "Saved " + clean + " to " + target.nativePath);
                        return true;
                    }
                }
            } catch (e:Dynamic) {
                ApiLogger.warn("Storage", "Error writing " + clean + ": " + e);
            }
        }
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
                ApiLogger.warn("Storage", "Error writing bytes: " + e);
            }
        }
        return false;
    }
}


