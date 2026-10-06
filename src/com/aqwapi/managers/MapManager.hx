package com.aqwapi.managers;

import flash.utils.Timer;
import flash.events.TimerEvent;
import com.aqwapi.utils.ApiTimings;

import com.aqwapi.Api;
import com.aqwapi.Game;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiLogger;

class MapManager {
    private static var PAD_CLASS_REGEX:EReg = ~/Pad_\d+$/;

    private var _game:Game;
    private var _lastJoinTime:Float = 0;
    private var _lastJumpTime:Float = 0;
    private var _lastMapItemTime:Float = 0;
    private var _lastCombatCooldownLogTime:Float = 0;
    private var _jumpCorrectionTimer:Timer = null;
    private var _jumpCorrectionHandler:Dynamic = null;
    private var _autoCorrectJump:Bool = true;

    public function new(gameReference:Game) {
        _game = gameReference;
    }

    private inline function _g():Game {
        return (_game != null) ? _game : Api.game;
    }

    private var _usePrivateRoom:Bool = true;
    private var _privateRoomNumber:Int = 100000;

    private function _pauseScriptIfRunning(ms:Float):Void {
        try {
            var engine = com.aqwapi.scripting.HScriptEngine.SINGLETON;
            if (engine != null && engine.isRunning) {
                engine.sleep(ms);
            }
        } catch (_:Dynamic) {}
    }

    private inline function _getClassName(obj:Dynamic):String {
        if (obj == null) return "";
        try {
            return Std.string(untyped __global__["flash.utils.getQualifiedClassName"](obj));
        } catch (_:Dynamic) {
            return "";
        }
    }

    private function _getMapMovieClip():Dynamic {
        var g = _g();
        if (g == null || g.world == null || g.world.map == null) return null;
        var mapObj:Dynamic = g.world.map;
        try {
            if (mapObj.mc != null) return mapObj.mc;
            if (mapObj.mC != null) return mapObj.mC;
        } catch (_:Dynamic) {}
        return mapObj;
    }

    public function stopJumpCorrection():Void {
        if (_jumpCorrectionTimer != null) {
            try {
                _jumpCorrectionTimer.stop();
                if (_jumpCorrectionHandler != null) {
                    _jumpCorrectionTimer.removeEventListener(TimerEvent.TIMER, _jumpCorrectionHandler);
                }
            } catch (_:Dynamic) {}
        }
        _jumpCorrectionTimer = null;
        _jumpCorrectionHandler = null;
    }

    public function isMap(mapName:String):Bool {
        if (mapName == null || mapName == "") return false;
        var cur = (name != null) ? name.toLowerCase() : "";
        return cur == StringTools.trim(mapName).toLowerCase();
    }

    public function isCell(cellName:String):Bool {
        if (cellName == null || cellName == "") return false;
        var cur = (Api.player != null && Api.player.cell != null) ? Api.player.cell.toLowerCase() : "";
        return cur == StringTools.trim(cellName).toLowerCase();
    }

    public function isAt(mapName:String, cellName:String = null):Bool {
        if (!isMap(mapName)) return false;
        if (cellName != null && cellName != "" && !isCell(cellName)) return false;
        return true;
    }

    public function ensure(mapName:String, cell:String = null, pad:String = null):Bool {
        if (Api.player != null && !Api.player.isAlive) return false;
        if (!isLoaded) return false;

        if (mapName != null && mapName != "") {
            var mLower = mapName.toLowerCase();
            if (mLower == "house" || mLower == "myhouse") {
                return ensureHouse();
            }
            if (!isMap(mapName)) {
                var inCombat = (Api.player != null && Api.player.isInCombat) || (Api.combat != null && Api.combat.isRunning());
                if (inCombat) {
                    if (Api.combat != null) Api.combat.dropCombat();
                    else reload();
                    _pauseScriptIfRunning(600);
                    return false;
                }
                join(mapName, cell, pad);
                return false;
            }
        }

        if (cell != null && cell != "") {
            if (!isCell(cell)) {
                jump(cell, pad);
                return false;
            }
        }

        return true;
    }

