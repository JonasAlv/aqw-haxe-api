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

    public function getMonsterCells(nameOrId:Dynamic, mmid:Dynamic = null):Array<String> {
        var cells:Array<String> = [];
        if ((nameOrId == null || nameOrId == "") && mmid == null) return cells;
        var strVal:String = Std.string(nameOrId);
        var search:String = StringTools.trim(strVal).toLowerCase();
        var idInt:Int = ApiUtils.parseInt(nameOrId, 0);
        var mmidStr:String = (mmid != null) ? Std.string(mmid) : null;
        var mmidInt:Int = (mmid != null) ? ApiUtils.parseInt(mmid, 0) : 0;

        // 1. Check live monsters in world.monsters
        for (monster in _getRawMonsters()) {
            if (monster == null) continue;
            var target = new EntityDTO(monster);
            if (target.cell == "") continue;

            if (mmidStr != null) {
                if (target.mapId == mmidStr || (mmidInt > 0 && (target.id == mmidStr || target.monsterId == mmidStr))) {
                    if (cells.indexOf(target.cell) == -1) cells.push(target.cell);
                }
                continue;
            }

            var match:Bool = (idInt > 0 && (target.id == nameOrId || target.mapId == nameOrId || target.monsterId == nameOrId))
                || (search == "*" || (target.name != "" && target.name.toLowerCase().indexOf(search) != -1));
            if (match && cells.indexOf(target.cell) == -1) {
                cells.push(target.cell);
            }
        }

        // 2. Check world.monTree and world.mondef (directory of all monster spawns on the map)
        if (_game != null && _game.world != null) {
            var w:Dynamic = _game.world;
            var sources:Array<Dynamic> = [];
            if (w.monTree != null) sources.push(w.monTree);
            if (w.mondef != null) sources.push(w.mondef);

            for (src in sources) {
                if (src == null) continue;
                try {
                    var leaves:Array<Dynamic> = [];
                    if (Std.isOfType(src, Array)) {
                        var arr:Array<Dynamic> = cast src;
                        for (item in arr) if (item != null) leaves.push(item);
                    } else {
                        for (k in Reflect.fields(src)) {
                            var item:Dynamic = Reflect.field(src, k);
                            if (item != null) leaves.push(item);
                        }
                    }

                    for (leaf in leaves) {
                        if (leaf == null) continue;
                        var sFrame:String = "";
                        if (leaf.sFrame != null) sFrame = Std.string(leaf.sFrame);
                        else if (leaf.frame != null) sFrame = Std.string(leaf.frame);
                        else if (leaf.cell != null) sFrame = Std.string(leaf.cell);
                        else if (leaf.strFrame != null) sFrame = Std.string(leaf.strFrame);
                        if (sFrame == "") continue;

                        var mId:Int = (leaf.MonID != null) ? Std.int(leaf.MonID) : 0;
                        var mmapId:Int = (leaf.MonMapID != null) ? Std.int(leaf.MonMapID) : 0;

                        if (mmidInt > 0 || mmidStr != null) {
                            if (mmapId == mmidInt || Std.string(mmapId) == mmidStr) {
                                if (cells.indexOf(sFrame) == -1) cells.push(sFrame);
                            }
                            continue;
                        }

                        var monName:String = "";
                        if (leaf.strMonName != null) monName = Std.string(leaf.strMonName).toLowerCase();
                        else if (leaf.sName != null) monName = Std.string(leaf.sName).toLowerCase();
                        else if (leaf.monName != null) monName = Std.string(leaf.monName).toLowerCase();
                        else if (leaf.objData != null) {
                            if (leaf.objData.strMonName != null) monName = Std.string(leaf.objData.strMonName).toLowerCase();
                            else if (leaf.objData.sName != null) monName = Std.string(leaf.objData.sName).toLowerCase();
                        }

                        var match:Bool = (idInt > 0 && (idInt == mId || idInt == mmapId))
                            || (search == "*" || (monName != "" && monName.indexOf(search) != -1));

                        if (match && cells.indexOf(sFrame) == -1) {
                            cells.push(sFrame);
                        }
                    }
                } catch (e:Dynamic) {}
            }
        }

        return cells;
    }

    public function getMonsterCell(nameOrId:Dynamic, mmid:Dynamic = null):String {
        var list = getMonsterCells(nameOrId, mmid);
        if (list.length == 0) return "";
        var curCell = (Api.player != null && Api.player.cell != null) ? Api.player.cell.toLowerCase() : "";
        for (c in list) {
            if (c.toLowerCase() == curCell) return c;
        }
        return list[0];
    }

    public function getMapMonsters():Array<Dynamic> {
        var list:Array<Dynamic> = [];
        if (_game == null || _game.world == null) return list;
        var w:Dynamic = _game.world;

        var sources:Array<Dynamic> = [];
        if (w.monTree != null) sources.push(w.monTree);
        if (w.mondef != null) sources.push(w.mondef);

        for (src in sources) {
            if (src == null) continue;
            try {
                var leaves:Array<Dynamic> = [];
                if (Std.isOfType(src, Array)) {
                    var arr:Array<Dynamic> = cast src;
                    for (item in arr) if (item != null) leaves.push(item);
                } else {
                    for (k in Reflect.fields(src)) {
                        var item:Dynamic = Reflect.field(src, k);
                        if (item != null) leaves.push(item);
                    }
                }

                for (leaf in leaves) {
                    if (leaf == null) continue;
                    var sFrame:String = "";
                    if (leaf.sFrame != null) sFrame = Std.string(leaf.sFrame);
                    else if (leaf.frame != null) sFrame = Std.string(leaf.frame);
                    else if (leaf.cell != null) sFrame = Std.string(leaf.cell);
                    else if (leaf.strFrame != null) sFrame = Std.string(leaf.strFrame);

                    var monName:String = "";
                    if (leaf.strMonName != null) monName = Std.string(leaf.strMonName);
                    else if (leaf.sName != null) monName = Std.string(leaf.sName);
                    else if (leaf.monName != null) monName = Std.string(leaf.monName);
                    else if (leaf.objData != null) {
                        if (leaf.objData.strMonName != null) monName = Std.string(leaf.objData.strMonName);
                        else if (leaf.objData.sName != null) monName = Std.string(leaf.objData.sName);
                    }

                    if (monName != "") {
                        list.push({
                            name: monName,
                            cell: sFrame,
                            monId: leaf.MonID != null ? Std.int(leaf.MonID) : 0,
                            monMapId: leaf.MonMapID != null ? Std.int(leaf.MonMapID) : 0
                        });
                    }
                }
            } catch (e:Dynamic) {}
        }

        return list;
    }

    public function getMapMonsterNames():Array<String> {
        var names:Array<String> = [];
        for (m in getMapMonsters()) {
            if (m.name != null) {
                var n:String = Std.string(m.name);
                if (names.indexOf(n) == -1) names.push(n);
            }
        }
        return names;
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

    public function sortByLowestHp(monsters:Array<EntityDTO>):Array<EntityDTO> {
        if (monsters == null || monsters.length <= 1) return monsters;
        var res = monsters.copy();
        res.sort(function(a:EntityDTO, b:EntityDTO):Int {
            var aAlive = (a != null && a.alive && a.hp > 0);
            var bAlive = (b != null && b.alive && b.hp > 0);
            if (aAlive != bAlive) return aAlive ? -1 : 1;
            var aHp = (a != null) ? a.hp : 0;
            var bHp = (b != null) ? b.hp : 0;
            if (aHp != bHp) return aHp - bHp;
            var aId = (a != null) ? ApiUtils.parseInt(a.mapId, 0) : 0;
            var bId = (b != null) ? ApiUtils.parseInt(b.mapId, 0) : 0;
            return aId - bId;
        });
        return res;
    }

    public function sortByHighestHp(monsters:Array<EntityDTO>):Array<EntityDTO> {
        if (monsters == null || monsters.length <= 1) return monsters;
        var res = monsters.copy();
        res.sort(function(a:EntityDTO, b:EntityDTO):Int {
            var aAlive = (a != null && a.alive && a.hp > 0);
            var bAlive = (b != null && b.alive && b.hp > 0);
            if (aAlive != bAlive) return aAlive ? -1 : 1;
            var aHp = (a != null) ? a.hp : 0;
            var bHp = (b != null) ? b.hp : 0;
            if (aHp != bHp) return bHp - aHp;
            var aId = (a != null) ? ApiUtils.parseInt(a.mapId, 0) : 0;
            var bId = (b != null) ? ApiUtils.parseInt(b.mapId, 0) : 0;
            return aId - bId;
        });
        return res;
    }

    public function sortByClosest(monsters:Array<EntityDTO>):Array<EntityDTO> {
        if (monsters == null || monsters.length <= 1) return monsters;
        var pX:Float = 0.0;
        var pY:Float = 0.0;
        if (Api.player != null) {
            pX = Api.player.x;
            pY = Api.player.y;
        }
        var res = monsters.copy();
        res.sort(function(a:EntityDTO, b:EntityDTO):Int {
            var aAlive = (a != null && a.alive && a.hp > 0);
            var bAlive = (b != null && b.alive && b.hp > 0);
            if (aAlive != bAlive) return aAlive ? -1 : 1;
            var adx = (a != null) ? (a.x - pX) : 999999.0;
            var ady = (a != null) ? (a.y - pY) : 999999.0;
            var aDist = adx * adx + ady * ady;
            var bdx = (b != null) ? (b.x - pX) : 999999.0;
            var bdy = (b != null) ? (b.y - pY) : 999999.0;
            var bDist = bdx * bdx + bdy * bdy;
            if (aDist != bDist) return (aDist < bDist) ? -1 : 1;
            return 0;
        });
        return res;
    }

    public function sortMonsters(monsters:Array<EntityDTO>, priority:String = "lowest_hp"):Array<EntityDTO> {
        if (monsters == null || monsters.length <= 1) return monsters;
        var p = (priority != null) ? priority.toLowerCase() : "lowest_hp";
        if (p == "highest" || p == "highest_hp" || p == "max_hp") return sortByHighestHp(monsters);
        if (p == "closest" || p == "distance" || p == "near") return sortByClosest(monsters);
        return sortByLowestHp(monsters);
    }

    public function getBestMonsterTargetInCell(cell:String = null, nameOrId:Dynamic = "*"):EntityDTO {
        var c = (cell != null && cell != "") ? cell : ((Api.player != null) ? Api.player.cell : "");
        var living = getLivingMonstersInCell(c);
        if (living.length == 0) return null;
        var nameOrIdStr:String = Std.string(nameOrId);
        var search = (nameOrId != null) ? nameOrIdStr.toLowerCase() : "*";
        var idInt = (nameOrId != null) ? ApiUtils.parseInt(nameOrId, 0) : 0;

        var candidates:Array<EntityDTO> = [];
        for (m in living) {
            if (m == null || !m.alive || m.hp <= 0 || !m.hasGraphic) continue;
            var matches = (search == "*" || search == "any" || search == "")
                || (idInt > 0 && (m.id == nameOrId || m.mapId == nameOrId || m.monsterId == nameOrId))
                || (m.name != "" && m.name.toLowerCase().indexOf(search) != -1);
            if (matches) candidates.push(m);
        }
        if (candidates.length == 0) return null;
        var sorted = sortByLowestHp(candidates);
        return sorted[0];
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
