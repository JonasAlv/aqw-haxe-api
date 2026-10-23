package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreQuest {
    public function new() {}
    public function loaded(questId:Dynamic):Bool return Api.quest != null && Api.quest.isLoaded(questId);
    public function accepted(questId:Dynamic):Bool return Api.quest != null && Api.quest.isAccepted(questId);
    public function canComplete(questId:Dynamic):Bool return Api.quest != null && Api.quest.canComplete(questId);
    public function completionPending(questId:Dynamic):Bool return Api.quest != null && Api.quest.isCompletePending(questId);
    public function complete(questId:Dynamic, reward:Dynamic = -1):Bool {
        if (Api.quest == null || Api.quest.hasBeenCompleted(questId)) return true;
        if (Api.quest.isCompletePending(questId)) return false;
        if (!Api.quest.isLoaded(questId)) {
            Api.quest.load(questId);
            return false;
        }
        if (!Api.quest.isAccepted(questId)) {
            Api.quest.accept(questId);
            return false;
        }
        if (!Api.quest.canComplete(questId)) return false;
        if (Api.combat != null) Api.combat.stopCombat();
        if (!Api.quest.ensureCompleteChoose(questId, reward)) return false;
        return Api.quest.hasBeenCompleted(questId);
    }
    public function progress(questId:Dynamic, mapName:String = null):Bool {
        if (Api.quest == null) return false;
        if (Api.quest.hasBeenCompleted(questId)) return true;
        if (Api.quest.isCompletePending(questId)) return false;
        if (!Api.quest.isLoaded(questId)) {
            Api.quest.load(questId);
            return false;
        }
        if (mapName != null && mapName != "" && Api.map != null && !Api.map.ensure(mapName)) return false;
        if (!Api.quest.isAccepted(questId)) {
            Api.quest.accept(questId);
            return false;
        }
        return complete(questId);
    }
    public function accept(questId:Dynamic):Void if (Api.quest != null) Api.quest.accept(questId);
    public function turnIn(questId:Dynamic, reward:Dynamic = -1):Bool return complete(questId, reward);
    public function isDone(questId:Dynamic):Bool return Api.quest != null && Api.quest.hasBeenCompleted(questId);
}