    public inline function ensureMap(mapName:String, cell:String = null, pad:String = null):Bool {
        return ensure(mapName, cell, pad);
    }

    public function ensureHouse():Bool {
        if (Api.player != null && !Api.player.isAlive) return false;
        if (!isLoaded) return false;
        if (isHouse()) return true;

        var inCombat = (Api.player != null && Api.player.isInCombat) || (Api.combat != null && Api.combat.isRunning());
        if (inCombat) {
            if (Api.combat != null) Api.combat.dropCombat();
            _pauseScriptIfRunning(600);
            return false;
        }

        joinHouse();
        return false;
    }

    public inline function ensureCell(cell:String, pad:String = null):Bool {
        return ensure(null, cell, pad);
    }

    public inline function stay(mapName:String, cell:String = null, pad:String = null):Bool {
        return ensure(mapName, cell, pad);
    }

    public function join(mapName:String, cell:String = null, pad:String = null, force:Bool = false):Void {
        var g = _g();
        if (g == null || g.world == null || g.sfc == null) return;
        stopJumpCorrection();

        if (mapName != null && StringTools.trim(mapName).toLowerCase() == "house") {
            joinHouse();
            return;
        }

        // If already on this map, simply jump to cell if specified and not already there
        if (!force && isMap(mapName)) {
            if (cell != null && cell != "" && !isCell(cell)) {
                jump(cell, pad);
            }
            return;
        }

        // If in combat or combat recently ended (< 2000ms), drop combat and safely wait for server combat cooldown
        var inCombat = (Api.player != null && Api.player.isInCombat) || (Api.combat != null && Api.combat.isRunning());
        var timeSinceCombat:Float = (Api.combat != null && Api.combat.lastCombatExitTime > 0) ? (ApiTime.now() - Api.combat.lastCombatExitTime) : 999999.0;
        if (inCombat || timeSinceCombat < 2000) {
            if (Api.combat != null) Api.combat.dropCombat();
            else reload();
            var remainingMs:Int = inCombat ? 2000 : Std.int(Math.max(200, 2000 - timeSinceCombat));
            var now2 = ApiTime.now();
            if (now2 - _lastCombatCooldownLogTime >= ApiTimings.COMBAT_COOLDOWN_LOG_MS) {
                _lastCombatCooldownLogTime = now2;
                ApiLogger.debug("Map", "Waiting " + remainingMs + "ms for combat cooldown before joining " + mapName + "...");
                ApiTime.delay(remainingMs, function() {
                    join(mapName, cell, pad, force);
                });
            }
            return;
        }

        var now = ApiTime.now();
        if (now - _lastJoinTime < ApiTimings.MAP_JOIN_MS) return;
        _lastJoinTime = now;
        _pauseScriptIfRunning(2000);
        var avatar:Dynamic = g.world.myAvatar;
        var username:String = "";
        if (avatar != null) {
            if (avatar.objData != null && avatar.objData.strUsername != null)
                username = Std.string(avatar.objData.strUsername);
            else if (avatar.dataLeaf != null && avatar.dataLeaf.strUsername != null)
                username = Std.string(avatar.dataLeaf.strUsername);
        }

        var targetMap:String = mapName;
        if (_usePrivateRoom && targetMap.indexOf("-") == -1) {
            targetMap = targetMap + "-" + _privateRoomNumber;
        }

        var c:String = (cell != null && cell != "") ? cell : "Enter";
        var p:String = pad;
        if (p == null || p == "" || (c.toLowerCase() != "enter" && p == "Spawn")) {
            p = (c.toLowerCase() == "enter") ? "Spawn" : "Left";
        }

        if (g.world.gotoTown != null) {
            try {
                g.world.gotoTown(targetMap, c, p);
                return;
            } catch (e:Dynamic) {}
        }

        if (g.world.setReturnInfo != null) {
            try { g.world.setReturnInfo(targetMap, c, p); } catch (e:Dynamic) {}
        }
        if (Api.transport != null) {
            Api.transport.send("zm", "cmd", ["1", "tfer", username, targetMap, c, p]);
        }
    }

