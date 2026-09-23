package com.aqwapi.modules;

import com.aqwapi.data.QuestDTO;
import com.aqwapi.utils.ApiLogger;

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
            var questFile:Dynamic = null;

            if (appDir != null) {
                questFile = appDir.resolvePath("assets/QuestData.json");
                if (!questFile.exists) questFile = appDir.resolvePath("assets/questdata.json");
                if (!questFile.exists) questFile = appDir.resolvePath("QuestData.json");
                if (!questFile.exists) questFile = appDir.resolvePath("questdata.json");
            }
            if ((questFile == null || !questFile.exists) && storageDir != null) {
                questFile = storageDir.resolvePath("QuestData.json");
                if (!questFile.exists) questFile = storageDir.resolvePath("assets/QuestData.json");
            }

            if (questFile != null && questFile.exists) {
                var FileModeClass:Dynamic = Type.resolveClass("flash.filesystem.FileMode");
                var readMode:String = (FileModeClass != null) ? Reflect.getProperty(FileModeClass, "READ") : "read";
                var stream:Dynamic = Type.createInstance(FileStreamClass, []);
                stream.open(questFile, readMode);
                var raw:String = stream.readUTFBytes(stream.bytesAvailable);
                stream.close();

                var rawList:Array<Dynamic> = haxe.Json.parse(raw);
                _quests = new Map<Int, QuestDTO>();

                var loadedCount:Int = 0;
                if (rawList != null) {
                    for (item in rawList) {
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
                if (!silent) ApiLogger.info("Quest", "Loaded " + loadedCount + " quests from QuestData.json!");
            } else {
                _quests = new Map<Int, QuestDTO>();
                _loaded = true;
                _loading = false;
                if (!silent) ApiLogger.warn("Quest", "assets/QuestData.json missing!");
            }
        } catch (e:Dynamic) {
            _quests = new Map<Int, QuestDTO>();
            _loaded = true;
            _loading = false;
            if (!silent) ApiLogger.error("Quest", "Failed to load QuestData.json: " + Std.string(e));
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
