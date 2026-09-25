package com.aqwapi.managers;

import com.aqwapi.modules.CombatEngine;
import com.aqwapi.AqwApi;

class CombatManager {
    private var _game:AqwGame;

    public function new(gameReference:AqwGame) {
        _game = gameReference;
    }

    private var _infiniteRange:Bool = true;

    public function applyInfiniteRange():Void {
        if (!_infiniteRange || _game == null || _game.world == null || _game.world.actions == null) return;
        try {
            var active:Dynamic = _game.world.actions.active;
            if (active != null) {
                var len:Int = (Reflect.hasField(active, "length")) ? Std.int(active.length) : 6;
                for (i in 0...len) {
                    var act:Dynamic = active[i];
                    if (act != null) {
                        act.range = 20000;
                    }
                }
            }
        } catch (e:Dynamic) {}
    }

    public function setInfiniteRange(enabled:Bool = true):Void {
        _infiniteRange = enabled;
        applyInfiniteRange();
    }

    public function magnetize():Void {
        if (_game == null || _game.world == null || _game.world.myAvatar == null) return;
        try {
            var myAvt:Dynamic = _game.world.myAvatar;
            if (myAvt != null && myAvt.target != null && myAvt.target.pMC != null && myAvt.pMC != null) {
                myAvt.target.pMC.x = myAvt.pMC.x;
                myAvt.target.pMC.y = myAvt.pMC.y;
            }
        } catch (e:Dynamic) {}
    }

