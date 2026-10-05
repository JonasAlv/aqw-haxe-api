package com.aqwapi.modules;

import com.aqwapi.Api;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiTime;

/**
 * Records the exact moments enemy attacks resolve against us, straight from the SmartFox packet
 * stream.
 *
 * Why packets and not animation state: the server resolves every swing and sends the result back, and
 * the client applies it in `World.handleSAR` / `World.handleSARS`. That is the real "the mob attacked
 * me" instant. Reading it off the target's MovieClip label was tried first and does not work in
 * practice - the mob's attack animation is not in `world.combatAnims`, so the label check never
 * matched and `[counter]` stayed false through a whole fight.
 *
 * Wire format, from the decompiled client:
 *
 *   Game.as:3995   case "sar":  world.handleSAR(resObj)     one result
 *   Game.as:3996   case "sars": world.handleSARS(resObj)    one attacker, many targets
 *   Game.as:3920   `ct` is a periodic composite tick that also carries `sara` / `sarsa` arrays, so the
 *                  same resolutions arrive on that path too and both have to be handled.
 *
 * A result carries `iRes` (1 = resolved, 0 = rejected, World.as:9582), `typ` ("d" = damage-over-time
 * aura tick, World.as:9555), the attacker as `cInf` ("m:<MonMapID>" or "p:<userId>"), and the
 * resolution `type` - one of hit/crit/miss/dodge/parry/block/none (World.as:10009-10074).
 *
 * The two result shapes differ, and this is the detail that matters. `sars` (World.as:9592) carries
 * an `a[]` array of `{tInf, hp, type}`, one entry per struck target. `sar` (World.as:9503) does not
 * send an array at all - the client manufactures the single-element list itself at World.as:9570
 * (`_loc2_.a = [copyObj(actionResult)]`), so on the wire a single result is flat, with `cInf`, `tInf`,
 * `hp` and `type` directly on `actionResult`. Reading `a` unconditionally discards every `sar`, and
 * `sar` is the ordinary mob-hits-one-player case, so the counter stayed silent through a whole fight.
 * Both shapes are handled here.
 *
 * There is no Flash event for any of this - `Game.as` dispatches exactly 8 events and every one is
 * UI. So we register on the raw extension-response dispatcher at priority 100, which runs before the
 * game's own priority-0 listener (Game.as:4946) and therefore sees the object before the game mutates
 * or consumes it.
 *
 * The command is read from `cmd` first and `[0]` second: the json branch uses `cmd = resObj.cmd`
 * (Game.as:1679) while the str branch uses `cmd = resObj[0]` (Game.as:1135). This client runs json.
 */
class ActionFeed {

    /** A single resolved attack against us. */
    private static inline function Rec(seq:Int, at:Float, attacker:String, type:String, hp:Int):Dynamic {
        return {seq: seq, at: at, attacker: attacker, type: (type == null) ? "" : type, hp: hp};
    }

    /**
     * Newest first. Bounded because a long fight on a busy server produces a lot of these, and the
     * query only ever cares about the most recent handful.
     */
    private static var _records:Array<Dynamic> = [];

    private static inline var MAX_RECORDS:Int = 24;

    /** Monotonic id so records can be ordered and consumed without relying on timestamp resolution. */
    private static var _seq:Int = 0;

    /**
     * Highest record seq already spent on a riposte.
     *
     * This is what makes the window-less `[counter]` edge-triggered rather than level-triggered.
     * Without it, once the mob had hit even once, `hasAnyForTarget` stayed true for the rest of the
     * fight and every `[counter]` slot in a rotation passed instantly - so `1 > 2 > 3[counter] > 2 >
     * 3[counter] > 4` would fire skill 3 back-to-back with no mob attack in between, which is the exact
     * opposite of a riposte. A seq is used rather than a timestamp because two attacks can resolve
     * inside the same millisecond, and `>` on identical timestamps would wait forever.
     */
    private static var _consumedSeq:Int = 0;

    private static var _installedOn:Dynamic = null;
    private static var _handler:Dynamic = null;

    /** Raw packets seen, so a dead hook is distinguishable from a parser bug. */
    public static var packetsSeen:Int = 0;
    public static var resultsSeen:Int = 0;

