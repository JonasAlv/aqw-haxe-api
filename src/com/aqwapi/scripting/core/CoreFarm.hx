package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreFarm {
    public var hunt:CoreHunt;
    public var drops:CoreDrops;
    public var recovery:CoreRecovery;
    public function new(hunt:CoreHunt, drops:CoreDrops, recovery:CoreRecovery) { this.hunt = hunt; this.drops = drops; this.recovery = recovery; }
    public function item(monster:Dynamic, itemName:String, quantity:Int = 1, mapName:String = null, temp:Bool = false):Bool { if (Api.inventory != null && Api.inventory.getQuantity(itemName) >= quantity) return true; if (!recovery.maintain()) return false; return hunt.item(monster, itemName, quantity, mapName, temp); }
    public function kills(monster:Dynamic, count:Int, mapName:String = null):Bool { if (count <= 0) return true; if (mapName != null && mapName != "" && !hunt.travel.ensure(mapName)) return false; return hunt.combat.hunt(monster, count); }
    public function collect(itemName:String = "all"):Int return drops.pickup(itemName);
    public function stop():Void hunt.stop();
}
