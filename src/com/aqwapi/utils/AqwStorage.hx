package com.aqwapi.utils;

import com.aqwapi.modules.DefaultSkillsData;

class AqwStorage {
    private static var _dataDir:Dynamic = null;
    private static var _provisioned:Bool = false;

    private static function cleanFileName(name:String):String {
        if (name == null) return "";
        if (name.indexOf("assets/") == 0) return name.substring(7);
        if (name.indexOf("/") == 0) return name.substring(1);
        return name;
    }

    /**
     * Resolves the unified storage folder:
     * - Android: File.documentsDirectory (/storage/emulated/0/Android/data/<pkg>/files)
     * - Desktop: File.applicationDirectory.resolvePath("assets")
     */
    public static function getDataDirectory():Dynamic {
        if (_dataDir != null) return _dataDir;

        try {
            var FileClass:Dynamic = Type.resolveClass("flash.filesystem.File");
            if (FileClass == null) return null;

            var isAndroid:Bool = false;
            try {
                var caps:Dynamic = Type.resolveClass("flash.system.Capabilities");
                if (caps != null) {
                    var v:String = Reflect.field(caps, "version");
                    var m:String = Reflect.field(caps, "manufacturer");
                    if ((v != null && v.indexOf("AND") == 0) || (m != null && m.indexOf("Android") != -1)) {
                        isAndroid = true;
                    }
                }
            } catch (_:Dynamic) {}

            // Android: use documentsDirectory
            if (isAndroid) {
                try {
                    var docDir:Dynamic = Reflect.getProperty(FileClass, "documentsDirectory");
                    if (docDir != null) {
                        _dataDir = docDir;
                        return _dataDir;
                    }
                } catch (_:Dynamic) {}
            }

            // Desktop: use application assets folder
            try {
                var appDir:Dynamic = Reflect.getProperty(FileClass, "applicationDirectory");
                if (appDir != null) {
                    var assetsDir = appDir.resolvePath("assets");
                    if (assetsDir != null && assetsDir.exists) {
                        _dataDir = assetsDir;
                        return _dataDir;
                    }
                    var loaderAssets = appDir.resolvePath("loader/assets");
                    if (loaderAssets != null && loaderAssets.exists) {
                        _dataDir = loaderAssets;
                        return _dataDir;
                    }
                }
            } catch (_:Dynamic) {}

            // Fallback
            try {
                var docDir:Dynamic = Reflect.getProperty(FileClass, "documentsDirectory");
                if (docDir != null) {
                    _dataDir = docDir;
                    return _dataDir;
                }
            } catch (_:Dynamic) {}
        } catch (_:Dynamic) {}

        return null;
    }

    public static function resolvePackagedFile(fileName:String):Dynamic {
        var clean = cleanFileName(fileName);
        try {
            var FileClass:Dynamic = Type.resolveClass("flash.filesystem.File");
            if (FileClass == null) return null;
            var appDir:Dynamic = Reflect.getProperty(FileClass, "applicationDirectory");
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
            var def = DefaultSkillsData.getDefaultSkills();
            return (def != null && def.length > 0) ? def : null;
        });

        // 3. userSkills.txt
        ensureFile(dir, "userSkills.txt", function():Dynamic {
            var pkg = resolvePackagedFile("userSkills.txt");
            var bytes = readBinaryFile(pkg);
            if (bytes != null) return bytes;
            var def = DefaultSkillsData.getDefaultUserSkills();
            return (def != null && def.length > 0) ? def : null;
        });
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
                var FileStreamClass:Dynamic = Type.resolveClass("flash.filesystem.FileStream");
                var FileModeClass:Dynamic = Type.resolveClass("flash.filesystem.FileMode");
                var readMode:String = (FileModeClass != null) ? Reflect.getProperty(FileModeClass, "READ") : "read";
                var stream:Dynamic = Type.createInstance(FileStreamClass, []);
                stream.open(f, readMode);
                var txt:String = stream.readUTFBytes(stream.bytesAvailable);
                stream.close();
                return txt;
            }
        } catch (_:Dynamic) {}

        // Fallback: read directly from packaged app asset
        try {
            var pkg = resolvePackagedFile(clean);
            if (pkg != null && pkg.exists) {
                var FileStreamClass:Dynamic = Type.resolveClass("flash.filesystem.FileStream");
                var FileModeClass:Dynamic = Type.resolveClass("flash.filesystem.FileMode");
                var readMode:String = (FileModeClass != null) ? Reflect.getProperty(FileModeClass, "READ") : "read";
                var stream:Dynamic = Type.createInstance(FileStreamClass, []);
                stream.open(pkg, readMode);
                var txt:String = stream.readUTFBytes(stream.bytesAvailable);
                stream.close();
                return txt;
            }
        } catch (_:Dynamic) {}

        return null;
    }

    public static function writeText(fileName:String, content:String):Bool {
        var clean = cleanFileName(fileName);
        var dir = getDataDirectory();
        if (dir == null || content == null) return false;
        try {
            var FileStreamClass:Dynamic = Type.resolveClass("flash.filesystem.FileStream");
            var FileModeClass:Dynamic = Type.resolveClass("flash.filesystem.FileMode");
            var writeMode:String = (FileModeClass != null) ? Reflect.getProperty(FileModeClass, "WRITE") : "write";
            var target = dir.resolvePath(clean);
            if (target.parent != null && !target.parent.exists) {
                target.parent.createDirectory();
            }
            var stream:Dynamic = Type.createInstance(FileStreamClass, []);
            stream.open(target, writeMode);
            stream.writeUTFBytes(content);
            stream.close();
            return true;
        } catch (_:Dynamic) {}
        return false;
    }

    public static function writeBytes(fileName:String, bytes:Dynamic):Bool {
        var clean = cleanFileName(fileName);
        var dir = getDataDirectory();
        if (dir == null || bytes == null) return false;
        try {
            var FileStreamClass:Dynamic = Type.resolveClass("flash.filesystem.FileStream");
            var FileModeClass:Dynamic = Type.resolveClass("flash.filesystem.FileMode");
            var writeMode:String = (FileModeClass != null) ? Reflect.getProperty(FileModeClass, "WRITE") : "write";
            var target = dir.resolvePath(clean);
            if (target.parent != null && !target.parent.exists) {
                target.parent.createDirectory();
            }
            var stream:Dynamic = Type.createInstance(FileStreamClass, []);
            stream.open(target, writeMode);
            stream.writeBytes(bytes);
            stream.close();
            return true;
        } catch (_:Dynamic) {}
        return false;
    }

    private static function readBinaryFile(file:Dynamic):Dynamic {
        if (file == null || !file.exists) return null;
        try {
            var FileStreamClass:Dynamic = Type.resolveClass("flash.filesystem.FileStream");
            var FileModeClass:Dynamic = Type.resolveClass("flash.filesystem.FileMode");
            var readMode:String = (FileModeClass != null) ? Reflect.getProperty(FileModeClass, "READ") : "read";
            var stream:Dynamic = Type.createInstance(FileStreamClass, []);
            stream.open(file, readMode);
            var ByteArrayClass:Dynamic = Type.resolveClass("flash.utils.ByteArray");
            var bytes:Dynamic = Type.createInstance(ByteArrayClass, []);
            stream.readBytes(bytes);
            stream.close();
            return bytes;
        } catch (_:Dynamic) {}
        return null;
    }
}
