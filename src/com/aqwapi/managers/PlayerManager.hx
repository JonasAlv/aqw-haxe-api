package com.aqwapi.managers;

import com.aqwapi.Api;
import com.aqwapi.data.EntityDTO;
import com.aqwapi.Game;

class PlayerManager {

    private var _game:Game;

    public function new(gameReference:Game) {
        _game = gameReference;
    }

    private inline function _g():Game {
        return (_game != null) ? _game : Api.game;
    }

    private function _avatar():Dynamic {
        var g = _g();
        return (g != null && g.world != null) ? g.world.myAvatar : null;
    }

    private inline function _di(val:Dynamic, def:Int = 0):Int {
        return val != null ? Std.int(untyped val) : def;
    }

    private inline function _ds(val:Dynamic, def:String = ""):String {
        return val != null ? Std.string(val) : def;
    }

    public var state(get, never):Int;
    @:getter(state)
    public function get_state_prop():Int { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _di(a.dataLeaf.intState) : 0; }
    public function get_state():Int { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _di(a.dataLeaf.intState) : 0; }

    public var hp(get, never):Int;
    @:getter(hp)
    public function get_hp_prop():Int { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _di(a.dataLeaf.intHP) : 0; }
    public function get_hp():Int { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _di(a.dataLeaf.intHP) : 0; }

    public var maxHp(get, never):Int;
    @:getter(maxHp)
    public function get_maxHp_prop():Int { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _di(a.dataLeaf.intHPMax) : 0; }
    public function get_maxHp():Int { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _di(a.dataLeaf.intHPMax) : 0; }

    public var mp(get, never):Int;
    @:getter(mp)
    public function get_mp_prop():Int { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _di(a.dataLeaf.intMP) : 0; }
    public function get_mp():Int { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _di(a.dataLeaf.intMP) : 0; }

    public var maxMp(get, never):Int;
    @:getter(maxMp)
    public function get_maxMp_prop():Int { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _di(a.dataLeaf.intMPMax) : 0; }
    public function get_maxMp():Int { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _di(a.dataLeaf.intMPMax) : 0; }

    public var gold(get, never):Int;
    @:getter(gold)
    public function get_gold_prop():Int { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _di(a.dataLeaf.intGold) : 0; }
    public function get_gold():Int { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _di(a.dataLeaf.intGold) : 0; }

    public var username(get, never):String;
    @:getter(username)
    public function get_username_prop():String { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _ds(a.dataLeaf.strUsername) : ""; }
    public function get_username():String { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _ds(a.dataLeaf.strUsername) : ""; }

    public var isAlive(get, never):Bool;
    @:getter(isAlive)
    public function get_isAlive_prop():Bool { var a = _avatar(); return a != null && a.dataLeaf != null && _di(a.dataLeaf.intHP) > 0 && _di(a.dataLeaf.intState) > 0; }
    public function get_isAlive():Bool { var a = _avatar(); return a != null && a.dataLeaf != null && _di(a.dataLeaf.intHP) > 0 && _di(a.dataLeaf.intState) > 0; }

    public var isInCombat(get, never):Bool;
    @:getter(isInCombat)
    public function get_isInCombat_prop():Bool { var a = _avatar(); return a != null && (untyped a.intCombatOn) == 1; }
    public function get_isInCombat():Bool { var a = _avatar(); return a != null && (untyped a.intCombatOn) == 1; }

    public var cell(get, never):String;
    @:getter(cell)
    public function get_cell_prop():String { var g = _g(); return (g != null && g.world != null) ? _ds(g.world.strFrame) : ""; }
    public function get_cell():String { var g = _g(); return (g != null && g.world != null) ? _ds(g.world.strFrame) : ""; }

    public var pad(get, never):String;
    @:getter(pad)
    public function get_pad_prop():String { var g = _g(); return (g != null && g.world != null) ? _ds(g.world.strPad) : ""; }
    public function get_pad():String { var g = _g(); return (g != null && g.world != null) ? _ds(g.world.strPad) : ""; }

    public var level(get, never):Int;
    @:getter(level)
    public function get_level_prop():Int { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _di(a.dataLeaf.intLevel) : 0; }
    public function get_level():Int { var a = _avatar(); return (a != null && a.dataLeaf != null) ? _di(a.dataLeaf.intLevel) : 0; }

