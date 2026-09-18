package com.aqwapi.data;

class ItemDTO {
    public var itemId:Int;
    public var charItemId:Int;
    public var name:String;
    public var quantity:Int;
    public var isEquipped:Bool;
    public var raw:Dynamic;

    public function new(rawData:Dynamic) {
        if (rawData == null) return;
        this.raw = rawData;
        this.itemId = rawData.ItemID != null ? Std.int(rawData.ItemID) : 0;
        this.charItemId = rawData.CharItemID != null ? Std.int(rawData.CharItemID) : 0;
        this.name = rawData.sName != null ? Std.string(rawData.sName) : "";
        this.quantity = rawData.iQty != null ? Std.int(rawData.iQty) : 1;
        this.isEquipped = rawData.bEquip == 1 || rawData.bEquip == "1" || rawData.bEquip == true;
    }
}