    public function joinHouse(username:String = ""):Void {
        var g = _g();
        if (g == null || g.world == null) return;
        stopJumpCorrection();

        // If in combat or combat recently ended (< 2000ms), drop combat and safely wait for server combat cooldown
        var inCombat = (Api.player != null && Api.player.isInCombat) || (Api.combat != null && Api.combat.isRunning());
        var timeSinceCombat:Float = (Api.combat != null && Api.combat.lastCombatExitTime > 0) ? (ApiTime.now() - Api.combat.lastCombatExitTime) : 999999.0;
        if (inCombat || timeSinceCombat < 2000) {
            if (Api.combat != null) Api.combat.dropCombat();
            var remainingMs:Int = inCombat ? 2000 : Std.int(Math.max(200, 2000 - timeSinceCombat));
            var now2 = ApiTime.now();
            if (now2 - _lastCombatCooldownLogTime >= ApiTimings.COMBAT_COOLDOWN_LOG_MS) {
                _lastCombatCooldownLogTime = now2;
                ApiLogger.debug("Map", "Waiting " + remainingMs + "ms for combat cooldown before joining house...");
                ApiTime.delay(remainingMs, function() {
                    joinHouse(username);
                });
            }
            return;
        }

        var un:String = username != null ? StringTools.trim(username) : "";
        if (un == "" && Api.player != null) un = Api.player.username;
        if (un == "" && g.world.myAvatar != null && g.world.myAvatar.objData != null && g.world.myAvatar.objData.strUsername != null) {
            un = Std.string(g.world.myAvatar.objData.strUsername);
        }
        if (g.world.gotoHouse != null) {
            try { g.world.gotoHouse(un); return; } catch (e:Dynamic) {}
        }
        if (Api.transport != null) {
            Api.transport.send("zm", "house", [un]);
        }
    }

    public function dungeonQueue(mapName:String, roomNum:Int = -1):Void {
        if (_game == null || _game.sfc == null) return;
        var rId:Int = roomId;
        var targetMap:String = mapName;

        if (targetMap.indexOf("-") != -1) {
            // Already explicitly contains room number (forced overwrite)
        } else if (roomNum > 0) {
            _privateRoomNumber = roomNum;
            targetMap = mapName + "-" + roomNum;
        } else if (_usePrivateRoom) {
            var num:Int = (_privateRoomNumber > 0) ? _privateRoomNumber : (100000 + Std.random(90000));
            _privateRoomNumber = num;
            targetMap = mapName + "-" + num;
        } else {
            // Public room queue
            targetMap = mapName;
        }

        var packet:String = "%xt%zm%dungeonQueue%" + rId + "%" + targetMap + "%";
        var g = _g();
        if (g != null && g.sfc != null) g.sfc.sendString(packet);
    }

    private var _autoDeathSpawn:Bool = false;
    private var _lastSpawnCell:String = "";

    public function checkAutoDeathSpawn():Void {
        var g = _g();
        if (!_autoDeathSpawn || g == null || g.world == null) return;
        if (Api.player != null && !Api.player.isAlive) return;
        var curCell:String = (g.world.strFrame != null) ? Std.string(g.world.strFrame) : "";
        var curPad:String = (g.world.strPad != null) ? Std.string(g.world.strPad) : "Spawn";
        if (curCell != "" && curCell != _lastSpawnCell && curCell.toLowerCase().indexOf("cut") == -1) {
            _lastSpawnCell = curCell;
            Api.player.setSpawnPoint(curCell, curPad);
        }
    }

