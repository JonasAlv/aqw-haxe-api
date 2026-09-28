package com.aqwapi.managers;

import com.aqwapi.Api;
import com.aqwapi.Game;
import com.aqwapi.modules.DefaultSkillsData;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiStorage;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiUtils;
import com.aqwapi.utils.SkillDslParser;

class SkillManager {
    private var _game:Game;

    private static var _skillsData:Dynamic = null;
    private static var _skillsLoaded:Bool = false;
    private static var _userSkillsCache:Dynamic = null;
    private static var _skillsDataLower:Map<String, Dynamic> = new Map<String, Dynamic>();
    private static var _skillsDataClean:Map<String, Dynamic> = new Map<String, Dynamic>();
    private static var _classConfigCache:Map<String, Dynamic> = new Map<String, Dynamic>();
    private static var _cachedKnownClasses:Array<String> = null;
    private static var _cachedCleanKeys:Array<{ clean:String, len:Int, key:String }> = null;
    private static final NULL_CONFIG:Dynamic = { __null: true };

    public function new(gameReference:Game) {
        _game = gameReference;
    }

    public static function ensureStorageInitialized():Void {
        ApiStorage.ensureFiles();
    }

    public static function cleanClassName(name:String):String {
        if (name == null) return "";
        var s:String = name.toLowerCase();
        var parenStart:Int = s.indexOf("(");
        if (parenStart != -1) {
            s = s.substring(0, parenStart);
        }
        var result:StringBuf = new StringBuf();
        for (i in 0...s.length) {
            var c:Int = s.charCodeAt(i);
            if ((c >= 97 && c <= 122) || (c >= 48 && c <= 57)) {
                result.addChar(c);
            }
        }
        return result.toString();
    }

    private static var _cachedCurrentClassName:String = "";
    private static var _lastCurrentClassCheck:Float = 0;

    public static function invalidateCurrentClass():Void {
        _lastCurrentClassCheck = 0;
        _cachedCurrentClassName = "";
    }

    public static function getCurrentClassName():String {
        var now = ApiTime.now();
        if (_cachedCurrentClassName != "" && (now - _lastCurrentClassCheck < 1000)) {
            return _cachedCurrentClassName;
        }
        _lastCurrentClassCheck = now;

        try {
            if (Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null) {
                var av:Dynamic = Api.game.world.myAvatar;
                var equippedClassItemName:String = "";

                // 1. Check equipped items in myAvatar.items
                if (av.items != null) {
                    try {
                        var items:Array<Dynamic> = cast av.items;
                        for (it in items) {
                            if (it == null) continue;
                            var equipped:Bool = (it.bEquip == 1 || it.bEquip == "1" || it.bEquip == true);
                            if (!equipped) continue;
                            var sTypeStr:String = (it.sType != null) ? Std.string(it.sType).toLowerCase() : "";
                            var isClassItem:Bool = (sTypeStr == "class" || it.bClass == 1 || it.bClass == true || it.bClass == "1");
                            if (!isClassItem && it.sES != null && Std.string(it.sES).toLowerCase() == "ar") {
                                isClassItem = true;
                            }
                            if (isClassItem && it.sName != null) {
                                var s:String = StringTools.trim(Std.string(it.sName));
                                if (s != "" && s != "null") {
                                    equippedClassItemName = s;
                                    // If this exact item name matches a known class config, return it immediately!
                                    if (findClassConfig(s) != null) {
                                        _cachedCurrentClassName = s;
                                        return s;
                                    }
                                }
                            }
                        }
                    } catch (_:Dynamic) {}
                }

                // 2. Check av.objData.strClassName against known class configs
                if (av.objData != null && av.objData.strClassName != null) {
                    var c:String = StringTools.trim(Std.string(av.objData.strClassName));
                    if (c != "" && c != "null") {
                        if (findClassConfig(c) != null) {
                            _cachedCurrentClassName = c;
                            return c;
                        }
                    }
                }

                // 3. Fallback to equipped class item name (even if not yet in skills.json)
                if (equippedClassItemName != "") {
                    _cachedCurrentClassName = equippedClassItemName;
                    return equippedClassItemName;
                }

                // 4. Fallback to objData.strClassName
                if (av.objData != null && av.objData.strClassName != null) {
                    var c:String = StringTools.trim(Std.string(av.objData.strClassName));
                    if (c != "" && c != "null") {
                        _cachedCurrentClassName = c;
                        return c;
                    }
                }
            }
        } catch (_:Dynamic) {}
        return _cachedCurrentClassName;
    }

