package com.aqwapi.interfaces;

import com.aqwapi.utils.Promise;

interface IScriptInventory {
    function hasItem(itemName:String, quantity:Int = 1):Bool;
    function isEquipped(itemNameOrId:String):Bool;
    function getQuantity(itemName:String):Int;
    function getQuestQuantity(itemName:String):Int;
    function equip(itemNameOrId:String):Promise<Dynamic>;
    function equipWait(itemNameOrId:String, onComplete:Void->Void):Void;
    function equipUsable(itemNameOrId:String):Void;
    function bank(itemName:String):Promise<Dynamic>;
    function unbank(itemName:String):Promise<Dynamic>;
    function loadBank():Void;
    function toggleBank():Void;
}
