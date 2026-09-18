package com.aqwapi.interfaces;

import com.aqwapi.data.EntityDTO;

interface IScriptMonster {
    function findByName(name:String, aliveOnly:Bool = true):EntityDTO;
    function findByMapId(mapId:String, aliveOnly:Bool = true):EntityDTO;
    function getLivingCells(name:String):Array<String>;
    function getByCell(cell:String):Array<EntityDTO>;
}
