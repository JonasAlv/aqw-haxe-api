package com.aqwapi.scripting.core;

class CoreStory {
    public var quest:CoreQuest;
    public var hunt:CoreHunt;
    public function new(quest:CoreQuest, hunt:CoreHunt) { this.quest = quest; this.hunt = hunt; }
    public function questChain(questIds:Array<Dynamic>, mapName:String = null):Bool { if (questIds == null) return true; for (id in questIds) if (!quest.progress(id, mapName)) return false; return true; }
    public function killQuest(questId:Dynamic, monster:Dynamic, mapName:String = null):Bool { if (quest.isDone(questId)) return true; if (!hunt.monster(monster, mapName)) return false; return quest.progress(questId, mapName); }
}
