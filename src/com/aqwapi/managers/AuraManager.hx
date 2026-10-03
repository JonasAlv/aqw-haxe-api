package com.aqwapi.managers;

import com.aqwapi.Api;
import com.aqwapi.Game;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiUtils;

class AuraManager {
    private var _game:Game;

    public function new(gameReference:Game) {
        _game = gameReference;
    }

    private inline function _g():Game {
        return (_game != null) ? _game : Api.game;
    }

    /**
     * Resolves the raw auras collection for player or target.
     */
    public function getRawAuras(target:String = "player", ?customWorld:Dynamic, ?customAvatar:Dynamic, ?customTarget:Dynamic):Dynamic {
        var g = _g();
        var world:Dynamic = (customWorld != null) ? customWorld : ((g != null) ? g.world : null);
        if (world == null) return null;

        var avatar:Dynamic = (customAvatar != null) ? customAvatar : world.myAvatar;
        var tObj:Dynamic = (customTarget != null) ? customTarget : (avatar != null ? avatar.target : null);
        var isPlayer = (target == null || target == "" || target.toLowerCase() == "self" || target.toLowerCase() == "player" || target.toLowerCase() == "me");

        var auras:Dynamic = null;
        if (isPlayer) {
            if (avatar != null) {
                if (world.uoTree != null && avatar.pnm != null) {
                    try {
                        var uo = Reflect.field(world.uoTree, Std.string(avatar.pnm).toLowerCase());
                        if (uo != null && uo.auras != null) auras = uo.auras;
                    } catch (_:Dynamic) {}
                }
                if (auras == null) {
                    try {
                        if (world.uoTreeLeaf != null && avatar.pnm != null) {
                            var n:Dynamic = world.uoTreeLeaf(avatar.pnm);
                            if (n != null && n.auras != null) auras = n.auras;
                        }
                    } catch (_:Dynamic) {}
                }
                if (auras == null && avatar.auras != null) auras = avatar.auras;
                if (auras == null && avatar.dataLeaf != null && avatar.dataLeaf.auras != null) auras = avatar.dataLeaf.auras;
            }
        } else {
            if (tObj != null) {
                try {
                    var mmid:Dynamic = null;
                    if (tObj.dataLeaf != null && tObj.dataLeaf.MonMapID != null) mmid = tObj.dataLeaf.MonMapID;
                    else if (tObj.objData != null && tObj.objData.MonMapID != null) mmid = tObj.objData.MonMapID;
                    if (mmid != null && world.monTree != null) {
                        var monObj = Reflect.field(world.monTree, Std.string(mmid));
                        if (monObj != null && monObj.auras != null) auras = monObj.auras;
                    }
                } catch (_:Dynamic) {}
                if (auras == null && world.uoTree != null) {
                    try {
                        var tpnm:String = null;
                        if (tObj.pnm != null) tpnm = Std.string(tObj.pnm);
                        else if (tObj.dataLeaf != null && tObj.dataLeaf.strUsername != null) tpnm = Std.string(tObj.dataLeaf.strUsername);
                        if (tpnm != null && tpnm != "") {
                            var uo = Reflect.field(world.uoTree, tpnm.toLowerCase());
                            if (uo != null && uo.auras != null) auras = uo.auras;
                        }
                    } catch (_:Dynamic) {}
                }
                if (auras == null && tObj.dataLeaf != null && tObj.dataLeaf.auras != null) {
                    auras = tObj.dataLeaf.auras;
                }
                if (auras == null && tObj.auras != null) {
                    auras = tObj.auras;
                }
            }
        }
        return auras;
    }

    /**
     * Checks if player or target currently has the specified aura.
     */
    public function has(auraName:String, target:String = "player", ?world:Dynamic, ?avatar:Dynamic, ?targetObj:Dynamic):Bool {
        return getStacks(auraName, target, world, avatar, targetObj) > 0;
    }

    /**
     * Returns the stack count of the specified aura.
     */
/**
     * Normalises an aura name for lookup.
     *
     * The raw compare is an exact lowercased match, which makes a hand-written config
     * silently useless the moment it disagrees with the game by punctuation - e.g.
     * `aura(self:Rounds Empty!)` never matched, so the bracket degraded to `0 <= 1`
     * and always passed. Trim and drop trailing punctuation so a cosmetic typo
     * degrades to a match instead of a dead condition.
     */
    private static function normalizeAuraName(n:String):String {
        if (n == null) return "";
        var s:String = StringTools.trim(n).toLowerCase();
        while (s.length > 0) {
            var last:String = s.charAt(s.length - 1);
            if (last == "!" || last == "." || last == " ") {
                s = s.substr(0, s.length - 1);
            } else {
                break;
            }
        }
        return s;
    }

