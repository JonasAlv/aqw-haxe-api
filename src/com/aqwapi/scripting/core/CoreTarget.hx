package com.aqwapi.scripting.core;
import com.aqwapi.Api;
import com.aqwapi.data.EntityDTO;

class CoreTarget {
    public var lockedId:String = null;
    public var lockedName:String = null;
    public function new() {}
    public function find(nameOrId:Dynamic, cell:String = null):EntityDTO { if (Api.monster == null) return null; if (cell != null && cell != "") return Api.monster.getBestMonsterTargetInCell(cell, nameOrId); var key:String = Std.string(nameOrId); var byName = Api.monster.findByName(key, true); return byName != null ? byName : Api.monster.findByMapId(key, true); }
    public function lock(nameOrId:Dynamic, cell:String = null):Bool { var target = find(nameOrId, cell); if (target == null || !target.isMonster || !target.alive) return false; target.select(); lockedId = target.mapId != "" ? target.mapId : target.id; lockedName = target.name; return true; }
    public function current():EntityDTO return Api.player != null ? Api.player.target : null;
    public function clear():Void { lockedId = null; lockedName = null; if (Api.combat != null) Api.combat.cancelTarget(); }
    public function valid():Bool { var t = current(); return t != null && t.isMonster && t.alive && (lockedId == null || lockedId == "" || t.mapId == lockedId || t.id == lockedId); }
    public function nearest(nameOrId:Dynamic = "*"):EntityDTO {
        if (Api.monster == null) return null;
        var cell:String = Api.player != null ? Api.player.cell : null;
        return Api.monster.getBestMonsterTargetInCell(cell, nameOrId);
    }
}
