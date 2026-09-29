package com.aqwapi.managers;

import com.aqwapi.data.EntityDTO;
import com.aqwapi.utils.ApiUtils;
import com.aqwapi.Game;

class MonsterManager {
    private var _game:Game;

    public function new(gameReference:Game) {
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
        var idInt:Int = ApiUtils.parseInt(search, 0);

        // 1. Native AQW world.getMonster(int) lookup (returns live Avatar instance with pMC)
        if (idInt > 0 && _game != null && _game.world != null && _game.world.getMonster != null) {
            try {
                var rawAvt:Dynamic = _game.world.getMonster(idInt);
                if (rawAvt != null) {
                    var ent = new EntityDTO(rawAvt);
                    if (!aliveOnly || ent.alive) return ent;
                }
            } catch (e:Dynamic) {}
        }

        // 2. Scan raw monsters (Avatar instances from world.monsters)
        for (monster in _getRawMonsters()) {
            if (monster == null) continue;
            var target = new EntityDTO(monster);
            if ((target.mapId == search || target.id == search) && (!aliveOnly || target.alive)) return target;
        }

        // 3. Fallback to world.monTree leaf (for metadata if Avatar not yet spawned)
        if (_game != null && _game.world != null && _game.world.monTree != null) {
            try {
                var rawTree:Dynamic = _game.world.monTree;
                var rawMon:Dynamic = null;
                if (Reflect.hasField(rawTree, search)) {
                    rawMon = Reflect.field(rawTree, search);
                } else if (idInt > 0 && Reflect.hasField(rawTree, Std.string(idInt))) {
                    rawMon = Reflect.field(rawTree, Std.string(idInt));
                }
                if (rawMon != null) {
                    var ent = new EntityDTO(rawMon);
                    if (!aliveOnly || ent.alive) return ent;
                }
            } catch (e:Dynamic) {}
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

    public function getMonsterCells(nameOrId:String):Array<String> {
        var cells:Array<String> = [];
        if (nameOrId == null || nameOrId == "") return cells;
        var search:String = StringTools.trim(nameOrId).toLowerCase();
        var idInt:Int = ApiUtils.parseInt(nameOrId, 0);

        // 1. Check live monsters in world.monsters
        for (monster in _getRawMonsters()) {
            if (monster == null) continue;
            var target = new EntityDTO(monster);
            if (target.cell == "") continue;
            var match:Bool = (idInt > 0 && (target.id == nameOrId || target.mapId == nameOrId || target.monsterId == nameOrId))
                || (search == "*" || target.name.toLowerCase().indexOf(search) != -1);
            if (match && cells.indexOf(target.cell) == -1) {
                cells.push(target.cell);
            }
        }

        // 2. Check world.monTree (directory of all monster spawns on the map)
        if (_game != null && _game.world != null && _game.world.monTree != null) {
            try {
                var rawTree:Dynamic = _game.world.monTree;
                for (k in Reflect.fields(rawTree)) {
                    var leaf:Dynamic = Reflect.field(rawTree, k);
                    if (leaf == null) continue;
                    var sFrame:String = (leaf.sFrame != null) ? Std.string(leaf.sFrame) : "";
                    if (sFrame == "") continue;
                    var monName:String = (leaf.strMonName != null) ? Std.string(leaf.strMonName).toLowerCase() : "";
                    var mId:Int = (leaf.MonID != null) ? Std.int(leaf.MonID) : 0;
                    var mmapId:Int = (leaf.MonMapID != null) ? Std.int(leaf.MonMapID) : 0;

                    var match:Bool = (idInt > 0 && (idInt == mId || idInt == mmapId || Std.string(idInt) == k))
                        || (search == "*" || monName.indexOf(search) != -1);

                    if (match && cells.indexOf(sFrame) == -1) {
                        cells.push(sFrame);
                    }
                }
            } catch (e:Dynamic) {}
        }

        return cells;
    }

    public function getMonsterCell(nameOrId:String):String {
        var list = getMonsterCells(nameOrId);
        return list.length > 0 ? list[0] : "";
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

    public function isMonsterAliveInCell(cell:String):Bool {
        var list = getByCell(cell);
        for (m in list) {
            if (m != null && m.alive && m.hp > 0 && m.hasGraphic) return true;
        }
        return false;
    }

    public function getLivingMonstersInCell(cell:String):Array<EntityDTO> {
        var list = getByCell(cell);
        var res:Array<EntityDTO> = [];
        for (m in list) {
            if (m != null && m.alive && m.hp > 0 && m.hasGraphic) res.push(m);
        }
        return res;
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
