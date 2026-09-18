package com.aqwapi.managers;

import com.aqwapi.interfaces.IScriptCombat;
import com.aqwapi.modules.CombatManager;
import com.aqwapi.AqwApi;

class ScriptCombat {
    private var _game:AQWGame;

    public function new(gameReference:AQWGame) {
        _game = gameReference;
    }

    public function attack(monsterName:String):Void {
        if (_game == null || _game.world == null || _game.world.myAvatar == null) return;
        var targetMonster:Dynamic = null;
        var sName:String = (monsterName != null) ? monsterName : "*";
        var targetName:String = sName.toLowerCase();

        // 1. Wildcard / any monster in current cell
        if (targetName == "*" || targetName == "any" || targetName == "") {
            var currentCell = (_game.world.strFrame != null) ? Std.string(_game.world.strFrame) : "";
            var living = AqwApi.monsters.getByCell(currentCell);
            for (m in living) {
                if (m != null && m.alive && m.raw != null && Reflect.field(m.raw, "pMC") != null) {
                    targetMonster = m.raw;
                    break;
                }
            }
        }

        // 2. MonMapID integer lookup (native world.getMonster(int))
        if (targetMonster == null) {
            var idInt:Null<Int> = Std.parseInt(sName);
            if (idInt != null && idInt > 0 && _game.world.getMonster != null) {
                try {
                    var avt:Dynamic = _game.world.getMonster(idInt);
                    if (avt != null && Reflect.field(avt, "pMC") != null) {
                        targetMonster = avt;
                    }
                } catch (e:Dynamic) {}
            }
        }

        // 3. Fallback to findByMapId
        if (targetMonster == null) {
            var ent:com.aqwapi.data.EntityDTO = AqwApi.monsters.findByMapId(sName, true);
            if (ent != null && ent.raw != null && Reflect.field(ent.raw, "pMC") != null) {
                targetMonster = ent.raw;
            }
        }

        // 4. Fallback to findByName
        if (targetMonster == null) {
            var entName:com.aqwapi.data.EntityDTO = AqwApi.monsters.findByName(sName, true);
            if (entName != null && entName.raw != null && Reflect.field(entName.raw, "pMC") != null) {
                targetMonster = entName.raw;
            }
        }

        if (targetMonster != null) {
            try {
                if (Reflect.field(targetMonster, "pMC") != null) {
                    if (_game.world.setTarget != null) _game.world.setTarget(targetMonster);
                    if (_game.world.approachTarget != null) _game.world.approachTarget();
                }
            } catch (e:Dynamic) {}
        }
    }

    public function cancelAutoAttack():Void {
        if (_game == null || _game.world == null) return;
        try {
            if (_game.world.cancelAutoAttack != null) {
                _game.world.cancelAutoAttack();
            }
        } catch (e:Dynamic) {}
    }

    public function cancelTarget():Void {
        if (_game == null || _game.world == null) return;
        try {
            if (_game.world.cancelTarget != null) {
                _game.world.cancelTarget();
            }
        } catch (e:Dynamic) {}
    }

    public function useSkill(index:Int):Bool {
        return CombatManager.tryFireSkillPublic(index);
    }

    public function canUseSkill(index:Int):Bool {
        return CombatManager.canFireSkill(index);
    }

    public function dropCombat():Void {
        cancelAutoAttack();
        cancelTarget();
        if (_game == null || _game.world == null || _game.world.moveToCell == null) return;
        try {
            var currentCell:String = _game.world.strFrame;
            var currentPad:String = _game.world.strPad;
            if (currentCell != null && currentPad != null && currentCell != "") {
                _game.world.moveToCell(currentCell, currentPad);
            }
        } catch (e:Dynamic) {}
    }

    public function startSmart():Void { CombatManager.start(true, false); }

    public function startCustom(rotation:String):Void {
        if (rotation != null && rotation.length > 0) {
            var rotInts:Array<Int> = [];
            if (rotation.indexOf(",") != -1) {
                var rotParts = rotation.split(",");
                for (rp in rotParts) {
                    var ri = com.aqwapi.utils.AqwUtils.parseInt(rp, -1);
                    if (ri >= 0) rotInts.push(ri);
                }
            } else {
                for (i in 0...rotation.length) {
                    var charVal = com.aqwapi.utils.AqwUtils.parseInt(rotation.charAt(i), -1);
                    if (charVal >= 0) rotInts.push(charVal);
                }
            }
            if (rotInts.length > 0) CombatManager.setCustomRotation(rotInts);
        }
        CombatManager.start(false, false);
    }

    public function stopAuto():Void {
        CombatManager.stop();
        cancelAutoAttack();
    }

    public function equipLoadout(type:String):Bool {
        var c = ""; var m = "";
        type = type.toLowerCase();
        if (type == "farm") { c = CombatManager.farmClass; m = CombatManager.farmMode; }
        else if (type == "solo") { c = CombatManager.soloClass; m = CombatManager.soloMode; }
        else if (type == "boss") { c = CombatManager.bossClass; m = CombatManager.bossMode; }
        else if (type == "dodge") { c = CombatManager.dodgeClass; m = CombatManager.dodgeMode; }
        else return false;
        if (c != null && c != "") AqwApi.inventory.equip(c);
        if (m != null && m != "") CombatManager.skillMode = m;
        return true;
    }

