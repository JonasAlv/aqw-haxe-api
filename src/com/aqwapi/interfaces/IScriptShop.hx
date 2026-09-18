package com.aqwapi.interfaces;

interface IScriptShop {
    function loadShop(shopId:Int):Void;
    function buyItem(itemNameOrId:String, quantity:Int = 1):Void;
    function sellItem(itemNameOrId:String, quantity:Int = 1):Void;
    var isShopLoaded(get, never):Bool;
    var loadedShopId(get, never):Int;
}