    public static function resolveClassName(className:String):String {
        if (className == null || className == "" || className.toLowerCase() == "current") {
            var cur = getCurrentClassName();
            if (cur != null && cur != "" && cur.toLowerCase() != "current") return cur;
            if (Api.combat != null && Api.combat.smartClass != null && Api.combat.smartClass != "" && Api.combat.smartClass.toLowerCase() != "current") {
                return Api.combat.smartClass;
            }
            return (className != null) ? className : "";
        }
        return className;
    }

    public static function rebuildClassIndex():Void {
        _skillsDataLower = new Map<String, Dynamic>();
        _skillsDataClean = new Map<String, Dynamic>();
        _classConfigCache = new Map<String, Dynamic>();
        _cachedKnownClasses = null;

        var cleanList:Array<{ clean:String, len:Int, key:String }> = [];
        if (_skillsData != null) {
            for (key in Reflect.fields(_skillsData)) {
                if (key == null || key == "") continue;
                var val:Dynamic = Reflect.field(_skillsData, key);
                if (val == null) continue;
                _skillsDataLower.set(key.toLowerCase(), val);
                var clean = cleanClassName(key);
                if (clean != "") {
                    _skillsDataClean.set(clean, val);
                    cleanList.push({ clean: clean, len: clean.length, key: key });
                }
            }
        }
        cleanList.sort(function(a, b) return b.len - a.len);
        _cachedCleanKeys = cleanList;
    }

    public static function findClassConfig(className:String):Dynamic {
        if (!_skillsLoaded) ensureLoaded(true);
        if (_skillsData == null || className == null || className == "") return null;

        var trimmed = StringTools.trim(className);
        if (trimmed == "") return null;

        if (trimmed.toLowerCase() == "current") {
            var cur:String = getCurrentClassName();
            if (cur != "" && cur.toLowerCase() != "current") {
                return findClassConfig(cur);
            }
            return null;
        }

        if (_classConfigCache != null && _classConfigCache.exists(trimmed)) {
            var cached:Dynamic = _classConfigCache.get(trimmed);
            if (cached == NULL_CONFIG) return null;
            return cached;
        }

        var result:Dynamic = null;

        // 1. Exact match
        if (Reflect.hasField(_skillsData, trimmed)) {
            result = Reflect.field(_skillsData, trimmed);
        }

        // 2. Case-insensitive match
        if (result == null && _skillsDataLower != null) {
            var lower:String = trimmed.toLowerCase();
            if (_skillsDataLower.exists(lower)) {
                result = _skillsDataLower.get(lower);
            }
        }

        // 3. Clean and fuzzy substring match
        var cleanTarget:String = cleanClassName(trimmed);
        if (result == null && cleanTarget != "") {
            if (_skillsDataClean != null && _skillsDataClean.exists(cleanTarget)) {
                result = _skillsDataClean.get(cleanTarget);
            } else if (_cachedCleanKeys != null) {
                var bestMatchKey:String = null;
                var bestMatchLen:Int = 0;
                for (item in _cachedCleanKeys) {
                    if (cleanTarget.indexOf(item.clean) != -1 || item.clean.indexOf(cleanTarget) != -1) {
                        if (item.len > bestMatchLen) {
                            bestMatchLen = item.len;
                            bestMatchKey = item.key;
                        }
                    }
                }
                if (bestMatchKey != null) {
                    result = Reflect.field(_skillsData, bestMatchKey);
                }
            }
        }

        // 4. User skills lookup
        if (result == null) {
            try {
                var userObj = readUserSkillsObject();
                if (userObj != null) {
                    var lower = trimmed.toLowerCase();
                    if (Reflect.hasField(userObj, trimmed)) {
                        result = Reflect.field(userObj, trimmed);
                        compileSkillsData(userObj);
                        Reflect.setField(_skillsData, trimmed, result);
                    } else {
                        for (cKey in Reflect.fields(userObj)) {
                            if (cKey.toLowerCase() == lower || (cleanTarget != "" && cleanClassName(cKey) == cleanTarget)) {
                                result = Reflect.field(userObj, cKey);
                                compileSkillsData(userObj);
                                Reflect.setField(_skillsData, cKey, result);
                                break;
                            }
                        }
                    }
                }
            } catch (_:Dynamic) {}
        }

        if (_classConfigCache != null) {
            _classConfigCache.set(trimmed, (result != null) ? result : NULL_CONFIG);
        }

        return result;
    }

    public static function getKnownClasses():Array<String> {
        if (!_skillsLoaded) ensureLoaded(true);
        if (_cachedKnownClasses != null) return _cachedKnownClasses.copy();
        if (_skillsData == null) return [];
        var list:Array<String> = [];
        for (key in Reflect.fields(_skillsData)) {
            if (key != null && key != "" && list.indexOf(key) == -1) {
                list.push(key);
            }
        }
        list.sort(function(a, b) {
            var la:String = a.toLowerCase();
            var lb:String = b.toLowerCase();
            return (la < lb) ? -1 : ((la > lb) ? 1 : 0);
        });
        _cachedKnownClasses = list;
        return list.copy();
    }