    private static var _announced:Bool = false;
    private static var _sawAnyPacket:Bool = false;
    private static var _shapesSeen:Map<String, Bool> = new Map<String, Bool>();
    private static var _cmdCounts:Map<String, Int> = new Map<String, Int>();

    private static var _ticks:Bool = false;
    private static var _ticksWithResults:Int = 0;
    private static var _tickResults:Int = 0;
    private static var _lastSummaryAt:Float = -10000;

    private static inline function countCmd(cmd:String):Void {
        _cmdCounts.set(cmd, (_cmdCounts.exists(cmd) ? _cmdCounts.get(cmd) : 0) + 1);
    }

    /**
     * Tally ticks that actually carried combat results, and report periodically.
     *
     * This is the diagnostic that matters: it separates "ticks are arriving but carry no results"
     * (wrong shape, or genuinely no combat) from "results arrive but are rejected by a filter".
     */
    private static function noteTick(sara:Array<Dynamic>, sarsa:Array<Dynamic>):Void {
        _ticks = true;
        // Count per-target entries, not container elements. A `sars` entry is one attacker carrying an
        // `a[]` list of every target it struck, so counting elements under-reports multi-target hits and
        // makes "are we catching everything" unanswerable. Counting entries gives a true total that
        // `results` (hits on us) can be compared against.
        var n:Int = 0;
        if (sara != null) n += sara.length;
        if (sarsa != null) {
            for (s in sarsa) {
                if (s == null) continue;
                var list:Array<Dynamic> = null;
                try {
                    list = cast s.a;
                } catch (_:Dynamic) {}
                n += (list != null) ? list.length : 1;
            }
        }
        if (n > 0) {
            _ticksWithResults++;
            _tickResults += n;
        }
        var now:Float = ApiTime.now();
        if (now - _lastSummaryAt < 15000) return;
        _lastSummaryAt = now;
        ApiLogger.info("ActionFeed", "Stats: packets=" + packetsSeen + " hitsOnUs=" + resultsSeen + " ticks=" + _ticksWithResults + " totalHits=" + _tickResults + " buffer=" + _records.length + " resets=" + resets + " lockOpen=" + hasAnyForTarget(-1e30) + " consumed=" + _consumedSeq + "/" + _seq + " cmds=" + cmdSummary());
    }

    private static function cmdSummary():String {
        var parts:Array<String> = [];
        for (k in _cmdCounts.keys()) parts.push(k + "=" + _cmdCounts.get(k));
        return (parts.length == 0) ? "none" : parts.join(",");
    }

    // -------------------------------------------------------------------------
    // Installation
    // -------------------------------------------------------------------------

    /**
     * Idempotent. Safe to call every tick; it only re-registers if the socket object changed, which
     * happens after a map change or reconnect.
     */
    public static function install():Void {
        try {
            var sfc:Dynamic = (Api.game != null) ? Api.game.sfc : null;
            if (sfc == null) {
                _installedOn = null;
                return;
            }
            if (_installedOn == sfc) return;
            _installedOn = sfc;
            if (_handler == null) _handler = function(e:Dynamic) handlePacket(e);
            // (type, listener, useCapture, priority, useWeak) - priority 100 beats the game's own 0.
            sfc.addEventListener("onExtensionResponse", _handler, false, 100, false);
            ApiLogger.info("ActionFeed", "Hooked sfc.onExtensionResponse (priority 100).");
        } catch (err:Dynamic) {
            _installedOn = null;
            ApiLogger.warn("ActionFeed", "Hook failed: " + Std.string(err));
        }
    }

    // -------------------------------------------------------------------------
    // Packet handling
    // -------------------------------------------------------------------------

