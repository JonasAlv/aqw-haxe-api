package com.aqwapi.managers;

import com.aqwapi.utils.ApiTimings;

import com.aqwapi.events.GameEvent;
import com.aqwapi.Api;
import com.aqwapi.data.ItemDTO;
import com.aqwapi.utils.ApiUtils;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.Promise;
import com.aqwapi.Game;
import flash.utils.Timer;
import flash.events.TimerEvent;

class InventoryManager {
    private var _game:Game;

    public function new(gameReference:Game) {
        _game = gameReference;
    }

    public function hasItem(itemNameOrId:Dynamic, quantity:Int = 1):Bool {
        var str = Std.string(itemNameOrId);
        var qty = getQuantity(str);
        if (qty < quantity) {
            qty = getQuestQuantity(str);
        }
        return qty >= quantity;
    }

    public function hasItemById(itemId:Int, quantity:Int = 1):Bool {
        if (itemId <= 0) return false;
        var strId = Std.string(itemId);
        var q = getQuestQuantity(strId);
        if (q >= quantity) return true;
        var invQ = getQuantity(strId);
        return invQ >= quantity;
    }

    public function isEquipped(itemNameOrId:Dynamic):Bool {
        var item = _findItem(Std.string(itemNameOrId));
        if (item == null) return false;
        var bEquip:Dynamic = item.bEquip;
        return bEquip == 1 || bEquip == "1" || bEquip == true;
    }

    public function isWorn(itemNameOrId:Dynamic):Bool {
        var item = _findItem(Std.string(itemNameOrId));
        if (item == null) return false;
        var bWear:Dynamic = item.bWear;
        return bWear == 1 || bWear == "1" || bWear == true;
    }

    public inline function isCosmetic(itemNameOrId:Dynamic):Bool {
        return isWorn(itemNameOrId);
    }

