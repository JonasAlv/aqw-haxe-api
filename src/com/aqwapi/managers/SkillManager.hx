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
            // A class holding only class-level metadata (e.g. an `autoattack` override) has no
            // modes to rotate, so it is not a usable class.
            if (key != null && key != "" && list.indexOf(key) == -1 && hasAnyMode(Reflect.field(_skillsData, key))) {
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
                if (isModeConfigObject(candidate) && modes.indexOf(key) == -1) {
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

    public static function resolveActiveModeName(className:String, desiredMode:String):String {
        if (className == null || className == "") return "Base";
        var availableModes = getAvailableModes(className);
        if (availableModes == null || availableModes.length == 0) return "Base";

        // If user/script specified a concrete mode (not Auto or Current), check if class supports it
        if (desiredMode != null && desiredMode != "" && desiredMode.toLowerCase() != "auto" && desiredMode.toLowerCase() != "current") {
            for (m in availableModes) {
                if (m != null && m.toLowerCase() == desiredMode.toLowerCase()) {
                    return m; // return with canonical casing
                }
            }
        }

        // Otherwise (or if class doesn't have the desired mode), return the first available mode of that class
        for (m in availableModes) {
            if (m != null && m != "" && m.toLowerCase() != "auto") {
                return m;
            }
        }
        return (availableModes.length > 0) ? availableModes[0] : "Base";
    }

    public static function registerCustomMode(className:String, modeName:String, skillUseMode:String, timeout:Int, combo:String, stopOnTargetAuras:String = null, resetComboOnTargetChange:Null<Bool> = null, autoAttack:Null<Bool> = null):Void {
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
        // Explicit choice wins; otherwise keep an `autoattack` flag already on the mode being replaced.
        if (autoAttack != null) modeObj.autoattack = autoAttack;
        else copyAutoAttackFlag(Reflect.field(targetClass, trimmedMode), modeObj);

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
            // Class-level autoattack is a scalar sibling of the modes, so it is skipped by the
            // mode loop below and must be carried over separately.
            var classFlag:Dynamic = rawAutoAttackField(classObj);

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
                copyAutoAttackFlag(modeObj, cleanMode);
                Reflect.setField(cleanClass, mField, cleanMode);
                hasModes = true;
            }
            // A class may declare only a class-level flag (no modes of its own) when it overrides
            // a bundled class. Such an entry carries the flag only, so keep it without requiring modes.
            if (hasModes || classFlag != null) {
                if (classFlag != null) Reflect.setField(cleanClass, "autoattack", classFlag);
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
                var candidate:Dynamic = Reflect.field(classObj, mKey);
                if (mKey != null && mKey != "" && isModeConfigObject(candidate) && modes.indexOf(mKey) == -1) {
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
            if (field != null && field != "" && classes.indexOf(field) == -1 && hasAnyMode(Reflect.field(data, field))) {
                classes.push(field);
            }
        }
        return classes;
    }

    /** True when `classObj` declares at least one mode config (class-level scalars don't count). */
    private static function hasAnyMode(classObj:Dynamic):Bool {
        if (classObj == null || !Reflect.isObject(classObj) || Std.isOfType(classObj, Array)) return false;
        for (f in Reflect.fields(classObj)) {
            if (isModeConfigObject(Reflect.field(classObj, f))) return true;
        }
        return false;
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
                        var details:Dynamic = {
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
                        copyAutoAttackFlag(mObj, details);
                        return details;
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
                var details:Dynamic = {
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
                copyAutoAttackFlag(mObj, details);
                return details;
            }
        }
        return null;
    }

    public static function saveMode(className:String, modeName:String, skillUseMode:String, timeout:Int, combo:String, stopOnTargetAuras:String = null, resetComboOnTargetChange:Null<Bool> = null, autoAttack:Null<Bool> = null):Bool {
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

            var existingEntry:Dynamic = Reflect.field(classObj, trimmedMode);
            if (existingEntry == null) {
                var lower = trimmedMode.toLowerCase();
                for (f in Reflect.fields(classObj)) {
                    if (f.toLowerCase() == lower) {
                        existingEntry = Reflect.field(classObj, f);
                        break;
                    }
                }
            }
            if (existingEntry != null) {
                deleteFieldSafe(classObj, trimmedMode);
                var lowerDel = trimmedMode.toLowerCase();
                for (f in Reflect.fields(classObj)) {
                    if (f.toLowerCase() == lowerDel) {
                        deleteFieldSafe(classObj, f);
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
            // An explicit choice wins; "inherit" (null) keeps whatever the mode already had, so
            // re-saving a mode never silently flips Auto Attack.
            if (autoAttack != null) modeEntry.autoattack = autoAttack;
            else copyAutoAttackFlag(existingEntry, modeEntry);

            Reflect.setField(classObj, trimmedMode, modeEntry);
            var ok = writeUserSkillsObject(data);

            registerCustomMode(targetClassKey, trimmedMode, effectiveMode, effectiveTimeout, effectiveCombo, stopOnTargetAuras, resetComboOnTargetChange, autoAttack);
            if (targetClassKey != trimmedClass) {
                registerCustomMode(trimmedClass, trimmedMode, effectiveMode, effectiveTimeout, effectiveCombo, stopOnTargetAuras, resetComboOnTargetChange, autoAttack);
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
                if (!silent) ApiLogger.debug("Skills", "Loaded skills.json successfully!");
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
                // Skip scalars at the class level (e.g. autoattack: false as a class name).
                if (cObj == null || Std.isOfType(cObj, Array) || !Reflect.isObject(cObj)) continue;
                for (mKey in Reflect.fields(cObj)) {
                    var mObj:Dynamic = Reflect.field(cObj, mKey);
                    // Skip class-level metadata scalars (autoattack / hasAutoAttack).
                    if (!isModeConfigObject(mObj)) continue;
                    if (mObj.mode != null && mObj.skillUseMode == null) mObj.skillUseMode = mObj.mode;
                    if (mObj.timeout != null) {
                        var rawTo = ApiUtils.parseInt(mObj.timeout, 0);
                        var safeTo = (rawTo > 1500) ? rawTo : 0;
                        mObj.timeout = safeTo;
                        if (mObj.skillTimeout == null) mObj.skillTimeout = safeTo;
                    }
                    if (mObj.skillTimeout != null) {
                        var rawSto = ApiUtils.parseInt(mObj.skillTimeout, 0);
                        mObj.skillTimeout = (rawSto > 1500) ? rawSto : 0;
                    }
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
                    copyAutoAttackFlag(details, modeConfig);
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
                // autoattack / hasAutoAttack and similar class-level metadata are scalars.
                if (isModeConfigObject(candidate)) {
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

    /**
 * Whether CombatEngine should fire Auto Attack outside the combo.
 * Reads `autoattack` (also `autoAttack` / `hasAutoAttack`) from the class first, then the mode.
 * A class-level flag is authoritative: a class whose action bar slot 0 holds a real skill can keep
 * the internal Auto Attack off for every one of its modes, and no mode can switch it back on.
 * Missing flag defaults to true.
 */
    public static function classHasAutoAttack(className:String, ?modeName:String):Bool {
        var resolvedClass = resolveClassName(className);
        var conf:Dynamic = findClassConfig(resolvedClass);
        if (conf == null) return true;

        // Same precedence as modeHasAutoAttack: the mode is the more specific setting, so it wins and
        // the class object acts purely as a default. Kept in step deliberately - these two resolvers
        // used to disagree about which level outranked the other.
        if (modeName != null && modeName != "") {
            var resolvedMode = resolveActiveModeName(resolvedClass, modeName);
            var mObj = getModeObject(conf, resolvedMode);
            if (mObj == null) mObj = getModeObject(conf, modeName);
            var modeFlag = readAutoAttackFlag(mObj);
            if (modeFlag != null) return modeFlag;
        }

        var classFlag = readAutoAttackFlag(conf);
        if (classFlag != null) return classFlag;

        return true;
    }

    public static function modeHasAutoAttack(modeConfig:Dynamic, className:String, ?modeName:String):Bool {
        // Mode wins, class is only the default. The previous order was inverted - the broader class
        // flag outranked the specific mode - which meant a class that turned Auto Attack off locked
        // every one of its modes out of re-enabling it, with no way to recover. Whether a rotation
        // wants Auto Attack is a property of that rotation: a hard-locked riposte combo needs it off so
        // it does not burn the dodge buff, while a chip-damage rotation for the same class wants it on.
        //
        // Safe to change: no bundled or user config declares a class-level flag, so classFlag is
        // always null today and the mode value already won.
        var fromMode = readAutoAttackFlag(modeConfig);
        if (fromMode != null) return fromMode;
        var classFlag = readClassAutoAttackFlag(className);
        if (classFlag != null) return classFlag;
        return true;
    }

    /** The class object's own `autoattack` flag, ignoring any mode. Null when not declared. */
    public static function getClassAutoAttackFlag(className:String):Null<Bool> {
        return readClassAutoAttackFlag(className);
    }

    private static function readClassAutoAttackFlag(className:String):Null<Bool> {
        if (className == null || className == "") return null;
        var conf:Dynamic = findClassConfig(resolveClassName(className));
        if (conf == null) return null;
        return readAutoAttackFlag(conf);
    }

    private static function isModeConfigObject(candidate:Dynamic):Bool {
        if (candidate == null) return false;
        if (Std.isOfType(candidate, Array)) return false;
        if (Std.isOfType(candidate, Bool) || Std.isOfType(candidate, Int) || Std.isOfType(candidate, Float) || Std.isOfType(candidate, String)) return false;
        return Reflect.isObject(candidate);
    }

    private static function getModeObject(conf:Dynamic, modeName:String):Dynamic {
        if (conf == null || modeName == null || modeName == "") return null;
        if (Reflect.hasField(conf, modeName)) {
            var obj:Dynamic = Reflect.field(conf, modeName);
            if (isModeConfigObject(obj)) return obj;
        }
        var lower = modeName.toLowerCase();
        for (key in Reflect.fields(conf)) {
            if (key.toLowerCase() == lower) {
                var obj:Dynamic = Reflect.field(conf, key);
                if (isModeConfigObject(obj)) return obj;
            }
        }
        return null;
    }

    /**
     * Raw `autoattack` value from `obj`, or null when the flag is absent. Kept unparsed (and
     * untyped) so it can be copied between configs verbatim, including the `"True"` / `"False"`
     * strings that survive a JSON round trip.
     */
    private static function rawAutoAttackField(obj:Dynamic):Dynamic {
        if (obj == null) return null;
        if (Reflect.hasField(obj, "autoattack")) return Reflect.field(obj, "autoattack");
        if (Reflect.hasField(obj, "autoAttack")) return Reflect.field(obj, "autoAttack");
        if (Reflect.hasField(obj, "hasAutoAttack")) return Reflect.field(obj, "hasAutoAttack");
        return null;
    }

    /**
     * Copies an existing `autoattack` flag from `from` onto `to` under the canonical key.
     * Called wherever a mode object is rebuilt, otherwise the flag is silently dropped.
     * Recognisable values are normalized to a real boolean, so a hand-written `"True"` /
     * `"False"` is stored as `true` / `false` from then on. Unparseable values are kept as-is
     * and ignored by the reader, which falls back to the default.
     */
    private static function copyAutoAttackFlag(from:Dynamic, to:Dynamic):Bool {
        if (to == null) return false;
        var raw = rawAutoAttackField(from);
        if (raw == null) return false;
        var parsed = readAutoAttackFlag(from);
        Reflect.setField(to, "autoattack", (parsed != null) ? parsed : raw);
        return true;
    }

    private static function readAutoAttackFlag(obj:Dynamic):Null<Bool> {
        var flag = rawAutoAttackField(obj);
        if (flag == null) return null;
        if (Std.isOfType(flag, Bool)) return flag;
        var s = Std.string(flag).toLowerCase();
        if (s == "false" || s == "0" || s == "no") return false;
        if (s == "true" || s == "1" || s == "yes") return true;
        return null;
    }
}