    public static function getAvailableModes(className:String):Array<String> {
        if (className == null || className == "") return ["Auto"];
        var resolved = resolveClassName(className);
        var conf:Dynamic = findClassConfig(resolved);
        var modes:Array<String> = [];

        if (conf != null) {
            for (key in Reflect.fields(conf)) {
                var candidate:Dynamic = Reflect.field(conf, key);
                if (candidate != null && !Std.isOfType(candidate, Array) && modes.indexOf(key) == -1) {
                    modes.push(key);
                }
            }
        }

        var userModes = getUserModesForClass(resolved);
        for (um in userModes) {
            if (um != null && um != "" && modes.indexOf(um) == -1) {
                modes.push(um);
            }
        }

        if (modes.length == 0) modes.push("Auto");
        return modes;
    }

    public static function registerCustomMode(className:String, modeName:String, skillUseMode:String, timeout:Int, combo:String, stopOnTargetAuras:String = null, resetComboOnTargetChange:Null<Bool> = null):Void {
        if (className == null || className == "" || modeName == null || modeName == "") return;
        if (!_skillsLoaded) ensureLoaded(true);
        if (_skillsData == null) _skillsData = {};

        var trimmedClass = StringTools.trim(className);
        var trimmedMode = StringTools.trim(modeName);
        var targetKey:String = trimmedClass;
        var targetClass:Dynamic = Reflect.field(_skillsData, trimmedClass);
        if (targetClass == null) {
            var cleanC:String = cleanClassName(trimmedClass);
            var lowerClass = trimmedClass.toLowerCase();
            for (existingKey in Reflect.fields(_skillsData)) {
                if (existingKey.toLowerCase() == lowerClass || (cleanC != "" && cleanClassName(existingKey) == cleanC)) {
                    targetKey = existingKey;
                    targetClass = Reflect.field(_skillsData, existingKey);
                    break;
                }
            }
        }
        if (targetClass == null) {
            targetClass = {};
            Reflect.setField(_skillsData, targetKey, targetClass);
        }

        var parsedCombo:Array<Dynamic> = SkillDslParser.parseCombo(combo);
        var modeObj:Dynamic = {
            mode: skillUseMode,
            timeout: timeout,
            skillUseMode: skillUseMode,
            skillTimeout: timeout,
            skills: parsedCombo,
            combo: combo
        };
        if (stopOnTargetAuras != null && stopOnTargetAuras != "") modeObj.stopOnTargetAuras = stopOnTargetAuras;
        if (resetComboOnTargetChange != null) modeObj.resetComboOnTargetChange = resetComboOnTargetChange;

        Reflect.setField(targetClass, trimmedMode, modeObj);
        rebuildClassIndex();
    }

    public static function unregisterCustomMode(className:String, modeName:String):Bool {
        if (className == null || modeName == null || _skillsData == null) return false;
        var trimmedClass = StringTools.trim(className);
        var trimmedMode = StringTools.trim(modeName);
        var targetClass:Dynamic = Reflect.field(_skillsData, trimmedClass);
        if (targetClass == null) {
            var cleanC:String = cleanClassName(trimmedClass);
            var lowerClass = trimmedClass.toLowerCase();
            for (existingKey in Reflect.fields(_skillsData)) {
                if (existingKey.toLowerCase() == lowerClass || (cleanC != "" && cleanClassName(existingKey) == cleanC)) {
                    targetClass = Reflect.field(_skillsData, existingKey);
                    break;
                }
            }
        }
        if (targetClass == null) return false;

        var removed:Bool = false;
        if (Reflect.hasField(targetClass, trimmedMode)) {
            Reflect.deleteField(targetClass, trimmedMode);
            removed = true;
        } else {
            var lowerMode = trimmedMode.toLowerCase();
            for (f in Reflect.fields(targetClass)) {
                if (f.toLowerCase() == lowerMode) {
                    Reflect.deleteField(targetClass, f);
                    removed = true;
                    break;
                }
            }
        }
        if (removed) rebuildClassIndex();
        return removed;
    }

    public static function readUserSkillsObject():Dynamic {
        if (_userSkillsCache != null) return _userSkillsCache;
        var rawJson:String = null;
        try {
            ensureStorageInitialized();
            rawJson = ApiStorage.readText("userSkills.json");
        } catch (_:Dynamic) {}

        var parsedData:Dynamic = null;
        if (rawJson != null && StringTools.trim(rawJson).length > 0) {
            try {
                parsedData = haxe.Json.parse(rawJson);
            } catch (e:Dynamic) {
                ApiLogger.error("Skills", "JSON parse error in userSkills.json: " + e);
            }
        }
        if (parsedData == null || !Reflect.isObject(parsedData) || Std.isOfType(parsedData, Array)) {
            parsedData = {};
        } else {
            parsedData = sanitizeUserSkillsObject(parsedData);
        }
        _userSkillsCache = parsedData;
        return _userSkillsCache;
    }

