package com.aqwapi.managers;

import com.aqwapi.events.GameEvent;
import com.aqwapi.Api;
import com.aqwapi.data.ItemDTO;
import com.aqwapi.utils.ApiUtils;
import com.aqwapi.utils.Promise;
import com.aqwapi.Game;
import haxe.Timer;

class InventoryManager {
    private var _game:Game;

    public function new(gameReference:Game) {
        _game = gameReference;
    }

    public function hasItem(itemName:String, quantity:Int = 1):Bool {
        var qty = getQuantity(itemName);
        if (qty < quantity) {
            qty = getQuestQuantity(itemName);
        }
        return qty >= quantity;
    }

    public function hasItemById(itemId:Int, quantity:Int = 1):Bool {
        if (itemId <= 0) return false;
        if (_game != null && _game.world != null && _game.world.invTree != null) {
            var treeItem:Dynamic = Reflect.field(_game.world.invTree, Std.string(itemId));
            if (treeItem != null) {
                var curQty:Int = (treeItem.iQty != null) ? Std.int(treeItem.iQty) : 1;
                if (curQty >= quantity) return true;
            }
        }
        return hasItem(Std.string(itemId), quantity);
    }

    public function isEquipped(itemNameOrId:String):Bool {
        var item = _findItem(itemNameOrId);
        if (item == null) return false;
        var bEquip:Dynamic = item.bEquip;
        return bEquip == 1 || bEquip == "1" || bEquip == true;
    }

