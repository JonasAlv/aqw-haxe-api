package com.aqwapi.scripting.core;
import com.aqwapi.Api;
import com.aqwapi.events.GameEvent;

/** Event wiring used by higher-level cores; game objects remain on the game thread. */
class CoreEvents {
    public function new() {}
    public function on(eventName:String, handler:Dynamic):Void if (Api.dispatcher != null && handler != null) Api.dispatcher.addEventListener(eventName, handler);
    public function off(eventName:String, handler:Dynamic):Void if (Api.dispatcher != null && handler != null) Api.dispatcher.removeEventListener(eventName, handler);
    public function onZone(handler:Dynamic):Void on(GameEvent.ZONE_ENTERED, handler);
    public function onQuest(handler:Dynamic):Void on(GameEvent.QUEST_UPDATED, handler);
    public function onInventory(handler:Dynamic):Void on(GameEvent.INVENTORY_CHANGED, handler);
    public function onCombat(handler:Dynamic):Void on(GameEvent.COMBAT_UPDATED, handler);
    public function onPacket(handler:Dynamic):Void on(GameEvent.PACKET_RECEIVED, handler);
}