    private static function handlePacket(e:Dynamic):Void {
        try {
            if (e == null) return;
            var p:Dynamic = e.params;
            if (p == null) return;
            var d:Dynamic = p.dataObj;
            if (d == null) return;

            // The command lives in a different place per wire format, and getting this wrong fails
            // silently - no exception, just nothing ever parsed. `ExtHandler.as:41-46` dispatches
            // JSON payloads as `param1.o`, and the game reads `cmd = resObj.cmd` in the json branch
            // (`Game.as:1679`) but `cmd = resObj[0]` in the str branch (`Game.as:1135`). This client
            // runs JSON, so reading `[0]` alone yields undefined and the feed never sees a packet.
            var cmd:String = null;
            var via:String = "none";
            if (d.cmd != null) {
                cmd = Std.string(d.cmd);
                via = "cmd";
            } else if (d[0] != null) {
                cmd = Std.string(d[0]);
                via = "[0]";
            }
            if (cmd == null) return;
            packetsSeen++;

            if (!_sawAnyPacket) {
                _sawAnyPacket = true;
                ApiLogger.info("ActionFeed", "First packet: cmd='" + cmd + "' via " + via + " keys=" + fieldList(d));
            }

            if (cmd == "sar") {
                countCmd(cmd);
                logShape(cmd, d.actionResult);
                parseResult(d.actionResult);
            } else if (cmd == "sars") {
                countCmd(cmd);
                logShape(cmd, d);
                parseResult(d);
            } else if (cmd == "ct") {
                countCmd(cmd);
                // Log the first tick unconditionally, even when it carries no combat results. The
                // earlier build only logged when a `sara` element existed, so "no log lines" could not
                // distinguish "no ticks" from "ticks with nothing in them" - which is exactly the
                // ambiguity that made the previous two failures expensive to localise.
                logShape("ct", d);
                var sara:Array<Dynamic> = cast d.sara;
                var sarsa:Array<Dynamic> = cast d.sarsa;
                if (sara != null) {
                    for (s in sara) {
                        if (s != null) {
                            logShape("sar(ct)", s.actionResult);
                            parseResult(s.actionResult);
                        }
                    }
                }
                if (sarsa != null) {
                    for (s in sarsa) {
                        logShape("sars(ct)", s);
                        parseResult(s);
                    }
                }
                noteTick(sara, sarsa);
            }
        } catch (_:Dynamic) {
            // A parse failure must never take down the dispatcher or the rest of combat.
        }
    }

    private static function fieldList(o:Dynamic):String {
        try {
            var names:Array<String> = [];
            for (k in Reflect.fields(o)) names.push(k);
            return names.join(",");
        } catch (_:Dynamic) {
            return "?";
        }
    }

    private static function parseResult(r:Dynamic):Void {
        if (r == null) return;
        // iRes 0 means the server rejected the action - nothing was rolled, so nothing happened.
        if (r.iRes != null && Std.int(r.iRes) != 1) return;
        // "d" is a damage-over-time aura tick, not a swing.
        if (r.typ != null && Std.string(r.typ) == "d") return;

        var me:String = myTag();
        if (me == null) return;
        var attacker:String = (r.cInf != null) ? Std.string(r.cInf) : "";

        // The two result shapes are NOT the same, and reading `a` unconditionally drops the common
        // case. `sars` (World.as:9592) carries a real `a[]` of `{tInf, hp, type}`. `sar`
        // (World.as:9503) does not: the client builds the one-element list itself at World.as:9570
        // with `_loc2_.a = [copyObj(actionResult)]`, so on the wire a single result is flat, carrying
        // `cInf`/`tInf`/`hp`/`type` directly. `sar` is the normal mob-hits-one-player case, so
        // requiring `a` threw away almost every swing.
        if (r.a != null) {
            var list:Array<Dynamic> = cast r.a;
            if (list == null) return;
            for (hit in list) noteHit(me, attacker, hit);
        } else {
            noteHit(me, attacker, r);
        }
    }

    private static inline function noteHit(me:String, attacker:String, hit:Dynamic):Void {
        if (hit == null) return;
        var tInf:String = (hit.tInf != null) ? Std.string(hit.tInf) : "";
        if (tInf != me) return;
        resultsSeen++;
        record(attacker, (hit.type != null) ? Std.string(hit.type) : "", (hit.hp != null) ? Std.int(hit.hp) : 0);
    }

    /** Field names of the first packet of each kind, so a future shape mismatch is self-evident. */
    private static function logShape(cmd:String, d:Dynamic):Void {
        if (d == null) return;
        if (_shapesSeen.exists(cmd)) return;
        _shapesSeen.set(cmd, true);
        ApiLogger.info("ActionFeed", "Shape '" + cmd + "' result keys=[" + fieldList(d) + "]");
    }

    private static inline function record(attacker:String, type:String, hp:Int):Void {
        _seq++;
        _records.unshift(Rec(_seq, ApiTime.now(), attacker, type, hp));
        while (_records.length > MAX_RECORDS) _records.pop();
        if (!_announced) {
            _announced = true;
            ApiLogger.info("ActionFeed", "First action on us: attacker=" + attacker + " type=" + type + " hp=" + hp);
        }
    }