    public function jump(cell:String, pad:String = null, force:Bool = false, autoCorrect:Bool = true, clientOnly:Bool = false):Void {
        var g = _g();
        if (g == null || g.world == null) return;
        stopJumpCorrection();

        var p:String = pad;
        if (p == null || p == "" || (cell != null && cell.toLowerCase() != "enter" && p == "Spawn")) {
            p = (cell != null && cell.toLowerCase() == "enter") ? "Spawn" : "Left";
        }

        var isSameCell = (cell != null && isCell(cell));
        var isDifferentPad = (p != null && Api.player != null && Api.player.pad != null && Api.player.pad.toLowerCase() != p.toLowerCase());
        var shouldJump = cell != null && (force || !isSameCell || isDifferentPad);

        if (g.world.moveToCell != null && shouldJump) {
            var now = ApiTime.now();
            if (!force && !isSameCell && (now - _lastJumpTime < ApiTimings.CELL_JUMP_MS)) return;
            _lastJumpTime = now;
            _pauseScriptIfRunning(500);
            try {
                g.world.moveToCell(cell, p, clientOnly);
            } catch (_:Dynamic) {
                g.world.moveToCell(cell, p);
            }
        }

        if (_disableCollisions) {
            applyCollisionState();
        }

        if (_autoDeathSpawn && cell != null && cell != "" && cell.toLowerCase().indexOf("cut") == -1) {
            _lastSpawnCell = cell;
            Api.player.setSpawnPoint(cell, p);
        }

        if (!_autoCorrectJump || !autoCorrect || cell == null || cell == "") {
            return;
        }

        var world:Dynamic = g.world;
        var mapName:String = (world.strMapName != null) ? Std.string(world.strMapName) : "";
        var mc:Dynamic = _getMapMovieClip();
        if (mc == null) return;

        var targetCell:String = StringTools.trim(cell);
        var targetPad:String = StringTools.trim(p);

        var timer = new Timer(50, 40);
        _jumpCorrectionTimer = timer;

        var handler:Dynamic = null;
        handler = function(e:TimerEvent):Void {
            if (_jumpCorrectionTimer != timer) {
                try {
                    timer.stop();
                    timer.removeEventListener(TimerEvent.TIMER, handler);
                } catch (_:Dynamic) {}
                return;
            }

            var curG = _g();
            if (curG == null || curG.world == null) {
                stopJumpCorrection();
                return;
            }

            var curWorld:Dynamic = curG.world;
            var curMapName:String = (curWorld.strMapName != null) ? Std.string(curWorld.strMapName) : "";
            var curMc:Dynamic = _getMapMovieClip();

            if (curWorld != world || curMapName != mapName || curMc != mc) {
                stopJumpCorrection();
                return;
            }

            var curLabel:String = (mc.currentLabel != null) ? Std.string(mc.currentLabel) : "";
            var isPlaying:Bool = false;
            try {
                isPlaying = (mc.isPlaying == true);
            } catch (_:Dynamic) {}

            // Wait until the map timeline reaches the target frame and stops playing
            if (curLabel.toLowerCase() != targetCell.toLowerCase() || isPlaying) {
                if (timer.currentCount >= timer.repeatCount) {
                    stopJumpCorrection();
                }
                return;
            }

            var validPads = getValidCellPads();
            if (validPads.length == 0) {
                validPads = getCellPads();
            }
            if (validPads.length == 0) {
                if (timer.currentCount >= timer.repeatCount) {
                    stopJumpCorrection();
                }
                return;
            }

            // Check if requested target pad exists in valid pads (case-insensitive)
            var foundValid:Bool = false;
            for (vp in validPads) {
                if (vp.toLowerCase() == targetPad.toLowerCase()) {
                    foundValid = true;
                    break;
                }
            }

            if (foundValid) {
                // Requested pad is valid, no correction needed
                stopJumpCorrection();
                return;
            }

            // Select best fallback pad
            var selectedPad:String = "";
            for (vp in validPads) {
                if (vp.toLowerCase() == "left") {
                    selectedPad = vp;
                    break;
                }
            }
            if (selectedPad == "") {
                for (vp in validPads) {
                    if (vp.toLowerCase() == "spawn") {
                        selectedPad = vp;
                        break;
                    }
                }
            }
            if (selectedPad == "") {
                selectedPad = validPads[0];
            }

            stopJumpCorrection();

            if (selectedPad != "" && selectedPad.toLowerCase() != targetPad.toLowerCase()) {
                ApiLogger.debug("Map", "AutoCorrecting jump pad in " + targetCell + ": '" + targetPad + "' -> '" + selectedPad + "' (valid: " + validPads.join(", ") + ")");
                try {
                    curWorld.moveToCell(targetCell, selectedPad, clientOnly);
                } catch (_:Dynamic) {
                    curWorld.moveToCell(targetCell, selectedPad);
                }
                if (_autoDeathSpawn && targetCell.toLowerCase().indexOf("cut") == -1) {
                    _lastSpawnCell = targetCell;
                    Api.player.setSpawnPoint(targetCell, selectedPad);
                }
            }
        };

        _jumpCorrectionHandler = handler;
        timer.addEventListener(TimerEvent.TIMER, handler);
        timer.start();
    }