    public function attack(monsterName:String):Void {
        if (_game == null || _game.world == null || _game.world.myAvatar == null) return;
        var targetMonster:Dynamic = null;
        var sName:String = (monsterName != null) ? monsterName : "*";
        var targetName:String = sName.toLowerCase();

        // 1. Wildcard / any monster in current cell
        if (targetName == "*" || targetName == "any" || targetName == "") {
            var currentCell = (_game.world.strFrame != null) ? Std.string(_game.world.strFrame) : "";
            var living = AqwApi.monster.getByCell(currentCell);
            for (m in living) {
                if (m != null && m.alive && m.raw != null && Reflect.field(m.raw, "pMC") != null) {
                    targetMonster = m.raw;
                    break;
                }
            }
        }

        // 2. MonMapID integer lookup (native world.getMonster(int))
        if (targetMonster == null) {
            var idInt:Int = com.aqwapi.utils.AqwUtils.parseInt(sName, 0);
            if (idInt > 0 && _game.world.getMonster != null) {
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
            var ent:com.aqwapi.data.EntityDTO = AqwApi.monster.findByMapId(sName, true);
            if (ent != null && ent.raw != null && Reflect.field(ent.raw, "pMC") != null) {
                targetMonster = ent.raw;
            }
        }

        // 4. Fallback to findByName
        if (targetMonster == null) {
            var entName:com.aqwapi.data.EntityDTO = AqwApi.monster.findByName(sName, true);
            if (entName != null && entName.raw != null && Reflect.field(entName.raw, "pMC") != null) {
                targetMonster = entName.raw;
            }
        }

        if (targetMonster != null) {
            try {
                var mc:Dynamic = Reflect.field(targetMonster, "pMC");
                if (mc != null) {
                    if (_game.world.setTarget != null) _game.world.setTarget(targetMonster);
                    applyInfiniteRange();
                }
            } catch (e:Dynamic) {}
        }
    }

    public function approachTarget():Void {
        if (_game == null || _game.world == null) return;
        try {
            var avt:Dynamic = _game.world.myAvatar;
            if (avt != null && avt.target != null && avt.target.pMC != null) {
                if (_game.world.approachTarget != null) _game.world.approachTarget();
            }
        } catch (e:Dynamic) {}
    }

    public function cancelAutoAttack():Void {
        if (_game == null || _game.world == null) return;
        try {
            if (_game.world.cancelAutoAttack != null) {
                _game.world.cancelAutoAttack();
            }
            if (_game.world.autoActionTimer != null) {
                _game.world.autoActionTimer.reset();
            }
            if (_game.world.AATestTimer != null) {
                _game.world.AATestTimer.reset();
            }
        } catch (e:Dynamic) {}
    }

    public function cancelTarget():Void {
        if (_game == null || _game.world == null) return;
        try {
            if (_game.world.cancelTarget != null) {
                _game.world.cancelTarget();
            }
            if (_game.world.myAvatar != null) {
                _game.world.myAvatar.target = null;
            }
        } catch (e:Dynamic) {}
    }

    public function pauseCombat():Void {
        cancelAutoAttack();
        cancelTarget();
    }

    public function useSkill(index:Int):Bool {
        applyInfiniteRange();
        return CombatEngine.tryFireSkillPublic(index);
    }

    public function canUseSkill(index:Int):Bool {
        return CombatEngine.canFireSkill(index);
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

    public function startSmart():Void { CombatEngine.start(true, false); }

    public function startCustom(rotation:String, mode:String = "auto"):Void {
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
            if (rotInts.length > 0) CombatEngine.setCustomRotation(rotInts, mode);
        }
        CombatEngine.start(false, false);
    }

    public function stopAuto():Void {
        CombatEngine.stop();
        cancelAutoAttack();
    }

    public function equipLoadout(type:String):Bool {
        var c = ""; var m = "";
        type = type.toLowerCase();
        if (type == "farm") { c = CombatEngine.farmClass; m = CombatEngine.farmMode; }
        else if (type == "solo") { c = CombatEngine.soloClass; m = CombatEngine.soloMode; }
        else if (type == "boss") { c = CombatEngine.bossClass; m = CombatEngine.bossMode; }
        else if (type == "dodge") { c = CombatEngine.dodgeClass; m = CombatEngine.dodgeMode; }
        else return false;
        if (c != null && c != "" && c != "Current" && AqwApi.inventory != null) AqwApi.inventory.equip(c);
        if (m != null && m != "") CombatEngine.skillMode = m;
        return true;
    }

    public var isAutoRunning(get, never):Bool;
    @:getter(isAutoRunning)
    public function get_isAutoRunning_prop():Bool { return CombatEngine.IS_ON; }
    public function get_isAutoRunning():Bool { return CombatEngine.IS_ON; }

    public var isSmartRunning(get, never):Bool;
    @:getter(isSmartRunning)
    public function get_isSmartRunning_prop():Bool { return CombatEngine.IS_ON && CombatEngine.isSmart; }
    public function get_isSmartRunning():Bool { return CombatEngine.IS_ON && CombatEngine.isSmart; }

    public var isCustomRunning(get, never):Bool;
    @:getter(isCustomRunning)
    public function get_isCustomRunning_prop():Bool { return CombatEngine.IS_ON && !CombatEngine.isSmart; }
    public function get_isCustomRunning():Bool { return CombatEngine.IS_ON && !CombatEngine.isSmart; }

    public var mode(get, set):String;
    @:getter(mode)
    public function get_mode_prop():String { return CombatEngine.skillMode; }
    @:setter(mode)
    public function set_mode_prop(v:String):Void { CombatEngine.skillMode = v; }
    public function get_mode():String { return CombatEngine.skillMode; }
    public function set_mode(v:String):String { CombatEngine.skillMode = v; return v; }

    public var farmClass(get, set):String;
    @:getter(farmClass)
    public function get_farmClass_prop():String { return CombatEngine.farmClass; }
    @:setter(farmClass)
    public function set_farmClass_prop(v:String):Void { CombatEngine.farmClass = v; }
    public function get_farmClass():String { return CombatEngine.farmClass; }
    public function set_farmClass(v:String):String { CombatEngine.farmClass = v; return v; }

    public var farmMode(get, set):String;
    @:getter(farmMode)
    public function get_farmMode_prop():String { return CombatEngine.farmMode; }
    @:setter(farmMode)
    public function set_farmMode_prop(v:String):Void { CombatEngine.farmMode = v; }
    public function get_farmMode():String { return CombatEngine.farmMode; }
    public function set_farmMode(v:String):String { CombatEngine.farmMode = v; return v; }

    public var soloClass(get, set):String;
    @:getter(soloClass)
    public function get_soloClass_prop():String { return CombatEngine.soloClass; }
    @:setter(soloClass)
    public function set_soloClass_prop(v:String):Void { CombatEngine.soloClass = v; }
    public function get_soloClass():String { return CombatEngine.soloClass; }
    public function set_soloClass(v:String):String { CombatEngine.soloClass = v; return v; }

    public var soloMode(get, set):String;
    @:getter(soloMode)
    public function get_soloMode_prop():String { return CombatEngine.soloMode; }
    @:setter(soloMode)
    public function set_soloMode_prop(v:String):Void { CombatEngine.soloMode = v; }
    public function get_soloMode():String { return CombatEngine.soloMode; }
    public function set_soloMode(v:String):String { CombatEngine.soloMode = v; return v; }

    public var bossClass(get, set):String;
    @:getter(bossClass)
    public function get_bossClass_prop():String { return CombatEngine.bossClass; }
    @:setter(bossClass)
    public function set_bossClass_prop(v:String):Void { CombatEngine.bossClass = v; }
    public function get_bossClass():String { return CombatEngine.bossClass; }
    public function set_bossClass(v:String):String { CombatEngine.bossClass = v; return v; }

    public var bossMode(get, set):String;
    @:getter(bossMode)
    public function get_bossMode_prop():String { return CombatEngine.bossMode; }
    @:setter(bossMode)
    public function set_bossMode_prop(v:String):Void { CombatEngine.bossMode = v; }
    public function get_bossMode():String { return CombatEngine.bossMode; }
    public function set_bossMode(v:String):String { CombatEngine.bossMode = v; return v; }

    public var dodgeClass(get, set):String;
    @:getter(dodgeClass)
    public function get_dodgeClass_prop():String { return CombatEngine.dodgeClass; }
    @:setter(dodgeClass)
    public function set_dodgeClass_prop(v:String):Void { CombatEngine.dodgeClass = v; }
    public function get_dodgeClass():String { return CombatEngine.dodgeClass; }
    public function set_dodgeClass(v:String):String { CombatEngine.dodgeClass = v; return v; }

    public var dodgeMode(get, set):String;
    @:getter(dodgeMode)
    public function get_dodgeMode_prop():String { return CombatEngine.dodgeMode; }
    @:setter(dodgeMode)
    public function set_dodgeMode_prop(v:String):Void { CombatEngine.dodgeMode = v; }
    public function get_dodgeMode():String { return CombatEngine.dodgeMode; }
    public function set_dodgeMode(v:String):String { CombatEngine.dodgeMode = v; return v; }

    public var infiniteRange(get, set):Bool;
    @:getter(infiniteRange)
    public function get_infiniteRange_prop():Bool { return _infiniteRange; }
    @:setter(infiniteRange)
    public function set_infiniteRange_prop(v:Bool):Void { setInfiniteRange(v); }
    public function get_infiniteRange():Bool { return _infiniteRange; }
    public function set_infiniteRange(v:Bool):Bool { setInfiniteRange(v); return v; }

    // ==========================================
    // STATIC ENGINE PROXIES (Convenience & Backward Compatibility)
    // ==========================================
    public static inline function init():Void { CombatEngine.init(); }
    public static inline function reloadSkills(silent:Bool = false):Void { CombatEngine.reloadSkills(silent); }
    public static inline function toggleSmart():Void { CombatEngine.toggleSmart(); }
    public static inline function toggleCustom():Void { CombatEngine.toggleCustom(); }
    public static inline function start(smart:Bool, silent:Bool = false):Void { CombatEngine.start(smart, silent); }
    public static inline function stop():Void { CombatEngine.stop(); }
    public static inline function getAvailableModes(className:String):Array<String> { return CombatEngine.getAvailableModes(className); }

    public static var IS_ON(get, set):Bool;
    private static inline function get_IS_ON():Bool { return CombatEngine.IS_ON; }
    private static inline function set_IS_ON(v:Bool):Bool { return CombatEngine.IS_ON = v; }

    public static var isSmart(get, set):Bool;
    private static inline function get_isSmart():Bool { return CombatEngine.isSmart; }
    private static inline function set_isSmart(v:Bool):Bool { return CombatEngine.isSmart = v; }

    public static var skillMode(get, set):String;
    private static inline function get_skillMode():String { return CombatEngine.skillMode; }
    private static inline function set_skillMode(v:String):String { return CombatEngine.skillMode = v; }

    public static var customMode(get, set):String;
    private static inline function get_customMode():String { return CombatEngine.customMode; }
    private static inline function set_customMode(v:String):String { return CombatEngine.customMode = v; }

    public static var staticFarmClass(get, set):String;
    private static inline function get_staticFarmClass():String { return CombatEngine.farmClass; }
    private static inline function set_staticFarmClass(v:String):String { return CombatEngine.farmClass = v; }
}