    private static inline function myTag():String {
        try {
            if (Api.game == null || Api.game.sfc == null) return null;
            var uid:Dynamic = Api.game.sfc.myUserId;
            if (uid == null) return null;
            return "p:" + Std.string(uid);
        } catch (_:Dynamic) {
            return null;
        }
    }

    // -------------------------------------------------------------------------
    // Queries
    // -------------------------------------------------------------------------

    /**
     * The `cInf` string identifying whatever we are currently targeting, or `null` when there is no
     * target or it cannot be identified.
     *
     * A `null` here is not treated as "match anything" blindly - see `matches`, which only accepts a
     * monster attacker in that case, so an unidentifiable target cannot be spoofed by another player.
     */
    private static function currentTargetTag():String {
        try {
            var world:Dynamic = (Api.game != null) ? Api.game.world : null;
            if (world == null || world.myAvatar == null) return null;
            var target:Dynamic = world.myAvatar.target;
            if (target == null) return null;

            var mmid:Dynamic = null;
            if (target.dataLeaf != null && target.dataLeaf.MonMapID != null) mmid = target.dataLeaf.MonMapID;
            else if (target.objData != null && target.objData.MonMapID != null) mmid = target.objData.MonMapID;
            if (mmid != null && Std.string(mmid) != "") return "m:" + Std.string(mmid);

            var uid:Dynamic = null;
            if (target.objData != null && target.objData.UserID != null) uid = target.objData.UserID;
            else if (target.dataLeaf != null && target.dataLeaf.UserID != null) uid = target.dataLeaf.UserID;
            if (uid != null && Std.string(uid) != "") return "p:" + Std.string(uid);
        } catch (_:Dynamic) {}
        return null;
    }

    /**
     * Stable identity of whatever we are targeting, for change detection.
     *
     * Callers must key target-change detection on this rather than the target *object*, because the
     * game replaces the target wrapper as its state updates. Keyed on the object, every replacement
     * looked like a new mob and wiped the buffer - observed live as `buffer=0` and `consumed=0/93`
     * while 93 hits had been seen. MonMapID (or UserID) is stable for as long as we are on the same
     * enemy.
     */
    public static function targetIdentity():String {
        return currentTargetTag();
    }

    /** How many times the buffer has been cleared. Diagnostic for target-change churn. */
    public static var resets:Int = 0;

    private static inline function matches(recAttacker:String, targetTag:String):Bool {
        if (targetTag != null) return recAttacker == targetTag;
        // Unidentified target: only trust a monster, never another player.
        return recAttacker != null && recAttacker.substr(0, 2) == "m:";
    }

    /**
     * Age in ms of the most recent attack against us by our current target, or -1 when there is none
     * inside the window.
     *
     * `typeFilter` of null/empty accepts every resolution type, which is what a riposte wants: the
     * window has to open on a dodged or missed swing too, not only on the ones that connected.
     */
    public static function lastActionAgeMs(windowMs:Float, ?typeFilter:String):Float {
        if (_records.length == 0) return -1;
        var targetTag:String = currentTargetTag();
        if (targetTag == null && (Api.game == null || Api.game.world == null)) return -1;

        var want:String = (typeFilter != null) ? typeFilter.toLowerCase() : "";
        var now:Float = ApiTime.now();
        for (rec in _records) {
            if (rec == null) continue;
            if (!matches(rec.attacker, targetTag)) continue;
            if (want != "" && rec.type != null && Std.string(rec.type).toLowerCase() != want) continue;
            var age:Float = now - rec.at;
            return (age <= windowMs) ? age : -1;
        }
        return -1;
    }

    public static inline function lastActionFresh(windowMs:Float, ?typeFilter:String):Bool {
        return lastActionAgeMs(windowMs, typeFilter) >= 0;
    }

    /** Type of the most recent matching action, or `""`. Diagnostic use. */
    public static function lastActionType():String {
        var targetTag:String = currentTargetTag();
        for (rec in _records) {
            if (rec == null) continue;
            if (matches(rec.attacker, targetTag)) return (rec.type != null) ? Std.string(rec.type) : "";
        }
        return "";
    }

