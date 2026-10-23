package com.aqwapi.scripting.core;
import com.aqwapi.Api;
import com.aqwapi.data.EntityDTO;

class CoreBoss {
    public var combat:CoreCombat;
    public var target:CoreTarget;
    public function new(combat:CoreCombat, target:CoreTarget) { this.combat = combat; this.target = target; }
    public function engage(boss:Dynamic, mapName:String = null):Bool { if (mapName != null && mapName != "" && Api.map != null && !Api.map.ensure(mapName)) return false; if (!target.lock(boss)) return false; combat.start(true); return true; }
    public function shielded(auraName:String):Bool return Api.player != null && Api.player.target != null && Api.player.target.getAura(auraName) != null;
    public function stopOnShield(auraName:String):Bool { var active = shielded(auraName); if (active) combat.stop(); return !active; }
    public function alive():Bool { var t:EntityDTO = target.current(); return t != null && t.alive; }
}
