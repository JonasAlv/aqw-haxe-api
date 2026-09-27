package com.aqwapi.data;

class ItemDTO {
    public var itemId:Int;
    public var charItemId:Int;
    public var name:String;
    public var desc:String;
    public var type:String;
    public var es:String;
    public var quantity:Int;
    public var maxStack:Int;
    public var isCoins:Bool;
    public var isTemp:Bool;
    public var isEquipped:Bool;
    public var isMember:Bool;
    public var raw:Dynamic;

    public function new(rawData:Dynamic) {
        if (rawData == null) return;
        this.raw = rawData;
        this.itemId = rawData.ItemID != null ? Std.int(rawData.ItemID) : 0;
        this.charItemId = rawData.CharItemId != null ? Std.int(rawData.CharItemId) : (rawData.CharItemID != null ? Std.int(rawData.CharItemID) : 0);
        this.name = rawData.sName != null ? Std.string(rawData.sName) : "";
        this.desc = rawData.sDesc != null ? Std.string(rawData.sDesc) : "";
        this.type = rawData.sType != null ? Std.string(rawData.sType) : "";
        this.es = rawData.sES != null ? Std.string(rawData.sES) : "";
        this.quantity = rawData.iQty != null ? Std.int(rawData.iQty) : 1;
        this.maxStack = rawData.iStk != null ? Std.int(rawData.iStk) : 1;
        this.isCoins = rawData.bCoins == 1 || rawData.bCoins == "1" || rawData.bCoins == true;
        this.isTemp = rawData.bTemp == 1 || rawData.bTemp == "1" || rawData.bTemp == true;
        this.isEquipped = rawData.bEquip == 1 || rawData.bEquip == "1" || rawData.bEquip == true;
        this.isMember = rawData.bUpg == 1 || rawData.bUpg == "1" || rawData.bUpg == true;
    }
}