    /**
     * Whether the current target has resolved a NEW attack on us that has not already been spent on a
     * riposte, at any age.
     *
     * This backs the window-less `[counter]` hard lock, and it is deliberately edge-triggered: one mob
     * attack opens exactly one `[counter]` slot. A level-triggered check ("has it ever happened")
     * latches true after the first hit and makes every later `[counter]` slot in the rotation pass
     * instantly, destroying the riposte timing.
     *
     * `notBefore` is the arming cutoff: attacks that resolved before it are ignored, so a hit landing
     * in the same instant we cast a skill does not immediately consume the riposte. Without it, casting
     * the arm skill (e.g. a dodge buff) and having the mob swing a few ms later would riposte straight
     * away, and the player would never get to answer the *next* swing. The cutoff is only re-evaluated
     * when we cast, so an ignored early hit stays ignored rather than being picked up once the arm
     * window passes.
     */
    public static function hasAnyForTarget(notBefore:Float = -1e30):Bool {
        if (_records.length == 0) return false;
        var targetTag:String = currentTargetTag();
        if (targetTag == null && (Api.game == null || Api.game.world == null)) return false;
        for (rec in _records) {
            if (rec == null) continue;
            if (!matches(rec.attacker, targetTag)) continue;
            if (rec.seq != null && Std.int(rec.seq) <= _consumedSeq) continue;
            if (rec.at != null && rec.at < notBefore) continue;
            return true;
        }
        return false;
    }

    /**
     * How many attacks from the current target are waiting to be answered.
     *
     * Backs `[counter xN]`, which opens only once N attacks have landed instead of on the first one.
     * Counts only records that are still unconsumed, so a riposte already spent on an earlier attack
     * does not count toward the next one. `notBefore` applies the same arming cutoff as
     * {@link hasAnyForTarget} so an attack landing in the instant we cast is not counted.
     */
    public static function unconsumedCountForTarget(notBefore:Float = -1e30, ?typeFilter:String):Int {
        if (_records.length == 0) return 0;
        var targetTag:String = currentTargetTag();
        if (targetTag == null && (Api.game == null || Api.game.world == null)) return 0;
        var want:String = (typeFilter != null) ? typeFilter.toLowerCase() : "";
        var n:Int = 0;
        for (rec in _records) {
            if (rec == null) continue;
            if (!matches(rec.attacker, targetTag)) continue;
            if (rec.seq != null && Std.int(rec.seq) <= _consumedSeq) continue;
            if (rec.at != null && rec.at < notBefore) continue;
            if (want != "" && rec.type != null && Std.string(rec.type).toLowerCase() != want) continue;
            n++;
        }
        return n;
    }

    /**
     * Marks every attack currently observed from the current target as spent.
     *
     * Called when a hard-locked `[counter]` slot actually fires, so the next `[counter]` slot in the
     * rotation waits for the mob's *next* swing instead of replaying this one.
     */
    public static function consumeForTarget():Void {
        var targetTag:String = currentTargetTag();
        if (targetTag == null && (Api.game == null || Api.game.world == null)) return;
        var newest:Int = _consumedSeq;
        for (rec in _records) {
            if (rec == null || rec.seq == null) continue;
            if (!matches(rec.attacker, targetTag)) continue;
            var sq:Int = Std.int(rec.seq);
            if (sq > newest) newest = sq;
        }
        _consumedSeq = newest;
    }

    public static function count():Int {
        return _records.length;
    }

    /** Clears state. Called on target change so a new mob does not inherit the old one's window. */
    public static function reset():Void {
        resets++;
        _records = [];
        // A new target has not spent anything yet, so its first attack must open the lock. Leaving
        // _consumedSeq set would make the new mob's first hit look already-answered.
        _consumedSeq = 0;
    }

    /**
     * Snapshot for the UI / scripting. `tickResults` is the useful one: it counts combat results that
     * arrived on the wire, independent of whether any filter accepted them.
     */
    public static function stats():Dynamic {
        return {
            packets: packetsSeen,
            hitsOnUs: resultsSeen,
            ticksWithResults: _ticksWithResults,
            totalHits: _tickResults,
            buffer: _records.length,
            resets: resets,
            lockOpen: hasAnyForTarget(-1e30),
            consumed: _consumedSeq,
            seen: _seq,
            lastType: lastActionType()
        };
    }
}
