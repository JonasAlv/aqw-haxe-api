package com.aqwapi.utils;

class ApiStorage {
    private static var _dataDir:Dynamic = null;
    private static var _provisioned:Bool = false;
    private static var _so:Dynamic = null;

    public static function getSharedObjectStorage():Dynamic {
        if (_so != null) return _so;
        #if flash
        try {
            var soCls = flash.net.SharedObject;
            if (soCls != null) {
                _so = soCls.getLocal("AqwApiStorage");
                if (_so != null && _so.data == null) {
                    _so.data = {};
                }
            }
        } catch (_:Dynamic) {}
        #end
        return _so;
    }

    public static var currentAccount(default, null):String = null;

    public static function getActiveAccount():String {
        if (currentAccount != null && currentAccount != "") return currentAccount;
        try {
            var g:Dynamic = com.aqwapi.Api.game;
            if (g != null && g.sfc != null && g.sfc.myUserName != null) {
                var s:String = StringTools.trim(Std.string(g.sfc.myUserName).toLowerCase());
                if (s != "" && s != "null" && s != "undefined") {
                    setAccount(s);
                    return s;
                }
            }
            if (com.aqwapi.Api.player != null && com.aqwapi.Api.player.username != null) {
                var s:String = StringTools.trim(com.aqwapi.Api.player.username.toLowerCase());
                if (s != "" && s != "null" && s != "undefined") {
                    setAccount(s);
                    return s;
                }
            }
        } catch (_:Dynamic) {}
        return null;
    }

    public static function isAccountBoundFile(fileName:String):Bool {
        if (fileName == null) return false;
        var clean = cleanFileName(fileName).toLowerCase();
        if (clean == "item_presets.json" || clean == "api_blacklist.json" || clean == "blacklist.json" || clean == "config.json") {
            return true;
        }
        if (clean.indexOf("accounts/") == 0 || clean.indexOf("account/") == 0) {
            return true;
        }
        return false;
    }

    public static function getAccountDirectory(accountName:String = null):Dynamic {
        var acc = (accountName != null && accountName != "") ? StringTools.trim(accountName.toLowerCase()) : getActiveAccount();
        if (acc == null || acc == "") return null;
        var dir = getDataDirectory();
        if (dir == null) return null;
        try {
            var accDir = dir.resolvePath("accounts/" + acc);
            if (!accDir.exists) accDir.createDirectory();
            return accDir;
        } catch (_:Dynamic) {}
        return null;
    }

    public static function setAccount(accountName:String):Void {
        var acc = (accountName != null) ? StringTools.trim(accountName.toLowerCase()) : "";
        if (acc == "" || acc == currentAccount) return;
        currentAccount = acc;
        ApiLogger.info("Storage", "Active account set to: " + acc);

        var dir = getDataDirectory();
        if (dir != null) {
            try {
                var accDir = dir.resolvePath("accounts/" + acc);
                if (!accDir.exists) {
                    accDir.createDirectory();
                    ApiLogger.info("Storage", "Created account directory: accounts/" + acc);
                }

                // Auto-migrate / seed existing root presets and blacklist if not present in account folder
                var filesToMigrate = ["item_presets.json", "api_blacklist.json", "config.json"];
                for (fname in filesToMigrate) {
                    try {
                        var target = accDir.resolvePath(fname);
                        if (!target.exists) {
                            var rootFile = dir.resolvePath(fname);
                            if (rootFile != null && rootFile.exists) {
                                var content = readFileStream(rootFile);
                                if (content != null && StringTools.trim(content).length > 0) {
                                    writeFileStream(target, content);
                                    ApiLogger.info("Storage", "Migrated root " + fname + " to accounts/" + acc + "/");
                                }
                            }
                        }
                    } catch (err:Dynamic) {
                        ApiLogger.warn("Storage", "Error migrating " + fname + " for " + acc + ": " + err);
                    }
                }
            } catch (e:Dynamic) {
                ApiLogger.warn("Storage", "Error initializing account directory for " + acc + ": " + e);
            }
        }

        // Reload managers that rely on account-bound data
        try {
            if (com.aqwapi.managers.PresetManager.instance != null) {
                com.aqwapi.managers.PresetManager.instance.loadPresets();
            }
        } catch (_:Dynamic) {}
        try {
            if (com.aqwapi.managers.BlacklistManager.instance != null) {
                com.aqwapi.managers.BlacklistManager.instance.load();
            }
        } catch (_:Dynamic) {}
        try {
            com.aqwapi.utils.ApiConfig.reload();
        } catch (_:Dynamic) {}

        if (com.aqwapi.Api.dispatcher != null) {
            com.aqwapi.Api.dispatcher.dispatchEvent(new com.aqwapi.events.ApiEvent(com.aqwapi.events.ApiEvent.ACCOUNT_CHANGED, acc));
        }
    }

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

