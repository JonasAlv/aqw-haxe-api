package com.aqwapi.scripting.core;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiTime;

/** Non-blocking state predicates for onTick/onEvent script workflows. */
class CoreWait {
    public function new() {}
    public function ready():Bool return Api.game != null && Api.game.world != null;
    public function mapLoaded(mapName:String = null):Bool return Api.map != null && Api.map.isLoaded && (mapName == null || mapName == "" || Api.map.isMap(mapName));
    public function cell(cellName:String):Bool return Api.map != null && Api.map.isCell(cellName);
    public function combatExit():Bool return Api.player != null && !Api.player.isInCombat;
    public function item(itemName:String, quantity:Int = 1):Bool return Api.inventory != null && Api.inventory.hasItem(itemName, quantity);
    public function questComplete(questId:Dynamic):Bool return Api.quest != null && Api.quest.hasBeenCompleted(questId);
    public function timeout(startedAt:Float, timeoutMs:Int):Bool return ApiTime.now() - startedAt >= timeoutMs;
    public function until(predicate:Dynamic, timeoutMs:Int = 10000):Bool { if (predicate == null) return false; try { if (Reflect.isFunction(predicate) && predicate()) return true; } catch (_:Dynamic) {} return false; }
}
