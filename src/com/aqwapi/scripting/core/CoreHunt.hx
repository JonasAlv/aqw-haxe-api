package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreHunt {
    public var combat:CoreCombat;
    public var travel:CoreTravel;
    public var recovery:CoreRecovery;
    public function new(combat:CoreCombat, travel:CoreTravel, recovery:CoreRecovery) { this.combat = combat; this.travel = travel; this.recovery = recovery; }
    public function monster(monster:Dynamic, mapName:String = null, cell:String = null):Bool { if (mapName != null && mapName != "" && !travel.ensure(mapName, cell)) return false; if (!recovery.ensureAlive()) return false; return combat.hunt(monster); }
    public function item(monster:Dynamic, item:String, quantity:Int = 1, mapName:String = null, temp:Bool = false):Bool { if (mapName != null && mapName != "" && !travel.ensure(mapName)) return false; if (Api.inventory != null && Api.inventory.hasItem(item, quantity)) return true; return combat.farmItem(monster, item, quantity, temp); }
    public function stop():Void combat.stop();
}