    public static function sanitizeUserSkillsObject(data:Dynamic):Dynamic {
        if (data == null || !Reflect.isObject(data) || Std.isOfType(data, Array)) return {};
        var cleanRoot:Dynamic = {};
        for (cField in Reflect.fields(data)) {
            var classObj:Dynamic = Reflect.field(data, cField);
            if (classObj == null || !Reflect.isObject(classObj) || Std.isOfType(classObj, Array)) continue;
            var cleanClass:Dynamic = {};
            var hasModes:Bool = false;

            for (mField in Reflect.fields(classObj)) {
                var modeObj:Dynamic = Reflect.field(classObj, mField);
                if (modeObj == null || !Reflect.isObject(modeObj) || Std.isOfType(modeObj, Array)) continue;

                var modeStr = (modeObj.mode != null) ? Std.string(modeObj.mode) : ((modeObj.skillUseMode != null) ? Std.string(modeObj.skillUseMode) : "WaitForCooldown");
                var rawTo = (modeObj.timeout != null) ? ApiUtils.parseInt(modeObj.timeout, 0) : ((modeObj.skillTimeout != null) ? ApiUtils.parseInt(modeObj.skillTimeout, 0) : 0);
                var timeoutInt = (rawTo > 1500) ? rawTo : 0;
                var comboStr = (modeObj.combo != null) ? StringTools.trim(Std.string(modeObj.combo)) : "";

                if (comboStr == "" && modeObj.skills != null && Std.isOfType(modeObj.skills, Array)) {
                    var skillsArr:Array<Dynamic> = cast modeObj.skills;
                    var parts:Array<String> = [];
                    for (sk in skillsArr) {
                        if (sk == null) continue;
                        var idxStr = (sk.skillId != null) ? Std.string(sk.skillId) : ((sk.idx != null) ? Std.string(sk.idx) : "1");
                        parts.push(idxStr);
                    }
                    comboStr = parts.join(" > ");
                }

                var cleanMode:Dynamic = {
                    mode: modeStr,
                    timeout: timeoutInt,
                    combo: comboStr
                };
                if (modeObj.stopOnTargetAuras != null && Std.string(modeObj.stopOnTargetAuras) != "") {
                    cleanMode.stopOnTargetAuras = Std.string(modeObj.stopOnTargetAuras);
                }
                if (modeObj.resetComboOnTargetChange != null) {
                    cleanMode.resetComboOnTargetChange = (modeObj.resetComboOnTargetChange == true);
                }
                Reflect.setField(cleanClass, mField, cleanMode);
                hasModes = true;
            }
            if (hasModes) {
                Reflect.setField(cleanRoot, cField, cleanClass);
            }
        }
        return cleanRoot;
    }

    public static function deleteFieldSafe(o:Dynamic, field:String):Bool {
        if (o == null || field == null || field == "") return false;
        #if flash
        try {
            untyped __delete__(o, field);
            return true;
        } catch (_:Dynamic) {}
        #end
        try {
            return Reflect.deleteField(o, field);
        } catch (_:Dynamic) {}
        return false;
    }

    public static function readUserSkills():String {
        var obj = readUserSkillsObject();
        try {
            return haxe.Json.stringify(obj, null, "  ");
        } catch (_:Dynamic) {}
        return "{}";
    }

    public static function writeUserSkills(content:String):Bool {
        if (content == null || content == "") return false;
        try {
            var parsed = haxe.Json.parse(content);
            return writeUserSkillsObject(parsed);
        } catch (e:Dynamic) {
            ApiLogger.error("SkillManager", "Invalid JSON in writeUserSkills: " + e);
            return false;
        }
    }

    public static function writeUserSkillsObject(data:Dynamic):Bool {
        if (data == null) return false;
        try {
            ensureStorageInitialized();
            var sanitized = sanitizeUserSkillsObject(data);
            var serialized = haxe.Json.stringify(sanitized, null, "  ");
            var ok = ApiStorage.writeText("userSkills.json", serialized);
            _userSkillsCache = sanitized;
            return ok;
        } catch (e:Dynamic) {
            ApiLogger.error("Skills", "writeUserSkillsObject error: " + e);
            return false;
        }
    }

