package com.aqwapi.managers;

import com.aqwapi.utils.ApiUtils;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.Game;

class DropManager {
    private var _game:Game;
    public var pendingDrops:Array<Dynamic> = [];
    public var targetDrops:Array<Dynamic> = [];
    public var requestedDrops:Map<String, Float> = new Map();
    public var interceptedDropIds:Array<String> = [];
    public var rejectAll:Bool = false;
    public var acceptAll:Bool = false;
    public var acceptACs:Bool = false;
    private var _isListening:Bool = false;

    public function new(gameReference:Game) {
        _game = gameReference;
    }

    public function start():Void {
        if (_isListening || _game == null || _game.sfc == null) return;
        // Priority -10 ensures AQW's native onExtensionResponse runs first
        // to populate world.invTree and notify Custom Drops UI (cDropsUI).
        _game.sfc.addEventListener("onExtensionResponse", onExtensionResponseHandler, false, -10, true);
        _isListening = true;
    }

    public function stop():Void {
        if (!_isListening || _game == null || _game.sfc == null) return;
        _game.sfc.removeEventListener("onExtensionResponse", onExtensionResponseHandler);
        _isListening = false;
    }

    public function getRoomId():Dynamic {
        if (_game != null && _game.world != null && _game.world.curRoom != null) {
            return _game.world.curRoom;
        }
        if (_game != null && _game.sfc != null && _game.sfc.activeRoomId != null) {
            return _game.sfc.activeRoomId;
        }
        return 1;
    }

    public function sendGetDrop(itemId:Dynamic):Void {
        if (_game == null || _game.sfc == null || itemId == null) return;
        var idStr:String = Std.string(itemId);
        var now:Float = ApiTime.now();
        if (requestedDrops.exists(idStr) && (now - requestedDrops.get(idStr)) < 1500) {
            return;
        }
        requestedDrops.set(idStr, now);
        var roomId:Dynamic = getRoomId();
        _game.sfc.sendString("%xt%zm%getDrop%" + roomId + "%" + idStr + "%");
    }

    private function onExtensionResponseHandler(event:Dynamic):Void {
        try {
            if (event != null && event.params != null && event.params.type == "json") {
                var dataObj:Dynamic = event.params.dataObj;
                if (dataObj == null) return;
                var cmd:String = Std.string(dataObj.cmd);
                if (cmd == "dropItem") {
                    for (k in Reflect.fields(dataObj)) {
                        if (k == "cmd") continue;
                        var val:Dynamic = Reflect.field(dataObj, k);
                        if (val != null) {
                            for (subK in Reflect.fields(val)) {
                                var item:Dynamic = Reflect.field(val, subK);
                                if (item == null) continue;
                                var isAC:Bool = (item.bCoins == 1 || item.bCoins == "1" || item.bCoins == true);
                                var matchesTarget:Bool = isTargetDrop(item);

                                if (acceptAll || matchesTarget || (acceptACs && isAC)) {
                                    sendGetDrop(item.ItemID);
                                } else if (rejectAll) {
                                    try {
                                        if (_game.cDropsUI != null && _game.cDropsUI.onBtNo != null) {
                                            _game.cDropsUI.onBtNo(item);
                                        } else if (_game.showItemDrop != null) {
                                            _game.showItemDrop(item, false);
                                        }
                                    } catch (e:Dynamic) {}
                                } else {
                                    addPendingDrop(item);
                                }
                            }
                        }
                    }
                } else if (cmd == "getDrop") {
                    if (dataObj.ItemID != null) {
                        var resId:String = Std.string(dataObj.ItemID);
                        requestedDrops.remove(resId);
                        removePendingDropById(resId);
                    }
                }
            }
        } catch (e:Dynamic) {}
    }

    public function addPendingDrop(item:Dynamic):Void {
        if (item == null) return;
        var itemId:String = item.ItemID != null ? Std.string(item.ItemID) : null;
        var itemName:String = item.sName != null ? Std.string(item.sName).toLowerCase() : null;
        for (pending in pendingDrops) {
            if (pending == null) continue;
            if (itemId != null && pending.ItemID != null && Std.string(pending.ItemID) == itemId) return;
            if (itemId == null && pending.ItemID == null && itemName != null && pending.sName != null && Std.string(pending.sName).toLowerCase() == itemName) return;
        }

        pendingDrops.push(item);
        if (pendingDrops.length > 50) pendingDrops.shift();
    }

    public function removePendingDrop(index:Int):Void {
        pendingDrops.splice(index, 1);
    }

    public function removePendingDropById(itemId:String):Void {
        if (itemId == null || pendingDrops.length == 0) return;
        var i = pendingDrops.length - 1;
        while (i >= 0) {
            var p = pendingDrops[i];
            if (p != null && Std.string(p.ItemID) == itemId) {
                pendingDrops.splice(i, 1);
            }
            i--;
        }
    }