    public function getStacks(auraName:String, target:String = "player", ?world:Dynamic, ?avatar:Dynamic, ?targetObj:Dynamic):Float {
        if (auraName == null || auraName == "") return 0.0;
        var auras = getRawAuras(target, world, avatar, targetObj);
        if (auras == null) return 0.0;

        var search:String = normalizeAuraName(auraName);
        if (search == "") return 0.0;
        var maxVal:Float = 0.0;

        var processAura = function(a:Dynamic):Void {
            if (a == null) return;
            if (a.e == 1 || a.e == "1" || a.e == true) return;
            var name:String = (a.nam != null) ? Std.string(a.nam) : ((a.name != null) ? Std.string(a.name) : ((a.sName != null) ? Std.string(a.sName) : ""));
            if (name != "" && normalizeAuraName(name) == search) {
                var val:Float = 1.0;
                if (a.val != null) val = ApiUtils.parseFloat(a.val, 1.0);
                else if (a.value != null) val = ApiUtils.parseFloat(a.value, 1.0);
                else if (a.stack != null) val = ApiUtils.parseFloat(a.stack, 1.0);
                if (val > maxVal) maxVal = val;
            }
        };

        if (Std.isOfType(auras, Array)) {
            for (a in (cast auras : Array<Dynamic>)) processAura(a);
        } else {
            for (k in Reflect.fields(auras)) processAura(Reflect.field(auras, k));
        }
        return maxVal;
    }

    /**
     * Returns remaining time in seconds for the specified aura.
     */
    public function getRemaining(auraName:String, target:String = "player", ?world:Dynamic, ?avatar:Dynamic, ?targetObj:Dynamic):Float {
        if (auraName == null || auraName == "") return 0.0;
        var auras = getRawAuras(target, world, avatar, targetObj);
        if (auras == null) return 0.0;

var search:String = normalizeAuraName(auraName);
        if (search == "") return 0.0;
        var maxRemaining:Float = 0.0;

        var processAura = function(a:Dynamic):Void {
            if (a == null) return;
            if (a.e == 1 || a.e == "1" || a.e == true) return;
            var name:String = (a.nam != null) ? Std.string(a.nam) : ((a.name != null) ? Std.string(a.name) : ((a.sName != null) ? Std.string(a.sName) : ""));
            if (name != "" && normalizeAuraName(name) == search) {
                var dur:Float = (a.dur != null) ? ApiUtils.parseFloat(a.dur, 0.0) : 0.0;
                if (dur <= 0) return;
                var ts:Float = (a.ts != null) ? ApiUtils.parseFloat(a.ts, 0.0) : 0.0;
                if (ts <= 0) {
                    if (dur > maxRemaining) maxRemaining = dur;
                    return;
                }
                var tsMs:Float = (ts < 10000000000.0) ? (ts * 1000.0) : ts;
                var nowMs:Float = ApiTime.epochMs();
                var rem:Float = (tsMs + (dur * 1000.0) - nowMs) / 1000.0;
                if (rem > maxRemaining) maxRemaining = rem;
            }
        };

        if (Std.isOfType(auras, Array)) {
            for (a in (cast auras : Array<Dynamic>)) processAura(a);
        } else {
            for (k in Reflect.fields(auras)) processAura(Reflect.field(auras, k));
        }
        return maxRemaining > 0 ? maxRemaining : 0.0;
    }

    /**
     * Checks whether combat should pause due to forbidden target reflect/shield auras.
     */
    public function shouldStopForTargetAuras(globalStopAuras:Array<String>, modeConfig:Dynamic, ?world:Dynamic, ?avatar:Dynamic, ?targetObj:Dynamic):Bool {
        var aurasToCheck:Array<String> = [];
        if (globalStopAuras != null) {
            for (a in globalStopAuras) if (a != null && a != "") aurasToCheck.push(a.toLowerCase());
        }
        if (modeConfig != null && modeConfig.stopOnTargetAuras != null) {
            var val:Dynamic = modeConfig.stopOnTargetAuras;
            if (Std.isOfType(val, Array)) {
                for (item in (cast val : Array<Dynamic>)) {
                    if (item != null && Std.string(item) != "") aurasToCheck.push(Std.string(item).toLowerCase());
                }
            } else if (Std.isOfType(val, String)) {
                var parts:Array<String> = Std.string(val).split(",");
                for (p in parts) {
                    var tr = StringTools.trim(p).toLowerCase();
                    if (tr != "") aurasToCheck.push(tr);
                }
            }
        }
        if (aurasToCheck.length == 0) return false;

        for (aName in aurasToCheck) {
            if (getStacks(aName, "target", world, avatar, targetObj) > 0) {
                return true;
            }
        }
        return false;
    }
}