    public function reload(pad:String = null):Void {
        var g = _g();
        var curCell = (Api.player != null && Api.player.cell != null && Api.player.cell != "") ? Api.player.cell : "";
        if (curCell == "" && g != null && g.world != null && g.world.strFrame != null) {
            curCell = Std.string(g.world.strFrame);
        }
        if (curCell == "") return;

        var curPad = pad;
        if (curPad == null || curPad == "") {
            curPad = (g != null && g.world != null && g.world.strPad != null) ? Std.string(g.world.strPad) : "";
        }

        var curX:Float = 0;
        var curY:Float = 0;
        var hasCoords:Bool = false;
        if (g != null && g.world != null && g.world.myAvatar != null && g.world.myAvatar.pMC != null) {
            curX = g.world.myAvatar.pMC.x;
            curY = g.world.myAvatar.pMC.y;
            hasCoords = (curX != 0 || curY != 0);
        }

        jump(curCell, curPad, true);

        if (hasCoords) {
            var restoreCoords = function() {
                try {
                    var curG = _g();
                    if (curG != null && curG.world != null && curG.world.myAvatar != null && curG.world.myAvatar.pMC != null) {
                        var myMC:Dynamic = curG.world.myAvatar.pMC;
                        myMC.x = curX;
                        myMC.y = curY;
                        if (curG.world.pushMove != null) {
                            curG.world.pushMove(myMC, curX, curY, 16);
                        }
                    }
                } catch (e:Dynamic) {}
            };
            restoreCoords();
            ApiTime.delay(50, restoreCoords);
        }
    }

    public function getMapItem(itemId:Int):Bool {
        var g = _g();
        if (g == null || g.world == null || g.sfc == null) return false;
        var now = ApiTime.now();
        if (now - _lastMapItemTime < ApiTimings.MAP_ITEM_MS) return false;
        _lastMapItemTime = now;
        _pauseScriptIfRunning(2000);
        try {
            var roomId:Dynamic = (g.world.curRoom != null) ? g.world.curRoom : (g.sfc.activeRoomId != null ? g.sfc.activeRoomId : 1);
            g.sfc.sendString("%xt%zm%getMapItem%" + roomId + "%" + itemId + "%");
            return true;
        } catch (e:Dynamic) { return false; }
    }

    public function snapTo(target:Dynamic):Void {
        var g = _g();
        if (g == null || g.world == null || g.world.myAvatar == null || target == null) return;
        try {
            var myMC:Dynamic = g.world.myAvatar.pMC;
            var tMC:Dynamic = null;
            if (Reflect.hasField(target, "raw") && target.raw != null) tMC = Reflect.field(target.raw, "pMC");
            else if (Reflect.hasField(target, "pMC")) tMC = Reflect.field(target, "pMC");
            if (myMC != null && tMC != null) {
                myMC.x = tMC.x;
                myMC.y = tMC.y;
                if (g.world.pushMove != null) g.world.pushMove(myMC, tMC.x, tMC.y, 16);
            }
        } catch (e:Dynamic) {}
    }

