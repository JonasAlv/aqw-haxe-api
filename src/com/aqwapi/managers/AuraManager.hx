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
                // New game client (Skua e127162) populates hudAuras on the leaf instead of auras.
                // Fall back to it so reads don't go stale.
                if (auras == null && avatar.dataLeaf != null && avatar.dataLeaf.hudAuras != null) auras = avatar.dataLeaf.hudAuras;
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
        return TRAILING_PUNCT.replace(s, "");
    }

    /** Trailing `!` `.` `*` `?` and any whitespace. Anchored at the end so internal
     *  spaces inside multi-word aura names survive intact. Note: no backslash escapes
     *  inside the class - Haxe rejects `\!` and friends in a `~/../` literal. */
    private static var TRAILING_PUNCT = ~/[!.*?\s]+$/;

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
                // If aura has duration and start timestamp, check if it already expired
                if (a.dur != null) {
                    var dur:Float = ApiUtils.parseFloat(a.dur, 0.0);
                    if (dur > 0) {
                        var ts:Float = (a.ts != null) ? ApiUtils.parseFloat(a.ts, 0.0) : 0.0;
                        if (ts > 0) {
                            var tsMs:Float = (ts < 10000000000.0) ? (ts * 1000.0) : ts;
                            var nowMs:Float = ApiTime.epochMs();
                            if (nowMs >= tsMs + (dur * 1000.0)) return; // Expired by time!
                        }
                    }
                }
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
     * Standard AQW boss counter-attack / reflect / invulnerability auras.
     * When counterHandler is enabled, attacks are paused while any of these are active on the target.
     */
    public static var DEFAULT_COUNTER_AURAS:Array<String> = [
        "counter attack",
        "retaliate",
        "fox",
        "damage reflect",
        "reflect",
        "reflective shield",
        "talon twisting"
    ];

    /**
     * Checks target auras and returns the name of any active counter/shield/pause aura.
     * Evaluates built-in counter auras (if enableCounterHandler is true), globalStopAuras,
     * and modeConfig.stopOnTargetAuras. Returns null if no forbidden aura is active.
     */
    public function findTriggeringTargetAura(enableCounterHandler:Bool = false, ?globalStopAuras:Array<String>, ?modeConfig:Dynamic, ?world:Dynamic, ?avatar:Dynamic, ?targetObj:Dynamic):String {
        var aurasToCheck:Array<String> = [];
        if (enableCounterHandler) {
            for (a in DEFAULT_COUNTER_AURAS) aurasToCheck.push(a);
        }
        if (globalStopAuras != null) {
            for (a in globalStopAuras) {
                if (a != null && a != "") {
                    var tr = normalizeAuraName(a);
                    if (tr != "" && aurasToCheck.indexOf(tr) == -1) aurasToCheck.push(tr);
                }
            }
        }
        if (modeConfig != null && modeConfig.stopOnTargetAuras != null) {
            var val:Dynamic = modeConfig.stopOnTargetAuras;
            if (Std.isOfType(val, Array)) {
                for (item in (cast val : Array<Dynamic>)) {
                    if (item != null) {
                        var tr = normalizeAuraName(Std.string(item));
                        if (tr != "" && aurasToCheck.indexOf(tr) == -1) aurasToCheck.push(tr);
                    }
                }
            } else if (Std.isOfType(val, String)) {
                var parts:Array<String> = Std.string(val).split(",");
                for (p in parts) {
                    var tr = normalizeAuraName(p);
                    if (tr != "" && aurasToCheck.indexOf(tr) == -1) aurasToCheck.push(tr);
                }
            }
        }
        if (aurasToCheck.length == 0) return null;

        for (aName in aurasToCheck) {
            if (getStacks(aName, "target", world, avatar, targetObj) > 0) {
                return aName;
            }
        }
        return null;
    }

    /**
     * Checks whether combat should pause due to forbidden target reflect/shield auras.
     */
    public function shouldStopForTargetAuras(?globalStopAuras:Array<String>, ?modeConfig:Dynamic, ?world:Dynamic, ?avatar:Dynamic, ?targetObj:Dynamic, enableCounterHandler:Bool = false):Bool {
        return findTriggeringTargetAura(enableCounterHandler, globalStopAuras, modeConfig, world, avatar, targetObj) != null;
    }

    /**
     * Checks if target currently has any known reflect or counter aura.
     */
    public function hasCounterAura(target:String = "target", ?world:Dynamic, ?avatar:Dynamic, ?targetObj:Dynamic):Bool {
        for (a in DEFAULT_COUNTER_AURAS) {
            if (getStacks(a, target, world, avatar, targetObj) > 0) return true;
        }
        return false;
    }

    // -------------------------------------------------------------------------
    // Expired Aura Garbage Collection (Anti-Leak & Stale-State Prevention)
    // -------------------------------------------------------------------------

    private var _cleanTimer:flash.utils.Timer = null;
    private var _autoClean:Bool = false;

    public function cleanExpiredAuras():Int {
        var g = _g();
        if (g == null || g.world == null) return 0;
        var world:Dynamic = g.world;
        var removedCount:Int = 0;

        // 1. Clean player auras in uoTree
        if (world.uoTree != null) {
            try {
                for (playerName in Reflect.fields(world.uoTree)) {
                    var userObj:Dynamic = Reflect.field(world.uoTree, playerName);
                    if (userObj != null && userObj.auras != null && Std.isOfType(userObj.auras, Array)) {
                        removedCount += _cleanAuraArray(cast userObj.auras);
                    }
                }
            } catch (_:Dynamic) {}
        }

        // 2. Clean monster auras in monTree
        try {
            if (world.monTree != null) {
                for (monId in Reflect.fields(world.monTree)) {
                    var monObj:Dynamic = Reflect.field(world.monTree, monId);
                    if (monObj != null) {
                        var monAuras:Dynamic = Reflect.field(monObj, "auras");
                        if (monAuras != null && Std.isOfType(monAuras, Array)) {
                            removedCount += _cleanAuraArray(cast monAuras);
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}

        // 3. Clean myAvatar auras if present
        try {
            if (world.myAvatar != null) {
                if (world.myAvatar.dataLeaf != null && world.myAvatar.dataLeaf.auras != null && Std.isOfType(world.myAvatar.dataLeaf.auras, Array)) {
                    removedCount += _cleanAuraArray(cast world.myAvatar.dataLeaf.auras);
                }
                var avAuras:Dynamic = Reflect.field(world.myAvatar, "auras");
                if (avAuras != null && Std.isOfType(avAuras, Array)) {
                    removedCount += _cleanAuraArray(cast avAuras);
                }
            }
        } catch (_:Dynamic) {}

        return removedCount;
    }

    private function _cleanAuraArray(auras:Array<Dynamic>):Int {
        if (auras == null) return 0;
        var removed:Int = 0;
        var i = auras.length - 1;
        while (i >= 0) {
            var a:Dynamic = auras[i];
            if (a == null || a.nam == null || a.nam == "" || a.e == 1 || a.e == "1" || a.e == true) {
                auras.splice(i, 1);
                removed++;
            }
            i--;
        }
        return removed;
    }

    public function startAutoClean(intervalMs:Int = 5000):Void {
        stopAutoClean();
        _autoClean = true;
        _cleanTimer = new flash.utils.Timer(intervalMs);
        _cleanTimer.addEventListener(flash.events.TimerEvent.TIMER, function(_) {
            cleanExpiredAuras();
        });
        _cleanTimer.start();
    }

    public function stopAutoClean():Void {
        _autoClean = false;
        if (_cleanTimer != null) {
            _cleanTimer.stop();
            _cleanTimer = null;
        }
    }

    public var autoClean(get, set):Bool;
    @:getter(autoClean)
    public function get_autoClean_prop():Bool { return _autoClean; }
    @:setter(autoClean)
    public function set_autoClean_prop(v:Bool):Void { if (v) startAutoClean(); else stopAutoClean(); }
    public function get_autoClean():Bool { return _autoClean; }
    public function set_autoClean(v:Bool):Bool { if (v) startAutoClean(); else stopAutoClean(); return v; }

    /**
     * Read the current game HUD aura data for the target, including auSnap effects.
     *
     * Mirrors Skua's `Bot.Target.Snapshots`. Each snapshot has Name, Stacks, Duration,
     * RemainingTime, Persistent, Icon, and Description. Duration and remaining time use seconds;
     * a zero duration means no timed expiry.
     */
    public function getSnapshots(target:String = "player", ?world:Dynamic, ?avatar:Dynamic, ?targetObj:Dynamic):Array<Dynamic> {
        var result:Array<Dynamic> = [];
        try {
            var g:Dynamic = (world != null) ? world : _game.world;
            if (g == null) return result;
            var leaf:Dynamic = (target == "target")
                ? ((g.world != null && g.world.myAvatar != null) ? g.world.myAvatar.target : null)
                : ((g.world != null && g.world.myAvatar != null) ? g.world.myAvatar : null);
            if (leaf != null && leaf.dataLeaf != null && leaf.dataLeaf.hudAuras != null) {
                var arr:Array<Dynamic> = cast leaf.dataLeaf.hudAuras;
                for (raw in arr) {
                    result.push(buildSnapshot(raw));
                }
                if (result.length > 0) return result;
            }
            var rawAuras:Dynamic = getRawAuras(target, world, avatar, targetObj);
            if (rawAuras != null && Std.isOfType(rawAuras, Array)) {
                var arr2:Array<Dynamic> = cast rawAuras;
                for (raw in arr2) {
                    result.push(buildSnapshot(raw));
                }
            }
        } catch (_:Dynamic) {}
        return result;
    }

    private function buildSnapshot(raw:Dynamic):Dynamic {
        return {
            Name: (raw.nam != null) ? Std.string(raw.nam) : "",
            Stacks: (raw.n != null) ? Std.int(raw.n) : 0,
            Duration: (raw.dur != null) ? Std.parseFloat(raw.dur) : 0.0,
            RemainingTime: (raw.remaining != null) ? Std.parseFloat(raw.remaining) : 0.0,
            Persistent: (raw.persist != null) ? (raw.persist == true || raw.persist == "1" || raw.persist == 1) : false,
            Icon: (raw.icon != null) ? Std.string(raw.icon) : "",
            Description: (raw.desc != null) ? Std.string(raw.desc) : "",
            Value: (raw.value != null) ? Std.parseFloat(raw.value) : 0.0
        };
    }

    /**
     * The HUD stack count for an aura, or zero when absent. Case-insensitive name matching.
     *
     * Mirrors Skua's `Bot.Self.GetAuraStacks(string auraName)` / `Bot.Target.GetAuraStacks(...)`.
     */
    public function getAuraStacks(auraName:String, target:String = "player", ?world:Dynamic, ?avatar:Dynamic, ?targetObj:Dynamic):Int {
        if (auraName == null || auraName == "") return 0;
        var snapshots:Array<Dynamic> = getSnapshots(target, world, avatar, targetObj);
        var lower:String = auraName.toLowerCase();
        for (snap in snapshots) {
            var name:String = (snap.Name != null) ? Std.string(snap.Name).toLowerCase() : "";
            if (name == lower) return Std.int(snap.Stacks);
        }
        return 0;
    }

    /**
     * The matching AuraSnapshot for an aura, or null when absent. Case-insensitive name matching.
     *
     * Mirrors Skua's `Bot.Self.GetAuraSnapshot(string auraName)` / `Bot.Target.GetAuraSnapshot(...)`.
     */
    public function getAuraSnapshot(auraName:String, target:String = "player", ?world:Dynamic, ?avatar:Dynamic, ?targetObj:Dynamic):Dynamic {
        if (auraName == null || auraName == "") return null;
        var snapshots:Array<Dynamic> = getSnapshots(target, world, avatar, targetObj);
        var lower:String = auraName.toLowerCase();
        for (snap in snapshots) {
            var name:String = (snap.Name != null) ? Std.string(snap.Name).toLowerCase() : "";
            if (name == lower) return snap;
        }
        return null;
    }
}
