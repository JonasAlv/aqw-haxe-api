package com.aqwapi.modules;

import com.aqwapi.data.QuestDTO;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwJson;

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
            com.aqwapi.utils.AqwStorage.ensureFiles();
            var rawJson:String = com.aqwapi.utils.AqwStorage.readText("quests.json");

            _quests = new Map<Int, QuestDTO>();

            if (rawJson != null && rawJson.length > 0) {
                var rawList:Dynamic = AqwJson.parse(rawJson);
                var loadedCount:Int = 0;
                if (rawList != null && Std.isOfType(rawList, Array)) {
                    var arr:Array<Dynamic> = cast rawList;
                    for (item in arr) {
                        if (item != null) {
                            var dto = new QuestDTO(item);
                            if (dto.id > 0) {
                                _quests.set(dto.id, dto);
                                loadedCount++;
                            }
                        }
                    }
                }

                _loaded = true;
                _loading = false;
                if (!silent) ApiLogger.info("Quest", "Loaded " + loadedCount + " quests from quests.json!");
            } else {
                _loaded = true;
                _loading = false;
                if (!silent) ApiLogger.warn("Quest", "assets/quests.json not found!");
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
            if (!silent) ApiLogger.error("Quest", "Failed to load quests.json: " + msg);
        }
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