    public var isLoaded(get, never):Bool;
    @:getter(isLoaded)
    public function get_isLoaded_prop():Bool {
        var g = _g();
        return g != null && g.world != null
            && g.world.mapLoadInProgress != true
            && g.world.myAvatar != null
            && g.world.myAvatar.pMC != null;
    }
    public function get_isLoaded():Bool {
        var g = _g();
        return g != null && g.world != null
            && g.world.mapLoadInProgress != true
            && g.world.myAvatar != null
            && g.world.myAvatar.pMC != null;
    }

    public var name(get, never):String;
    @:getter(name)
    public function get_name_prop():String {
        var g = _g();
        if (g == null || g.world == null) return "";
        return g.world.strMapName != null ? Std.string(g.world.strMapName) : "";
    }
    public function get_name():String {
        var g = _g();
        if (g == null || g.world == null) return "";
        return g.world.strMapName != null ? Std.string(g.world.strMapName) : "";
    }

    public var currentMap(get, never):String;
    @:getter(currentMap)
    public function get_currentMap_prop():String { return get_name(); }
    public inline function get_currentMap():String { return get_name(); }

    public function isHouse():Bool {
        var g = _g();
        if (g != null && g.world != null && g.world.isMyHouse != null) {
            try {
                if (g.world.isMyHouse() == true) return true;
            } catch (e:Dynamic) {}
        }
        var cur = get_name().toLowerCase();
        return cur.indexOf("house") != -1;
    }

    public var roomId(get, never):Int;
    @:getter(roomId)
    public function get_roomId_prop():Int {
        var g = _g();
        if (g == null) return 1;
        if (g.sfc != null && g.sfc.activeRoomId != null) return Std.int(g.sfc.activeRoomId);
        if (g.world != null && g.world.curRoom != null) return Std.int(g.world.curRoom);
        return 1;
    }
    public function get_roomId():Int {
        var g = _g();
        if (g == null) return 1;
        if (g.sfc != null && g.sfc.activeRoomId != null) return Std.int(g.sfc.activeRoomId);
        if (g.world != null && g.world.curRoom != null) return Std.int(g.world.curRoom);
        return 1;
    }

    public var usePrivateRoom(get, set):Bool;
    @:getter(usePrivateRoom)
    public function get_usePrivateRoom_prop():Bool { return _usePrivateRoom; }
    @:setter(usePrivateRoom)
    public function set_usePrivateRoom_prop(v:Bool):Void { _usePrivateRoom = v; }
    public function get_usePrivateRoom():Bool { return _usePrivateRoom; }
    public function set_usePrivateRoom(v:Bool):Bool { _usePrivateRoom = v; return v; }

    public var privateRoomNumber(get, set):Int;
    @:getter(privateRoomNumber)
    public function get_privateRoomNumber_prop():Int { return _privateRoomNumber; }
    @:setter(privateRoomNumber)
    public function set_privateRoomNumber_prop(v:Int):Void { _privateRoomNumber = v; }
    public function get_privateRoomNumber():Int { return _privateRoomNumber; }
    public function set_privateRoomNumber(v:Int):Int { _privateRoomNumber = v; return v; }

    public var autoDeathSpawn(get, set):Bool;
    @:getter(autoDeathSpawn)
    public function get_autoDeathSpawn_prop():Bool { return _autoDeathSpawn; }
    @:setter(autoDeathSpawn)
    public function set_autoDeathSpawn_prop(v:Bool):Void { _autoDeathSpawn = v; if (v) checkAutoDeathSpawn(); }
    public function get_autoDeathSpawn():Bool { return _autoDeathSpawn; }
    public function set_autoDeathSpawn(v:Bool):Bool { _autoDeathSpawn = v; if (v) checkAutoDeathSpawn(); return v; }

