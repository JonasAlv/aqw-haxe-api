package com.aqwapi.managers;

import com.aqwapi.Api;
import com.aqwapi.Game;
import com.aqwapi.utils.ApiTime;

class MapManager {
    private var _game:Game;
    private var _lastJoinTime:Float = 0;
    private var _lastJumpTime:Float = 0;

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
            if (!isMap(mapName)) {
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

    public inline function stay(mapName:String, cell:String = null, pad:String = null):Bool {
        return ensure(mapName, cell, pad);
    }

    public function join(mapName:String, cell:String = null, pad:String = null, force:Bool = false):Void {
        var g = _g();
        if (g == null || g.world == null || g.sfc == null) return;

        // If already on this map, simply jump to cell if specified and not already there
        if (!force && isMap(mapName)) {
            if (cell != null && cell != "" && !isCell(cell)) {
                jump(cell, pad);
            }
            return;
        }

        var now = ApiTime.now();
        if (now - _lastJoinTime < 2000) return;
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
        var p:String = (pad != null && pad != "") ? pad : "Spawn";

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
        var un:String = username != null ? StringTools.trim(username) : "";
        if (un == "" && Api.player != null) un = Api.player.username;
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

    public function jump(cell:String, pad:String = null):Void {
        var g = _g();
        if (g == null || g.world == null) return;
        var p:String = (pad != null && pad != "") ? pad : "Spawn";
        if (g.world.moveToCell != null) {
            if (cell != null && !isCell(cell)) {
                var now = ApiTime.now();
                if (now - _lastJumpTime < 500) return;
                _lastJumpTime = now;
                _pauseScriptIfRunning(500);
                g.world.moveToCell(cell, p);
            }
        }
        if (_autoDeathSpawn && cell != null && cell != "" && cell.toLowerCase().indexOf("cut") == -1) {
            _lastSpawnCell = cell;
            Api.player.setSpawnPoint(cell, p);
        }
    }

    public function getMapItem(itemId:Int):Bool {
        var g = _g();
        if (g == null || g.world == null || g.sfc == null) return false;
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
}
