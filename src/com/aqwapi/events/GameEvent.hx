package com.aqwapi.events;

import flash.events.Event;

class GameEvent extends Event {
    public static inline var ZONE_ENTERED:String = "zoneEntered";
    public static inline var QUEST_UPDATED:String = "questUpdated";
    public static inline var INVENTORY_CHANGED:String = "inventoryChanged";
    public static inline var CHAT_MESSAGE:String = "chatMessage";
    public static inline var SOCIAL_UPDATED:String = "socialUpdated";
    public static inline var GUILD_UPDATED:String = "guildUpdated";
    public static inline var PVP_UPDATED:String = "pvpUpdated";
    public static inline var HOUSE_UPDATED:String = "houseUpdated";
    /** Raw combat response. `data.command` is the wire command and `data.payload` its payload. */
    public static inline var COMBAT_UPDATED:String = "combatUpdated";

    public var data:Dynamic;

    public function new(type:String, data:Dynamic = null, bubbles:Bool = false, cancelable:Bool = false) {
        super(type, bubbles, cancelable);
        this.data = data;
    }

    override public function clone():Event {
        return new GameEvent(type, data, bubbles, cancelable);
    }
}
