package com.aqwapi.managers;

class MapManager {
    private var _game:AqwGame;

    public function new(gameReference:AqwGame) {
        _game = gameReference;
    }

    private var _usePrivateRoom:Bool = true;
    private var _privateRoomNumber:Int = 100000;

    public function join(mapName:String, cell:String = "Enter", pad:String = "Spawn"):Void {
        if (_game == null || _game.world == null || _game.sfc == null) return;
        var avatar:Dynamic = _game.world.myAvatar;
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

        if (targetMap.indexOf("-") != -1) {
            if (AqwApi.transport != null) {
                AqwApi.transport.send("zm", "cmd", ["1", "tfer", username, targetMap]);
            }
        } else {
            if (_game.world.gotoTown != null) {
                _game.world.gotoTown(targetMap, cell, pad);
            } else if (AqwApi.transport != null) {
                AqwApi.transport.send("zm", "cmd", ["1", "tfer", username, targetMap]);
            }
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
        _game.sfc.sendString(packet);
    }

    private var _autoDeathSpawn:Bool = false;
    private var _lastSpawnCell:String = "";

    public function checkAutoDeathSpawn():Void {
        if (!_autoDeathSpawn || _game == null || _game.world == null) return;
        if (AqwApi.player != null && !AqwApi.player.isAlive) return;
        var curCell:String = (_game.world.strFrame != null) ? Std.string(_game.world.strFrame) : "";
        var curPad:String = (_game.world.strPad != null) ? Std.string(_game.world.strPad) : "Spawn";
        if (curCell != "" && curCell != _lastSpawnCell && curCell.toLowerCase().indexOf("cut") == -1) {
            _lastSpawnCell = curCell;
            AqwApi.player.setSpawnPoint(curCell, curPad);
        }
    }

    public function jump(cell:String, pad:String = "Enter"):Void {
        if (_game == null || _game.world == null) return;
        if (_game.world.moveToCell != null) {
            if (_game.world.strFrame != cell) {
                _game.world.moveToCell(cell, pad);
            }
        }
        if (_autoDeathSpawn && cell != null && cell != "" && cell.toLowerCase().indexOf("cut") == -1) {
            _lastSpawnCell = cell;
            AqwApi.player.setSpawnPoint(cell, pad);
        }
    }

    public function getMapItem(itemId:Int):Bool {
        if (_game == null || _game.world == null || _game.sfc == null) return false;
        try {
            var roomId:Dynamic = _game.sfc.activeRoomId != null ? _game.sfc.activeRoomId : _game.world.curRoom;
            _game.sfc.sendString("%xt%zm%getMapItem%" + roomId + "%" + itemId + "%");
            return true;
        } catch (e:Dynamic) { return false; }
    }

    public function snapTo(target:Dynamic):Void {
        if (_game == null || _game.world == null || _game.world.myAvatar == null || target == null) return;
        try {
            var myMC:Dynamic = _game.world.myAvatar.pMC;
            var tMC:Dynamic = null;
            if (Reflect.hasField(target, "raw") && target.raw != null) tMC = Reflect.field(target.raw, "pMC");
            else if (Reflect.hasField(target, "pMC")) tMC = Reflect.field(target, "pMC");
            if (myMC != null && tMC != null) {
                myMC.x = tMC.x;
                myMC.y = tMC.y;
                if (_game.world.pushMove != null) _game.world.pushMove(myMC, tMC.x, tMC.y, 16);
            }
        } catch (e:Dynamic) {}
    }

    public var isLoaded(get, never):Bool;
    @:getter(isLoaded)
    public function get_isLoaded_prop():Bool {
        return _game != null && _game.world != null
            && _game.world.mapLoadInProgress == false
            && _game.world.myAvatar != null
            && _game.world.myAvatar.pMC != null;
    }
    public function get_isLoaded():Bool {
        return _game != null && _game.world != null
            && _game.world.mapLoadInProgress == false
            && _game.world.myAvatar != null
            && _game.world.myAvatar.pMC != null;
    }

    public var name(get, never):String;
    @:getter(name)
    public function get_name_prop():String {
        if (_game == null || _game.world == null) return "";
        return _game.world.strMapName != null ? Std.string(_game.world.strMapName) : "";
    }
    public function get_name():String {
        if (_game == null || _game.world == null) return "";
        return _game.world.strMapName != null ? Std.string(_game.world.strMapName) : "";
    }

    public var roomId(get, never):Int;
    @:getter(roomId)
    public function get_roomId_prop():Int {
        if (_game == null) return 1;
        if (_game.sfc != null && _game.sfc.activeRoomId != null) return Std.int(_game.sfc.activeRoomId);
        if (_game.world != null && _game.world.curRoom != null) return Std.int(_game.world.curRoom);
        return 1;
    }
    public function get_roomId():Int {
        if (_game == null) return 1;
        if (_game.sfc != null && _game.sfc.activeRoomId != null) return Std.int(_game.sfc.activeRoomId);
        if (_game.world != null && _game.world.curRoom != null) return Std.int(_game.world.curRoom);
        return 1;
    }

    public var usePrivateRoom(get, set):Bool;
    @:getter(usePrivateRoom)
    public function get_usePrivateRoom_prop():Bool { return _usePrivateRoom; }
    @:setter(usePrivateRoom)
    public function set_usePrivateRoom_prop(v:Bool):Bool { _usePrivateRoom = v; return v; }
    public function get_usePrivateRoom():Bool { return _usePrivateRoom; }
    public function set_usePrivateRoom(v:Bool):Bool { _usePrivateRoom = v; return v; }

    public var privateRoomNumber(get, set):Int;
    @:getter(privateRoomNumber)
    public function get_privateRoomNumber_prop():Int { return _privateRoomNumber; }
    @:setter(privateRoomNumber)
    public function set_privateRoomNumber_prop(v:Int):Int { _privateRoomNumber = v; return v; }
    public function get_privateRoomNumber():Int { return _privateRoomNumber; }
    public function set_privateRoomNumber(v:Int):Int { _privateRoomNumber = v; return v; }

    public var autoDeathSpawn(get, set):Bool;
    @:getter(autoDeathSpawn)
    public function get_autoDeathSpawn_prop():Bool { return _autoDeathSpawn; }
    @:setter(autoDeathSpawn)
    public function set_autoDeathSpawn_prop(v:Bool):Bool { _autoDeathSpawn = v; if (v) checkAutoDeathSpawn(); return v; }
    public function get_autoDeathSpawn():Bool { return _autoDeathSpawn; }
    public function set_autoDeathSpawn(v:Bool):Bool { _autoDeathSpawn = v; if (v) checkAutoDeathSpawn(); return v; }
}