    public static function getUserModesForClass(className:String):Array<String> {
        if (className == null || className == "") return [];
        var data = readUserSkillsObject();
        if (data == null) return [];
        var targetKey = findTargetClassKey(data, className);
        if (targetKey == null) return [];

        var classObj:Dynamic = Reflect.field(data, targetKey);
        var modes:Array<String> = [];
        if (classObj != null && !Std.isOfType(classObj, Array)) {
            for (mKey in Reflect.fields(classObj)) {
                if (mKey != null && mKey != "" && modes.indexOf(mKey) == -1) {
                    modes.push(mKey);
                }
            }
        }
        return modes;
    }

    public static function getAllUserClasses():Array<String> {
        var data = readUserSkillsObject();
        if (data == null) return [];
        var classes:Array<String> = [];
        for (field in Reflect.fields(data)) {
            if (field != null && field != "" && classes.indexOf(field) == -1) {
                classes.push(field);
            }
        }
        return classes;
    }

    public static function isUserMode(className:String, modeName:String):Bool {
        if (className == null || modeName == null) return false;
        var trimmedMode = StringTools.trim(modeName);
        if (trimmedMode == "" || trimmedMode == "[+ New Mode]") return false;
        var data = readUserSkillsObject();
        if (data == null) return false;
        var targetKey = findTargetClassKey(data, className);
        if (targetKey == null) return false;
        var classObj:Dynamic = Reflect.field(data, targetKey);
        if (classObj != null && !Std.isOfType(classObj, Array)) {
            if (Reflect.hasField(classObj, trimmedMode)) return true;
            var lower = trimmedMode.toLowerCase();
            for (mKey in Reflect.fields(classObj)) {
                if (mKey.toLowerCase() == lower) return true;
            }
        }
        return false;
    }

    public static function getModeDetails(className:String, modeName:String):Dynamic {
        if (className == null || modeName == null) return null;
        var resolvedClass = resolveClassName(className);
        var trimmedMode = StringTools.trim(modeName);
        if (trimmedMode == "" || trimmedMode == "[+ New Mode]") return null;

        // 1. Check userSkills.json
        var data = readUserSkillsObject();
        if (data != null) {
            var targetKey = findTargetClassKey(data, resolvedClass);
            if (targetKey != null) {
                var classObj:Dynamic = Reflect.field(data, targetKey);
                if (classObj != null && !Std.isOfType(classObj, Array)) {
                    var mObj:Dynamic = Reflect.field(classObj, trimmedMode);
                    if (mObj == null) {
                        var lowerMode = trimmedMode.toLowerCase();
                        for (f in Reflect.fields(classObj)) {
                            if (f.toLowerCase() == lowerMode) {
                                mObj = Reflect.field(classObj, f);
                                break;
                            }
                        }
                    }
                    if (mObj != null) {
                        return {
                            className: targetKey,
                            modeName: trimmedMode,
                            skillUseMode: (mObj.mode != null) ? Std.string(mObj.mode) : ((mObj.skillUseMode != null) ? Std.string(mObj.skillUseMode) : "WaitForCooldown"),
                            timeout: {
                                var rawTo = (mObj.timeout != null) ? ApiUtils.parseInt(mObj.timeout, 0) : ((mObj.skillTimeout != null) ? ApiUtils.parseInt(mObj.skillTimeout, 0) : 0);
                                (rawTo > 1500) ? rawTo : 0;
                            },
                            combo: (mObj.combo != null) ? Std.string(mObj.combo) : "",
                            stopOnTargetAuras: (mObj.stopOnTargetAuras != null) ? Std.string(mObj.stopOnTargetAuras) : null,
                            resetComboOnTargetChange: (mObj.resetComboOnTargetChange != null) ? (mObj.resetComboOnTargetChange == true) : null,
                            isUser: true
                        };
                    }
                }
            }
        }

        // 2. Check bundled modes
        var classObj = findClassConfig(resolvedClass);
        if (classObj != null) {
            var mObj:Dynamic = Reflect.field(classObj, trimmedMode);
            if (mObj == null) {
                var lowerMode = trimmedMode.toLowerCase();
                for (f in Reflect.fields(classObj)) {
                    if (f.toLowerCase() == lowerMode) {
                        mObj = Reflect.field(classObj, f);
                        break;
                    }
                }
            }
            if (mObj != null) {
                var comboStr:String = (mObj.combo != null) ? Std.string(mObj.combo) : "";
                if (comboStr == "" && mObj.skills != null && Std.isOfType(mObj.skills, Array)) {
                    var skillsArr:Array<Dynamic> = cast mObj.skills;
                    var parts:Array<String> = [];
                    for (sk in skillsArr) {
                        if (sk == null) continue;
                        var idxStr = (sk.skillId != null) ? Std.string(sk.skillId) : "1";
                        parts.push(idxStr);
                    }
                    comboStr = parts.join(" > ");
                }
                var userFlag:Bool = isUserMode(resolvedClass, trimmedMode);
                return {
                    className: resolvedClass,
                    modeName: trimmedMode,
                    skillUseMode: (mObj.mode != null) ? Std.string(mObj.mode) : ((mObj.skillUseMode != null) ? Std.string(mObj.skillUseMode) : "WaitForCooldown"),
                    timeout: {
                        var rawTo = (mObj.timeout != null) ? ApiUtils.parseInt(mObj.timeout, 0) : ((mObj.skillTimeout != null) ? ApiUtils.parseInt(mObj.skillTimeout, 0) : 0);
                        (rawTo > 1500) ? rawTo : 0;
                    },
                    combo: comboStr,
                    stopOnTargetAuras: (mObj.stopOnTargetAuras != null) ? Std.string(mObj.stopOnTargetAuras) : null,
                    resetComboOnTargetChange: (mObj.resetComboOnTargetChange != null) ? (mObj.resetComboOnTargetChange == true) : null,
                    isUser: userFlag
                };
            }
        }
        return null;
    }

