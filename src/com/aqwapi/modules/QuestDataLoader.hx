package com.aqwapi.modules;

import com.aqwapi.data.QuestDTO;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwJson;

class QuestDataLoader {
    private static var _rawQuests:haxe.ds.IntMap<Dynamic> = null;
    private static var _dtoCache:haxe.ds.IntMap<QuestDTO> = null;
    private static var _loading:Bool = false;
    private static var _loaded:Bool = false;

    public static function isLoaded():Bool {
        return _loaded;
    }

    public static function count():Int {
        if (!_loaded) ensureLoaded(true);
        if (_rawQuests == null) return 0;
        var total = 0;
        for (_ in _rawQuests) total++;
        return total;
    }

    public static function ensureLoaded(silent:Bool = false):Void {
        if (_loaded || _loading) return;
        _loading = true;

        try {
            com.aqwapi.utils.AqwStorage.ensureFiles();
            var rawJson:String = com.aqwapi.utils.AqwStorage.readText("quests.json");

            _rawQuests = new haxe.ds.IntMap<Dynamic>();
            _dtoCache = new haxe.ds.IntMap<QuestDTO>();

            if (rawJson != null && rawJson.length > 0) {
                var rawList:Dynamic = AqwJson.parse(rawJson);
                var loadedCount:Int = 0;
                if (rawList != null && Std.isOfType(rawList, Array)) {
                    var arr:Array<Dynamic> = cast rawList;
                    for (item in arr) {
                        if (item != null) {
                            var qid:Int = (item.ID != null) ? Std.int(item.ID) : ((item.id != null) ? Std.int(item.id) : 0);
                            if (qid > 0) {
                                _rawQuests.set(qid, item);
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
            _rawQuests = new haxe.ds.IntMap<Dynamic>();
            _dtoCache = new haxe.ds.IntMap<QuestDTO>();
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
        if (_rawQuests == null || questId <= 0) return null;
        if (_dtoCache != null && _dtoCache.exists(questId)) {
            return _dtoCache.get(questId);
        }
        var raw:Dynamic = _rawQuests.get(questId);
        if (raw != null) {
            var dto = new QuestDTO(raw);
            if (_dtoCache != null) _dtoCache.set(questId, dto);
            return dto;
        }
        return null;
    }

    public static function search(query:String, maxResults:Int = 50):Array<QuestDTO> {
        if (!_loaded) ensureLoaded(true);
        var results:Array<QuestDTO> = [];
        if (_rawQuests == null || query == null || query == "") return results;
        var qLower:String = query.toLowerCase();

        for (raw in _rawQuests) {
            if (raw == null) continue;
            var name:String = (raw.Name != null) ? Std.string(raw.Name) : ((raw.name != null) ? Std.string(raw.name) : "");
            if (name != "" && name.toLowerCase().indexOf(qLower) != -1) {
                var qid:Int = (raw.ID != null) ? Std.int(raw.ID) : ((raw.id != null) ? Std.int(raw.id) : 0);
                var dto = get(qid);
                if (dto != null) {
                    results.push(dto);
                    if (results.length >= maxResults) break;
                }
            }
        }
        return results;
    }
}
