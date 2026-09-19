package com.aqwapi.managers;

import com.aqwapi.data.EntityDTO;

class ScriptPlayer {

    private var _game:AQWGame;

    public function new(gameReference:AQWGame) {
        _game = gameReference;
    }

    private function _avatar():Dynamic {
        return (_game != null && _game.world != null) ? _game.world.myAvatar : null;
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
    public function get_cell_prop():String { return (_game != null && _game.world != null) ? _ds(_game.world.strFrame) : ""; }
    public function get_cell():String { return (_game != null && _game.world != null) ? _ds(_game.world.strFrame) : ""; }

    public var pad(get, never):String;
    @:getter(pad)
    public function get_pad_prop():String { return (_game != null && _game.world != null) ? _ds(_game.world.strPad) : ""; }
    public function get_pad():String { return (_game != null && _game.world != null) ? _ds(_game.world.strPad) : ""; }

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
        if (_game != null && _game.world != null && Reflect.hasField(_game.world, "setSpawnPoint")) {
            var c = (cell != null && cell != "") ? cell : (_game.world.strFrame != null ? Std.string(_game.world.strFrame) : "Enter");
            var p = (pad != null && pad != "") ? pad : (_game.world.strPad != null ? Std.string(_game.world.strPad) : "Spawn");
            try { _game.world.setSpawnPoint(c, p); } catch (e:Dynamic) {}
        }
    }
}

