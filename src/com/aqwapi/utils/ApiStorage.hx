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

    public static function isAndroid():Bool {
        #if flash
        try {
            var capCls = flash.system.Capabilities;
            if (capCls != null) {
                if (capCls.version != null && capCls.version.indexOf("AND") == 0) return true;
                if (capCls.os != null && capCls.os.toLowerCase().indexOf("android") != -1) return true;
            }
        } catch (_:Dynamic) {}
        #end
        return false;
    }

    public static function isDesktop():Bool {
        if (isAndroid()) return false;
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

    private static var _permissionRequested:Bool = false;

    public static function requestAndroidStoragePermission():Void {
        if (_permissionRequested) return;
        _permissionRequested = true;
        if (!isAndroid()) return;
        var FileClass:Dynamic = getFileClass();
        if (FileClass == null) return;
        try {
            var docDir:Dynamic = null;
            #if flash
            try { docDir = untyped FileClass.documentsDirectory; } catch (_:Dynamic) {}
            #end
            if (docDir == null) docDir = getStaticProp(FileClass, "documentsDirectory");
            if (docDir == null) {
                #if flash
                try { docDir = untyped FileClass.userDirectory; } catch (_:Dynamic) {}
                #end
                if (docDir == null) docDir = getStaticProp(FileClass, "userDirectory");
            }
            if (docDir != null) {
                var pStatus:Dynamic = null;
                #if flash
                try { pStatus = untyped docDir.permissionStatus; } catch (_:Dynamic) {}
                #end
                if (pStatus == null) pStatus = Reflect.field(docDir, "permissionStatus");
                ApiLogger.info("Storage", "Android storage permission status: " + pStatus);
                if (pStatus != null && pStatus != "granted") {
                    ApiLogger.info("Storage", "Requesting Android storage permission...");
                    #if flash
                    try {
                        untyped docDir.requestPermission();
                    } catch (err:Dynamic) {
                        ApiLogger.warn("Storage", "Error calling requestPermission: " + err);
                    }
                    #end
                }
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("Storage", "Could not request Android storage permission: " + e);
        }
    }

    /**
     * Single data directory with read & write access:
     * - Desktop/Wine/Windows: File.applicationStorageDirectory (%APPDATA%/<appID>/Local Store/)
     * - Android: File.documentsDirectory/AQWPocket/ (User-accessible without root) with fallback to applicationStorageDirectory
     */
    public static function getDataDirectory():Dynamic {
        if (_dataDir != null) return _dataDir;
        var FileClass:Dynamic = getFileClass();
        if (FileClass == null) return null;

        // On Android, use user-accessible shared storage (Documents/AQWPocket) so users can manage files & scripts
        if (isAndroid()) {
            requestAndroidStoragePermission();
            try {
                var docDir:Dynamic = null;
                #if flash
                try { docDir = untyped FileClass.documentsDirectory; } catch (_:Dynamic) {}
                #end
                if (docDir == null) docDir = getStaticProp(FileClass, "documentsDirectory");
                if (docDir == null) {
                    #if flash
                    try { docDir = untyped FileClass.userDirectory; } catch (_:Dynamic) {}
                    #end
                    if (docDir == null) docDir = getStaticProp(FileClass, "userDirectory");
                }
                if (docDir != null) {
                    var sharedDir:Dynamic = docDir.resolvePath("AQWPocket");
                    if (!sharedDir.exists) sharedDir.createDirectory();
                    _dataDir = sharedDir;
                    ApiLogger.info("Storage", "Android accessible storage path: " + _dataDir.nativePath);
                    return _dataDir;
                }
            } catch (e:Dynamic) {
                ApiLogger.warn("Storage", "Could not initialize Android shared storage, falling back: " + e);
            }
        }

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

            // Ensure scripts folder exists in user storage for custom scripts
            try {
                var scriptsDir = dir.resolvePath("scripts");
                if (!scriptsDir.exists) {
                    scriptsDir.createDirectory();
                }
            } catch (e:Dynamic) {}
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

        // 1. Try reading from user storage (applicationStorageDirectory)
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

        // 2. Fallback to bundled app directory (File.applicationDirectory/assets/<clean> or File.applicationDirectory/<clean>)
        try {
            var FileClass:Dynamic = getFileClass();
            if (FileClass != null) {
                var appDir:Dynamic = null;
                #if flash
                try { appDir = untyped FileClass.applicationDirectory; } catch (_:Dynamic) {}
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

    public static function listScripts():Array<String> {
        var scripts:Array<String> = [];
        var cleanName = function(fName:String):String {
            if (fName == null) return null;
            if (StringTools.endsWith(fName.toLowerCase(), ".hxs")) {
                return fName.substring(0, fName.length - 4);
            }
            return fName;
        };

        // 1. Scan bundled scripts in applicationDirectory/assets/scripts
        try {
            var FileClass:Dynamic = getFileClass();
            if (FileClass != null) {
                var appDir:Dynamic = getStaticProp(FileClass, "applicationDirectory");
                if (appDir != null) {
                    var bDir = appDir.resolvePath("assets/scripts");
                    if (bDir != null && bDir.exists && bDir.isDirectory) {
                        var list:Array<Dynamic> = untyped bDir.getDirectoryListing();
                        if (list != null) {
                            for (f in list) {
                                if (f != null && !f.isDirectory) {
                                    var s = cleanName(f.name);
                                    if (s != null && s != "" && scripts.indexOf(s) == -1) {
                                        scripts.push(s);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}

        // 2. Scan user scripts in applicationStorageDirectory/scripts
        try {
            var dir = getDataDirectory();
            if (dir != null) {
                var uDir = dir.resolvePath("scripts");
                if (uDir != null && uDir.exists && uDir.isDirectory) {
                    var list:Array<Dynamic> = untyped uDir.getDirectoryListing();
                    if (list != null) {
                        for (f in list) {
                            if (f != null && !f.isDirectory) {
                                var s = cleanName(f.name);
                                if (s != null && s != "" && scripts.indexOf(s) == -1) {
                                    scripts.push(s);
                                }
                            }
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}

        return scripts;
    }

    public static function isBundledScript(scriptName:String):Bool {
        if (scriptName == null || scriptName == "") return false;
        try {
            var FileClass:Dynamic = getFileClass();
            if (FileClass != null) {
                var appDir:Dynamic = null;
                #if flash
                try { appDir = untyped FileClass.applicationDirectory; } catch (_:Dynamic) {}
                #end
                if (appDir == null) {
                    appDir = getStaticProp(FileClass, "applicationDirectory");
                }
                if (appDir != null) {
                    var f = appDir.resolvePath("assets/scripts/" + scriptName + ".hxs");
                    if (f != null && f.exists) return true;
                }
            }
        } catch (_:Dynamic) {}
        return false;
    }

    public static function isUserScript(scriptName:String):Bool {
        if (scriptName == null || scriptName == "") return false;
        if (isBundledScript(scriptName)) return false;
        var dir = getDataDirectory();
        if (dir == null) return false;
        try {
            var f = dir.resolvePath("scripts/" + scriptName + ".hxs");
            return (f != null && f.exists == true);
        } catch (_:Dynamic) {}
        return false;
    }

    public static function readScript(scriptName:String):String {
        if (scriptName == null || scriptName == "") return null;
        var clean = cleanFileName(scriptName);
        if (StringTools.endsWith(clean.toLowerCase(), ".hxs")) {
            clean = clean.substring(0, clean.length - 4);
        }

        // 1. If it's a user script, read from user storage
        var dir = getDataDirectory();
        if (dir != null) {
            try {
                var uf = dir.resolvePath("scripts/" + clean + ".hxs");
                var txt = readFileStream(uf);
                if (txt != null && StringTools.trim(txt).length > 0) return txt;
            } catch (_:Dynamic) {}
        }

        // 2. If it's a bundled script, read from applicationDirectory assets
        try {
            var FileClass:Dynamic = getFileClass();
            if (FileClass != null) {
                var appDir:Dynamic = null;
                #if flash
                try { appDir = untyped FileClass.applicationDirectory; } catch (_:Dynamic) {}
                #end
                if (appDir == null) {
                    appDir = getStaticProp(FileClass, "applicationDirectory");
                }
                if (appDir != null) {
                    var bf = appDir.resolvePath("assets/scripts/" + clean + ".hxs");
                    var btxt = readFileStream(bf);
                    if (btxt != null && StringTools.trim(btxt).length > 0) return btxt;
                }
            }
        } catch (_:Dynamic) {}

        return null;
    }

    public static function deleteUserScript(scriptName:String):Bool {
        if (scriptName == null || scriptName == "") return false;
        var dir = getDataDirectory();
        if (dir == null) return false;
        try {
            var f = dir.resolvePath("scripts/" + scriptName + ".hxs");
            if (f != null && f.exists) {
                f.deleteFile();
                return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }
}