    public static function saveMode(className:String, modeName:String, skillUseMode:String, timeout:Int, combo:String, stopOnTargetAuras:String = null, resetComboOnTargetChange:Null<Bool> = null):Bool {
        if (className == null || className == "" || modeName == null || modeName == "") return false;
        var resolvedClass = resolveClassName(className);
        var trimmedClass = StringTools.trim(resolvedClass);
        var trimmedMode = StringTools.trim(modeName);
        if (trimmedClass == "" || trimmedClass.toLowerCase() == "current") return false;
        if (trimmedMode == "" || trimmedMode == "[+ New Mode]") return false;

        try {
            var data:Dynamic = readUserSkillsObject();
            if (data == null) data = {};
            var targetClassKey:String = findTargetClassKey(data, trimmedClass);
            if (targetClassKey == null) targetClassKey = trimmedClass;

            var classObj:Dynamic = Reflect.field(data, targetClassKey);
            if (classObj == null || !Reflect.isObject(classObj) || Std.isOfType(classObj, Array)) {
                classObj = {};
                Reflect.setField(data, targetClassKey, classObj);
            }

            var effectiveMode = (skillUseMode != null && skillUseMode != "") ? skillUseMode : "WaitForCooldown";
            var effectiveTimeout = (timeout > 1500) ? timeout : 0;
            var effectiveCombo = (combo != null) ? StringTools.trim(combo) : "";

            if (Reflect.hasField(classObj, trimmedMode)) {
                Reflect.deleteField(classObj, trimmedMode);
            } else {
                var lower = trimmedMode.toLowerCase();
                for (f in Reflect.fields(classObj)) {
                    if (f.toLowerCase() == lower) {
                        Reflect.deleteField(classObj, f);
                        break;
                    }
                }
            }

            var modeEntry:Dynamic = {
                mode: effectiveMode,
                timeout: effectiveTimeout,
                combo: effectiveCombo
            };
            if (stopOnTargetAuras != null && stopOnTargetAuras != "") modeEntry.stopOnTargetAuras = stopOnTargetAuras;
            if (resetComboOnTargetChange != null) modeEntry.resetComboOnTargetChange = resetComboOnTargetChange;

            Reflect.setField(classObj, trimmedMode, modeEntry);
            var ok = writeUserSkillsObject(data);

            registerCustomMode(targetClassKey, trimmedMode, effectiveMode, effectiveTimeout, effectiveCombo, stopOnTargetAuras, resetComboOnTargetChange);
            if (targetClassKey != trimmedClass) {
                registerCustomMode(trimmedClass, trimmedMode, effectiveMode, effectiveTimeout, effectiveCombo, stopOnTargetAuras, resetComboOnTargetChange);
            }
            return ok;
        } catch (e:Dynamic) {
            ApiLogger.error("Skills", "saveMode exception: " + e);
            return false;
        }
    }

