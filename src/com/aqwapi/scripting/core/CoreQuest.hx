package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreQuest {
    public function new() {}
    public function loaded(questId:Dynamic):Bool return Api.quest != null && Api.quest.isLoaded(questId);
    public function complete(questId:Dynamic, reward:Dynamic = -1):Bool {
        if (Api.quest == null || Api.quest.hasBeenCompleted(questId)) return true;
        if (!Api.quest.isLoaded(questId)) Api.quest.load(questId);
        if (!Api.quest.canComplete(questId)) return false;
        if (Api.combat != null) Api.combat.stopCombat();
        return Api.quest.ensureCompleteChoose(questId, reward);
    }
    public function progress(questId:Dynamic, mapName:String = null):Bool {
        if (Api.quest == null) return false;
        if (Api.quest.hasBeenCompleted(questId)) return true;
        if (!Api.quest.isLoaded(questId)) Api.quest.load(questId);
        if (mapName != null && mapName != "" && Api.map != null && !Api.map.ensure(mapName)) return false;
        if (!Api.quest.isAccepted(questId)) Api.quest.accept(questId);
        return complete(questId);
    }
    public function accept(questId:Dynamic):Void if (Api.quest != null) Api.quest.accept(questId);
    public function turnIn(questId:Dynamic, reward:Dynamic = -1):Bool return complete(questId, reward);
    public function isDone(questId:Dynamic):Bool return Api.quest != null && Api.quest.hasBeenCompleted(questId);
}
