package com.aqwapi.scripting.core;

class CoreMerge {
    public var travel:CoreTravel;
    public var shop:CoreShop;
    public var inventory:CoreInventory;
    public function new(travel:CoreTravel, shop:CoreShop, inventory:CoreInventory) { this.travel = travel; this.shop = shop; this.inventory = inventory; }
    public function buyRequirements(items:Array<Dynamic>, mapName:String = null, shopId:Int = -1):Bool { if (mapName != null && mapName != "" && !travel.ensure(mapName)) return false; if (shopId > 0) shop.load(shopId); shop.buyMany(items); return true; }
    public function ready(items:Array<Dynamic>):Bool { if (items == null) return true; for (item in items) if (!inventory.has(item)) return false; return true; }
}
