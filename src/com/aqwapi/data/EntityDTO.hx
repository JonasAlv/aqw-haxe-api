package com.aqwapi.data;

class EntityDTO {
    public var id:String = "";
    public var name:String = "";
    public var cell:String = "";
    public var hp:Int = 0;
    public var mp:Int = 0;
    public var state:Int = 0;
    public var mapId:String = "";
    public var monsterId:String = "";
    public var raw:Dynamic;

    public var alive(get, never):Bool;
    private function get_alive():Bool {
        if (hp <= 0) return false;
        if (state == 0 && raw != null && raw.dataLeaf != null && raw.dataLeaf.intState != null && Std.int(raw.dataLeaf.intState) == 0) return false;
        return true;
    }

    public function new(rawData:Dynamic) {
        if (rawData == null) return;
        this.raw = rawData;

        var n:Dynamic = null;
        if (rawData.objData != null) n = rawData.objData.strMonName != null ? rawData.objData.strMonName : rawData.objData.strUsername;
        if (n == null && rawData.dataLeaf != null) n = rawData.dataLeaf.strMonName != null ? rawData.dataLeaf.strMonName : rawData.dataLeaf.strUsername;
        if (n == null) n = rawData.strMonName != null ? rawData.strMonName : rawData.strUsername;
        this.name = n != null ? Std.string(n) : "";

        if (rawData.dataLeaf != null && rawData.dataLeaf.intHP != null) this.hp = Std.int(rawData.dataLeaf.intHP);
        else if (rawData.objData != null && rawData.objData.intHP != null) this.hp = Std.int(rawData.objData.intHP);
        else if (rawData.objData != null && rawData.objData.intHPMax != null) this.hp = Std.int(rawData.objData.intHPMax);
        else if (rawData.intHP != null) this.hp = Std.int(rawData.intHP);

        if (rawData.dataLeaf != null && rawData.dataLeaf.intMP != null) this.mp = Std.int(rawData.dataLeaf.intMP);
        else if (rawData.objData != null && rawData.objData.intMP != null) this.mp = Std.int(rawData.objData.intMP);
        else if (rawData.intMP != null) this.mp = Std.int(rawData.intMP);

        if (rawData.dataLeaf != null && rawData.dataLeaf.intState != null) this.state = Std.int(rawData.dataLeaf.intState);
        else if (rawData.objData != null && rawData.objData.intState != null) this.state = Std.int(rawData.objData.intState);
        else if (rawData.intState != null) this.state = Std.int(rawData.intState);
        else this.state = (this.hp > 0) ? 1 : 0;

        if (rawData.dataLeaf != null && rawData.dataLeaf.strFrame != null && Std.string(rawData.dataLeaf.strFrame) != "")
            this.cell = Std.string(rawData.dataLeaf.strFrame);
        else if (rawData.objData != null && rawData.objData.strFrame != null && Std.string(rawData.objData.strFrame) != "")
            this.cell = Std.string(rawData.objData.strFrame);
        else if (rawData.strFrame != null && Std.string(rawData.strFrame) != "")
            this.cell = Std.string(rawData.strFrame);

        if (rawData.dataLeaf != null) {
            if (rawData.dataLeaf.MonMapID != null) { this.id = Std.string(rawData.dataLeaf.MonMapID); this.mapId = this.id; }
            else if (rawData.dataLeaf.entID != null) this.id = Std.string(rawData.dataLeaf.entID);
            if (rawData.dataLeaf.MonID != null) this.monsterId = Std.string(rawData.dataLeaf.MonID);
        } else if (rawData.objData != null && rawData.objData.MonMapID != null) {
            this.id = Std.string(rawData.objData.MonMapID);
        }
        if (this.mapId == "" && rawData.objData != null && rawData.objData.MonMapID != null) this.mapId = Std.string(rawData.objData.MonMapID);
        if (this.mapId == "" && rawData.MonMapID != null) this.mapId = Std.string(rawData.MonMapID);
        if (this.monsterId == "" && rawData.objData != null && rawData.objData.MonID != null) this.monsterId = Std.string(rawData.objData.MonID);
        if (this.monsterId == "" && rawData.MonID != null) this.monsterId = Std.string(rawData.MonID);
    }
}