    public static function deleteMode(className:String, modeName:String):Bool {
        if (className == null || className == "" || modeName == null || modeName == "") return false;
        var resolvedClass = resolveClassName(className);
        var trimmedClass = StringTools.trim(resolvedClass);
        var trimmedMode = StringTools.trim(modeName);
        if (trimmedClass == "" || trimmedMode == "") return false;

        var removed:Bool = false;
        try {
            var data:Dynamic = readUserSkillsObject();
            if (data != null) {
                var targetClassKey = findTargetClassKey(data, trimmedClass);
                if (targetClassKey != null) {
                    var classObj:Dynamic = Reflect.field(data, targetClassKey);
                    if (classObj != null && !Std.isOfType(classObj, Array)) {
                        if (Reflect.hasField(classObj, trimmedMode)) {
                            Reflect.deleteField(classObj, trimmedMode);
                            removed = true;
                        } else {
                            var lowerMode = trimmedMode.toLowerCase();
                            for (mKey in Reflect.fields(classObj)) {
                                if (mKey.toLowerCase() == lowerMode) {
                                    Reflect.deleteField(classObj, mKey);
                                    removed = true;
                                    break;
                                }
                            }
                        }
                        if (removed) {
                            if (Reflect.fields(classObj).length == 0) {
                                Reflect.deleteField(data, targetClassKey);
                            }
                            writeUserSkillsObject(data);
                        }
                    }
                }
            }
        } catch (e:Dynamic) {
            ApiLogger.error("Skills", "deleteMode userSkills error: " + e);
        }

        unregisterCustomMode(trimmedClass, trimmedMode);
        return removed;
    }

    public static function isLoaded():Bool {
        return _skillsLoaded && _skillsData != null;
    }

    public static function ensureLoaded(silent:Bool = true):Void {
        if (isLoaded()) return;
        reload(silent, false);
    }

    public static function reload(silent:Bool = false, force:Bool = true):Void {
        if (!force && isLoaded()) return;
        _skillsLoaded = true;
        try {
            var rawTxt:String = null;
            try {
                ensureStorageInitialized();
                rawTxt = ApiStorage.readText("skills.json");
                if (rawTxt == null || rawTxt.length == 0) rawTxt = ApiStorage.readText("skills.txt");
            } catch (_:Dynamic) {}
            if (rawTxt == null || rawTxt.length == 0) {
                rawTxt = DefaultSkillsData.getDefaultSkills();
            }

            if (rawTxt != null && rawTxt.length > 0) {
                var trimmed = StringTools.trim(rawTxt);
                if (trimmed.charAt(0) == "{" || trimmed.charAt(0) == "[") {
                    try {
                        _skillsData = haxe.Json.parse(rawTxt);
                    } catch (je:Dynamic) {
                        ApiLogger.error("Skills", "skills.json parse error: " + je);
                        _skillsData = {};
                    }
                } else {
                    _skillsData = SkillDslParser.parse(rawTxt);
                }
                compileSkillsData(_skillsData);
                if (!silent) ApiLogger.info("Skills", "Loaded skills.json successfully!");
            } else {
                _skillsData = {};
            }

            var userSkillsObj:Dynamic = readUserSkillsObject();
            if (userSkillsObj != null && Reflect.fields(userSkillsObj).length > 0) {
                compileSkillsData(userSkillsObj);
                for (cKey in Reflect.fields(userSkillsObj)) {
                    var targetKey:String = cKey;
                    var targetClass:Dynamic = Reflect.field(_skillsData, cKey);
                    if (targetClass == null) {
                        targetClass = {};
                        Reflect.setField(_skillsData, targetKey, targetClass);
                    }
                    var srcClass:Dynamic = Reflect.field(userSkillsObj, cKey);
                    for (mKey in Reflect.fields(srcClass)) {
                        Reflect.setField(targetClass, mKey, Reflect.field(srcClass, mKey));
                    }
                }
            }

            ensureStorageInitialized();
            rebuildClassIndex();
        } catch (e:Dynamic) {
            ApiLogger.error("Skills", "skills load error: " + e);
            if (_skillsData == null || Reflect.fields(_skillsData).length == 0) {
                try {
                    var defTxt = DefaultSkillsData.getDefaultSkills();
                    if (defTxt != null && defTxt.length > 0) {
                        _skillsData = haxe.Json.parse(defTxt);
                        compileSkillsData(_skillsData);
                    }
                } catch (_:Dynamic) {}
            }
            if (_skillsData == null) _skillsData = {};
            rebuildClassIndex();
        }
    }

    public static function compileSkillsData(data:Dynamic):Void {
        if (data == null) return;
        try {
            for (cKey in Reflect.fields(data)) {
                var cObj:Dynamic = Reflect.field(data, cKey);
                if (cObj == null || Std.isOfType(cObj, Array)) continue;
                for (mKey in Reflect.fields(cObj)) {
                    var mObj:Dynamic = Reflect.field(cObj, mKey);
                    if (mObj == null || Std.isOfType(mObj, Array)) continue;
                    if (mObj.mode != null && mObj.skillUseMode == null) mObj.skillUseMode = mObj.mode;
                    if (mObj.timeout != null && mObj.skillTimeout == null) mObj.skillTimeout = mObj.timeout;
                    if (mObj.resetComboOnTargetChange != null && mObj.resetOnTarget == null) mObj.resetOnTarget = mObj.resetComboOnTargetChange;
                    if (mObj.stopOnTargetAuras != null && mObj.stopTargetAuras == null) mObj.stopTargetAuras = mObj.stopOnTargetAuras;

                    // Note: combo parsing (mObj.skills) is deferred and resolved lazily on-demand
                    // in resolveActiveModeConfig(). This prevents parsing ~500 DSL combos upfront
                    // and eliminates lag spikes when loading or reloading skills.
                }
            }
        } catch (_:Dynamic) {}
    }