    public var target(get, never):EntityDTO;
    @:getter(target)
    public function get_target_prop():EntityDTO {
        var a = _avatar();
        if (a != null && a.target != null) return new EntityDTO(a.target);
        return null;
    }
    public function get_target():EntityDTO {
        var a = _avatar();
        if (a != null && a.target != null) return new EntityDTO(a.target);
        return null;
    }

    public function getAura(auraName:String):Dynamic {
        var a = _avatar();
        if (a == null) return null;
        var ent = new EntityDTO(a);
        return ent.getAura(auraName);
    }

    public function hasAura(auraName:String):Bool {
        return getAura(auraName) != null;
    }

    public function setSpawnPoint(cell:String = null, pad:String = null):Void {
        var g = _g();
        if (g != null && g.world != null && Reflect.hasField(g.world, "setSpawnPoint")) {
            var c = (cell != null && cell != "") ? cell : (g.world.strFrame != null ? Std.string(g.world.strFrame) : "Enter");
            var p = (pad != null && pad != "") ? pad : (g.world.strPad != null ? Std.string(g.world.strPad) : "Spawn");
            try { g.world.setSpawnPoint(c, p); } catch (e:Dynamic) {}
        }
    }

    public var className(get, never):String;
    @:getter(className)
    public function get_className_prop():String { return get_className(); }
    public function get_className():String {
        var a = _avatar();
        if (a != null) {
            if (a.objData != null && a.objData.strClassName != null) {
                var c:String = Std.string(a.objData.strClassName);
                if (c != "" && c != "null") return c;
            }
            if (a.items != null && Std.isOfType(a.items, Array)) {
                var arr:Array<Dynamic> = cast a.items;
                for (it in arr) {
                    if (it != null && (it.bEquip == 1 || it.bEquip == "1" || it.bEquip == true)) {
                        if (it.sES == "ar" || it.sType == "Class") {
                            if (it.sName != null) {
                                var s:String = Std.string(it.sName);
                                if (s != "" && s != "null") return s;
                            }
                        }
                    }
                }
            }
        }
        return "";
    }

    public var coins(get, never):Int;
    @:getter(coins)
    public function get_coins_prop():Int { return get_coins(); }
    public function get_coins():Int {
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intCoins != null) return _di(a.objData.intCoins);
        if (a != null && a.dataLeaf != null && a.dataLeaf.intCoins != null) return _di(a.dataLeaf.intCoins);
        return 0;
    }

    public var ac(get, never):Int;
    @:getter(ac)
    public function get_ac_prop():Int { return get_coins(); }
    public inline function get_ac():Int { return get_coins(); }

    public var xp(get, never):Int;
    @:getter(xp)
    public function get_xp_prop():Int { return get_xp(); }
    public function get_xp():Int {
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intExp != null) return _di(a.objData.intExp);
        if (a != null && a.dataLeaf != null && a.dataLeaf.intExp != null) return _di(a.dataLeaf.intExp);
        return 0;
    }

    public var maxXp(get, never):Int;
    @:getter(maxXp)
    public function get_maxXp_prop():Int { return get_maxXp(); }
    public function get_maxXp():Int {
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intExpToLevel != null) return _di(a.objData.intExpToLevel);
        return 0;
    }

    public var isMember(get, never):Bool;
    @:getter(isMember)
    public function get_isMember_prop():Bool { return get_isMember(); }
    public function get_isMember():Bool {
        var a = _avatar();
        if (a != null) {
            if (a.isUpgraded != null) {
                try { return a.isUpgraded() == true; } catch (_:Dynamic) {}
            }
            if (a.objData != null && a.objData.iUpgDays != null) return _di(a.objData.iUpgDays) > 0;
        }
        return false;
    }

    public var x(get, never):Float;
    @:getter(x)
    public function get_x_prop():Float { return get_x(); }
    public function get_x():Float {
        var a = _avatar();
        return (a != null && a.pMC != null) ? a.pMC.x : 0.0;
    }

    public var y(get, never):Float;
    @:getter(y)
    public function get_y_prop():Float { return get_y(); }
    public function get_y():Float {
        var a = _avatar();
        return (a != null && a.pMC != null) ? a.pMC.y : 0.0;
    }
}
