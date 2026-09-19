package com.aqwapi.managers;

class ScriptDrops {
    private var _game:AQWGame;
    public var pendingDrops:Array<Dynamic> = [];
    public var targetDrops:Array<Dynamic> = [];
    public var interceptedDropIds:Array<String> = [];
    public var rejectAll:Bool = false;
    public var acceptAll:Bool = false;
    public var acceptACs:Bool = false;
    private var _isListening:Bool = false;

    public function new(gameReference:AQWGame) {
        _game = gameReference;
    }

    public function start():Void {
        if (_isListening || _game == null || _game.sfc == null) return;
        _game.sfc.addEventListener("onExtensionResponse", onExtensionResponseHandler, false, 2147483647, true);
        _isListening = true;
    }

    public function stop():Void {
        if (!_isListening || _game == null || _game.sfc == null) return;
        _game.sfc.removeEventListener("onExtensionResponse", onExtensionResponseHandler);
        _isListening = false;
    }

    private function onExtensionResponseHandler(event:Dynamic):Void {
        try {
            if (event != null && event.params != null && event.params.type == "json") {
                var cmd:String = Std.string(event.params.dataObj.cmd);
                if (cmd == "dropItem") {
                    var allIntercepted:Bool = true;
                    var hasDrops:Bool = false;
                    for (k in Reflect.fields(event.params.dataObj)) {
                        if (k == "cmd") continue;
                        var val:Dynamic = Reflect.field(event.params.dataObj, k);
                        if (val != null) {
                            for (subK in Reflect.fields(val)) {
                                hasDrops = true;
                                var item:Dynamic = Reflect.field(val, subK);
                                var matchesTarget:Bool = isTargetDrop(item);
                                var isAC:Bool = (item.bCoins == 1 || item.bCoins == "1" || item.bCoins == true);

                                if (acceptAll || matchesTarget || (acceptACs && isAC)) {
                                    if (_game.world != null && _game.sfc != null) {
                                        var roomId:Dynamic = (_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : _game.sfc.myUserId;
                                        _game.sfc.sendString("%xt%zm%getDrop%" + roomId + "%" + item.ItemID + "%");
                                    }
                                    if (item.ItemID != null) {
                                        interceptedDropIds.push(Std.string(item.ItemID));
                                    }
                                    Reflect.deleteField(val, subK);
                                } else {
                                    allIntercepted = false;
                                    if (!rejectAll) {
                                        addPendingDrop({ sName: item.sName, ItemID: item.ItemID });
                                    } else {
                                        Reflect.deleteField(val, subK);
                                    }
                                }
                            }
                        }
                    }
                    if (hasDrops && allIntercepted) {
                        try { event.stopImmediatePropagation(); } catch (e:Dynamic) {}
                    }
                } else if (cmd == "getDrop") {
                    if (event.params.dataObj.ItemID != null) {
                        var resId:String = Std.string(event.params.dataObj.ItemID);
                        var idx:Int = interceptedDropIds.indexOf(resId);
                        if (idx != -1) {
                            try { event.stopImmediatePropagation(); } catch (e:Dynamic) {}
                            interceptedDropIds.splice(idx, 1);
                        }
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

    public function acceptPendingDrops(itemNames:Array<Dynamic>):Int {
        if (_game == null || _game.sfc == null || itemNames == null || itemNames.length == 0) return 0;
        var accepted:Int = 0;
        var i = pendingDrops.length - 1;
        while (i >= 0) {
            var pending:Dynamic = pendingDrops[i];
            if (pending != null && pending.sName != null) {
                var pendingName:String = Std.string(pending.sName).toLowerCase();
                var pendingId:Int = com.aqwapi.utils.AqwUtils.parseInt(pending.ItemID, 0);
                var matches:Bool = false;

                for (itemName in itemNames) {
                    var inStr:String = Std.string(itemName);
                    var inId:Int = com.aqwapi.utils.AqwUtils.parseInt(inStr, 0);
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
                        var inId2:Int = com.aqwapi.utils.AqwUtils.parseInt(inStr2, 0);
                        var inLower2:String = inStr2.toLowerCase();
                        var isIdLookup2:Bool = inId2 > 0;
                        if (!isIdLookup2 && pendingName.indexOf(inLower2) != -1) { matches = true; break; }
                    }
                }

                if (matches) {
                    var roomId:Dynamic = (_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : _game.sfc.myUserId;
                    _game.sfc.sendString("%xt%zm%getDrop%" + roomId + "%" + pending.ItemID + "%");
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

        if (targetDrops == null || targetDrops.length == 0 || item == null || item.sName == null) return false;
        var searchName:String = Std.string(item.sName).toLowerCase();
        var searchId:Int = com.aqwapi.utils.AqwUtils.parseInt(item.ItemID, 0);

        for (td in targetDrops) {
            var tdStr:String = Std.string(td);
            var tdLower:String = tdStr.toLowerCase();
            var tdId:Int = com.aqwapi.utils.AqwUtils.parseInt(tdStr, 0);
            var isIdLookup:Bool = tdId > 0;

            if (tdLower == "any" || tdLower == "all") return true;
            if (isIdLookup) {
                if (searchId == tdId) return true;
            } else {
                if (searchName == tdLower) return true;
            }
        }

        for (td2 in targetDrops) {
            var tdStr2:String = Std.string(td2);
            var tdLower2:String = tdStr2.toLowerCase();
            var tdId2:Int = com.aqwapi.utils.AqwUtils.parseInt(tdStr2, 0);
            var isIdLookup2:Bool = tdId2 > 0;
            if (!isIdLookup2 && searchName.indexOf(tdLower2) != -1) return true;
        }

        return false;
    }
}
