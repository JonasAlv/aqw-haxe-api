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
        if (raw != null) {
            if (Reflect.hasField(raw, "EnhPatternID") && Reflect.field(raw, "EnhPatternID") != null) {
                var v = Std.int(Reflect.field(raw, "EnhPatternID"));
                if (v > 0) return v;
            }
            if (Reflect.hasField(raw, "enhPID") && Reflect.field(raw, "enhPID") != null) {
                var v = Std.int(Reflect.field(raw, "enhPID"));
                if (v > 0) return v;
            }
            if (Reflect.hasField(raw, "PatternID") && Reflect.field(raw, "PatternID") != null) {
                var v = Std.int(Reflect.field(raw, "PatternID"));
                if (v > 0) return v;
            }
        }
        try {
            var g = Api.game;
            if (g != null && g.world != null && g.world.invTree != null && itemId > 0) {
                var tItem:Dynamic = Reflect.field(g.world.invTree, Std.string(itemId));
                if (tItem != null) {
                    if (Reflect.hasField(tItem, "EnhPatternID") && Reflect.field(tItem, "EnhPatternID") != null)
                        return Std.int(Reflect.field(tItem, "EnhPatternID"));
                    if (Reflect.hasField(tItem, "PatternID") && Reflect.field(tItem, "PatternID") != null)
                        return Std.int(Reflect.field(tItem, "PatternID"));
                }
            }
        } catch (_:Dynamic) {}
        return 0;
    }

    public var enhLevel(get, never):Int;
    @:getter(enhLevel)
    public function get_enhLevel_prop():Int { return get_enhLevel(); }
    public function get_enhLevel():Int {
        if (raw != null) {
            if (Reflect.hasField(raw, "EnhLvl") && Reflect.field(raw, "EnhLvl") != null) {
                var v = Std.int(Reflect.field(raw, "EnhLvl"));
                if (v > 0) return v;
            }
            if (Reflect.hasField(raw, "enhLvl") && Reflect.field(raw, "enhLvl") != null) {
                var v = Std.int(Reflect.field(raw, "enhLvl"));
                if (v > 0) return v;
            }
        }
        try {
            var g = Api.game;
            if (g != null && g.world != null && g.world.invTree != null && itemId > 0) {
                var tItem:Dynamic = Reflect.field(g.world.invTree, Std.string(itemId));
                if (tItem != null) {
                    if (Reflect.hasField(tItem, "EnhLvl") && Reflect.field(tItem, "EnhLvl") != null) {
                        var v = Std.int(Reflect.field(tItem, "EnhLvl"));
                        if (v > 0) return v;
                    }
                    if (Reflect.hasField(tItem, "enhLvl") && Reflect.field(tItem, "enhLvl") != null) {
                        var v = Std.int(Reflect.field(tItem, "enhLvl"));
                        if (v > 0) return v;
                    }
                }
            }
        } catch (_:Dynamic) {}

        var st = (type != null) ? type.toLowerCase() : "";
        if (st == "enhancement" || st == "scroll") {
            if (raw != null && Reflect.hasField(raw, "iLvl") && Reflect.field(raw, "iLvl") != null) {
                return Std.int(Reflect.field(raw, "iLvl"));
            }
        }
        return 0;
    }

    public var procId(get, never):Int;
    @:getter(procId)
    public function get_procId_prop():Int { return get_procId(); }
    public function get_procId():Int {
        if (raw != null) {
            if (Reflect.hasField(raw, "ProcID") && Reflect.field(raw, "ProcID") != null) {
                var v = Std.int(Reflect.field(raw, "ProcID"));
                if (v > 0) return v;
            }
            if (Reflect.hasField(raw, "procID") && Reflect.field(raw, "procID") != null) {
                var v = Std.int(Reflect.field(raw, "procID"));
                if (v > 0) return v;
            }
        }
        try {
            var g = Api.game;
            if (g != null && g.world != null && g.world.invTree != null && itemId > 0) {
                var tItem:Dynamic = Reflect.field(g.world.invTree, Std.string(itemId));
                if (tItem != null) {
                    if (Reflect.hasField(tItem, "ProcID") && Reflect.field(tItem, "ProcID") != null)
                        return Std.int(Reflect.field(tItem, "ProcID"));
                    if (Reflect.hasField(tItem, "procID") && Reflect.field(tItem, "procID") != null)
                        return Std.int(Reflect.field(tItem, "procID"));
                }
            }
        } catch (_:Dynamic) {}
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
