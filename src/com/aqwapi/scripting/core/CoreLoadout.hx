package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreLoadout {
    public function new() {}
    public function equipClass(className:String):Bool return Api.combat != null && Api.combat.equipLoadout(className);
    public function equip(item:Dynamic):Void if (Api.inventory != null) Api.inventory.equip(item);
    public function save():Array<Dynamic> return Api.inventory != null ? cast Api.inventory.storeGear() : [];
    public function restore():Void if (Api.inventory != null) Api.inventory.restoreGear();
    public function currentClass():String return Api.player != null ? Api.player.className : "";
}
