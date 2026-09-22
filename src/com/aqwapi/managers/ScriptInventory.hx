package com.aqwapi.managers;

import com.aqwapi.events.GameEvent;
import com.aqwapi.AqwApi;
import com.aqwapi.utils.Promise;

class ScriptInventory {
    private var _game:AqwGame;

    public function new(gameReference:AqwGame) {
        _game = gameReference;
    }

    public function hasItem(itemName:String, quantity:Int = 1):Bool {
        return getQuantity(itemName) >= quantity;
    }

    public function isEquipped(itemNameOrId:String):Bool {
        var item = _findItem(itemNameOrId);
        if (item == null) return false;
        var bEquip:Dynamic = item.bEquip;
        return bEquip == 1 || bEquip == "1" || bEquip == true;
    }

    public function getQuantity(itemNameOrId:String):Int {
        if (_game == null || _game.world == null || _game.world.myAvatar == null || _game.world.myAvatar.items == null) return 0;
        var targetId:Int = com.aqwapi.utils.AqwUtils.parseInt(itemNameOrId, 0);
        var isIdLookup:Bool = targetId > 0;
        var targetName:String = itemNameOrId.toLowerCase();
        var items:Array<Dynamic> = cast _game.world.myAvatar.items;
        for (item in items) {
            if (item == null || item.sName == null) continue;
            var sName:String = Std.string(item.sName).toLowerCase();
            var matches:Bool = isIdLookup ? (item.ItemID == targetId) : (sName == targetName);
            if (matches) return (item.iQty != null) ? Std.int(item.iQty) : 1;
        }
        return 0;
    }

    public function getQuestQuantity(itemName:String):Int {
        if (_game == null || _game.world == null) return 0;
        var targetNames:Array<String> = itemName.toLowerCase().split("|");
        var countedNames:Dynamic = {};
        var quantity:Int = 0;
        if (_game.world.invTree != null) {
            for (key in Reflect.fields(_game.world.invTree)) {
                var item:Dynamic = Reflect.field(_game.world.invTree, key);
                quantity += _addQuestQty(item, targetNames, countedNames);
            }
        }
        if (_game.world.myAvatar != null && _game.world.myAvatar.tempitems != null) {
            var tempItems:Array<Dynamic> = cast _game.world.myAvatar.tempitems;
            for (avatarItem in tempItems) quantity += _addQuestQty(avatarItem, targetNames, countedNames);
        }
        return quantity;
    }

    private function _addQuestQty(item:Dynamic, targetNames:Array<String>, countedNames:Dynamic):Int {
        if (item == null || item.sName == null) return 0;
        var itemName:String = Std.string(item.sName).toLowerCase();
        for (targetName in targetNames) {
            var targetId:Int = com.aqwapi.utils.AqwUtils.parseInt(targetName, 0);
            var isIdLookup:Bool = targetId > 0;
            var matches:Bool = isIdLookup ? (item.ItemID == targetId) : (itemName == targetName);
            if (matches) {
                if (Reflect.hasField(countedNames, targetName)) return 0;
                Reflect.setField(countedNames, targetName, true);
                var qty:Int = com.aqwapi.utils.AqwUtils.parseInt(item.iQty, 1);
                return (qty < 1) ? 1 : qty;
            }
        }
        return 0;
    }

    private function _findItem(itemNameOrId:String):Dynamic {
        if (_game == null || _game.world == null || _game.world.myAvatar == null || _game.world.myAvatar.items == null) return null;
        var itemId:Int = com.aqwapi.utils.AqwUtils.parseInt(itemNameOrId, 0);
        var isIdLookup:Bool = itemId > 0;
        var targetName:String = itemNameOrId.toLowerCase();
        var bestMatch:Dynamic = null;
        var items:Array<Dynamic> = cast _game.world.myAvatar.items;
        for (item in items) {
            if (item == null || item.sName == null) continue;
            if (isIdLookup) {
                if (item.ItemID == itemId) return item;
            } else {
                var sNameL:String = Std.string(item.sName).toLowerCase();
                if (sNameL == targetName) return item;
                else if (sNameL.indexOf(targetName) != -1 && bestMatch == null) bestMatch = item;
            }
        }
        return bestMatch;
    }