    public function getQuantity(itemNameOrId:String):Int {
        if (_game == null || _game.world == null || _game.world.myAvatar == null || _game.world.myAvatar.items == null) return 0;
        var targetId:Int = ApiUtils.parseInt(itemNameOrId, 0);
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

    public inline function getItemCount(itemNameOrId:String):Int {
        var q = getQuestQuantity(itemNameOrId);
        return q > 0 ? q : getQuantity(itemNameOrId);
    }

    public function getQuestQuantity(itemName:String):Int {
        if (_game == null || _game.world == null) return 0;
        var targetNames:Array<String> = itemName.toLowerCase().split("|");
        var countedNames:Dynamic = {};
        var quantity:Int = 0;

        // 1. Check world.invTree
        if (_game.world.invTree != null) {
            for (key in Reflect.fields(_game.world.invTree)) {
                var item:Dynamic = Reflect.field(_game.world.invTree, key);
                quantity += _addQuestQty(item, targetNames, countedNames);
            }
        }

        // 2. Check myAvatar items (normal inventory)
        if (_game.world.myAvatar != null && _game.world.myAvatar.items != null) {
            var items:Array<Dynamic> = cast _game.world.myAvatar.items;
            for (avatarItem in items) quantity += _addQuestQty(avatarItem, targetNames, countedNames);
        }

        // 3. Check myAvatar tempitems / tempItems
        var tempArr:Dynamic = null;
        if (_game.world.myAvatar != null) {
            if (_game.world.myAvatar.tempitems != null) tempArr = _game.world.myAvatar.tempitems;
            else if (Reflect.field(_game.world.myAvatar, "tempItems") != null) tempArr = Reflect.field(_game.world.myAvatar, "tempItems");
        }
        if (tempArr == null) {
            if (Reflect.field(_game.world, "tempitems") != null) tempArr = Reflect.field(_game.world, "tempitems");
            else if (Reflect.field(_game.world, "tempItems") != null) tempArr = Reflect.field(_game.world, "tempItems");
        }
        if (tempArr != null && Std.isOfType(tempArr, Array)) {
            var tempItems:Array<Dynamic> = cast tempArr;
            for (avatarItem in tempItems) quantity += _addQuestQty(avatarItem, targetNames, countedNames);
        }

        return quantity;
    }

    private function _addQuestQty(item:Dynamic, targetNames:Array<String>, countedNames:Dynamic):Int {
        if (item == null) return 0;
        var itemName:String = (item.sName != null) ? Std.string(item.sName).toLowerCase() : "";
        for (targetName in targetNames) {
            var targetId:Int = ApiUtils.parseInt(targetName, 0);
            var isIdLookup:Bool = targetId > 0;
            var matches:Bool = isIdLookup ? (item.ItemID == targetId) : (itemName == targetName);
            if (matches) {
                var uniqueKey:String = (item.ItemID != null) ? Std.string(item.ItemID) : targetName;
                if (Reflect.hasField(countedNames, uniqueKey)) return 0;
                Reflect.setField(countedNames, uniqueKey, true);
                var qty:Int = ApiUtils.parseInt(item.iQty, 1);
                return (qty < 1) ? 1 : qty;
            }
        }
        return 0;
    }

    private function _findItem(itemNameOrId:String):Dynamic {
        if (_game == null || _game.world == null || _game.world.myAvatar == null || _game.world.myAvatar.items == null) return null;
        var itemId:Int = ApiUtils.parseInt(itemNameOrId, 0);
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

            // If it is a consumable / potion / scroll, delegate to equipUsable
            var sES:String = (bestMatch.sES != null) ? Std.string(bestMatch.sES).toLowerCase() : "";
            var sType:String = (bestMatch.sType != null) ? Std.string(bestMatch.sType).toLowerCase() : "";
            var bU:Dynamic = bestMatch.bU;
            if (sES == "co" || sType == "item" || sType == "serveruse" || bU == 1 || bU == "1" || bU == true) {
                equipUsable(itemNameOrId);
                resolve(bestMatch);
                return;
            }

            var listener:Dynamic->Void = null;
            var timeoutTimer:Timer = null;

            var cleanup = function() {
                if (timeoutTimer != null) { timeoutTimer.stop(); timeoutTimer = null; }
                Api.dispatcher.removeEventListener(GameEvent.INVENTORY_CHANGED, listener);
            };

            listener = function(e:Dynamic) {
                cleanup();
                resolve(e);
            };

            Api.dispatcher.addEventListener(GameEvent.INVENTORY_CHANGED, listener);
            timeoutTimer = Timer.delay(function() {
                cleanup();
                resolve(null);
            }, 2500);

            if (_game.world != null && _game.world.sendEquipItemRequest != null) {
                _game.world.sendEquipItemRequest(bestMatch);
            } else if (_game.sfc != null) {
                var reqId:Dynamic = (_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : _game.world.curRoom;
                _game.sfc.sendString("%xt%zm%equipItem%" + reqId + "%" + bestMatch.ItemID + "%");
            } else {
                cleanup();
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
            var timeoutTimer:Timer = null;

            var cleanup = function() {
                if (timeoutTimer != null) { timeoutTimer.stop(); timeoutTimer = null; }
                Api.dispatcher.removeEventListener(GameEvent.INVENTORY_CHANGED, listener);
            };

            listener = function(e:Dynamic) {
                cleanup();
                resolve(e);
            };

            Api.dispatcher.addEventListener(GameEvent.INVENTORY_CHANGED, listener);
            timeoutTimer = Timer.delay(function() {
                cleanup();
                resolve(null);
            }, 2500);

            if (_game.world.sendBankFromInvRequest != null) {
                _game.world.sendBankFromInvRequest(bItem);
            } else if (_game.sfc != null) {
                var reqId:Dynamic = (_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : _game.sfc.myUserId;
                _game.sfc.sendString("%xt%zm%bankFromInv%" + reqId + "%" + bItem.ItemID + "%" + bItem.CharItemID + "%");
            } else {
                cleanup();
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
            var timeoutTimer:Timer = null;

            var cleanup = function() {
                if (timeoutTimer != null) { timeoutTimer.stop(); timeoutTimer = null; }
                Api.dispatcher.removeEventListener(GameEvent.INVENTORY_CHANGED, listener);
            };

            listener = function(e:Dynamic) {
                cleanup();
                resolve(e);
            };

            Api.dispatcher.addEventListener(GameEvent.INVENTORY_CHANGED, listener);
            timeoutTimer = Timer.delay(function() {
                cleanup();
                resolve(null);
            }, 2500);

            if (_game.world.sendBankToInvRequest != null) {
                _game.world.sendBankToInvRequest(uItem);
            } else if (_game.sfc != null) {
                var reqId:Dynamic = (_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : _game.sfc.myUserId;
                _game.sfc.sendString("%xt%zm%bankToInv%" + reqId + "%" + uItem.ItemID + "%" + uItem.CharItemID + "%");
            } else {
                cleanup();
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

    public function isInBank(itemNameOrId:String):Bool {
        if (_game == null || _game.world == null || _game.world.bankinfo == null || _game.world.bankinfo.items == null) return false;
        var targetId:Int = ApiUtils.parseInt(itemNameOrId, 0);
        var isIdLookup:Bool = targetId > 0;
        var targetName:String = itemNameOrId.toLowerCase();
        var bItems:Array<Dynamic> = cast _game.world.bankinfo.items;
        for (i in bItems) {
            if (i == null || i.sName == null) continue;
            if (isIdLookup) {
                if (i.ItemID == targetId) return true;
            } else {
                if (Std.string(i.sName).toLowerCase() == targetName) return true;
            }
        }
        return false;
    }

    public var isBankLoaded(get, never):Bool;
    @:getter(isBankLoaded)
    public function get_isBankLoaded_prop():Bool { return get_isBankLoaded(); }
    public function get_isBankLoaded():Bool {
        return _game != null && _game.world != null && _game.world.bankinfo != null && _game.world.bankinfo.isLoaded == true;
    }

    public var maxSlots(get, never):Int;
    @:getter(maxSlots)
    public function get_maxSlots_prop():Int { return get_maxSlots(); }
    public function get_maxSlots():Int {
        if (_game != null && _game.world != null && _game.world.myAvatar != null && _game.world.myAvatar.objData != null) {
            var s = _game.world.myAvatar.objData.iBagSlots;
            if (s != null) return Std.int(s);
        }
        return 0;
    }

    public var usedSlots(get, never):Int;
    @:getter(usedSlots)
    public function get_usedSlots_prop():Int { return get_usedSlots(); }
    public function get_usedSlots():Int {
        if (_game != null && _game.world != null && _game.world.myAvatar != null && _game.world.myAvatar.items != null) {
            return (cast _game.world.myAvatar.items : Array<Dynamic>).length;
        }
        return 0;
    }

    public var freeSlots(get, never):Int;
    @:getter(freeSlots)
    public function get_freeSlots_prop():Int { return get_freeSlots(); }
    public function get_freeSlots():Int {
        var max = maxSlots;
        if (max <= 0) return 0;
        var free = max - usedSlots;
        return free > 0 ? free : 0;
    }

    public var isFull(get, never):Bool;
    @:getter(isFull)
    public function get_isFull_prop():Bool { return get_isFull(); }
    public function get_isFull():Bool {
        var max = maxSlots;
        if (max <= 0) return false;
        return usedSlots >= max;
    }

    public var maxBankSlots(get, never):Int;
    @:getter(maxBankSlots)
    public function get_maxBankSlots_prop():Int { return get_maxBankSlots(); }
    public function get_maxBankSlots():Int {
        if (_game != null && _game.world != null && _game.world.myAvatar != null && _game.world.myAvatar.objData != null) {
            var s = _game.world.myAvatar.objData.iBankSlots;
            if (s != null) return Std.int(s);
        }
        return 0;
    }

    public var usedBankSlots(get, never):Int;
    @:getter(usedBankSlots)
    public function get_usedBankSlots_prop():Int { return get_usedBankSlots(); }
    public function get_usedBankSlots():Int {
        if (_game != null && _game.world != null && _game.world.bankinfo != null && _game.world.bankinfo.items != null) {
            return (cast _game.world.bankinfo.items : Array<Dynamic>).length;
        }
        return 0;
    }

    public function getItems():Array<ItemDTO> {
        var result:Array<ItemDTO> = [];
        if (_game != null && _game.world != null && _game.world.myAvatar != null && _game.world.myAvatar.items != null) {
            var rawList:Array<Dynamic> = cast _game.world.myAvatar.items;
            for (it in rawList) if (it != null) result.push(new ItemDTO(it));
        }
        return result;
    }

    public function getBankItems():Array<ItemDTO> {
        var result:Array<ItemDTO> = [];
        if (_game != null && _game.world != null && _game.world.bankinfo != null && _game.world.bankinfo.items != null) {
            var rawList:Array<Dynamic> = cast _game.world.bankinfo.items;
            for (it in rawList) if (it != null) result.push(new ItemDTO(it));
        }
        return result;
    }

    public function sellItem(itemNameOrId:String, quantity:Int = 1):Void {
        if (Api.shop != null) {
            Api.shop.sellItem(itemNameOrId, quantity);
        }
    }
}