    /** Single writable source of truth for all local runtime data. */
    public static function getDataDirectory():Dynamic {
        if (_dataDir != null) return _dataDir;
        var FileClass:Dynamic = getFileClass();
        if (FileClass == null) return null;
        try {
            #if flash
            try {
                var direct:Dynamic = untyped FileClass.applicationStorageDirectory;
                if (direct != null) {
                    if (!direct.exists) direct.createDirectory();
                    _dataDir = direct;
                    ApiLogger.debug("Storage", "Application storage path: " + _dataDir.nativePath);
                    return _dataDir;
                }
            } catch (_:Dynamic) {}
            #end
            var appStorage:Dynamic = getStaticProp(FileClass, "applicationStorageDirectory");
            if (appStorage != null) {
                if (!appStorage.exists) appStorage.createDirectory();
                _dataDir = appStorage;
                ApiLogger.debug("Storage", "Application storage path: " + _dataDir.nativePath);
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
            var acc = getActiveAccount();
            if (isAccountBoundFile(clean) && acc != null && acc != "") {
                var accFile = dir.resolvePath("accounts/" + acc + "/" + clean);
                if (accFile.exists) return accFile;
            }
            return dir.resolvePath(clean);
        } catch (_:Dynamic) {}
        return null;
    }

    public static function ensureFiles():Void {
        if (_provisioned) return;
        _provisioned = true;

        var dir = getDataDirectory();
        if (dir == null) {
            var so = getSharedObjectStorage();
            if (so != null && so.data != null) {
                if (!Reflect.hasField(so.data, "userSkills.json")) {
                    try {
                        var raw = haxe.Resource.getString("default_user_skills");
                        if (raw != null) Reflect.setField(so.data, "userSkills.json", raw);
                    } catch (_:Dynamic) {}
                }
                if (!Reflect.hasField(so.data, "userEnhancements.json")) {
                    try {
                        var raw = haxe.Resource.getString("default_enhancements");
                        if (raw != null) Reflect.setField(so.data, "userEnhancements.json", raw);
                    } catch (_:Dynamic) {}
                }
                try { if (so.flush != null) so.flush(); } catch (_:Dynamic) {}
            }
            return;
        }
        try {
            if (!dir.exists) {
                dir.createDirectory();
            }
        } catch (_:Dynamic) {}

        // Seed bundled defaults into application storage only when no user file exists.
        var FileClass:Dynamic = getFileClass();
        var appDir:Dynamic = (FileClass != null) ? getStaticProp(FileClass, "applicationDirectory") : null;
        if (appDir != null) {
            var seedFiles = ["userEnhancements.json"];
            for (fname in seedFiles) {
                try {
                    var target = dir.resolvePath(fname);
                    if (!target.exists) {
                        var src = appDir.resolvePath("assets/" + fname);
                        var seedContent = readFileStream(src);
                        if (seedContent != null && StringTools.trim(seedContent).length > 0) {
                            writeFileStream(target, seedContent);
                            ApiLogger.debug("Storage", "Seeded " + fname + " to applicationStorageDirectory");
                        }
                    }
                } catch (e:Dynamic) {
                    ApiLogger.warn("Storage", "Failed to seed " + fname + ": " + e);
                }
            }

            try {
                var skillsTarget = dir.resolvePath("userSkills.json");
                if (!skillsTarget.exists) {
                    var defaultSkills = readFileStream(appDir.resolvePath("assets/userSkills.json"));
                    if (defaultSkills != null && StringTools.trim(defaultSkills).length > 0) {
                        if (writeFileStream(skillsTarget, defaultSkills)) {
                            ApiLogger.info("Storage", "Seeded userSkills.json to applicationStorageDirectory");
                        } else {
                            ApiLogger.warn("Storage", "Could not initialize userSkills.json in application storage");
                        }
                    }
                }
            } catch (e:Dynamic) {
                ApiLogger.warn("Storage", "Failed to seed userSkills.json in application storage: " + e);
            }

            // Ensure scripts and assets folders exist in user storage
            try {
                var scriptsDir = dir.resolvePath("scripts");
                if (!scriptsDir.exists) {
                    scriptsDir.createDirectory();
                }
                var assetsDir = dir.resolvePath("assets");
                if (!assetsDir.exists) {
                    assetsDir.createDirectory();
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

        var dir = getDataDirectory();
        if (dir != null) {
            // 1. If it's an account-bound file and an account is active, check accounts/<acc>/<clean>
            var acc = getActiveAccount();
            if (isAccountBoundFile(clean) && acc != null && acc != "") {
                try {
                    var accFile = dir.resolvePath("accounts/" + acc + "/" + clean);
                    var txt = readFileStream(accFile);
                    if (txt != null && StringTools.trim(txt).length > 0) {
                        return txt;
                    }
                } catch (e:Dynamic) {
                    ApiLogger.warn("Storage", "Error reading account file " + clean + ": " + e);
                }
            }

            // 2. Try reading from root user storage (applicationStorageDirectory)
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

        // 3. Fallback to bundled app directory (File.applicationDirectory/assets/<clean> or File.applicationDirectory/<clean>)
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

        // 4. Fallback for non-AIR (Mugetsu / Flash Player): persistent SharedObject
        var so = getSharedObjectStorage();
        if (so != null && so.data != null) {
            var acc = getActiveAccount();
            if (isAccountBoundFile(clean) && acc != null && acc != "") {
                var key = "accounts/" + acc + "/" + clean;
                if (Reflect.hasField(so.data, key)) {
                    var val = Reflect.field(so.data, key);
                    if (val != null && Std.string(val).length > 0) return Std.string(val);
                }
            }
            if (Reflect.hasField(so.data, clean)) {
                var val = Reflect.field(so.data, clean);
                if (val != null && Std.string(val).length > 0) return Std.string(val);
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
                var target:Dynamic = null;
                var acc = getActiveAccount();
                if (isAccountBoundFile(clean) && acc != null && acc != "") {
                    target = dir.resolvePath("accounts/" + acc + "/" + clean);
                } else {
                    target = dir.resolvePath(clean);
                }
                if (target != null) {
                    if (target.parent != null && !target.parent.exists) {
                        try { target.parent.createDirectory(); } catch (_:Dynamic) {}
                    }
                    if (writeFileStream(target, content)) {
                        ApiLogger.debug("Storage", "Saved " + clean + " to " + target.nativePath);
                        return true;
                    }
                }
            } catch (e:Dynamic) {
                ApiLogger.warn("Storage", "Error writing " + clean + ": " + e);
            }
        }

        // Non-AIR fallback (Mugetsu / Flash Player): persistent SharedObject
        var so = getSharedObjectStorage();
        if (so != null && so.data != null) {
            var acc = getActiveAccount();
            var key = (isAccountBoundFile(clean) && acc != null && acc != "") ? ("accounts/" + acc + "/" + clean) : clean;
            Reflect.setField(so.data, key, content);
            try {
                if (so.flush != null) so.flush();
                ApiLogger.debug("Storage", "Saved " + key + " to SharedObject");
                return true;
            } catch (e:Dynamic) {
                ApiLogger.warn("Storage", "Error flushing SharedObject: " + e);
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
            return null;
        };

        var scanDir:Dynamic->String->Void = null;
        scanDir = function(dir:Dynamic, prefix:String):Void {
            if (dir == null) return;
            try {
                if (!dir.exists || !dir.isDirectory) return;
                var list:Array<Dynamic> = untyped dir.getDirectoryListing();
                if (list == null) return;
                for (f in list) {
                    if (f == null) continue;
                    try {
                        if (f.isDirectory) {
                            scanDir(f, prefix + f.name + "/");
                        } else {
                            var s = cleanName(f.name);
                            if (s != null && s != "") {
                                var full = prefix + s;
                                if (scripts.indexOf(full) == -1) {
                                    scripts.push(full);
                                }
                            }
                        }
                    } catch (_:Dynamic) {}
                }
            } catch (err:Dynamic) {
                ApiLogger.warn("Storage", "Error scanning scripts dir " + prefix + ": " + err);
            }
        };

        // 1. Scan bundled scripts in applicationDirectory/assets/scripts
        try {
            var FileClass:Dynamic = getFileClass();
            if (FileClass != null) {
                var appDir:Dynamic = getStaticProp(FileClass, "applicationDirectory");
                if (appDir != null) {
                    var bDir = appDir.resolvePath("assets/scripts");
                    scanDir(bDir, "");
                }
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("Storage", "Error scanning bundled scripts: " + e);
        }

        // 2. Scan user scripts in applicationStorageDirectory/scripts
        try {
            var dir = getDataDirectory();
            if (dir != null) {
                var uDir = dir.resolvePath("scripts");
                scanDir(uDir, "");
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("Storage", "Error scanning user scripts: " + e);
        }

        // 3. Scan scripts stored in SharedObject (Mugetsu / Flash Player)
        var so = getSharedObjectStorage();
        if (so != null && so.data != null) {
            for (field in Reflect.fields(so.data)) {
                if (StringTools.startsWith(field, "scripts/") && StringTools.endsWith(field.toLowerCase(), ".hxs")) {
                    var sName = field.substring(8, field.length - 4);
                    if (scripts.indexOf(sName) == -1) scripts.push(sName);
                }
            }
        }

        // Sort scripts alphabetically
        scripts.sort(function(a:String, b:String):Int {
            var aLow = a.toLowerCase();
            var bLow = b.toLowerCase();
            if (aLow < bLow) return -1;
            if (aLow > bLow) return 1;
            return 0;
        });

        return scripts;
    }

    public static function isBundledScript(scriptName:String):Bool {
        if (scriptName == null || scriptName == "") return false;
        var clean = cleanFileName(scriptName);
        if (StringTools.endsWith(clean.toLowerCase(), ".hxs")) {
            clean = clean.substring(0, clean.length - 4);
        }
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
                    var f = appDir.resolvePath("assets/scripts/" + clean + ".hxs");
                    if (f != null && f.exists) return true;
                    if (clean.indexOf("/") == -1) {
                        var fRep = appDir.resolvePath("assets/scripts/rep/" + clean + ".hxs");
                        if (fRep != null && fRep.exists) return true;
                        var fSaga = appDir.resolvePath("assets/scripts/saga/LordofChaos/" + clean + ".hxs");
                        if (fSaga != null && fSaga.exists) return true;
                    }
                }
            }
        } catch (_:Dynamic) {}
        return false;
    }

    public static function isUserScript(scriptName:String):Bool {
        if (scriptName == null || scriptName == "") return false;
        if (isBundledScript(scriptName)) return false;
        var clean = cleanFileName(scriptName);
        if (StringTools.endsWith(clean.toLowerCase(), ".hxs")) {
            clean = clean.substring(0, clean.length - 4);
        }
        var dir = getDataDirectory();
        if (dir != null) {
            try {
                var f = dir.resolvePath("scripts/" + clean + ".hxs");
                if (f != null && f.exists == true) return true;
                if (clean.indexOf("/") == -1) {
                    var fRep = dir.resolvePath("scripts/rep/" + clean + ".hxs");
                    if (fRep != null && fRep.exists == true) return true;
                    var fSaga = dir.resolvePath("scripts/saga/LordofChaos/" + clean + ".hxs");
                    if (fSaga != null && fSaga.exists == true) return true;
                }
            } catch (_:Dynamic) {}
        }

        var so = getSharedObjectStorage();
        if (so != null && so.data != null) {
            if (Reflect.hasField(so.data, "scripts/" + clean + ".hxs")) return true;
        }

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

                if (clean.indexOf("/") == -1) {
                    var ufRep = dir.resolvePath("scripts/rep/" + clean + ".hxs");
                    var txtRep = readFileStream(ufRep);
                    if (txtRep != null && StringTools.trim(txtRep).length > 0) return txtRep;

                    var ufSaga = dir.resolvePath("scripts/saga/LordofChaos/" + clean + ".hxs");
                    var txtSaga = readFileStream(ufSaga);
                    if (txtSaga != null && StringTools.trim(txtSaga).length > 0) return txtSaga;
                }
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

                    if (clean.indexOf("/") == -1) {
                        var bfRep = appDir.resolvePath("assets/scripts/rep/" + clean + ".hxs");
                        var btxtRep = readFileStream(bfRep);
                        if (btxtRep != null && StringTools.trim(btxtRep).length > 0) return btxtRep;

                        var bfSaga = appDir.resolvePath("assets/scripts/saga/LordofChaos/" + clean + ".hxs");
                        var btxtSaga = readFileStream(bfSaga);
                        if (btxtSaga != null && StringTools.trim(btxtSaga).length > 0) return btxtSaga;
                    }
                }
            }
        } catch (_:Dynamic) {}

        // 3. Fallback: Read from SharedObject (Mugetsu / Flash Player)
        var so = getSharedObjectStorage();
        if (so != null && so.data != null) {
            var sKey = "scripts/" + clean + ".hxs";
            if (Reflect.hasField(so.data, sKey)) {
                var txt = Reflect.field(so.data, sKey);
                if (txt != null && Std.string(txt).length > 0) return Std.string(txt);
            }
        }

        return null;
    }

    public static function deleteUserScript(scriptName:String):Bool {
        if (scriptName == null || scriptName == "") return false;
        var dir = getDataDirectory();
        if (dir != null) {
            try {
                var f = dir.resolvePath("scripts/" + scriptName + ".hxs");
                if (f != null && f.exists) {
                    f.deleteFile();
                    return true;
                }
            } catch (_:Dynamic) {}
        }
        var so = getSharedObjectStorage();
        if (so != null && so.data != null) {
            var sKey = "scripts/" + scriptName + ".hxs";
            if (Reflect.hasField(so.data, sKey)) {
                Reflect.deleteField(so.data, sKey);
                try { if (so.flush != null) so.flush(); } catch (_:Dynamic) {}
                return true;
            }
        }
        return false;
    }
}


