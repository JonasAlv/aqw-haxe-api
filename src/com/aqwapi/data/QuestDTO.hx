package com.aqwapi.data;

class QuestDTO {
    public var questId:Int;
    public var name:String;
    public var status:String;
    public var raw:Dynamic;

    public function new(rawData:Dynamic) {
        if (rawData == null) return;
        this.raw = rawData;
        this.questId = rawData.QuestID != null ? Std.int(rawData.QuestID) : 0;
        this.name = rawData.sName != null ? Std.string(rawData.sName) : "";
        this.status = rawData.status != null ? Std.string(rawData.status) : "";
    }

    public var isComplete(get, never):Bool;
    private function get_isComplete():Bool { return status == "c"; }

    public var isAccepted(get, never):Bool;
    private function get_isAccepted():Bool { return status == "a"; }
}
