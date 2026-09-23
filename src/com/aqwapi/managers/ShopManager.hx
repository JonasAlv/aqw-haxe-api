package com.aqwapi.managers;

class ShopManager {
    private var _game:AqwGame;

    public function new(gameReference:AqwGame) {
        _game = gameReference;
    }

    public function loadShop(shopId:Int):Void {
        if (_game == null || _game.world == null || shopId <= 0) return;
        if (isShopLoaded && loadedShopId == shopId) return;
        try {
            if (_game.world.sendLoadShopRequest != null)
                _game.world.sendLoadShopRequest(shopId);
        } catch(e:Dynamic) {}
    }

    public function buyItem(itemNameOrId:String, quantity:Int = 1):Void {
        if (quantity < 1) quantity = 1;
        if (_game == null || _game.world == null) return;
        var targetId:Int = com.aqwapi.utils.AqwUtils.parseInt(itemNameOrId, 0);
        var isIdLookup:Bool = targetId > 0;
        var target:String = itemNameOrId.toLowerCase();
        try {
            var shopInfo:Dynamic = (_game.world.shopinfo != null) ? _game.world.shopinfo : null;
            if (_game.ui != null && _game.ui.mcPopup != null) {
                var mcShop = _game.ui.mcPopup.getChildByName("mcShop");
                if (mcShop != null && mcShop.shopinfo != null) shopInfo = mcShop.shopinfo;
            }
            if (shopInfo != null && shopInfo.items != null) {
                var sItems:Array<Dynamic> = cast shopInfo.items;
                for (i in 0...sItems.length) {
                    if (sItems[i] == null || sItems[i].sName == null) continue;
                    var matches:Bool = isIdLookup ? (sItems[i].ItemID == targetId) : (Std.string(sItems[i].sName).toLowerCase() == target);
                    if (matches) {
                        if (sItems[i].iStk != null && Std.int(sItems[i].iStk) <= 1) {
                            if (_game.world.myAvatar != null && _game.world.myAvatar.items != null) {
                                var myItems:Array<Dynamic> = cast _game.world.myAvatar.items;
                                for (mi in myItems) {
                                    if (mi != null && mi.ItemID != null && mi.ItemID == sItems[i].ItemID) return;
                                }
                            }
                        }
                        if (quantity > 1 && _game.world.sendBuyItemRequestWithQuantity != null) {
                            _game.world.sendBuyItemRequestWithQuantity({ iSel: sItems[i], iQty: quantity, accept: 1 });
                        } else if (_game.world.sendBuyItemRequest != null) {
                            _game.world.sendBuyItemRequest(sItems[i]);
                        }
                        break;
                    }
                }
            }
        } catch(e:Dynamic) {}
    }

    public function sellItem(itemNameOrId:String, quantity:Int = 1):Void {
        if (quantity < 1) quantity = 1;
        if (_game == null || _game.world == null) return;
        var targetId:Int = com.aqwapi.utils.AqwUtils.parseInt(itemNameOrId, 0);
        var isIdLookup:Bool = targetId > 0;
        var target:String = itemNameOrId.toLowerCase();
        try {
            if (_game.world.myAvatar != null && _game.world.myAvatar.items != null) {
                var myItems:Array<Dynamic> = cast _game.world.myAvatar.items;
                for (i in myItems) {
                    if (i == null || i.sName == null) continue;
                    var matches:Bool = isIdLookup ? (i.ItemID == targetId) : (Std.string(i.sName).toLowerCase() == target);
                    if (matches) {
                        if (i.bEquip == true) continue;
                        if (i.CharItemID == null || i.CharItemID == 0) continue;
                        if (_game.sfc != null) {
                            var reqId:Dynamic = (_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : _game.world.curRoom;
                            _game.sfc.sendString("%xt%zm%sellItem%" + reqId + "%" + i.ItemID + "%" + quantity + "%" + i.CharItemID + "%");
                        } else if (_game.world.sendSellItemRequest != null) {
                            _game.world.sendSellItemRequest(i);
                        }
                        break;
                    }
                }
            }
        } catch(e:Dynamic) {}
    }

    public var isShopLoaded(get, never):Bool;
    @:getter(isShopLoaded)
    public function get_isShopLoaded_prop():Bool { return get_isShopLoaded(); }
    public function get_isShopLoaded():Bool {
        if (_game != null && _game.world != null && _game.world.shopinfo != null && _game.world.shopinfo.items != null) return true;
        if (_game != null && _game.ui != null && _game.ui.mcPopup != null && _game.ui.mcPopup.currentLabel == "Shop") return true;
        return false;
    }

    public var loadedShopId(get, never):Int;
    @:getter(loadedShopId)
    public function get_loadedShopId_prop():Int { return get_loadedShopId(); }
    public function get_loadedShopId():Int {
        try {
            if (_game != null && _game.world != null && _game.world.shopinfo != null && _game.world.shopinfo.ShopID != null)
                return Std.int(untyped _game.world.shopinfo.ShopID);
            if (_game != null && _game.ui != null && _game.ui.mcPopup != null && _game.ui.mcPopup.currentLabel == "Shop") {
                var mcShop = _game.ui.mcPopup.getChildByName("mcShop");
                if (mcShop != null && mcShop.shopinfo != null && mcShop.shopinfo.ShopID != null)
                    return Std.int(untyped mcShop.shopinfo.ShopID);
            }
        } catch(e:Dynamic) {}
        return 0;
    }
}
