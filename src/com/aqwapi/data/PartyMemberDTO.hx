package com.aqwapi.data;

import com.aqwapi.Api;

/**
 * Data Transfer Object representing a Party Member in AQW.
 * Holds real-time stats (HP, MaxHP, MP, MaxMP, Class, Level, Shield),
 * range/cell presence, and targeting capability.
 */
class PartyMemberDTO {
    public var username:String = "";
    public var level:Int = 1;
    public var className:String = "";
    public var hp:Int = 0;
    public var maxHp:Int = 100;
    public var mp:Int = 0;
    public var maxMp:Int = 100;
    public var shield:Int = 0;
    public var isLeader:Bool = false;
    public var isMe:Bool = false;
    public var inRange:Bool = true;
    public var inCell:Bool = true;
    public var raw:Dynamic = null;
    public var avatar:Dynamic = null;

    public var hpRatio(get, never):Float;
    public inline function get_hpRatio():Float {
        if (maxHp <= 0) return 0.0;
        var r:Float = hp / maxHp;
        return (r < 0.0) ? 0.0 : (r > 1.0 ? 1.0 : r);
    }

    public var hpPercent(get, never):Float;
    public inline function get_hpPercent():Float {
        return Math.round(hpRatio * 100.0);
    }

    public var mpRatio(get, never):Float;
    public inline function get_mpRatio():Float {
        if (maxMp <= 0) return 0.0;
        var r:Float = mp / maxMp;
        return (r < 0.0) ? 0.0 : (r > 1.0 ? 1.0 : r);
    }

    public var mpPercent(get, never):Float;
    public inline function get_mpPercent():Float {
        return Math.round(mpRatio * 100.0);
    }

    public var isAlive(get, never):Bool;
    public inline function get_isAlive():Bool {
        return hp > 0;
    }

    public function new() {}

    /**
     * Instantly targets this party member in-game if they are in the same cell.
     */
    public function target():Bool {
        return (Api.party != null) ? Api.party.targetMember(username) : false;
    }
}
