package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreProgression {
    public var quest:CoreQuest;
    public var hunt:CoreHunt;
    public function new(quest:CoreQuest, hunt:CoreHunt) { this.quest = quest; this.hunt = hunt; }
    public function level():Int return Api.player != null ? Api.player.level : 0;
    public function factionRank(faction:String):Int return Api.player != null ? Api.player.getFactionRank(faction) : 0;
    public function reputation(faction:String, rank:Int):Bool return factionRank(faction) >= rank;
    public function completeQuest(questId:Dynamic, mapName:String = null):Bool return quest.progress(questId, mapName);
    public function farm(monster:Dynamic, item:String, quantity:Int, mapName:String = null):Bool return hunt.item(monster, item, quantity, mapName);
}
