package com.aqwapi.managers;

import com.aqwapi.interfaces.IScriptMap;

class ScriptMap {
    private var _game:AQWGame;

    public function new(gameReference:AQWGame) {
        _game = gameReference;
    }

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

        if (mapName.indexOf("-") != -1) {
            if (AqwApi.transport != null) {
                AqwApi.transport.send("zm", "cmd", ["1", "tfer", username, mapName]);
            }
        } else {
            if (_game.world.gotoTown != null) {
                _game.world.gotoTown(mapName, cell, pad);
            }
        }
    }

    public function jump(cell:String, pad:String = "Enter"):Void {
        if (_game == null || _game.world == null) return;
        if (_game.world.moveToCell != null) {
            if (_game.world.strFrame != cell) {
                _game.world.moveToCell(cell, pad);
            }
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
        if (_game.world.myAvatar.pMC != null && target.pMC != null) {
            _game.world.myAvatar.pMC.x = target.pMC.x;
            _game.world.myAvatar.pMC.y = target.pMC.y;
        }
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
}
