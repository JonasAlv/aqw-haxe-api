package com.aqwapi.managers;

import com.aqwapi.utils.ApiTimings;

import com.aqwapi.utils.ApiUtils;
import com.aqwapi.Game;
import flash.events.TimerEvent;
import flash.utils.Timer;

class ShopManager {
    private var _game:Game;
    private var _lastShopLoadTime:Float = 0;
    private var _lastBuyTime:Float = 0;
    private var _lastSellTime:Float = 0;

    /** Pending bulk purchases, oldest first. */
    private var _buyQueue:Array<Dynamic> = [];
    private var _buyTimer:Timer = null;

    public function new(gameReference:Game) {
        _game = gameReference;
    }

    public function loadShop(shopId:Int):Void {
        if (_game == null || _game.world == null || shopId <= 0) return;
        if (isShopLoaded && loadedShopId == shopId) return;
        var now = com.aqwapi.utils.ApiTime.now();
        if (now - _lastShopLoadTime < ApiTimings.SHOP_LOAD_MS) return;
        _lastShopLoadTime = now;
        try {
            if (_game.world.sendLoadShopRequest != null)
                _game.world.sendLoadShopRequest(shopId);
        } catch(e:Dynamic) {}
    }

    public function buyItem(itemNameOrId:String, quantity:Int = 1):Void {
        if (quantity < 1) quantity = 1;
        if (_game == null || _game.world == null) return;
        var now = com.aqwapi.utils.ApiTime.now();
        // Single-purchase path is throttled and drops calls that arrive too soon. Bulk callers should
        // use buyItems(), which paces itself through a queue instead of discarding the surplus.
        if (now - _lastBuyTime < ApiTimings.SHOP_BUY_MS) return;
        _lastBuyTime = now;
        sendBuy(itemNameOrId, quantity);
    }

    /**
     * Queues several purchases and sends them one at a time, one per `gapMs`.
     *
     * A naive loop over `buyItem` would silently drop all but the first: the per-call throttle
     * discards anything inside 1000ms, so asking for five different voucher types in one tick would
     * buy one and throw the rest away. The queue paces them instead.
     *
     * Each entry is `{item: String, quantity: Int}`, or a two-element `[name, qty]` array. `item` may
     * be an item name or a numeric ItemID.
     *
     * Returns how many entries were accepted; entries naming an empty item are rejected.
     */
    public function buyItems(items:Array<Dynamic>, gapMs:Int = 1000):Int {
        if (items == null || items.length == 0) return 0;
        if (gapMs < 250) gapMs = 250;
        var accepted:Int = 0;
        for (raw in items) {
            var entry:Dynamic = com.aqwapi.utils.BuyRequestParser.parse(raw);
            if (entry == null) continue;
            _buyQueue.push(entry);
            accepted++;
        }
        if (accepted > 0) startQueue(gapMs);
        return accepted;
    }

    public function getPendingBuyCount():Int {
        return _buyQueue.length;
    }

    public function clearBuyQueue():Void {
        _buyQueue = [];
    }

    private function startQueue(gapMs:Int):Void {
        if (_buyTimer != null && _buyTimer.running) {
            // Keep the tighter of the two intervals if a caller asks for a faster drain.
            if (_buyTimer.delay < gapMs) _buyTimer.delay = gapMs;
            return;
        }
        if (_buyTimer == null) {
            _buyTimer = new Timer(gapMs, 0);
            _buyTimer.addEventListener(TimerEvent.TIMER, onBuyQueueTick);
        } else {
            _buyTimer.delay = gapMs;
        }
        _buyTimer.start();
        // Fire the first entry promptly instead of making the caller wait a full interval.
        drainOne();
    }

    private function onBuyQueueTick(e:TimerEvent):Void {
        drainOne();
    }

    private function drainOne():Void {
        if (_buyQueue.length == 0) {
            if (_buyTimer != null) _buyTimer.stop();
            return;
        }
        var entry:Dynamic = _buyQueue.shift();
        _lastBuyTime = com.aqwapi.utils.ApiTime.now();
        sendBuy(Std.string(entry.item), Std.int(entry.quantity));
        if (_buyQueue.length == 0 && _buyTimer != null) _buyTimer.stop();
    }

    /** Actual send path, with no throttle of its own. */
    private function sendBuy(itemNameOrId:String, quantity:Int):Void {
        if (quantity < 1) quantity = 1;
        if (_game == null || _game.world == null) return;
        try {
            if (_game.world.lock != null) {
                var lObj:Dynamic = Reflect.field(_game.world.lock, "buyItem");
                if (lObj != null) lObj.ts = com.aqwapi.utils.ApiTime.epochMs();
            }
        } catch (e:Dynamic) {}
        var targetId:Int = ApiUtils.parseInt(itemNameOrId, 0);
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
        var now = com.aqwapi.utils.ApiTime.now();
        if (now - _lastSellTime < ApiTimings.SHOP_SELL_MS) return;
        _lastSellTime = now;
        if (_game.world.lock != null) {
            try {
                var lObj:Dynamic = Reflect.field(_game.world.lock, "sellItem");
                if (lObj != null) lObj.ts = com.aqwapi.utils.ApiTime.epochMs();
            } catch (e:Dynamic) {}
        }
        var targetId:Int = ApiUtils.parseInt(itemNameOrId, 0);
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
                            var reqId:Dynamic = (_game.world != null && _game.world.curRoom != null) ? _game.world.curRoom : ((_game.sfc.activeRoomId != null) ? _game.sfc.activeRoomId : 1);
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