    // -------------------------------------------------------------------------
    // Skip Cutscenes
    // -------------------------------------------------------------------------

    private var _skipCutscenes:Bool = false;

    /**
     * When enabled, cancels any pending cutscene handler and dismisses external movie cutscenes every tick.
     * Call this from the script engine tick and on map zone-entered events.
     * Mirrors the technique used by Skua's skipCutscenes binding.
     */
    public function checkSkipCutscenes():Void {
        if (!_skipCutscenes) return;
        var g = _g();
        if (g == null) return;
        try {
            if (g.world != null && g.world.cHandle != null) {
                try { g.world.cHandle.cancel(); } catch (e:Dynamic) {}
            }
            if (g.mcExtSWF != null && g.mcExtSWF.numChildren != null && untyped g.mcExtSWF.numChildren > 0) {
                while (untyped g.mcExtSWF.numChildren > 0) {
                    untyped g.mcExtSWF.removeChildAt(0);
                }
                if (g.showInterface != null) untyped g.showInterface();
            }
        } catch (e:Dynamic) {}
    }

    public function skipCutscenesNow():Bool {
        var g = _g();
        if (g == null) return false;
        var dismissed:Bool = false;
        try {
            if (g.world != null && g.world.cHandle != null) {
                try { g.world.cHandle.cancel(); dismissed = true; } catch (e:Dynamic) {}
            }
            if (g.mcExtSWF != null && g.mcExtSWF.numChildren != null && untyped g.mcExtSWF.numChildren > 0) {
                while (untyped g.mcExtSWF.numChildren > 0) {
                    untyped g.mcExtSWF.removeChildAt(0);
                }
                if (g.showInterface != null) untyped g.showInterface();
                dismissed = true;
            }
        } catch (e:Dynamic) {}
        return dismissed;
    }

    public var skipCutscenes(get, set):Bool;
    @:getter(skipCutscenes)
    public function get_skipCutscenes_prop():Bool { return _skipCutscenes; }
    @:setter(skipCutscenes)
    public function set_skipCutscenes_prop(v:Bool):Void { _skipCutscenes = v; if (v) checkSkipCutscenes(); }
    public function get_skipCutscenes():Bool { return _skipCutscenes; }
    public function set_skipCutscenes(v:Bool):Bool { _skipCutscenes = v; if (v) checkSkipCutscenes(); return v; }

    // -------------------------------------------------------------------------
    // Walk Through Walls / Disable Collisions
    // -------------------------------------------------------------------------

    private var _disableCollisions:Bool = false;
    private var _savedArrSolid:Dynamic = null;
    private var _savedArrSolidR:Dynamic = null;

    public var disableCollisions(get, set):Bool;
    @:getter(disableCollisions)
    public function get_disableCollisions_prop():Bool { return _disableCollisions; }
    @:setter(disableCollisions)
    public function set_disableCollisions_prop(v:Bool):Void { setDisableCollisions(v); }
    public function get_disableCollisions():Bool { return _disableCollisions; }
    public function set_disableCollisions(v:Bool):Bool { setDisableCollisions(v); return v; }

    public function setDisableCollisions(enabled:Bool):Void {
        _disableCollisions = enabled;
        applyCollisionState();
    }

    public inline function walkThroughWalls(enabled:Bool = true):Void {
        setDisableCollisions(enabled);
    }

