package com.aqwapi.events;

import flash.events.Event;

class GameEvent extends Event {
    public static inline var ZONE_ENTERED:String = "zoneEntered";
    public static inline var QUEST_UPDATED:String = "questUpdated";
    public static inline var INVENTORY_CHANGED:String = "inventoryChanged";

    public var data:Dynamic;

    public function new(type:String, data:Dynamic = null, bubbles:Bool = false, cancelable:Bool = false) {
        super(type, bubbles, cancelable);
        this.data = data;
    }

    override public function clone():Event {
        return new GameEvent(type, data, bubbles, cancelable);
    }
}
