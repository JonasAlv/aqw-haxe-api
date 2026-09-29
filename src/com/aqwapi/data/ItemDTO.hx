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
    public var isWorn:Bool;
    public var isCosmetic:Bool;
    public var isMember:Bool;
    public var raw:Dynamic;

    public var enhPatternId(get, never):Int;
    @:getter(enhPatternId)
    public function get_enhPatternId_prop():Int { return get_enhPatternId(); }
    public function get_enhPatternId():Int {
        if (raw == null) return 0;
        if (Reflect.hasField(raw, "EnhPatternID")) return Std.int(Reflect.field(raw, "EnhPatternID"));
        if (Reflect.hasField(raw, "enhPID")) return Std.int(Reflect.field(raw, "enhPID"));
        if (Reflect.hasField(raw, "PatternID")) return Std.int(Reflect.field(raw, "PatternID"));
        return 0;
    }

    public var enhLevel(get, never):Int;
    @:getter(enhLevel)
    public function get_enhLevel_prop():Int { return get_enhLevel(); }
    public function get_enhLevel():Int {
        if (raw == null) return 0;
        if (Reflect.hasField(raw, "EnhLvl")) return Std.int(Reflect.field(raw, "EnhLvl"));
        if (Reflect.hasField(raw, "enhLvl")) return Std.int(Reflect.field(raw, "enhLvl"));
        if (Reflect.hasField(raw, "iLvl")) return Std.int(Reflect.field(raw, "iLvl"));
        return 0;
    }

    public var procId(get, never):Int;
    @:getter(procId)
    public function get_procId_prop():Int { return get_procId(); }
    public function get_procId():Int {
        if (raw == null) return 0;
        if (Reflect.hasField(raw, "ProcID")) return Std.int(Reflect.field(raw, "ProcID"));
        if (Reflect.hasField(raw, "procID")) return Std.int(Reflect.field(raw, "procID"));
        return 0;
    }

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
        this.isWorn = rawData.bWear == 1 || rawData.bWear == "1" || rawData.bWear == true;
        this.isCosmetic = this.isWorn;
        this.isMember = rawData.bUpg == 1 || rawData.bUpg == "1" || rawData.bUpg == true;
    }
}