    public function applyCollisionState():Void {
        var g = _g();
        if (g == null || g.world == null) return;
        try {
            var w:Dynamic = g.world;
            if (_disableCollisions) {
                if (w.arrSolid != null && (w.arrSolid.length != null && untyped w.arrSolid.length > 0)) {
                    _savedArrSolid = w.arrSolid;
                }
                if (w.arrSolidR != null && (w.arrSolidR.length != null && untyped w.arrSolidR.length > 0)) {
                    _savedArrSolidR = w.arrSolidR;
                }
                w.arrSolid = [];
                w.arrSolidR = [];
            } else {
                if (_savedArrSolid != null) w.arrSolid = _savedArrSolid;
                if (_savedArrSolidR != null) w.arrSolidR = _savedArrSolidR;
            }
        } catch (e:Dynamic) {}
    }

    public var autoCorrectJump(get, set):Bool;
    @:getter(autoCorrectJump)
    public function get_autoCorrectJump_prop():Bool { return _autoCorrectJump; }
    @:setter(autoCorrectJump)
    public function set_autoCorrectJump_prop(v:Bool):Void { _autoCorrectJump = v; }
    public function get_autoCorrectJump():Bool { return _autoCorrectJump; }
    public function set_autoCorrectJump(v:Bool):Bool { _autoCorrectJump = v; return v; }

    public function getValidCellPads():Array<String> {
        var pads:Array<String> = [];
        var mc:Dynamic = _getMapMovieClip();
        if (mc == null) return pads;

        try {
            if (mc.numChildren == null) return pads;
            var count:Int = Std.int(mc.numChildren);
            for (i in 0...count) {
                var child:Dynamic = mc.getChildAt(i);
                if (child == null || child.name == null) continue;
                var childName:String = Std.string(child.name);
                if (childName == "") continue;

                var className = _getClassName(child);
                if (!PAD_CLASS_REGEX.match(className)) continue;

                var isNamedProperty:Bool = false;
                try {
                    isNamedProperty = (untyped mc[childName] == child);
                } catch (_:Dynamic) {
                    try {
                        isNamedProperty = (Reflect.field(mc, childName) == child);
                    } catch (_:Dynamic) {}
                }
                if (!isNamedProperty) continue;

                if (pads.indexOf(childName) == -1) {
                    pads.push(childName);
                }
            }
        } catch (e:Dynamic) {}
        return pads;
    }

    public function getMapCells():Array<String> {
        var cells:Array<String> = [];
        var g = _g();
        if (g != null && g.world != null && g.world.map != null) {
            try {
                var mapObj:Dynamic = g.world.map;
                var mc:Dynamic = (mapObj.mc != null) ? mapObj.mc : ((mapObj.mC != null) ? mapObj.mC : mapObj);
                if (mc != null && mc.currentLabels != null) {
                    var labels:Array<Dynamic> = cast mc.currentLabels;
                    for (lbl in labels) {
                        if (lbl != null && lbl.name != null) {
                            var n = Std.string(lbl.name);
                            if (cells.indexOf(n) == -1) cells.push(n);
                        }
                    }
                }
            } catch (e:Dynamic) {}
        }
        return cells;
    }

    public function getCellPads():Array<String> {
        var valid = getValidCellPads();
        if (valid.length > 0) return valid;

        var pads:Array<String> = [];
        var g = _g();
        if (g != null && g.world != null && g.world.map != null) {
            try {
                var mapObj:Dynamic = g.world.map;
                var mc:Dynamic = (mapObj.mc != null) ? mapObj.mc : ((mapObj.mC != null) ? mapObj.mC : mapObj);
                if (mc != null && mc.numChildren != null) {
                    var n:Int = Std.int(mc.numChildren);
                    for (i in 0...n) {
                        var child:Dynamic = mc.getChildAt(i);
                        if (child != null && child.name != null) {
                            var cName:String = Std.string(child.name);
                            var lower = cName.toLowerCase();
                            if (lower == "spawn" || lower == "left" || lower == "right" || lower == "center"
                                || lower == "top" || lower == "bottom" || lower == "up" || lower == "down"
                                || lower.indexOf("pad") != -1) {
                                if (pads.indexOf(cName) == -1) pads.push(cName);
                            }
                        }
                    }
                }
            } catch (e:Dynamic) {}
        }
        return pads;
    }
}
