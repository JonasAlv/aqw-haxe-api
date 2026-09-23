package com.aqwapi.data;

class QuestDTO {
    public var id:Int;
    public var questId(get, never):Int;
    public inline function get_questId():Int { return id; }

    public var name:String;
    public var slot:Int;
    public var value:Int;
    public var level:Int;
    public var gold:Int;
    public var xp:Int;
    public var once:Bool;
    public var upgrade:Bool;
    public var field:String;
    public var index:Int;
    public var status:String;
    public var requirements:Array<Dynamic>;
    public var rewards:Array<Dynamic>;
    public var acceptRequirements:Array<Dynamic>;
    public var simpleRewards:Array<Dynamic>;
    public var raw:Dynamic;

    public function new(rawData:Dynamic) {
        if (rawData == null) return;
        this.raw = rawData;

        // ID
        if (rawData.ID != null) this.id = Std.int(rawData.ID);
        else if (rawData.QuestID != null) this.id = Std.int(rawData.QuestID);
        else if (rawData.id != null) this.id = Std.int(rawData.id);
        else this.id = 0;

        // Name
        if (rawData.Name != null) this.name = Std.string(rawData.Name);
        else if (rawData.sName != null) this.name = Std.string(rawData.sName);
        else if (rawData.name != null) this.name = Std.string(rawData.name);
        else this.name = "";

        // Status
        this.status = (rawData.status != null) ? Std.string(rawData.status) : "";

        // Slot
        if (rawData.Slot != null) this.slot = Std.int(rawData.Slot);
        else if (rawData.iSlot != null) this.slot = Std.int(rawData.iSlot);
        else this.slot = -1;

        // Value
        if (rawData.Value != null) this.value = Std.int(rawData.Value);
        else if (rawData.iValue != null) this.value = Std.int(rawData.iValue);
        else this.value = 0;

        // Level
        if (rawData.Level != null) this.level = Std.int(rawData.Level);
        else if (rawData.iLvl != null) this.level = Std.int(rawData.iLvl);
        else this.level = 0;

        // Once
        if (rawData.Once != null) this.once = (rawData.Once == true || rawData.Once == 1 || rawData.Once == "1");
        else if (rawData.bOnce != null) this.once = (rawData.bOnce == 1 || rawData.bOnce == "1" || rawData.bOnce == true);
        else this.once = false;

        // Upgrade / Member
        if (rawData.Upgrade != null) this.upgrade = (rawData.Upgrade == true || rawData.Upgrade == 1 || rawData.Upgrade == "1");
        else if (rawData.bUpg != null) this.upgrade = (rawData.bUpg == 1 || rawData.bUpg == "1" || rawData.bUpg == true);
        else this.upgrade = false;

        // Gold & XP
        if (rawData.Gold != null) this.gold = Std.int(rawData.Gold);
        else if (rawData.iGold != null) this.gold = Std.int(rawData.iGold);
        else this.gold = 0;

        if (rawData.XP != null) this.xp = Std.int(rawData.XP);
        else if (rawData.iExp != null) this.xp = Std.int(rawData.iExp);
        else this.xp = 0;

        // Field & Index
        if (rawData.Field != null) this.field = Std.string(rawData.Field);
        else if (rawData.sField != null) this.field = Std.string(rawData.sField);
        else this.field = null;

        if (rawData.Index != null) this.index = Std.int(rawData.Index);
        else if (rawData.iIndex != null) this.index = Std.int(rawData.iIndex);
        else this.index = 0;

        // Requirements
        if (rawData.Requirements != null && Std.isOfType(rawData.Requirements, Array)) {
            this.requirements = cast rawData.Requirements;
        } else if (rawData.turnin != null && Std.isOfType(rawData.turnin, Array)) {
            this.requirements = cast rawData.turnin;
        } else if (rawData.oItems != null && Std.isOfType(rawData.oItems, Array)) {
            this.requirements = cast rawData.oItems;
        } else {
            this.requirements = [];
        }

        // Rewards
        if (rawData.Rewards != null && Std.isOfType(rawData.Rewards, Array)) {
            this.rewards = cast rawData.Rewards;
        } else if (rawData.reward != null && Std.isOfType(rawData.reward, Array)) {
            this.rewards = cast rawData.reward;
        } else {
            this.rewards = [];
        }

        // Simple Rewards
        if (rawData.SimpleRewards != null && Std.isOfType(rawData.SimpleRewards, Array)) {
            this.simpleRewards = cast rawData.SimpleRewards;
        } else {
            this.simpleRewards = [];
        }

        // Accept Requirements
        if (rawData.AcceptRequirements != null && Std.isOfType(rawData.AcceptRequirements, Array)) {
            this.acceptRequirements = cast rawData.AcceptRequirements;
        } else {
            this.acceptRequirements = [];
        }
    }

    public var isComplete(get, never):Bool;
    @:getter(isComplete)
    public function get_isComplete_prop():Bool { return get_isComplete(); }
    public function get_isComplete():Bool { return status == "c"; }

    public var isAccepted(get, never):Bool;
    @:getter(isAccepted)
    public function get_isAccepted_prop():Bool { return get_isAccepted(); }
    public function get_isAccepted():Bool { return status == "a"; }
}
