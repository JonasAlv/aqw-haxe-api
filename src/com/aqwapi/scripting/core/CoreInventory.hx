package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreInventory {
    public function new() {}
    public function has(item:Dynamic, quantity:Int = 1):Bool return Api.inventory != null && Api.inventory.hasItem(item, quantity);
    public function quantity(item:Dynamic):Int return Api.inventory != null ? Api.inventory.getQuantity(item) : 0;
    public function questQuantity(item:String):Int return Api.inventory != null ? Api.inventory.getQuestQuantity(item) : 0;
    public function equip(item:Dynamic):Void if (Api.inventory != null) Api.inventory.equip(item);
    public function bank(items:Dynamic):Void if (Api.inventory != null) Api.inventory.bank(items);
    public function unbank(items:Dynamic):Void if (Api.inventory != null) Api.inventory.unbank(items);
    public function storeGear(items:Dynamic = null):Array<Dynamic> return Api.inventory != null ? cast Api.inventory.storeGear(items) : [];
    public function restoreGear():Void if (Api.inventory != null) Api.inventory.restoreGear();
    public function hasSpaceFor(item:Dynamic, quantity:Int = 1):Bool return Api.inventory != null && Api.inventory.hasSpaceFor(item, quantity);
    public function freeSlots():Int return Api.inventory != null ? Api.inventory.freeSlots : 0;
}
