package com.aqwapi.scripting.core;

class CoreStory {
    public var quest:CoreQuest;
    public var hunt:CoreHunt;
    public function new(quest:CoreQuest, hunt:CoreHunt) { this.quest = quest; this.hunt = hunt; }
    public function questChain(questIds:Array<Dynamic>, mapName:String = null):Bool { if (questIds == null) return true; for (id in questIds) if (!quest.progress(id, mapName)) return false; return true; }
    public function killQuest(questId:Dynamic, monster:Dynamic, mapName:String = null):Bool {
        if (quest.isDone(questId)) return true;

        // Load and accept before hunting so the workflow always knows the live quest state.
        if (!quest.loaded(questId)) {
            quest.progress(questId, mapName);
            return false;
        }
        if (!quest.accepted(questId)) {
            quest.progress(questId, mapName);
            return false;
        }

        // A ready quest must be turned in before another combat request is issued.
        // This prevents quest items from being farmed past the required quantity.
        if (quest.completionPending(questId)) return false;
        if (quest.canComplete(questId)) return quest.complete(questId);

        if (!hunt.monster(monster, mapName)) return false;
        return quest.progress(questId, mapName);
    }
}
