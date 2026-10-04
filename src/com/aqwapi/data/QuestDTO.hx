package com.aqwapi.data;

import com.aqwapi.utils.ApiUtils;
import com.aqwapi.Api;

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
        var parsedReqs:Array<Dynamic> = null;
        if (rawData.Requirements != null) {
            try {
                if (Std.isOfType(rawData.Requirements, Array) && (cast rawData.Requirements : Array<Dynamic>).length > 0) {
                    parsedReqs = cast rawData.Requirements;
                }
            } catch (e:Dynamic) {}
        }

        if (parsedReqs == null && rawData.turnin != null) {
            var rawTurnin:Dynamic = rawData.turnin;
            var turninLen:Int = 0;
            try {
                if (rawTurnin.length != null) {
                    turninLen = Std.int(rawTurnin.length);
                }
            } catch (e:Dynamic) {}

            if (turninLen > 0) {
                var reqList:Array<Dynamic> = [];
                for (i in 0...turninLen) {
                    var tItem:Dynamic = null;
                    try { tItem = rawTurnin[i]; } catch (e:Dynamic) {}
                    if (tItem == null) continue;
                    var tId:Int = (tItem.ItemID != null) ? Std.int(tItem.ItemID) : ((tItem.id != null) ? Std.int(tItem.id) : 0);
                    var tQty:Int = (tItem.iQty != null) ? Std.int(tItem.iQty) : ((tItem.qty != null) ? Std.int(tItem.qty) : 1);
                    var tName:String = (tItem.sName != null) ? Std.string(tItem.sName) : null;
                    var tTemp:Dynamic = tItem.bTemp;

                    // 1. Look up in rawData.oItems if name is missing
                    if ((tName == null || tName == "") && tId > 0 && rawData.oItems != null) {
                        try {
                            var oItem:Dynamic = Reflect.field(rawData.oItems, Std.string(tId));
                            if (oItem != null) {
                                if (oItem.sName != null) tName = Std.string(oItem.sName);
                                else if (oItem.name != null) tName = Std.string(oItem.name);
                                if (oItem.bTemp != null) tTemp = oItem.bTemp;
                                if (oItem.iQty != null && tQty <= 1) tQty = Std.int(oItem.iQty);
                            }
                        } catch (e:Dynamic) {}
                    }

                    // 2. Look up in invTree if name is still missing
                    if ((tName == null || tName == "") && tId > 0) {
                        try {
                            if (Api.game != null && Api.game.world != null && Api.game.world.invTree != null) {
                                var invItem:Dynamic = Reflect.field(Api.game.world.invTree, Std.string(tId));
                                if (invItem != null) {
                                    if (invItem.sName != null) tName = Std.string(invItem.sName);
                                    else if (invItem.name != null) tName = Std.string(invItem.name);
                                    if (invItem.bTemp != null) tTemp = invItem.bTemp;
                                }
                            }
                        } catch (e:Dynamic) {}
                    }

                    reqList.push({
                        ItemID: tId,
                        id: tId,
                        sName: (tName != null) ? tName : "",
                        name: (tName != null) ? tName : "",
                        iQty: tQty,
                        qty: tQty,
                        bTemp: tTemp
                    });
                }
                parsedReqs = reqList;
            }
        }

        if (parsedReqs == null && rawData.oItems != null) {
            if (Std.isOfType(rawData.oItems, Array)) {
                parsedReqs = cast rawData.oItems;
            } else {
                var reqList:Array<Dynamic> = [];
                for (key in Reflect.fields(rawData.oItems)) {
                    var oItem:Dynamic = Reflect.field(rawData.oItems, key);
                    if (oItem == null) continue;
                    var tId:Int = (oItem.ItemID != null) ? Std.int(oItem.ItemID) : ((oItem.id != null) ? Std.int(oItem.id) : ApiUtils.parseInt(key, 0));
                    var tQty:Int = (oItem.iQty != null) ? Std.int(oItem.iQty) : ((oItem.qty != null) ? Std.int(oItem.qty) : 1);
                    var tName:String = (oItem.sName != null) ? Std.string(oItem.sName) : ((oItem.name != null) ? Std.string(oItem.name) : "");
                    var tTemp:Dynamic = oItem.bTemp;
                    reqList.push({
                        ItemID: tId,
                        id: tId,
                        sName: tName,
                        name: tName,
                        iQty: tQty,
                        qty: tQty,
                        bTemp: tTemp
                    });
                }
                parsedReqs = reqList;
            }
        }

        this.requirements = (parsedReqs != null) ? parsedReqs : [];

        // Rewards
        this.rewards = [];
        this.choiceRewards = [];

        var seenRewardIds = new Map<Int, Bool>();

        // 1. Parse oRewards object (Live AQW tree: itemsC = Choice, itemsS = Static, itemsR = Roll, itemsrand = Random)
        if (rawData.oRewards != null) {
            for (catKey in Reflect.fields(rawData.oRewards)) {
                var isChoiceCat = (catKey == "itemsC" || catKey == "2");
                var catObj:Dynamic = Reflect.field(rawData.oRewards, catKey);
                if (catObj != null) {
                    for (itemKey in Reflect.fields(catObj)) {
                        var rItem:Dynamic = Reflect.field(catObj, itemKey);
                        if (rItem != null) {
                            var rId:Int = (rItem.ItemID != null) ? Std.int(rItem.ItemID) : ((rItem.id != null) ? Std.int(rItem.id) : 0);
                            var rName:String = (rItem.sName != null) ? Std.string(rItem.sName) : ((rItem.name != null) ? Std.string(rItem.name) : "");
                            var rQty:Int = (rItem.iQty != null) ? Std.int(rItem.iQty) : ((rItem.qty != null) ? Std.int(rItem.qty) : 1);
                            var normItem = {
                                ItemID: rId,
                                id: rId,
                                sName: rName,
                                name: rName,
                                iQty: rQty,
                                qty: rQty,
                                iType: isChoiceCat ? 2 : 0,
                                bCoins: rItem.bCoins,
                                iStk: rItem.iStk,
                                bUpg: rItem.bUpg
                            };
                            if (rId > 0 && !seenRewardIds.exists(rId)) {
                                seenRewardIds.set(rId, true);
                                this.rewards.push(normItem);
                            }
                            if (isChoiceCat) {
                                this.choiceRewards.push(normItem);
                            }
                        }
                    }
                }
            }
        }

        // 2. Parse rawData.Rewards (Skua format)
        if (rawData.Rewards != null && Std.isOfType(rawData.Rewards, Array)) {
            var rawList:Array<Dynamic> = cast rawData.Rewards;
            for (r in rawList) {
                if (r == null) continue;
                var rId:Int = (r.ItemID != null) ? Std.int(r.ItemID) : ((r.id != null) ? Std.int(r.id) : 0);
                if (rId > 0 && !seenRewardIds.exists(rId)) {
                    seenRewardIds.set(rId, true);
                    this.rewards.push(r);
                }
            }
        }

        // 3. Simple Rewards & iType == 2 choice identification
        if (rawData.SimpleRewards != null && Std.isOfType(rawData.SimpleRewards, Array)) {
            this.simpleRewards = cast rawData.SimpleRewards;
            for (sr in this.simpleRewards) {
                if (sr != null && (sr.iType == 2 || sr.iType == "2")) {
                    var sId:Int = (sr.ItemID != null) ? Std.int(sr.ItemID) : ((sr.id != null) ? Std.int(sr.id) : 0);
                    // Match to rewards list to populate choiceRewards
                    var found = false;
                    for (cr in this.choiceRewards) {
                        var crId:Int = (cr.ItemID != null) ? Std.int(cr.ItemID) : ((cr.id != null) ? Std.int(cr.id) : 0);
                        if (crId == sId) { found = true; break; }
                    }
                    if (!found) {
                        for (r in this.rewards) {
                            var rId:Int = (r.ItemID != null) ? Std.int(r.ItemID) : ((r.id != null) ? Std.int(r.id) : 0);
                            if (rId == sId) {
                                this.choiceRewards.push(r);
                                found = true;
                                break;
                            }
                        }
                    }
                }
            }
        } else if (rawData.reward != null && Std.isOfType(rawData.reward, Array)) {
            this.simpleRewards = cast rawData.reward;
            for (sr in this.simpleRewards) {
                if (sr != null && (sr.iType == 2 || sr.iType == "2")) {
                    var sId:Int = (sr.ItemID != null) ? Std.int(sr.ItemID) : ((sr.id != null) ? Std.int(sr.id) : 0);
                    var found = false;
                    for (cr in this.choiceRewards) {
                        var crId:Int = (cr.ItemID != null) ? Std.int(cr.ItemID) : ((cr.id != null) ? Std.int(cr.id) : 0);
                        if (crId == sId) { found = true; break; }
                    }
                    if (!found) {
                        for (r in this.rewards) {
                            var rId:Int = (r.ItemID != null) ? Std.int(r.ItemID) : ((r.id != null) ? Std.int(r.id) : 0);
                            if (rId == sId) {
                                this.choiceRewards.push(r);
                                found = true;
                                break;
                            }
                        }
                    }
                }
            }
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

    public var choiceRewards:Array<Dynamic>;
    public var isChoice(get, never):Bool;
    @:getter(isChoice)
    public function get_isChoice_prop():Bool { return get_isChoice(); }
    public function get_isChoice():Bool {
        return choiceRewards != null && choiceRewards.length > 0;
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
