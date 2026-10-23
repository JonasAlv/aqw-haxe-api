package com.aqwapi.scripting.core;

class CoreDailies {
    public var quest:CoreQuest;
    public var farm:CoreFarm;
    public function new(quest:CoreQuest, farm:CoreFarm) { this.quest = quest; this.farm = farm; }
    public function run(questIds:Array<Dynamic>):Bool { if (questIds == null) return true; for (id in questIds) if (!quest.progress(id)) return false; return true; }
    public function once(questId:Dynamic):Bool return quest.isDone(questId) || quest.progress(questId);
    public function farmDaily(monster:Dynamic, item:String, quantity:Int, mapName:String = null):Bool return farm.item(monster, item, quantity, mapName);
}
