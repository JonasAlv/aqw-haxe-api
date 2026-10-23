package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreDrops {
    public function new() {}
    public function track(item:Dynamic):Void if (Api.drop != null) Api.drop.requestedDrops.set(Std.string(item), com.aqwapi.utils.ApiTime.now());
    public function pickup(itemName:String = "all"):Int return Api.drop != null ? Api.drop.pickup(itemName) : 0;
    public function accept(itemName:String = "all"):Int return Api.drop != null ? Api.drop.accept(itemName) : 0;
    public function acceptAll(enabled:Bool = true):Int return Api.drop != null ? Api.drop.acceptAllDrops(enabled) : 0;
    public function acceptAC(enabled:Bool = true):Int return Api.drop != null ? Api.drop.acceptACDrops(enabled) : 0;
    public function hasTarget(item:Dynamic):Bool return Api.drop != null && Api.drop.isTargetDrop(item);
    public function pendingCount():Int return Api.drop != null ? Api.drop.pendingDrops.length : 0;
}