    public var isAutoRunning(get, never):Bool;
    @:getter(isAutoRunning)
    public function get_isAutoRunning_prop():Bool { return CombatManager.IS_ON; }
    public function get_isAutoRunning():Bool { return CombatManager.IS_ON; }

    public var isSmartRunning(get, never):Bool;
    @:getter(isSmartRunning)
    public function get_isSmartRunning_prop():Bool { return CombatManager.IS_ON && CombatManager.isSmart; }
    public function get_isSmartRunning():Bool { return CombatManager.IS_ON && CombatManager.isSmart; }

    public var isCustomRunning(get, never):Bool;
    @:getter(isCustomRunning)
    public function get_isCustomRunning_prop():Bool { return CombatManager.IS_ON && !CombatManager.isSmart; }
    public function get_isCustomRunning():Bool { return CombatManager.IS_ON && !CombatManager.isSmart; }

    public var mode(get, set):String;
    @:getter(mode)
    public function get_mode_prop():String { return CombatManager.skillMode; }
    @:setter(mode)
    public function set_mode_prop(v:String):String { CombatManager.skillMode = v; return v; }
    public function get_mode():String { return CombatManager.skillMode; }
    public function set_mode(v:String):String { CombatManager.skillMode = v; return v; }

    public var farmClass(get, set):String;
    @:getter(farmClass)
    public function get_farmClass_prop():String { return CombatManager.farmClass; }
    @:setter(farmClass)
    public function set_farmClass_prop(v:String):String { CombatManager.farmClass = v; return v; }
    public function get_farmClass():String { return CombatManager.farmClass; }
    public function set_farmClass(v:String):String { CombatManager.farmClass = v; return v; }

    public var farmMode(get, set):String;
    @:getter(farmMode)
    public function get_farmMode_prop():String { return CombatManager.farmMode; }
    @:setter(farmMode)
    public function set_farmMode_prop(v:String):String { CombatManager.farmMode = v; return v; }
    public function get_farmMode():String { return CombatManager.farmMode; }
    public function set_farmMode(v:String):String { CombatManager.farmMode = v; return v; }

    public var soloClass(get, set):String;
    @:getter(soloClass)
    public function get_soloClass_prop():String { return CombatManager.soloClass; }
    @:setter(soloClass)
    public function set_soloClass_prop(v:String):String { CombatManager.soloClass = v; return v; }
    public function get_soloClass():String { return CombatManager.soloClass; }
    public function set_soloClass(v:String):String { CombatManager.soloClass = v; return v; }

    public var soloMode(get, set):String;
    @:getter(soloMode)
    public function get_soloMode_prop():String { return CombatManager.soloMode; }
    @:setter(soloMode)
    public function set_soloMode_prop(v:String):String { CombatManager.soloMode = v; return v; }
    public function get_soloMode():String { return CombatManager.soloMode; }
    public function set_soloMode(v:String):String { CombatManager.soloMode = v; return v; }

    public var bossClass(get, set):String;
    @:getter(bossClass)
    public function get_bossClass_prop():String { return CombatManager.bossClass; }
    @:setter(bossClass)
    public function set_bossClass_prop(v:String):String { CombatManager.bossClass = v; return v; }
    public function get_bossClass():String { return CombatManager.bossClass; }
    public function set_bossClass(v:String):String { CombatManager.bossClass = v; return v; }

    public var bossMode(get, set):String;
    @:getter(bossMode)
    public function get_bossMode_prop():String { return CombatManager.bossMode; }
    @:setter(bossMode)
    public function set_bossMode_prop(v:String):String { CombatManager.bossMode = v; return v; }
    public function get_bossMode():String { return CombatManager.bossMode; }
    public function set_bossMode(v:String):String { CombatManager.bossMode = v; return v; }

    public var dodgeClass(get, set):String;
    @:getter(dodgeClass)
    public function get_dodgeClass_prop():String { return CombatManager.dodgeClass; }
    @:setter(dodgeClass)
    public function set_dodgeClass_prop(v:String):String { CombatManager.dodgeClass = v; return v; }
    public function get_dodgeClass():String { return CombatManager.dodgeClass; }
    public function set_dodgeClass(v:String):String { CombatManager.dodgeClass = v; return v; }

    public var dodgeMode(get, set):String;
    @:getter(dodgeMode)
    public function get_dodgeMode_prop():String { return CombatManager.dodgeMode; }
    @:setter(dodgeMode)
    public function set_dodgeMode_prop(v:String):String { CombatManager.dodgeMode = v; return v; }
    public function get_dodgeMode():String { return CombatManager.dodgeMode; }
    public function set_dodgeMode(v:String):String { CombatManager.dodgeMode = v; return v; }
}
