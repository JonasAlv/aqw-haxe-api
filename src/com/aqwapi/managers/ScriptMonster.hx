package com.aqwapi.managers;

import com.aqwapi.data.EntityDTO;
import com.aqwapi.interfaces.IScriptMonster;

class ScriptMonster {
    private var _game:AQWGame;

    public function new(gameReference:AQWGame) {
        _game = gameReference;
    }

    public function findByName(name:String, aliveOnly:Bool = true):EntityDTO {
        var search:String = name != null ? name.toLowerCase() : "";
        for (monster in _getRawMonsters()) {
            if (monster == null) continue;
            var target = new EntityDTO(monster);
            if (target.name == "") continue;
            if ((search == "*" || target.name.toLowerCase().indexOf(search) != -1) && (!aliveOnly || target.alive))
                return target;
        }
        return null;
    }

    public function findByMapId(mapId:String, aliveOnly:Bool = true):EntityDTO {
        if (mapId == null) return null;
        var search:String = Std.string(mapId);
        for (monster in _getRawMonsters()) {
            if (monster == null) continue;
            var target = new EntityDTO(monster);
            if ((target.mapId == search || target.id == search) && (!aliveOnly || target.alive)) return target;
        }
        return null;
    }

    public function getLivingCells(name:String):Array<String> {
        var cells:Array<String> = [];
        var search:String = name != null ? name.toLowerCase() : "";
        for (monster in _getRawMonsters()) {
            if (monster == null) continue;
            var target = new EntityDTO(monster);
            if (!target.alive || target.cell == "") continue;
            if (search != "*" && target.name.toLowerCase().indexOf(search) == -1) continue;
            if (cells.indexOf(target.cell) == -1) cells.push(target.cell);
        }
        return cells;
    }

    public function getByCell(cell:String):Array<EntityDTO> {
        var result:Array<EntityDTO> = [];
        var targetCell:String = cell != null ? cell.toLowerCase() : "";

        // 1. Prioritize native AQW world.getMonstersByCell(cell)
        if (_game != null && _game.world != null && _game.world.getMonstersByCell != null) {
            try {
                var rawList:Dynamic = _game.world.getMonstersByCell(cell);
                var arr:Array<Dynamic> = [];
                if (Std.isOfType(rawList, Array)) {
                    var a:Array<Dynamic> = cast rawList;
                    for (i in 0...a.length) {
                        if (a[i] != null) arr.push(a[i]);
                    }
                }
                if (arr.length == 0 && rawList != null) {
                    for (k in Reflect.fields(rawList)) {
                        var item:Dynamic = Reflect.field(rawList, k);
                        if (item != null) arr.push(item);
                    }
                }
                for (mon in arr) {
                    if (mon != null) {
                        var ent = new EntityDTO(mon);
                        if (ent.cell == "" && cell != null) ent.cell = cell;
                        result.push(ent);
                    }
                }
            } catch (e:Dynamic) {}
        }

        if (result.length > 0) return result;

        // 2. Fallback: iterate over all monsters in world.monsters and match cell
        for (monster in _getRawMonsters()) {
            if (monster == null) continue;
            var target = new EntityDTO(monster);
            var monCell:String = target.cell != null ? target.cell.toLowerCase() : "";
            if (targetCell == "*" || targetCell == "" || monCell == targetCell) {
                result.push(target);
            }
        }
        return result;
    }

    private function _getRawMonsters():Array<Dynamic> {
        if (_game == null || _game.world == null || _game.world.monsters == null) return [];
        var raw:Dynamic = _game.world.monsters;
        var list:Array<Dynamic> = [];

        // In Flash, raw can be an Array, a Dictionary, or an Object
        if (Std.isOfType(raw, Array)) {
            var arr:Array<Dynamic> = cast raw;
            for (i in 0...arr.length) {
                var item:Dynamic = arr[i];
                if (item != null && list.indexOf(item) == -1) {
                    list.push(item);
                }
            }
        }

        // Also check dynamic properties/keys if list is empty or raw is Object/Dictionary
        if (list.length == 0 && raw != null) {
            try {
                for (k in Reflect.fields(raw)) {
                    var item:Dynamic = Reflect.field(raw, k);
                    if (item != null && list.indexOf(item) == -1) {
                        list.push(item);
                    }
                }
            } catch (e:Dynamic) {}
        }

        return list;
    }
}