    public function equip(itemNameOrId:String):Promise<Dynamic> {
        return new Promise<Dynamic>(function(resolve:Dynamic->Void) {
            var bestMatch = _findItem(itemNameOrId);
            if (bestMatch == null) { resolve(null); return; }
            var bEquip:Dynamic = bestMatch.bEquip;
            if (bEquip == 1 || bEquip == "1" || bEquip == true) { resolve(null); return; }

            // Register listener BEFORE sending packet
            var listener:Dynamic->Void = null;
            listener = function(e:Dynamic) {
                AqwApi.dispatcher.removeEventListener(GameEvent.INVENTORY_CHANGED, listener);
                resolve(e);
            };
            AqwApi.dispatcher.addEventListener(GameEvent.INVENTORY_CHANGED, listener);

            if (_game.world != null && _game.world.sendEquipItemRequest != null) {
                _game.world.sendEquipItemRequest(bestMatch);
            } else if (_game.sfc != null) {
                var reqId:Dynamic = (_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : _game.world.curRoom;
                _game.sfc.sendString("%xt%zm%equipItem%" + reqId + "%" + bestMatch.ItemID + "%");
            } else {
                AqwApi.dispatcher.removeEventListener(GameEvent.INVENTORY_CHANGED, listener);
                resolve(null);
            }
        });
    }

    public function equipWait(itemNameOrId:String, onComplete:Void->Void):Void {
        equip(itemNameOrId).then(function(_:Dynamic) { if (onComplete != null) onComplete(); });
    }

    public function equipUsable(itemNameOrId:String):Void {
        var item = _findItem(itemNameOrId);
        if (item == null) return;
        if (_game.world != null && _game.world.equipUseableItem != null) {
            var usableObj:Dynamic = { ItemID: item.ItemID, sName: item.sName, sDesc: item.sDesc, sFile: item.sFile };
            _game.world.equipUseableItem(usableObj);
        }
    }

    public function bank(itemName:String):Promise<Dynamic> {
        return new Promise<Dynamic>(function(resolve:Dynamic->Void) {
            if (_game == null || _game.world == null || _game.world.myAvatar == null || _game.world.myAvatar.items == null) { resolve(null); return; }
            var targetName:String = itemName.toLowerCase();
            var bItem:Dynamic = null;
            var items:Array<Dynamic> = cast _game.world.myAvatar.items;
            for (i in items) { if (i != null && i.sName != null && Std.string(i.sName).toLowerCase() == targetName) { bItem = i; break; } }
            if (bItem == null) { resolve(null); return; }

            var listener:Dynamic->Void = null;
            listener = function(e:Dynamic) {
                AqwApi.dispatcher.removeEventListener(GameEvent.INVENTORY_CHANGED, listener);
                resolve(e);
            };
            AqwApi.dispatcher.addEventListener(GameEvent.INVENTORY_CHANGED, listener);

            if (_game.world.sendBankFromInvRequest != null) {
                _game.world.sendBankFromInvRequest(bItem);
            } else if (_game.sfc != null) {
                var reqId:Dynamic = (_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : _game.sfc.myUserId;
                _game.sfc.sendString("%xt%zm%bankFromInv%" + reqId + "%" + bItem.ItemID + "%" + bItem.CharItemID + "%");
            } else {
                AqwApi.dispatcher.removeEventListener(GameEvent.INVENTORY_CHANGED, listener);
                resolve(null);
            }
        });
    }

    public function unbank(itemName:String):Promise<Dynamic> {
        return new Promise<Dynamic>(function(resolve:Dynamic->Void) {
            if (_game == null || _game.world == null || _game.world.bankinfo == null || _game.world.bankinfo.items == null) { resolve(null); return; }
            var targetName:String = itemName.toLowerCase();
            var uItem:Dynamic = null;
            var bankItems:Array<Dynamic> = cast _game.world.bankinfo.items;
            for (i in bankItems) { if (i != null && i.sName != null && Std.string(i.sName).toLowerCase() == targetName) { uItem = i; break; } }
            if (uItem == null) { resolve(null); return; }

            var listener:Dynamic->Void = null;
            listener = function(e:Dynamic) {
                AqwApi.dispatcher.removeEventListener(GameEvent.INVENTORY_CHANGED, listener);
                resolve(e);
            };
            AqwApi.dispatcher.addEventListener(GameEvent.INVENTORY_CHANGED, listener);

            if (_game.world.sendBankToInvRequest != null) {
                _game.world.sendBankToInvRequest(uItem);
            } else if (_game.sfc != null) {
                var reqId:Dynamic = (_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : _game.sfc.myUserId;
                _game.sfc.sendString("%xt%zm%bankToInv%" + reqId + "%" + uItem.ItemID + "%" + uItem.CharItemID + "%");
            } else {
                AqwApi.dispatcher.removeEventListener(GameEvent.INVENTORY_CHANGED, listener);
                resolve(null);
            }
        });
    }

    public function loadBank():Void {
        if (_game == null || _game.world == null || _game.sfc == null) return;
        var reqId:Dynamic = (_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : _game.sfc.myUserId;
        _game.sfc.sendString("%xt%zm%loadBank%" + reqId + "%");
    }

    public function toggleBank():Void {
        if (_game != null && _game.world != null && _game.world.toggleBank != null)
            _game.world.toggleBank();
    }
}