    public function getQuantity(itemNameOrId:Dynamic):Int {
        if (_game == null || _game.world == null || _game.world.myAvatar == null || _game.world.myAvatar.items == null) return 0;
        var str = Std.string(itemNameOrId);
        var targetId:Int = ApiUtils.parseInt(str, 0);
        var isIdLookup:Bool = targetId > 0;
        var targetName:String = str.toLowerCase();
        try {
            var items:Dynamic = _game.world.myAvatar.items;
            var len:Int = Std.int(items.length);
            for (i in 0...len) {
                var item:Dynamic = items[i];
                if (item == null || item.sName == null) continue;
                var sName:String = Std.string(item.sName).toLowerCase();
                var matches:Bool = isIdLookup ? (Std.int(item.ItemID) == targetId) : (sName == targetName);
                if (matches) return (item.iQty != null) ? Std.int(item.iQty) : 1;
            }
        } catch (_:Dynamic) {}
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

        // 1. Check myAvatar items (normal inventory)
        if (_game.world.myAvatar != null && _game.world.myAvatar.items != null) {
            try {
                var items:Dynamic = _game.world.myAvatar.items;
                var itemLen:Int = Std.int(items.length);
                for (i in 0...itemLen) {
                    var avatarItem:Dynamic = items[i];
                    quantity += _addQuestQty(avatarItem, targetNames, countedNames);
                }
            } catch (_:Dynamic) {}
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
        if (tempArr != null) {
            try {
                var len:Int = Std.int(tempArr.length);
                for (i in 0...len) {
                    var avatarItem:Dynamic = tempArr[i];
                    quantity += _addQuestQty(avatarItem, targetNames, countedNames);
                }
            } catch (_:Dynamic) {}
        }

        // 4. Check invTree (AQW's master dictionary of inventory & temporary items)
        if (_game.world.invTree != null) {
            try {
                for (targetName in targetNames) {
                    var targetId:Int = ApiUtils.parseInt(targetName, 0);
                    if (targetId > 0) {
                        var treeItem:Dynamic = _game.world.invTree[targetId];
                        if (treeItem != null) {
                            quantity += _addQuestQty(treeItem, [targetName], countedNames);
                        }
                    } else {
                        for (k in Reflect.fields(_game.world.invTree)) {
                            var treeItem:Dynamic = Reflect.field(_game.world.invTree, k);
                            if (treeItem != null) {
                                quantity += _addQuestQty(treeItem, [targetName], countedNames);
                            }
                        }
                    }
                }
            } catch (_:Dynamic) {}
        }

        // 5. Check myAvatar.getItemByID (AQW native method that checks items, houseitems, and tempitems)
        if (_game.world.myAvatar != null && _game.world.myAvatar.getItemByID != null) {
            try {
                for (targetName in targetNames) {
                    var targetId:Int = ApiUtils.parseInt(targetName, 0);
                    if (targetId > 0) {
                        var avItem:Dynamic = _game.world.myAvatar.getItemByID(targetId);
                        if (avItem != null) {
                            quantity += _addQuestQty(avItem, [targetName], countedNames);
                        }
                    }
                }
            } catch (_:Dynamic) {}
        }

        return quantity;
    }

    private function _addQuestQty(item:Dynamic, targetNames:Array<String>, countedNames:Dynamic):Int {
        if (item == null) return 0;
        var itemName:String = (item.sName != null) ? Std.string(item.sName).toLowerCase() : "";
        var itemItemId:Int = (item.ItemID != null) ? Std.int(item.ItemID) : ((item.id != null) ? Std.int(item.id) : 0);
        for (targetName in targetNames) {
            var targetId:Int = ApiUtils.parseInt(targetName, 0);
            var isIdLookup:Bool = targetId > 0;
            var matches:Bool = isIdLookup ? (itemItemId == targetId) : (itemName == targetName);
            if (!matches && !isIdLookup && itemName != "" && targetName != "") {
                var cleanItem = StringTools.replace(itemName, "\"", "");
                var cleanTarget = StringTools.replace(targetName, "\"", "");
                matches = (cleanItem == cleanTarget);
            }
            if (matches) {
                var uniqueKey:String = itemItemId > 0 ? Std.string(itemItemId) : targetName;
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

    public function equip(itemNameOrId:Dynamic):Promise<Dynamic> {
        return new Promise<Dynamic>(function(resolve:Dynamic->Void) {
            var str = Std.string(itemNameOrId);
            var bestMatch = _findItem(str);
            if (bestMatch == null) { resolve(null); return; }
            var bEquip:Dynamic = bestMatch.bEquip;
            if (bEquip == 1 || bEquip == "1" || bEquip == true) { resolve(null); return; }

            // If it is a consumable / potion / scroll, delegate to equipUsable
            var sES:String = (bestMatch.sES != null) ? Std.string(bestMatch.sES).toLowerCase() : "";
            var sType:String = (bestMatch.sType != null) ? Std.string(bestMatch.sType).toLowerCase() : "";
            var bU:Dynamic = bestMatch.bU;
            if (sES == "co" || sType == "item" || sType == "serveruse" || bU == 1 || bU == "1" || bU == true) {
                equipUsable(str);
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
            timeoutTimer = new Timer(ApiTimings.EQUIP_TIMEOUT_MS, 1);
            timeoutTimer.addEventListener(TimerEvent.TIMER, function(e:TimerEvent) {
                cleanup();
                resolve(null);
            });
            timeoutTimer.start();

            if (_game.world != null && _game.world.sendEquipItemRequest != null) {
                _game.world.sendEquipItemRequest(bestMatch);
            } else if (_game.sfc != null) {
                var reqId:Dynamic = (_game.world != null && _game.world.curRoom != null) ? _game.world.curRoom : ((_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : 1);
                _game.sfc.sendString("%xt%zm%equipItem%" + reqId + "%" + bestMatch.ItemID + "%");
            } else {
                cleanup();
                resolve(null);
            }
        });
    }

    public function equipWait(itemNameOrId:Dynamic, onComplete:Void->Void):Void {
        equip(itemNameOrId).then(function(_:Dynamic) { if (onComplete != null) onComplete(); });
    }

    public function equipUsable(itemNameOrId:Dynamic):Void {
        var str = Std.string(itemNameOrId);
        var item = _findItem(str);
        if (item == null) return;
        if (_game.world != null && _game.world.equipUseableItem != null) {
            var usableObj:Dynamic = { ItemID: item.ItemID, sName: item.sName, sDesc: item.sDesc, sFile: item.sFile };
            _game.world.equipUseableItem(usableObj);
        }
    }

    public var isBanking:Bool = false;
    private var _bankQueue:Array<String> = [];
    private var _bankTimer:Timer = null;

    public function bank(items:Dynamic):Void {
        if (items == null) return;
        var toAdd:Array<String> = [];
        if (Std.isOfType(items, Array)) {
            var arr:Array<Dynamic> = cast items;
            for (it in arr) {
                if (it != null) {
                    var s = StringTools.trim(Std.string(it));
                    if (s != "") toAdd.push(s);
                }
            }
        } else {
            var s = Std.string(items);
            if (s.indexOf(",") != -1) {
                for (p in s.split(",")) {
                    var pt = StringTools.trim(p);
                    if (pt != "") toAdd.push(pt);
                }
            } else if (s != "") {
                toAdd.push(s);
            }
        }

        if (toAdd.length == 0) return;

        for (item in toAdd) {
            var lower = item.toLowerCase();
            var exists = false;
            for (q in _bankQueue) {
                if (q.toLowerCase() == lower) { exists = true; break; }
            }
            if (!exists) _bankQueue.push(item);
        }

        isBanking = true;
        _ensureInHouse(function() {
            _startBankProcess();
        });
    }

    public function bankAll(?excludeItems:Dynamic):Void {
        if (_game == null || _game.world == null || _game.world.myAvatar == null || _game.world.myAvatar.items == null) return;
        var toBank = getBankableItems(excludeItems);
        if (toBank.length > 0) {
            ApiLogger.info("Bank", "Banking " + toBank.length + " unequipped items to bank...");
            bank(toBank);
        } else {
            ApiLogger.info("Bank", "No unequipped items to bank.");
            isBanking = false;
        }
    }

    public function bankAllExcept(excludeItems:Dynamic):Void {
        bankAll(excludeItems);
    }

    public function getBankableItems(?excludeItems:Dynamic):Array<String> {
        if (_game == null || _game.world == null || _game.world.myAvatar == null || _game.world.myAvatar.items == null) return [];
        var exMap = new Map<String, Bool>();
        if (excludeItems != null) {
            var resolved = PresetManager.instance.resolveItems(excludeItems);
            for (ex in resolved) exMap.set(ex.toLowerCase(), true);
        }
        var items:Array<Dynamic> = cast _game.world.myAvatar.items;
        var result:Array<String> = [];
        for (item in items) {
            if (item == null || item.sName == null) continue;
            var isEquipped:Bool = (item.bEquip == 1 || item.bEquip == "1" || item.bEquip == true);
            var isWorn:Bool = (item.bWear == 1 || item.bWear == "1" || item.bWear == true);
            var isTemp:Bool = (item.bTemp == 1 || item.bTemp == "1" || item.bTemp == true);
            var itemName:String = Std.string(item.sName);
            if (!isEquipped && !isWorn && !isTemp && !exMap.exists(itemName.toLowerCase())) {
                result.push(itemName);
            }
        }
        return result;
    }

    public function bankAllAc(?excludeItems:Dynamic):Void {
        if (_game == null || _game.world == null || _game.world.myAvatar == null || _game.world.myAvatar.items == null) return;
        var toBank = getBankableAcItems(excludeItems);
        if (toBank.length > 0) {
            ApiLogger.info("Bank", "Banking " + toBank.length + " unequipped AC items to bank...");
            bank(toBank);
        } else {
            ApiLogger.info("Bank", "No unequipped AC items to bank.");
            isBanking = false;
        }
    }

    public inline function bankAllAcItems(?excludeItems:Dynamic):Void {
        bankAllAc(excludeItems);
    }

    public function getBankableAcItems(?excludeItems:Dynamic):Array<String> {
        if (_game == null || _game.world == null || _game.world.myAvatar == null || _game.world.myAvatar.items == null) return [];
        var exMap = new Map<String, Bool>();
        if (excludeItems != null) {
            var resolved = PresetManager.instance.resolveItems(excludeItems);
            for (ex in resolved) exMap.set(ex.toLowerCase(), true);
        }
        var items:Array<Dynamic> = cast _game.world.myAvatar.items;
        var result:Array<String> = [];
        for (item in items) {
            if (item == null || item.sName == null) continue;
            var isEquipped:Bool = (item.bEquip == 1 || item.bEquip == "1" || item.bEquip == true);
            var isWorn:Bool = (item.bWear == 1 || item.bWear == "1" || item.bWear == true);
            var isTemp:Bool = (item.bTemp == 1 || item.bTemp == "1" || item.bTemp == true);
            var isAC:Bool = (item.bCoins == 1 || item.bCoins == "1" || item.bCoins == true);
            var itemName:String = Std.string(item.sName);
            if (!isEquipped && !isWorn && !isTemp && isAC && !exMap.exists(itemName.toLowerCase())) {
                result.push(itemName);
            }
        }
        return result;
    }

    public function unbankPreset(presetName:String):Void {
        var items = PresetManager.instance.getPresetItems(presetName);
        if (items.length > 0) {
            ApiLogger.info("Bank", "Unbanking " + items.length + " items for preset: " + presetName);
            unbank(items);
        } else {
            ApiLogger.warn("Bank", "Preset not found or empty: " + presetName);
        }
    }

    public function ensurePresetUnbanked(presetName:String):Bool {
        var items = PresetManager.instance.getPresetItems(presetName);
        if (items.length == 0) return true;
        return ensureUnbanked(items);
    }

    private var _isBankLoaded:Bool = false;
    private var _isBankLoading:Bool = false;
    private var _unbankTimer:Timer = null;
    private var _bankLoadPollTimer:Timer = null;
    private var _housePollTimer:Timer = null;

    private function _ensureInHouse(onInHouse:Void->Void):Void {
        var inHouse:Bool = (Api.map != null && Api.map.isHouse() && Api.map.isLoaded);
        if (inHouse) {
            onInHouse();
            return;
        }

        ApiLogger.info("Bank", "Joining private house before banking...");
        if (Api.map != null) {
            Api.map.joinHouse();
        }

        if (_housePollTimer != null) {
            _housePollTimer.stop();
            _housePollTimer = null;
        }

        var elapsed:Int = 0;
        _housePollTimer = new Timer(ApiTimings.HOUSE_POLL_MS);
        _housePollTimer.addEventListener(TimerEvent.TIMER, function(e:TimerEvent) {
            elapsed += 500;
            var inHouseNow:Bool = (Api.map != null && Api.map.isHouse() && Api.map.isLoaded);
            if (inHouseNow) {
                if (_housePollTimer != null) {
                    _housePollTimer.stop();
                    _housePollTimer = null;
                }
                var settleTimer = new Timer(ApiTimings.SETTLE_MS, 1);
                settleTimer.addEventListener(TimerEvent.TIMER, function(ev:TimerEvent) {
                    settleTimer.stop();
                    onInHouse();
                });
                settleTimer.start();
                return;
            }

            if (elapsed >= 15000) {
                if (_housePollTimer != null) {
                    _housePollTimer.stop();
                    _housePollTimer = null;
                }
                ApiLogger.warn("Bank", "Timed out joining house. Proceeding in current area.");
                onInHouse();
            }
        });
        _housePollTimer.start();
    }

    private function _startBankProcess():Void {
        var executeProcess = function():Void {
            if (_bankQueue.length > 0) _processBankQueue();
            if (_unbankQueue.length > 0) _processUnbankQueue();
        };

        if (isBankLoaded) {
            executeProcess();
            return;
        }

        ApiLogger.info("Bank", "Loading bank items...");
        var completed:Bool = false;
        var onLoadedCallback = function():Void {
            if (completed) return;
            completed = true;
            if (_bankLoadPollTimer != null) {
                _bankLoadPollTimer.stop();
                _bankLoadPollTimer = null;
            }
            executeProcess();
        };

        loadBank(onLoadedCallback);

        if (_bankLoadPollTimer != null) {
            _bankLoadPollTimer.stop();
            _bankLoadPollTimer = null;
        }
        var pollElapsed:Int = 0;
        _bankLoadPollTimer = new Timer(ApiTimings.BANK_LOAD_POLL_MS);
        _bankLoadPollTimer.addEventListener(TimerEvent.TIMER, function(e:TimerEvent) {
            pollElapsed += 300;
            if (isBankLoaded || pollElapsed >= 8000) {
                onLoadedCallback();
            }
        });
        _bankLoadPollTimer.start();
    }

    private function _processBankQueue():Void {
        if (_bankTimer != null) return;
        _bankTimer = new Timer(ApiTimings.BANK_ACTION_MS);
        _bankTimer.addEventListener(TimerEvent.TIMER, function(e:TimerEvent) {
            if (_bankQueue.length == 0) {
                if (_bankTimer != null) {
                    _bankTimer.stop();
                    _bankTimer = null;
                }
                isBanking = false;
                closeBank();
                ApiLogger.info("Bank", "Banking complete.");
                return;
            }

            var nextItem = _bankQueue.shift();
            if (nextItem == null) return;

            var targetName = nextItem.toLowerCase();
            var bItem:Dynamic = null;
            if (_game != null && _game.world != null && _game.world.myAvatar != null && _game.world.myAvatar.items != null) {
                var items:Array<Dynamic> = cast _game.world.myAvatar.items;
                for (i in items) {
                    if (i != null && i.sName != null && Std.string(i.sName).toLowerCase() == targetName) {
                        var isEquipped:Bool = (i.bEquip == 1 || i.bEquip == "1" || i.bEquip == true);
                        var isWorn:Bool = (i.bWear == 1 || i.bWear == "1" || i.bWear == true);
                        if (!isEquipped && !isWorn) {
                            bItem = i;
                            break;
                        }
                    }
                }
            }

            if (bItem != null) {
                ApiLogger.info("Bank", "Deposited " + nextItem);
                if (_game.world.sendBankFromInvRequest != null) {
                    _game.world.sendBankFromInvRequest(bItem);
                } else if (_game.sfc != null) {
                    var curRoom:Dynamic = (_game.world != null && _game.world.curRoom != null) ? _game.world.curRoom : 1;
                    _game.sfc.sendXtMessage("zm", "bankFromInv", [bItem.ItemID, bItem.CharItemID], "str", curRoom);
                }
            }
        });
        _bankTimer.start();
    }

    public var isUnbanking:Bool = false;
    private var _unbankQueue:Array<String> = [];

    public function unbank(items:Dynamic):Void {
        if (items == null) return;
        var toAdd:Array<String> = [];
        if (Std.isOfType(items, Array)) {
            var arr:Array<Dynamic> = cast items;
            for (it in arr) {
                if (it != null) {
                    var s = StringTools.trim(Std.string(it));
                    if (s != "") toAdd.push(s);
                }
            }
        } else {
            var s = Std.string(items);
            if (s.indexOf(",") != -1) {
                for (p in s.split(",")) {
                    var pt = StringTools.trim(p);
                    if (pt != "") toAdd.push(pt);
                }
            } else if (s != "") {
                toAdd.push(s);
            }
        }

        if (toAdd.length == 0) return;

        for (item in toAdd) {
            var lower = item.toLowerCase();
            var exists = false;
            for (q in _unbankQueue) {
                if (q.toLowerCase() == lower) { exists = true; break; }
            }
            if (!exists) _unbankQueue.push(item);
        }

        isUnbanking = true;
        _ensureInHouse(function() {
            _startUnbankProcess();
        });
    }

    public function ensureUnbanked(items:Dynamic):Bool {
        if (items == null) return true;
        if (!isBankLoaded) {
            unbank(items);
            return false;
        }
        var itemList:Array<String> = [];
        if (Std.isOfType(items, Array)) {
            var arr:Array<Dynamic> = cast items;
            for (it in arr) if (it != null) itemList.push(StringTools.trim(Std.string(it)));
        } else {
            var s = Std.string(items);
            if (s.indexOf(",") != -1) {
                for (p in s.split(",")) itemList.push(StringTools.trim(p));
            } else if (s != "") {
                itemList.push(s);
            }
        }

        var anyInBank = false;
        for (it in itemList) {
            if (isInBank(it)) {
                anyInBank = true;
                break;
            }
        }

        if (anyInBank || isUnbanking) {
            unbank(items);
            return false;
        }

        return true;
    }

    public function getBankNonAcItems(?excludeItems:Dynamic):Array<String> {
        if (_game == null || _game.world == null || _game.world.bankinfo == null) return [];
        var exMap = new Map<String, Bool>();
        if (excludeItems != null) {
            var resolved = PresetManager.instance.resolveItems(excludeItems);
            for (ex in resolved) exMap.set(ex.toLowerCase(), true);
        }

        var result:Array<String> = [];
        var seen = new Map<String, Bool>();

        var checkItem = function(it:Dynamic):Void {
            if (it == null || it.sName == null) return;
            var isAC:Bool = (it.bCoins == 1 || it.bCoins == "1" || it.bCoins == true);
            if (!isAC) {
                var name:String = Std.string(it.sName);
                var lower = StringTools.trim(name).toLowerCase();
                if (!exMap.exists(lower) && !seen.exists(lower)) {
                    seen.set(lower, true);
                    result.push(name);
                }
            }
        };

        try {
            var bi:Dynamic = _game.world.bankinfo;
            if (bi.bankItems != null) {
                for (k in Reflect.fields(bi.bankItems)) {
                    checkItem(Reflect.field(bi.bankItems, k));
                }
            }
            if (bi.BankArray != null) {
                var arr:Array<Dynamic> = cast bi.BankArray;
                for (it in arr) checkItem(it);
            }
            if (bi.items != null) {
                var arr:Array<Dynamic> = cast bi.items;
                for (it in arr) checkItem(it);
            }
            if (_game.world.myAvatar != null && _game.world.myAvatar.bank != null) {
                var arr:Array<Dynamic> = cast _game.world.myAvatar.bank;
                for (it in arr) checkItem(it);
            }
        } catch (e:Dynamic) {}

        return result;
    }

    public function unbankAllNonAc(?excludeItems:Dynamic):Void {
        isUnbanking = true;
        _ensureInHouse(function() {
            var executeUnbank = function():Void {
                var nonAc = getBankNonAcItems(excludeItems);
                if (nonAc.length > 0) {
                    ApiLogger.info("Bank", "Unbanking " + nonAc.length + " Non-AC items from bank...");
                    unbank(nonAc);
                } else {
                    ApiLogger.info("Bank", "No Non-AC items found in bank.");
                    isUnbanking = false;
                }
            };

            if (isBankLoaded) {
                executeUnbank();
                return;
            }

            ApiLogger.info("Bank", "Loading bank items...");
            var completed:Bool = false;
            var onLoadedCallback = function():Void {
                if (completed) return;
                completed = true;
                if (_bankLoadPollTimer != null) {
                    _bankLoadPollTimer.stop();
                    _bankLoadPollTimer = null;
                }
                executeUnbank();
            };

            loadBank(onLoadedCallback);

            if (_bankLoadPollTimer != null) {
                _bankLoadPollTimer.stop();
                _bankLoadPollTimer = null;
            }
            var pollElapsed:Int = 0;
            _bankLoadPollTimer = new Timer(ApiTimings.BANK_LOAD_POLL_MS);
            _bankLoadPollTimer.addEventListener(TimerEvent.TIMER, function(e:TimerEvent) {
                pollElapsed += 300;
                if (isBankLoaded || pollElapsed >= 8000) {
                    onLoadedCallback();
                }
            });
            _bankLoadPollTimer.start();
        });
    }

    public inline function unbankAllNonAcItems(?excludeItems:Dynamic):Void {
        unbankAllNonAc(excludeItems);
    }

    public function bankAcAndUnbankNonAc(?excludeItems:Dynamic):Void {
        isBanking = true;
        _ensureInHouse(function() {
            var toBank = getBankableAcItems(excludeItems);
            if (toBank.length > 0) {
                ApiLogger.info("Bank", "Depositing " + toBank.length + " AC items first...");
                bank(toBank);
                var pollTimer:Timer = new Timer(ApiTimings.BANK_LOAD_POLL_MS);
                pollTimer.addEventListener(TimerEvent.TIMER, function(e:TimerEvent) {
                    if (_bankQueue.length == 0 && _bankTimer == null) {
                        pollTimer.stop();
                        isBanking = false;
                        unbankAllNonAc(excludeItems);
                    }
                });
                pollTimer.start();
            } else {
                ApiLogger.info("Bank", "No AC items to bank. Unbanking Non-AC items...");
                isBanking = false;
                unbankAllNonAc(excludeItems);
            }
        });
    }

    private function _startUnbankProcess():Void {
        var executeProcess = function():Void {
            if (_unbankQueue.length > 0) _processUnbankQueue();
            if (_bankQueue.length > 0) _processBankQueue();
        };

        if (isBankLoaded) {
            executeProcess();
            return;
        }

        ApiLogger.info("Bank", "Loading bank items...");
        var completed:Bool = false;
        var onLoadedCallback = function():Void {
            if (completed) return;
            completed = true;
            if (_bankLoadPollTimer != null) {
                _bankLoadPollTimer.stop();
                _bankLoadPollTimer = null;
            }
            executeProcess();
        };

        loadBank(onLoadedCallback);

        if (_bankLoadPollTimer != null) {
            _bankLoadPollTimer.stop();
            _bankLoadPollTimer = null;
        }
        var pollElapsed:Int = 0;
        _bankLoadPollTimer = new Timer(ApiTimings.BANK_LOAD_POLL_MS);
        _bankLoadPollTimer.addEventListener(TimerEvent.TIMER, function(e:TimerEvent) {
            pollElapsed += 300;
            if (isBankLoaded || pollElapsed >= 8000) {
                onLoadedCallback();
            }
        });
        _bankLoadPollTimer.start();
    }

    private function _processUnbankQueue():Void {
        if (_unbankTimer != null) return;
        _unbankTimer = new Timer(ApiTimings.BANK_ACTION_MS);
        _unbankTimer.addEventListener(TimerEvent.TIMER, function(e:TimerEvent) {
            if (_unbankQueue.length == 0) {
                if (_unbankTimer != null) {
                    _unbankTimer.stop();
                    _unbankTimer = null;
                }
                isUnbanking = false;
                closeBank();
                ApiLogger.info("Bank", "Unbanking complete.");
                return;
            }

            if (isFull) {
                _unbankQueue = [];
                if (_unbankTimer != null) {
                    _unbankTimer.stop();
                    _unbankTimer = null;
                }
                isUnbanking = false;
                closeBank();
                ApiLogger.warn("Bank", "Inventory full, unbanking halted.");
                return;
            }

            var nextItem = _unbankQueue.shift();
            if (nextItem == null) return;

            var targetName = StringTools.trim(nextItem).toLowerCase();
            var uItem:Dynamic = null;
            if (_game != null && _game.world != null && _game.world.bankinfo != null) {
                var bi:Dynamic = _game.world.bankinfo;
                if (bi.bankItems != null) {
                    for (k in Reflect.fields(bi.bankItems)) {
                        var item:Dynamic = Reflect.field(bi.bankItems, k);
                        if (item != null && item.sName != null && StringTools.trim(Std.string(item.sName)).toLowerCase() == targetName) {
                            uItem = item;
                            break;
                        }
                    }
                }
                if (uItem == null && bi.BankArray != null) {
                    var bItems:Array<Dynamic> = cast bi.BankArray;
                    for (i in bItems) {
                        if (i != null && i.sName != null && StringTools.trim(Std.string(i.sName)).toLowerCase() == targetName) {
                            uItem = i;
                            break;
                        }
                    }
                }
                if (uItem == null && bi.items != null) {
                    var bItems:Array<Dynamic> = cast bi.items;
                    for (i in bItems) {
                        if (i != null && i.sName != null && StringTools.trim(Std.string(i.sName)).toLowerCase() == targetName) {
                            uItem = i;
                            break;
                        }
                    }
                }
                if (uItem == null && _game.world.myAvatar != null && _game.world.myAvatar.bank != null) {
                    var bItems:Array<Dynamic> = cast _game.world.myAvatar.bank;
                    for (i in bItems) {
                        if (i != null && i.sName != null && StringTools.trim(Std.string(i.sName)).toLowerCase() == targetName) {
                            uItem = i;
                            break;
                        }
                    }
                }
            }

            if (uItem != null) {
                ApiLogger.info("Bank", "Withdrew " + nextItem);
                if (_game.world.sendBankToInvRequest != null) {
                    _game.world.sendBankToInvRequest(uItem);
                } else if (_game.sfc != null) {
                    var curRoom:Dynamic = (_game.world != null && _game.world.curRoom != null) ? _game.world.curRoom : 1;
                    _game.sfc.sendXtMessage("zm", "bankToInv", [uItem.ItemID, uItem.CharItemID], "str", curRoom);
                }
            }
        });
        _unbankTimer.start();
    }

    public function clearBankQueue():Void {
        _bankQueue = [];
        _unbankQueue = [];
        if (_bankTimer != null) {
            _bankTimer.stop();
            _bankTimer = null;
        }
        if (_unbankTimer != null) {
            _unbankTimer.stop();
            _unbankTimer = null;
        }
        if (_bankLoadPollTimer != null) {
            _bankLoadPollTimer.stop();
            _bankLoadPollTimer = null;
        }
        if (_housePollTimer != null) {
            _housePollTimer.stop();
            _housePollTimer = null;
        }
        isBanking = false;
        isUnbanking = false;
        _isBankLoading = false;
        closeBank();
    }

    public function loadBank(?onLoaded:Void->Void):Void {
        if (_game == null) {
            if (onLoaded != null) onLoaded();
            return;
        }

        if (isBankLoaded) {
            if (onLoaded != null) onLoaded();
            return;
        }

        var onDone = function():Void {
            _isBankLoaded = true;
            _isBankLoading = false;
            if (onLoaded != null) {
                var cb = onLoaded;
                onLoaded = null;
                cb();
            }
        };

        var handled:Bool = false;

        // 1. Primary: requestAPI("bank", {"layout":{"cat":"all"}}, onComplete, onError, true)
        try {
            var reqApi = Reflect.field(_game, "requestAPI");
            if (reqApi != null) {
                var onComplete = function(e:Dynamic):Void {
                    try {
                        if (Reflect.hasField(_game, "onBankComplete")) {
                            Reflect.callMethod(_game, Reflect.field(_game, "onBankComplete"), [e]);
                        } else {
                            var rawData:Dynamic = Reflect.field(e.target, "data");
                            var arr:Dynamic = null;
                            if (Std.isOfType(rawData, String)) {
                                try {
                                    arr = untyped __global__["JSON"].parse(rawData);
                                } catch (e1:Dynamic) {
                                    arr = haxe.Json.parse(rawData);
                                }
                            } else {
                                arr = rawData;
                            }
                            if (_game != null && _game.world != null && _game.world.addItemsToBank != null && arr != null) {
                                _game.world.addItemsToBank(arr);
                            }
                        }
                    } catch (err:Dynamic) {
                        try {
                            var rawData:Dynamic = Reflect.field(e.target, "data");
                            var arr:Dynamic = null;
                            if (Std.isOfType(rawData, String)) {
                                arr = untyped __global__["JSON"].parse(rawData);
                            } else {
                                arr = rawData;
                            }
                            if (_game != null && _game.world != null && _game.world.addItemsToBank != null && arr != null) {
                                _game.world.addItemsToBank(arr);
                            }
                        } catch (err2:Dynamic) {}
                    }
                    ApiLogger.info("Bank", "Bank data loaded.");
                    onDone();
                };

                var onError = function(e:Dynamic):Void {
                    _isBankLoading = false;
                    ApiLogger.warn("Bank", "Error loading bank information from server.");
                };

                var layoutObj:Dynamic = {layout: {cat: "all"}};
                Reflect.callMethod(_game, reqApi, ["bank", layoutObj, onComplete, onError, true]);
                handled = true;
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("Bank", "requestAPI call failed: " + Std.string(e));
        }

        // 2. Fallback: getBank()
        if (!handled) {
            try {
                var getB = Reflect.field(_game, "getBank");
                if (getB != null) {
                    Reflect.callMethod(_game, getB, []);
                    handled = true;
                }
            } catch (e:Dynamic) {}
        }

        // 3. Fallback: world.rootClass.getBank()
        if (!handled) {
            try {
                if (_game.world != null && _game.world.rootClass != null) {
                    var rcGetB = Reflect.field(_game.world.rootClass, "getBank");
                    if (rcGetB != null) {
                        Reflect.callMethod(_game.world.rootClass, rcGetB, []);
                        handled = true;
                    }
                }
            } catch (e:Dynamic) {}
        }

        // 4. Fallback: toggleHouseBank() / toggleBank()
        if (!handled) {
            try {
                if (_game.world != null) {
                    if (_game.world.toggleHouseBank != null) {
                        _game.world.toggleHouseBank();
                        handled = true;
                    } else if (_game.world.toggleBank != null) {
                        _game.world.toggleBank();
                        handled = true;
                    }
                }
            } catch (e:Dynamic) {}
        }

        // 5. Fallback: legacy socket sendLoadBankRequest
        if (!handled) {
            try {
                if (_game.world != null && _game.world.sendLoadBankRequest != null) {
                    _game.world.sendLoadBankRequest(["All"]);
                } else if (_game.sfc != null) {
                    var rId:Dynamic = (_game.world != null && _game.world.curRoom != null) ? _game.world.curRoom : 1;
                    _game.sfc.sendXtMessage("zm", "loadBank", ["All"], "str", rId);
                }
            } catch (e:Dynamic) {}
        }
    }

    public function onBankLoaded():Void {
        _isBankLoaded = true;
    }

    public function toggleBank():Void {
        if (_game != null && _game.world != null && _game.world.toggleBank != null)
            _game.world.toggleBank();
    }

    public function closeBank():Void {
        if (_game != null && _game.ui != null && _game.ui.mcPopup != null) {
            try {
                if (_game.ui.mcPopup.currentLabel == "Bank" || _game.ui.mcPopup.currentLabel == "HouseBank") {
                    _game.ui.mcPopup.fClose();
                }
            } catch (e:Dynamic) {}
        }
    }

    public function isInBank(itemNameOrId:String):Bool {
        if (_game == null || _game.world == null || _game.world.bankinfo == null) return false;
        var targetId:Int = ApiUtils.parseInt(itemNameOrId, 0);
        var isIdLookup:Bool = targetId > 0;
        var targetName:String = StringTools.trim(itemNameOrId).toLowerCase();

        if (isIdLookup && _game.world.bankinfo.isItemInBank != null) {
            try {
                if (_game.world.bankinfo.isItemInBank(targetId)) return true;
            } catch (e:Dynamic) {}
        }

        try {
            var bi:Dynamic = _game.world.bankinfo;
            if (bi.bankItems != null) {
                if (isIdLookup) {
                    if (Reflect.field(bi.bankItems, Std.string(targetId)) != null) return true;
                }
                for (k in Reflect.fields(bi.bankItems)) {
                    var it:Dynamic = Reflect.field(bi.bankItems, k);
                    if (it != null) {
                        if (isIdLookup) {
                            if (it.ItemID == targetId) return true;
                        } else if (it.sName != null && StringTools.trim(Std.string(it.sName)).toLowerCase() == targetName) {
                            return true;
                        }
                    }
                }
            }

            if (bi.BankArray != null) {
                var bItems:Array<Dynamic> = cast bi.BankArray;
                for (i in bItems) {
                    if (i == null) continue;
                    if (isIdLookup) {
                        if (i.ItemID == targetId) return true;
                    } else if (i.sName != null && StringTools.trim(Std.string(i.sName)).toLowerCase() == targetName) {
                        return true;
                    }
                }
            }

            if (bi.items != null) {
                var bItems:Array<Dynamic> = cast bi.items;
                for (i in bItems) {
                    if (i == null) continue;
                    if (isIdLookup) {
                        if (i.ItemID == targetId) return true;
                    } else if (i.sName != null && StringTools.trim(Std.string(i.sName)).toLowerCase() == targetName) {
                        return true;
                    }
                }
            }

            if (_game.world.myAvatar != null && _game.world.myAvatar.bank != null) {
                var bItems:Array<Dynamic> = cast _game.world.myAvatar.bank;
                for (i in bItems) {
                    if (i == null) continue;
                    if (isIdLookup) {
                        if (i.ItemID == targetId) return true;
                    } else if (i.sName != null && StringTools.trim(Std.string(i.sName)).toLowerCase() == targetName) {
                        return true;
                    }
                }
            }
        } catch (e:Dynamic) {}

        return false;
    }

    public var isBankLoaded(get, never):Bool;
    @:getter(isBankLoaded)
    public function get_isBankLoaded_prop():Bool { return get_isBankLoaded(); }
    public function get_isBankLoaded():Bool {
        if (_isBankLoaded) return true;
        if (_game != null && _game.world != null && _game.world.bankinfo != null) {
            var bi:Dynamic = _game.world.bankinfo;
            try {
                if (bi.bankItems != null && Reflect.fields(bi.bankItems).length > 0) return true;
                if (bi.BankArray != null && (cast(bi.BankArray, Array<Dynamic>)).length > 0) return true;
                if (bi.items != null && (cast(bi.items, Array<Dynamic>)).length > 0) return true;
            } catch (e:Dynamic) {}
        }
        if (_game != null && _game.world != null && _game.world.myAvatar != null && _game.world.myAvatar.bank != null) {
            try {
                var avBank:Array<Dynamic> = cast _game.world.myAvatar.bank;
                if (avBank.length > 0) return true;
            } catch (e:Dynamic) {}
        }
        return false;
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

    public var freeBankSlots(get, never):Int;
    @:getter(freeBankSlots)
    public function get_freeBankSlots_prop():Int { return get_freeBankSlots(); }
    public function get_freeBankSlots():Int {
        var max = maxBankSlots;
        if (max <= 0) return 0;
        var free = max - usedBankSlots;
        return free > 0 ? free : 0;
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
        if (_game == null || _game.world == null || _game.world.bankinfo == null) return result;
        var bi:Dynamic = _game.world.bankinfo;
        try {
            if (bi.BankArray != null) {
                var rawList:Array<Dynamic> = cast bi.BankArray;
                for (it in rawList) if (it != null) result.push(new ItemDTO(it));
            }
            if (result.length == 0 && bi.items != null) {
                var rawList:Array<Dynamic> = cast bi.items;
                for (it in rawList) if (it != null) result.push(new ItemDTO(it));
            }
            if (result.length == 0 && bi.bankItems != null) {
                for (k in Reflect.fields(bi.bankItems)) {
                    var it = Reflect.field(bi.bankItems, k);
                    if (it != null) result.push(new ItemDTO(it));
                }
            }
        } catch (e:Dynamic) {}
        return result;
    }

    // -------------------------------------------------------------------------
    // Temp items
    //
    // Quest/temporary items live in a third array, `avatar.tempitems` (Avatar.as:56), which is not
    // `items` and not the bank. The game splits them with `bTemp`: an `addItems` packet whose entry
    // has `bTemp != 0` goes to `addTempItem` instead of `addItem` (Game.as:3485-3492). They therefore
    // never show up in inventory or bank queries, which is why they need their own accessors.
    // -------------------------------------------------------------------------

    public function getTempItems():Array<ItemDTO> {
        var result:Array<ItemDTO> = [];
        if (_game == null || _game.world == null || _game.world.myAvatar == null) return result;
        try {
            var raw:Array<Dynamic> = cast _game.world.myAvatar.tempitems;
            if (raw == null) return result;
            for (it in raw) if (it != null) result.push(new ItemDTO(it));
        } catch (_:Dynamic) {}
        return result;
    }

    public function getTempQuantity(itemNameOrId:String):Int {
        return quantityIn(_tempRaw(), itemNameOrId);
    }

    public function hasTempItem(itemNameOrId:String, quantity:Int = 1):Bool {
        if (quantity < 1) quantity = 1;
        return getTempQuantity(itemNameOrId) >= quantity;
    }

    private function _tempRaw():Array<Dynamic> {
        try {
            if (_game == null || _game.world == null || _game.world.myAvatar == null) return null;
            var t:Dynamic = _game.world.myAvatar.tempitems;
            return (t == null) ? null : cast t;
        } catch (_:Dynamic) {
            return null;
        }
    }

    // -------------------------------------------------------------------------
    // Where is this item?
    // -------------------------------------------------------------------------

    /**
     * Locates an item across every container: `"temp"`, `"inventory"`, `"house"` or `"bank"`.
     * Returns `""` when the item is nowhere.
     *
     * Order matters: a quest temp item and a banked copy of the same ItemID are different things, and
     * temp wins because that is the array the game itself checks first in its own lookups.
     */
    public function getItemLocation(itemNameOrId:String):String {
        if (hasTempItem(itemNameOrId)) return "temp";
        if (getQuantity(itemNameOrId) > 0) return "inventory";
        try {
            if (_game != null && _game.world != null && _game.world.myAvatar != null) {
                var house:Array<Dynamic> = cast _game.world.myAvatar.houseitems;
                if (house != null && quantityIn(house, itemNameOrId) > 0) return "house";
            }
        } catch (_:Dynamic) {}
        if (isInBank(itemNameOrId)) return "bank";
        return "";
    }

    /**
     * Full picture for one item: `{item, id, name, quantity, location}`.
     *
     * `quantity` is the count in `location`, not a total across containers, because a caller acting
     * on it needs to know what the specific container holds.
     */
    public function findItem(itemNameOrId:String):Dynamic {
        var loc:String = getItemLocation(itemNameOrId);
        if (loc == "") return null;
        var qty:Int = 0;
        if (loc == "temp") qty = getTempQuantity(itemNameOrId);
        else if (loc == "inventory") qty = getQuantity(itemNameOrId);
        else if (loc == "house") qty = quantityIn(_houseRaw(), itemNameOrId);
        else if (loc == "bank") qty = getBankQuantity(itemNameOrId);
        var id:Int = ApiUtils.parseInt(itemNameOrId, 0);
        return {
            item: itemNameOrId,
            id: (id > 0) ? id : resolveItemId(itemNameOrId),
            name: (id > 0) ? resolveItemName(itemNameOrId) : itemNameOrId,
            quantity: qty,
            location: loc
        };
    }

    public function getBankQuantity(itemNameOrId:String):Int {
        try {
            if (_game == null || _game.world == null || _game.world.bankinfo == null) return 0;
            var bi:Dynamic = _game.world.bankinfo;
            if (bi.BankArray != null) {
                var q:Int = quantityIn(cast bi.BankArray, itemNameOrId);
                if (q > 0) return q;
            }
            if (bi.items != null) {
                var q2:Int = quantityIn(cast bi.items, itemNameOrId);
                if (q2 > 0) return q2;
            }
        } catch (_:Dynamic) {}
        return 0;
    }

    private function _houseRaw():Array<Dynamic> {
        try {
            if (_game == null || _game.world == null || _game.world.myAvatar == null) return null;
            var h:Dynamic = _game.world.myAvatar.houseitems;
            return (h == null) ? null : cast h;
        } catch (_:Dynamic) {
            return null;
        }
    }

    /**
     * Shared name-or-ID scan over a raw item array. Returns the matching stack's `iQty`, or 0.
     *
     * Centralised so temp/inventory/house/bank all resolve names and IDs identically; the previous
     * per-container copies were easy to let drift apart.
     */
    private function quantityIn(list:Array<Dynamic>, itemNameOrId:String):Int {
        if (list == null || itemNameOrId == null || itemNameOrId == "") return 0;
        var targetId:Int = ApiUtils.parseInt(itemNameOrId, 0);
        var isIdLookup:Bool = targetId > 0;
        var targetName:String = itemNameOrId.toLowerCase();
        try {
            for (item in list) {
                if (item == null) continue;
                var matches:Bool = false;
                if (isIdLookup) {
                    matches = (item.ItemID != null && Std.int(item.ItemID) == targetId);
                } else if (item.sName != null) {
                    matches = (Std.string(item.sName).toLowerCase() == targetName);
                }
                if (matches) return (item.iQty != null) ? Std.int(item.iQty) : 1;
            }
        } catch (_:Dynamic) {}
        return 0;
    }

    private function resolveItemId(itemName:String):Int {
        try {
            if (_game != null && _game.world != null && _game.world.myAvatar != null) {
                var items:Array<Dynamic> = cast _game.world.myAvatar.items;
                if (items == null) return 0;
                for (item in items) {
                    if (item != null && item.sName != null && Std.string(item.sName).toLowerCase() == itemName.toLowerCase()) {
                        return (item.ItemID != null) ? Std.int(item.ItemID) : 0;
                    }
                }
            }
        } catch (_:Dynamic) {}
        return 0;
    }

    private function resolveItemName(itemNameOrId:String):String {
        var id:Int = ApiUtils.parseInt(itemNameOrId, 0);
        try {
            if (_game != null && _game.world != null && _game.world.invTree != null && id > 0) {
                var tree:Dynamic = _game.world.invTree;
                for (k in Reflect.fields(tree)) {
                    var it:Dynamic = Reflect.field(tree, k);
                    if (it != null && it.ItemID != null && Std.int(it.ItemID) == id && it.sName != null) {
                        return Std.string(it.sName);
                    }
                }
            }
        } catch (_:Dynamic) {}
        return "";
    }

    public function sellItem(itemNameOrId:String, quantity:Int = 1):Void {
        if (Api.shop != null) {
            Api.shop.sellItem(itemNameOrId, quantity);
        }
    }
}