    public static function resolveActiveModeConfig(world:Dynamic, avatar:Dynamic, target:Dynamic, smartClass:String, skillMode:String):Dynamic {
        var confClass = (smartClass != null && smartClass != "" && smartClass != "Current") ? smartClass : "Current";
        var className:String = "";
        if (confClass != null && confClass != "" && confClass != "Current") {
            className = confClass;
        } else {
            className = getCurrentClassName();
            if (className == "" && avatar != null && avatar.objData != null && avatar.objData.strClassName != null) {
                className = Std.string(avatar.objData.strClassName);
            }
        }
        var config:Dynamic = (className != "") ? findClassConfig(className) : null;
        if (config == null) return null;

        var modeConfig:Dynamic = null;
        var isExplicitMode:Bool = (skillMode != null && skillMode != "" && skillMode != "Auto");

        if (isExplicitMode && Reflect.hasField(config, skillMode)) {
            modeConfig = Reflect.field(config, skillMode);
        }
        if (modeConfig == null && isExplicitMode) {
            for (key in Reflect.fields(config)) {
                if (key.toLowerCase() == skillMode.toLowerCase()) {
                    modeConfig = Reflect.field(config, key);
                    break;
                }
            }
        }
        if (modeConfig == null && isExplicitMode) {
            var details = getModeDetails(className, skillMode);
            if (details != null && details.combo != null && details.combo != "") {
                var parsedSkills = SkillDslParser.parseCombo(details.combo);
                if (parsedSkills != null && parsedSkills.length > 0) {
                    modeConfig = {
                        skillUseMode: details.skillUseMode,
                        skillTimeout: details.timeout,
                        skills: parsedSkills,
                        combo: details.combo,
                        stopOnTargetAuras: details.stopOnTargetAuras,
                        resetComboOnTargetChange: details.resetComboOnTargetChange
                    };
                    Reflect.setField(config, skillMode, modeConfig);
                }
            }
        }
        if (modeConfig == null) {
            if (Reflect.field(config, "Base") != null) {
                modeConfig = Reflect.field(config, "Base");
            } else {
                for (key in Reflect.fields(config)) {
                    if (key.toLowerCase() == "base") {
                        modeConfig = Reflect.field(config, key);
                        break;
                    }
                }
            }
        }
        if (modeConfig == null) {
            for (key in Reflect.fields(config)) {
                var candidate:Dynamic = Reflect.field(config, key);
                if (candidate != null && !Std.isOfType(candidate, Array)) {
                    modeConfig = candidate;
                    break;
                }
            }
        }

        if (modeConfig != null) {
            if (modeConfig.skills == null || !Std.isOfType(modeConfig.skills, Array) || (cast(modeConfig.skills, Array<Dynamic>)).length == 0) {
                if (modeConfig.combo != null && Std.string(modeConfig.combo) != "") {
                    modeConfig.skills = SkillDslParser.parseCombo(Std.string(modeConfig.combo));
                }
            }
        }

        return modeConfig;
    }

    private static function findTargetClassKey(data:Dynamic, className:String):String {
        if (data == null || className == null) return null;
        var resolved = resolveClassName(className);
        var trimmed = StringTools.trim(resolved);
        if (trimmed == "") return null;

        if (Reflect.hasField(data, trimmed)) return trimmed;
        var lower = trimmed.toLowerCase();
        for (cKey in Reflect.fields(data)) {
            if (cKey.toLowerCase() == lower) return cKey;
        }

        var cleanTarget = cleanClassName(trimmed);
        if (cleanTarget != "") {
            for (cKey in Reflect.fields(data)) {
                if (cleanClassName(cKey) == cleanTarget) return cKey;
            }
            var bestKey:String = null;
            var bestLen:Int = 0;
            for (cKey in Reflect.fields(data)) {
                var cleanKey = cleanClassName(cKey);
                if (cleanKey != "") {
                    if (cleanTarget == cleanKey) return cKey;
                    if (cleanTarget.indexOf(cleanKey) != -1 || cleanKey.indexOf(cleanTarget) != -1) {
                        if (cleanKey.length > bestLen) {
                            bestLen = cleanKey.length;
                            bestKey = cKey;
                        }
                    }
                }
            }
            if (bestKey != null) return bestKey;
        }
        return null;
    }
}