    public function scanScreenDrops():Void {
        if (_game == null) return;
        // Check cDropsUI.invTree (Custom Drops UI)
        try {
            if (_game.cDropsUI != null && _game.cDropsUI.invTree != null) {
                var tree:Dynamic = _game.cDropsUI.invTree;
                var len:Int = tree.length;
                for (i in 0...len) {
                    var item:Dynamic = tree[i];
                    if (item != null && item.ItemID != null) {
                        addPendingDrop(item);
                    }
                }
            }
        } catch (e:Dynamic) {}

        // Check classic ui.dropStack
        try {
            if (_game.ui != null && _game.ui.dropStack != null) {
                var stack:Dynamic = _game.ui.dropStack;
                var count:Int = stack.numChildren;
                for (idx in 0...count) {
                    var child:Dynamic = stack.getChildAt(idx);
                    if (child != null && child.fData != null && child.fData.ItemID != null) {
                        addPendingDrop(child.fData);
                    }
                }
            }
        } catch (e:Dynamic) {}
    }

    public inline function accept(itemName:String = "all"):Int {
        return acceptPendingDrops([itemName]);
    }

    public inline function pickup(itemName:String = "all"):Int {
        return acceptPendingDrops([itemName]);
    }

    public inline function acceptAllDrops():Int {
        scanScreenDrops();
        return acceptPendingDrops(["all"]);
    }

    public function acceptACDrops():Int {
        if (_game == null || _game.sfc == null) return 0;
        scanScreenDrops();
        var accepted:Int = 0;
        var i = pendingDrops.length - 1;
        while (i >= 0) {
            var pending:Dynamic = pendingDrops[i];
            if (pending != null && pending.ItemID != null) {
                var isAC:Bool = (pending.bCoins == 1 || pending.bCoins == "1" || pending.bCoins == true);
                if (isAC) {
                    sendGetDrop(pending.ItemID);
                    pendingDrops.splice(i, 1);
                    accepted++;
                }
            }
            i--;
        }
        return accepted;
    }

    public function acceptPendingDrops(itemNames:Array<Dynamic>):Int {
        if (_game == null || _game.sfc == null || itemNames == null || itemNames.length == 0) return 0;
        scanScreenDrops();
        var accepted:Int = 0;
        var i = pendingDrops.length - 1;
        while (i >= 0) {
            var pending:Dynamic = pendingDrops[i];
            if (pending != null && (pending.sName != null || pending.ItemID != null)) {
                var pendingName:String = pending.sName != null ? Std.string(pending.sName).toLowerCase() : "";
                var pendingId:Int = ApiUtils.parseInt(pending.ItemID, 0);
                var matches:Bool = false;

                for (itemName in itemNames) {
                    var inStr:String = Std.string(itemName);
                    var inId:Int = ApiUtils.parseInt(inStr, 0);
                    var inLower:String = inStr.toLowerCase();
                    var isIdLookup:Bool = inId > 0;

                    if (inLower == "any" || inLower == "all") { matches = true; break; }
                    if (isIdLookup) {
                        if (pendingId == inId) { matches = true; break; }
                    } else {
                        if (pendingName == inLower) { matches = true; break; }
                    }
                }

                if (!matches) {
                    for (itemName2 in itemNames) {
                        var inStr2:String = Std.string(itemName2);
                        var inId2:Int = ApiUtils.parseInt(inStr2, 0);
                        var inLower2:String = inStr2.toLowerCase();
                        var isIdLookup2:Bool = inId2 > 0;
                        if (!isIdLookup2 && pendingName != "" && pendingName.indexOf(inLower2) != -1) { matches = true; break; }
                    }
                }

                if (matches) {
                    sendGetDrop(pending.ItemID);
                    pendingDrops.splice(i, 1);
                    accepted++;
                }
            }
            i--;
        }
        return accepted;
    }

    public function getDrop(itemName:String):Void {
        acceptPendingDrops([itemName]);
    }

    public function isTargetDrop(item:Dynamic):Bool {
        if (targetDrops == null || targetDrops.length == 0 || item == null) return false;
        var searchName:String = item.sName != null ? Std.string(item.sName).toLowerCase() : "";
        var searchId:Int = ApiUtils.parseInt(item.ItemID, 0);

        for (td in targetDrops) {
            var tdStr:String = Std.string(td);
            var tdLower:String = tdStr.toLowerCase();
            var tdId:Int = ApiUtils.parseInt(tdStr, 0);
            var isIdLookup:Bool = tdId > 0;

            if (tdLower == "any" || tdLower == "all") return true;
            if (isIdLookup) {
                if (searchId == tdId) return true;
            } else {
                if (searchName != "" && searchName == tdLower) return true;
            }
        }

        for (td2 in targetDrops) {
            var tdStr2:String = Std.string(td2);
            var tdLower2:String = tdStr2.toLowerCase();
            var tdId2:Int = ApiUtils.parseInt(tdStr2, 0);
            var isIdLookup2:Bool = tdId2 > 0;
            if (!isIdLookup2 && searchName != "" && searchName.indexOf(tdLower2) != -1) return true;
        }

        return false;
    }
}
