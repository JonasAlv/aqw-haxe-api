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
     * Resolves the unified storage folder:
     * - Android: File.documentsDirectory (/storage/emulated/0/Android/data/<pkg>/files)
     * - Desktop: File.applicationDirectory.resolvePath("assets")
     */
    public static function getDataDirectory():Dynamic {
        if (_dataDir != null) return _dataDir;

        try {
            var FileClass:Dynamic = getFileClass();
            if (FileClass == null) {
                ApiLogger.error("Storage", "flash.filesystem.File class is not available");
                return null;
            }

            var isAndroid:Bool = false;
            try {
                var caps:Dynamic = null;
                #if flash
                try { caps = untyped __global__["flash.system.Capabilities"]; } catch (_:Dynamic) {}
                #end
                if (caps == null) caps = Type.resolveClass("flash.system.Capabilities");
                if (caps != null) {
                    var v:String = Std.string(getStaticProp(caps, "version"));
                    var m:String = Std.string(getStaticProp(caps, "manufacturer"));
                    if ((v != null && v.indexOf("AND") == 0) || (m != null && m.indexOf("Android") != -1)) {
                        isAndroid = true;
                    }
                }
            } catch (_:Dynamic) {}

            // 1. Android: use documentsDirectory (/storage/emulated/0/Android/data/<pkg>/files)
            if (isAndroid) {
                try {
                    var docDir:Dynamic = getStaticProp(FileClass, "documentsDirectory");
                    if (docDir != null) {
                        _dataDir = docDir;
                        var p:String = "";
                        try { p = docDir.nativePath; } catch (_:Dynamic) {}
                        ApiLogger.info("Storage", "Using Android documentsDirectory: " + p);
                        return _dataDir;
                    }
                } catch (e:Dynamic) {
                    ApiLogger.warn("Storage", "documentsDirectory access failed: " + e);
                }
            }

            // 2. Desktop: look for "assets" in applicationDirectory
            try {
                var appDir:Dynamic = getStaticProp(FileClass, "applicationDirectory");
                if (appDir != null) {
                    var assetsDir = appDir.resolvePath("assets");
                    if (assetsDir != null && assetsDir.exists) {
                        _dataDir = assetsDir;
                        var p:String = "";
                        try { p = assetsDir.nativePath; } catch (_:Dynamic) {}
                        ApiLogger.info("Storage", "Using Desktop assets folder: " + p);
                        return _dataDir;
                    }
                    var loaderAssets = appDir.resolvePath("loader/assets");
                    if (loaderAssets != null && loaderAssets.exists) {
                        _dataDir = loaderAssets;
                        var p:String = "";
                        try { p = loaderAssets.nativePath; } catch (_:Dynamic) {}
                        ApiLogger.info("Storage", "Using Desktop loader/assets folder: " + p);
                        return _dataDir;
                    }
                }
            } catch (e:Dynamic) {
                ApiLogger.warn("Storage", "applicationDirectory access failed: " + e);
            }

            // 3. Fallback: documentsDirectory
            try {
                var docDir:Dynamic = getStaticProp(FileClass, "documentsDirectory");
                if (docDir != null) {
                    _dataDir = docDir;
                    return _dataDir;
                }
            } catch (_:Dynamic) {}

            // 4. Fallback: applicationStorageDirectory
            try {
                var appStorage:Dynamic = getStaticProp(FileClass, "applicationStorageDirectory");
                if (appStorage != null) {
                    _dataDir = appStorage;
                    return _dataDir;
                }
            } catch (_:Dynamic) {}
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

        // 2. skills.txt
        ensureFile(dir, "skills.txt", function():Dynamic {
            var pkg = resolvePackagedFile("skills.txt");
            var bytes = readBinaryFile(pkg);
            if (bytes != null) return bytes;
            var def = getDefaultSkillsResource();
            return (def != null && def.length > 0) ? def : null;
        });

        // 3. userSkills.txt
        ensureFile(dir, "userSkills.txt", function():Dynamic {
            var pkg = resolvePackagedFile("userSkills.txt");
            var bytes = readBinaryFile(pkg);
            if (bytes != null) return bytes;
            var def = getDefaultUserSkillsResource();
            return (def != null && def.length > 0) ? def : null;
        });
    }

    private static function getDefaultSkillsResource():String {
        try {
            var res = haxe.Resource.getString("default_skills");
            if (res != null && res.length > 0) return res;
        } catch (_:Dynamic) {}
        return "";
    }

    private static function getDefaultUserSkillsResource():String {
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
                var size:Float = 0;
                try { size = target.size; } catch (_:Dynamic) {}
                if (size > 0) return;
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
                    stream.open(f, "read");
                    var txt:String = stream.readUTFBytes(stream.bytesAvailable);
                    stream.close();
                    if (txt != null && txt.length > 0) return txt;
                }
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("Storage", "Error reading " + clean + ": " + e);
        }

        // Fallback: read directly from packaged app asset
        try {
            var pkg = resolvePackagedFile(clean);
            if (pkg != null && pkg.exists) {
                var fsCls:Dynamic = getFileStreamClass();
                if (fsCls != null) {
                    var stream:Dynamic = Type.createInstance(fsCls, []);
                    stream.open(pkg, "read");
                    var txt:String = stream.readUTFBytes(stream.bytesAvailable);
                    stream.close();
                    if (txt != null && txt.length > 0) return txt;
                }
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("Storage", "Error reading packaged " + clean + ": " + e);
        }

        // Fallback 2: read from documentsDirectory / applicationStorageDirectory if written there
        try {
            var FileClass:Dynamic = getFileClass();
            var fallbackDir = getStaticProp(FileClass, "documentsDirectory");
            if (fallbackDir == null) fallbackDir = getStaticProp(FileClass, "applicationStorageDirectory");
            if (fallbackDir != null) {
                var f = fallbackDir.resolvePath(clean);
                if (f != null && f.exists) {
                    var fsCls:Dynamic = getFileStreamClass();
                    if (fsCls != null) {
                        var stream:Dynamic = Type.createInstance(fsCls, []);
                        stream.open(f, "read");
                        var txt:String = stream.readUTFBytes(stream.bytesAvailable);
                        stream.close();
                        if (txt != null && txt.length > 0) return txt;
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
            if (fsCls == null) return false;
            var target = dir.resolvePath(clean);
            if (target == null) return false;
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
        } catch (e:Dynamic) {
            ApiLogger.error("Storage", "writeText failed for " + clean + ": " + e);
        }

        // Fallback: if writing to primary data directory failed, try documentsDirectory or applicationStorageDirectory
        try {
            var FileClass:Dynamic = getFileClass();
            var fallbackDir = getStaticProp(FileClass, "documentsDirectory");
            if (fallbackDir == null) fallbackDir = getStaticProp(FileClass, "applicationStorageDirectory");
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

        return false;
    }

    public static function writeBytes(fileName:String, bytes:Dynamic):Bool {
        var clean = cleanFileName(fileName);
        var dir = getDataDirectory();
        if (dir == null || bytes == null) return false;
        try {
            var fsCls:Dynamic = getFileStreamClass();
            if (fsCls == null) return false;
            var target = dir.resolvePath(clean);
            if (target == null) return false;
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
        } catch (e:Dynamic) {
            ApiLogger.error("Storage", "writeBytes failed for " + clean + ": " + e);
        }
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
