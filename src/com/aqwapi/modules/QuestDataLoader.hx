package com.aqwapi.modules;

import com.aqwapi.data.QuestDTO;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwUtils;

class QuestDataLoader {
    private static var _quests:Map<Int, QuestDTO> = null;
    private static var _loading:Bool = false;
    private static var _loaded:Bool = false;

    public static function isLoaded():Bool {
        return _loaded;
    }

    public static function count():Int {
        if (!_loaded) ensureLoaded(true);
        if (_quests == null) return 0;
        var total = 0;
        for (_ in _quests) total++;
        return total;
    }

    public static function ensureLoaded(silent:Bool = false):Void {
        if (_loaded || _loading) return;
        _loading = true;

        try {
            var FileClass:Dynamic = Type.resolveClass("flash.filesystem.File");
            var FileStreamClass:Dynamic = Type.resolveClass("flash.filesystem.FileStream");

            if (FileClass == null || FileStreamClass == null) {
                _quests = new Map<Int, QuestDTO>();
                _loaded = true;
                _loading = false;
                return;
            }

            var appDir:Dynamic = Reflect.getProperty(FileClass, "applicationDirectory");
            var storageDir:Dynamic = Reflect.getProperty(FileClass, "applicationStorageDirectory");
            var FileModeClass:Dynamic = Type.resolveClass("flash.filesystem.FileMode");
            var readMode:String = (FileModeClass != null) ? Reflect.getProperty(FileModeClass, "READ") : "read";

            var readFileText = function(file:Dynamic):String {
                if (file == null || !file.exists) return null;
                try {
                    var stream:Dynamic = Type.createInstance(FileStreamClass, []);
                    stream.open(file, readMode);
                    var content:String = stream.readUTFBytes(stream.bytesAvailable);
                    stream.close();
                    return content;
                } catch (e:Dynamic) {
                    return null;
                }
            };

            var rawTxt:String = null;
            if (appDir != null) {
                rawTxt = readFileText(appDir.resolvePath("assets/quests.txt"));
                if (rawTxt == null) rawTxt = readFileText(appDir.resolvePath("quests.txt"));
            }
            if (rawTxt == null && storageDir != null) {
                rawTxt = readFileText(storageDir.resolvePath("quests.txt"));
                if (rawTxt == null) rawTxt = readFileText(storageDir.resolvePath("assets/quests.txt"));
            }

            _quests = new Map<Int, QuestDTO>();

            if (rawTxt != null && rawTxt.length > 0) {
                var loadedCount:Int = 0;
                var lines:Array<String> = rawTxt.split("\n");
                for (rawLine in lines) {
                    var line:String = StringTools.trim(rawLine);
                    if (line.length == 0 || StringTools.startsWith(line, "#")) continue;

                    var fields:Array<String> = line.split("|");
                    if (fields.length < 2) continue;

                    var qid:Int = AqwUtils.parseInt(fields[0], 0);
                    if (qid <= 0) continue;

                    var name:String = fields[1];
                    var slot:Int = (fields.length > 2) ? AqwUtils.parseInt(fields[2], -1) : -1;
                    var val:Int = (fields.length > 3) ? AqwUtils.parseInt(fields[3], 0) : 0;
                    var gold:Int = (fields.length > 4) ? AqwUtils.parseInt(fields[4], 0) : 0;
                    var xp:Int = (fields.length > 5) ? AqwUtils.parseInt(fields[5], 0) : 0;
                    var flags:String = (fields.length > 6) ? fields[6] : "";
                    var reqs:Array<Dynamic> = (fields.length > 7) ? parseItemList(fields[7]) : [];
                    var rews:Array<Dynamic> = (fields.length > 8) ? parseItemList(fields[8]) : [];
                    var accs:Array<Dynamic> = (fields.length > 9) ? parseItemList(fields[9]) : [];

                    var dto:QuestDTO = Type.createEmptyInstance(QuestDTO);
                    dto.id = qid;
                    dto.name = name;
                    dto.slot = slot;
                    dto.value = val;
                    dto.gold = gold;
                    dto.xp = xp;
                    dto.level = 0;
                    dto.upgrade = (flags.indexOf("U") != -1);
                    dto.once = (flags.indexOf("O") != -1);
                    dto.requirements = reqs;
                    dto.rewards = rews;
                    dto.acceptRequirements = accs;
                    dto.simpleRewards = [];
                    dto.status = "";
                    dto.field = null;
                    dto.index = 0;
                    dto.raw = dto;

                    _quests.set(qid, dto);
                    loadedCount++;
                }

                _loaded = true;
                _loading = false;
                if (!silent) ApiLogger.info("Quest", "Loaded " + loadedCount + " quests from quests.txt!");
            } else {
                _loaded = true;
                _loading = false;
                if (!silent) ApiLogger.warn("Quest", "assets/quests.txt not found!");
            }
        } catch (e:Dynamic) {
            _quests = new Map<Int, QuestDTO>();
            _loaded = true;
            _loading = false;
            var msg:String = Std.string(e);
            #if flash
            try {
                if (Std.isOfType(e, flash.errors.Error)) {
                    var flashErr:flash.errors.Error = cast e;
                    var st:String = flashErr.getStackTrace();
                    if (st != null && st != "") msg += " @ " + st;
                }
            } catch (_:Dynamic) {}
            #end
            if (!silent) ApiLogger.error("Quest", "Failed to load quests.txt: " + msg);
        }
    }

    private static function parseItemList(str:String):Array<Dynamic> {
        if (str == null || str.length == 0) return [];
        var items:Array<Dynamic> = [];
        var parts:Array<String> = str.split(",");
        for (p in parts) {
            if (p.length == 0) continue;
            var sub:Array<String> = p.split(":");
            var iid:Int = AqwUtils.parseInt(sub[0], 0);
            var qty:Int = (sub.length > 1) ? AqwUtils.parseInt(sub[1], 1) : 1;
            var isTemp:Bool = (sub.length > 2 && sub[2] == "1");
            var name:String = (sub.length > 3) ? sub[3] : "";
            items.push({
                ItemID: iid,
                id: iid,
                iQty: qty,
                qty: qty,
                bTemp: isTemp ? 1 : 0,
                sName: name,
                name: name
            });
        }
        return items;
    }

    public static function get(questId:Int):QuestDTO {
        if (!_loaded) ensureLoaded(true);
        if (_quests == null) return null;
        return _quests.get(questId);
    }

    public static function search(query:String, maxResults:Int = 50):Array<QuestDTO> {
        if (!_loaded) ensureLoaded(true);
        var results:Array<QuestDTO> = [];
        if (_quests == null || query == null || query == "") return results;
        var qLower:String = query.toLowerCase();

        for (quest in _quests) {
            if (quest.name != null && quest.name.toLowerCase().indexOf(qLower) != -1) {
                results.push(quest);
                if (results.length >= maxResults) break;
            }
        }
        return results;
    }
}
