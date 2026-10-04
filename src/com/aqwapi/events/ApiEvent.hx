package com.aqwapi.events;

import flash.events.Event;

class ApiEvent extends Event {
    public static inline var NOTIFICATION:String = "apiNotification";
    public static inline var STICKY_NOTIFICATION:String = "apiStickyNotification";
    public static inline var REMOVE_STICKY:String = "apiRemoveSticky";
    public static inline var SCRIPT_STARTED:String = "apiScriptStarted";
    public static inline var SCRIPT_STOPPED:String = "apiScriptStopped";
    public static inline var COMBAT_TOGGLED:String = "apiCombatToggled";

    public var message:String;
    public var data:Dynamic;

    public function new(type:String, message:String = "", data:Dynamic = null, bubbles:Bool = false, cancelable:Bool = false) {
        super(type, bubbles, cancelable);
        this.message = message;
        this.data = data;
    }

    override public function clone():Event {
        return new ApiEvent(type, message, data, bubbles, cancelable);
    }
}
