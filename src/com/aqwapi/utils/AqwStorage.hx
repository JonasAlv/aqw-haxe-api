package com.aqwapi.utils;

class AqwStorage {
    private static var _dataDir:Dynamic = null;
    private static var _provisioned:Bool = false;

    public static inline function cleanFileName(name:String):String {
        if (name == null) return "";
        if (name.indexOf("assets/") == 0) return name.substring(7);
        if (name.indexOf("/") == 0) return name.substring(1);
        return name;
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
     * Resolves the primary writable data directory:
     * - Priority 1: File.applicationStorageDirectory (guaranteed writable on both Android and Desktop,
     *   requires zero Android permissions, avoids Android 10+ Error #3001 scoped storage denial).
     * - Priority 2: File.documentsDirectory (fallback if applicationStorageDirectory is unavailable).
     */
    public static function getDataDirectory():Dynamic {
        if (_dataDir != null) return _dataDir;

        try {
            var FileClass:Dynamic = getFileClass();
            if (FileClass == null) {
                ApiLogger.error("Storage", "flash.filesystem.File class is not available");
                return null;
            }

            // 1. Primary: use applicationStorageDirectory (guaranteed writable across Android, Windows, macOS)
            try {
                var appStorage:Dynamic = getStaticProp(FileClass, "applicationStorageDirectory");
                if (appStorage != null) {
                    _dataDir = appStorage;
                    var p:String = "";
                    try { p = appStorage.nativePath; } catch (_:Dynamic) {}
                    ApiLogger.info("Storage", "Using applicationStorageDirectory: " + p);
                    return _dataDir;
                }
            } catch (e:Dynamic) {
                ApiLogger.debug("Storage", "applicationStorageDirectory access failed: " + e);
            }

            // 2. Fallback: documentsDirectory
            try {
                var docDir:Dynamic = getStaticProp(FileClass, "documentsDirectory");
                if (docDir != null) {
                    _dataDir = docDir;
                    var p:String = "";
                    try { p = docDir.nativePath; } catch (_:Dynamic) {}
                    ApiLogger.info("Storage", "Using documentsDirectory: " + p);
                    return _dataDir;
                }
            } catch (e:Dynamic) {
                ApiLogger.debug("Storage", "documentsDirectory access failed: " + e);
            }
        } catch (e:Dynamic) {
            ApiLogger.error("Storage", "Failed to resolve data directory: " + e);
        }

        return null;
    }

    public static function resolvePackagedFile(fileName:String):Dynamic {
        var clean = cleanFileName(fileName);
        try {
            var FileClass:Dynamic = getFileClass();
            if (FileClass == null) return null;
            var appDir:Dynamic = getStaticProp(FileClass, "applicationDirectory");
            if (appDir == null) return null;

            var p1 = appDir.resolvePath("assets/" + clean);
            if (p1 != null && p1.exists) return p1;

            var p2 = appDir.resolvePath(clean);
            if (p2 != null && p2.exists) return p2;

            var p3 = appDir.resolvePath("loader/assets/" + clean);
            if (p3 != null && p3.exists) return p3;
        } catch (_:Dynamic) {}
        return null;
    }

    public static function getFile(fileName:String):Dynamic {
        var clean = cleanFileName(fileName);
        var dir = getDataDirectory();
        if (dir == null) return null;
        try {
            var f = dir.resolvePath(clean);
            if (f != null && f.exists) return f;

            var sub = dir.resolvePath("assets/" + clean);
            if (sub != null && sub.exists) return sub;

            return f;
        } catch (_:Dynamic) {}
        return null;
    }

    /**
     * Auto-provisions quests.json, skills.txt, userSkills.txt to data directory if missing.
     */
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

        // 1. quests.json
        ensureFile(dir, "quests.json", function():Dynamic {
            var pkg = resolvePackagedFile("quests.json");
            return readBinaryFile(pkg);
        });

        // 2. skills.json
        ensureFile(dir, "skills.json", function():Dynamic {
            var pkg = resolvePackagedFile("skills.json");
            var bytes = readBinaryFile(pkg);
            if (bytes != null) return bytes;
            var def = getDefaultSkillsResource();
            return (def != null && def.length > 0) ? def : null;
        });

        // 3. userSkills.json
        ensureFile(dir, "userSkills.json", function():Dynamic {
            var pkg = resolvePackagedFile("userSkills.json");
            var bytes = readBinaryFile(pkg);
            if (bytes != null) return bytes;
            var def = getDefaultUserSkillsResource();
            return (def != null && def.length > 0) ? def : null;
        });
    }

    private static function getDefaultSkillsResource():String {
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

    private static function getDefaultUserSkillsResource():String {
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

    private static function ensureFile(dir:Dynamic, fileName:String, getSourceData:Void->Dynamic):Void {
        try {
            var target = dir.resolvePath(fileName);
            if (target != null && target.exists) {
                if (fileName == "userSkills.json" || fileName == "userSkills.txt") {
                    var size:Float = 0;
                    try { size = target.size; } catch (_:Dynamic) {}
                    if (size > 0) return;
                } else {
                    var pkg = resolvePackagedFile(fileName);
                    if (pkg != null && pkg.exists) {
                        var pkgSize:Float = 0;
                        var targetSize:Float = 0;
                        try { pkgSize = pkg.size; } catch (_:Dynamic) {}
                        try { targetSize = target.size; } catch (_:Dynamic) {}
                        if (pkgSize > 0 && targetSize == pkgSize) return;
                    } else {
                        var size:Float = 0;
                        try { size = target.size; } catch (_:Dynamic) {}
                        if (size > 0) return;
                    }
                }
            }

            var data = getSourceData();
            if (data == null) return;

            if (Std.isOfType(data, String)) {
                writeText(fileName, cast(data, String));
                ApiLogger.info("Storage", "Provisioned " + fileName + " in data folder");
            } else {
                writeBytes(fileName, data);
                ApiLogger.info("Storage", "Provisioned " + fileName + " in data folder");
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("Storage", "Failed to provision " + fileName + ": " + e);
        }
    }

    public static function readText(fileName:String):String {
        var clean = cleanFileName(fileName);
        try {
            var f = getFile(clean);
            if (f != null && f.exists) {
                var fsCls:Dynamic = getFileStreamClass();
                if (fsCls != null) {
                    var stream:Dynamic = Type.createInstance(fsCls, []);
                    if (stream != null && Reflect.field(stream, "open") != null) {
                        stream.open(f, "read");
                        var txt:String = stream.readUTFBytes(stream.bytesAvailable);
                        stream.close();
                        if (txt != null && txt.length > 0) return txt;
                    }
                }
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("Storage", "Error reading " + clean + ": " + e);
        }

        // Fallback 1: read directly from packaged app asset
        try {
            var pkg = resolvePackagedFile(clean);
            if (pkg != null && pkg.exists) {
                var fsCls:Dynamic = getFileStreamClass();
                if (fsCls != null) {
                    var stream:Dynamic = Type.createInstance(fsCls, []);
                    if (stream != null && Reflect.field(stream, "open") != null) {
                        stream.open(pkg, "read");
                        var txt:String = stream.readUTFBytes(stream.bytesAvailable);
                        stream.close();
                        if (txt != null && txt.length > 0) return txt;
                    }
                }
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("Storage", "Error reading packaged " + clean + ": " + e);
        }

        // Fallback 2: read from documentsDirectory / applicationStorageDirectory if written there
        try {
            var FileClass:Dynamic = getFileClass();
            var fallbackDir = getStaticProp(FileClass, "documentsDirectory");
            if (fallbackDir == null || fallbackDir == getDataDirectory()) fallbackDir = getStaticProp(FileClass, "applicationStorageDirectory");
            if (fallbackDir != null && fallbackDir != getDataDirectory()) {
                var f = fallbackDir.resolvePath(clean);
                if (f != null && f.exists) {
                    var fsCls:Dynamic = getFileStreamClass();
                    if (fsCls != null) {
                        var stream:Dynamic = Type.createInstance(fsCls, []);
                        if (stream != null && Reflect.field(stream, "open") != null) {
                            stream.open(f, "read");
                            var txt:String = stream.readUTFBytes(stream.bytesAvailable);
                            stream.close();
                            if (txt != null && txt.length > 0) return txt;
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}

        return null;
    }

    public static function writeText(fileName:String, content:String):Bool {
        var clean = cleanFileName(fileName);
        var dir = getDataDirectory();
        if (dir == null || content == null) return false;
        try {
            var fsCls:Dynamic = getFileStreamClass();
            if (fsCls != null) {
                var target = dir.resolvePath(clean);
                if (target != null) {
                    if (target.parent != null && !target.parent.exists) {
                        try { target.parent.createDirectory(); } catch (_:Dynamic) {}
                    }
                    var stream:Dynamic = Type.createInstance(fsCls, []);
                    if (stream != null && Reflect.field(stream, "open") != null) {
                        stream.open(target, "write");
                        stream.writeUTFBytes(content);
                        stream.close();
                        return true;
                    }
                }
            }
        } catch (e:Dynamic) {
            ApiLogger.debug("Storage", "Primary writeText failed for " + clean + ": " + e);
        }

        // Fallback: if writing to primary data directory failed, try documentsDirectory or applicationStorageDirectory
        try {
            var FileClass:Dynamic = getFileClass();
            var fallbackDir = getStaticProp(FileClass, "documentsDirectory");
            if (fallbackDir == null || fallbackDir == dir) fallbackDir = getStaticProp(FileClass, "applicationStorageDirectory");
            if (fallbackDir != null && fallbackDir != dir) {
                var fsCls:Dynamic = getFileStreamClass();
                if (fsCls != null) {
                    var target = fallbackDir.resolvePath(clean);
                    if (target != null) {
                        if (target.parent != null && !target.parent.exists) {
                            try { target.parent.createDirectory(); } catch (_:Dynamic) {}
                        }
                        var stream:Dynamic = Type.createInstance(fsCls, []);
                        if (stream != null && Reflect.field(stream, "open") != null) {
                            stream.open(target, "write");
                            stream.writeUTFBytes(content);
                            stream.close();
                            ApiLogger.info("Storage", "Saved " + clean + " to fallback storage folder");
                            return true;
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}

        ApiLogger.error("Storage", "writeText failed for " + clean);
        return false;
    }

    public static function writeBytes(fileName:String, bytes:Dynamic):Bool {
        var clean = cleanFileName(fileName);
        var dir = getDataDirectory();
        if (dir == null || bytes == null) return false;
        try {
            var fsCls:Dynamic = getFileStreamClass();
            if (fsCls != null) {
                var target = dir.resolvePath(clean);
                if (target != null) {
                    if (target.parent != null && !target.parent.exists) {
                        try { target.parent.createDirectory(); } catch (_:Dynamic) {}
                    }
                    var stream:Dynamic = Type.createInstance(fsCls, []);
                    if (stream != null && Reflect.field(stream, "open") != null) {
                        stream.open(target, "write");
                        stream.writeBytes(bytes);
                        stream.close();
                        return true;
                    }
                }
            }
        } catch (e:Dynamic) {
            ApiLogger.debug("Storage", "Primary writeBytes failed for " + clean + ": " + e);
        }

        // Fallback: try alternate directory
        try {
            var FileClass:Dynamic = getFileClass();
            var fallbackDir = getStaticProp(FileClass, "documentsDirectory");
            if (fallbackDir == null || fallbackDir == dir) fallbackDir = getStaticProp(FileClass, "applicationStorageDirectory");
            if (fallbackDir != null && fallbackDir != dir) {
                var fsCls:Dynamic = getFileStreamClass();
                if (fsCls != null) {
                    var target = fallbackDir.resolvePath(clean);
                    if (target != null) {
                        if (target.parent != null && !target.parent.exists) {
                            try { target.parent.createDirectory(); } catch (_:Dynamic) {}
                        }
                        var stream:Dynamic = Type.createInstance(fsCls, []);
                        if (stream != null && Reflect.field(stream, "open") != null) {
                            stream.open(target, "write");
                            stream.writeBytes(bytes);
                            stream.close();
                            ApiLogger.info("Storage", "Saved " + clean + " to fallback storage folder");
                            return true;
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}

        ApiLogger.error("Storage", "writeBytes failed for " + clean);
        return false;
    }

    private static function readBinaryFile(file:Dynamic):Dynamic {
        if (file == null || !file.exists) return null;
        try {
            var fsCls:Dynamic = getFileStreamClass();
            if (fsCls == null) return null;
            var stream:Dynamic = Type.createInstance(fsCls, []);
            if (stream != null && Reflect.field(stream, "open") != null) {
                stream.open(file, "read");
                var baCls:Dynamic = getByteArrayClass();
                var bytes:Dynamic = (baCls != null) ? Type.createInstance(baCls, []) : null;
                if (bytes != null) {
                    stream.readBytes(bytes);
                }
                stream.close();
                return bytes;
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("Storage", "readBinaryFile failed: " + e);
        }
        return null;
    }
}
