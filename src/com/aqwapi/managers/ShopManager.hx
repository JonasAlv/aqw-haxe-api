package com.aqwapi.managers;

import com.aqwapi.utils.ApiTimings;
import com.aqwapi.utils.ApiLogger;
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

    public function buyItem(itemNameOrId:Dynamic, quantity:Int = 1):Void {
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
        sendBuy(entry.item, Std.int(entry.quantity));
        if (_buyQueue.length == 0 && _buyTimer != null) _buyTimer.stop();
    }

    /** Actual send path, with no throttle of its own. */
    private function sendBuy(itemNameOrId:Dynamic, quantity:Int):Void {
        if (quantity < 1) quantity = 1;
        if (_game == null || _game.world == null) return;
        try {
            if (_game.world.lock != null) {
                var lObj:Dynamic = Reflect.field(_game.world.lock, "buyItem");
                if (lObj != null) lObj.ts = com.aqwapi.utils.ApiTime.epochMs();
            }
        } catch (e:Dynamic) {}
        var strVal:String = Std.string(itemNameOrId);
        var targetId:Int = ApiUtils.parseInt(itemNameOrId, 0);
        var isIdLookup:Bool = targetId > 0;
        var target:String = strVal.toLowerCase();
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

    public function sellItem(itemNameOrId:Dynamic, quantity:Int = 1):Void {
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
        var strVal:String = Std.string(itemNameOrId);
        var targetId:Int = ApiUtils.parseInt(itemNameOrId, 0);
        var isIdLookup:Bool = targetId > 0;
        var target:String = strVal.toLowerCase();
        try {
            if (_game.world.myAvatar != null && _game.world.myAvatar.items != null) {
                var myItems:Array<Dynamic> = cast _game.world.myAvatar.items;
                for (i in myItems) {
                    if (i == null || i.sName == null) continue;
                    var matches:Bool = isIdLookup ? (i.ItemID == targetId) : (Std.string(i.sName).toLowerCase() == target);
                    if (matches) {
                        if (i.bEquip == true) continue;
                        if (i.CharItemID == null || i.CharItemID == 0) continue;
                        if (_protectFavorites && Api.inventory != null && i.ItemID != null && Api.inventory.isFavorited(Std.int(i.ItemID))) {
                            ApiLogger.warn("Shop", "Skipped selling favorited item: " + Std.string(i.sName));
                            continue;
                        }
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

    /**
     * Returns the maximum quantity of a shop item that the player can currently buy (`World.maximumShopBuys` in World.as:7163).
     */
    public function getMaxBuyQuantity(itemNameOrId:Dynamic):Int {
        if (_game == null || _game.world == null || itemNameOrId == null) return 0;
        var item:Dynamic = itemNameOrId;
        if (Std.isOfType(itemNameOrId, String) || Std.isOfType(itemNameOrId, Int) || Std.isOfType(itemNameOrId, Float)) {
            item = null;
            var strVal:String = Std.string(itemNameOrId);
            var targetId:Int = ApiUtils.parseInt(itemNameOrId, 0);
            var isIdLookup:Bool = targetId > 0;
            var target:String = strVal.toLowerCase();
            try {
                var shopInfo:Dynamic = _game.world.shopinfo;
                if (shopInfo != null && shopInfo.items != null && Std.isOfType(shopInfo.items, Array)) {
                    var sItems:Array<Dynamic> = cast shopInfo.items;
                    for (si in sItems) {
                        if (si == null || si.sName == null) continue;
                        var matches:Bool = isIdLookup ? (si.ItemID == targetId) : (Std.string(si.sName).toLowerCase() == target);
                        if (matches) {
                            item = si;
                            break;
                        }
                    }
                }
            } catch (_:Dynamic) {}
        }
        if (item == null) return 0;
        try {
            if (_game.world.maximumShopBuys != null) {
                return Std.int(_game.world.maximumShopBuys(item));
            }
        } catch (_:Dynamic) {}
        return 1;
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

    /**
     * Whether scripted sales should stop when the item is a favorite.
     *
     * Protects favorites by default. When true, a sale is blocked if the
     * destination item is marked as a favorite on the current character.
     */
    public var protectFavorites(get, set):Bool;
    @:getter(protectFavorites)
    public function get_protectFavorites():Bool {
        return _protectFavorites;
    }
    @:setter(protectFavorites)
    public function set_protectFavorites(v:Bool):Bool {
        _protectFavorites = v;
        return v;
    }
    private var _protectFavorites:Bool = true;

    /**
     * Missing inventory materials (`item.turnin`), missing tokens (`item.TokID`/`TokQty`),
     * LQS stock (`item.bLimited`/`iQtyRemain`), achievement locks (`shopinfo.sField`/`iIndex`),
     * and unmet quest progress (`item.iQSindex`/`iQSvalue`) for a purchase (`InvCat.as` & `LPFFrameSimpleListShop.as`).
     */
    public function getUnmetPurchaseRequirements(item:Dynamic, quantity:Int = -1):Array<String> {
        var result:Array<String> = [];
        if (item == null) {
            result.push("Invalid shop item");
            return result;
        }
        try {
            var bundleQty:Int = getDefaultQuantity(item);
            var totalQty:Int = (quantity <= 0) ? bundleQty : quantity;
            var purchases:Int = Std.int(Math.max(1, Math.floor(totalQty / (bundleQty > 0 ? bundleQty : 1))));
            var inv = com.aqwapi.Api.inventory;
            var w:Dynamic = (_game != null) ? _game.world : null;

            // 1. Merge / Turn-in materials (`item.turnin` in InvCat.as:145)
            var turnin:Dynamic = (item.turnin != null) ? item.turnin : Reflect.field(item, "matCost");
            if (turnin != null && Std.isOfType(turnin, Array)) {
                var arr:Array<Dynamic> = cast turnin;
                for (m in arr) {
                    if (m == null) continue;
                    var matId:Int = (m.ItemID != null) ? Std.int(m.ItemID) : ((m.id != null) ? Std.int(m.id) : 0);
                    var baseMatQty:Int = (m.iQty != null) ? Std.int(m.iQty) : ((m.qty != null) ? Std.int(m.qty) : 1);
                    var matQty:Int = baseMatQty * purchases;
                    if (matId > 0 && matQty > 0 && inv != null && !inv.hasItemById(matId, matQty)) {
                        var matName:String = (m.sName != null && Std.string(m.sName) != "") ? Std.string(m.sName) : ("id " + matId);
                        result.push("Missing material " + matName + " x" + matQty);
                    }
                }
            }

            // 2. Tokens (`item.TokID` & `item.TokQty` in InvCat.as:211)
            var tokId:Dynamic = (item.TokID != null) ? item.TokID : Reflect.field(item, "tID");
            var tokQty:Dynamic = (item.TokQty != null) ? item.TokQty : Reflect.field(item, "tQty");
            if (tokId != null && tokQty != null) {
                var tokIdNum:Int = ApiUtils.parseInt(tokId, 0);
                var tokNeed:Int = Std.int(Math.ceil(ApiUtils.parseFloat(tokQty, 0) * purchases));
                if (tokIdNum > 0 && tokNeed > 0 && inv != null && !inv.hasItemById(tokIdNum, tokNeed)) {
                    var tokName:String = (item.TokName != null && Std.string(item.TokName) != "") ? Std.string(item.TokName) : ("id " + tokIdNum);
                    result.push("Missing token " + tokName + " x" + tokNeed);
                }
            }

            // 3. Quest progress lock (`item.iQSindex` & `item.iQSvalue` in InvCat.as:182)
            if (item.iQSindex != null && ApiUtils.parseInt(item.iQSindex, -1) >= 0 && item.iQSvalue != null) {
                var qsIdx:Int = ApiUtils.parseInt(item.iQSindex, -1);
                var qsVal:Int = ApiUtils.parseInt(item.iQSvalue, 0);
                var curVal:Int = (com.aqwapi.Api.quest != null) ? com.aqwapi.Api.quest.getQuestValue(qsIdx) : 0;
                if (curVal < qsVal) {
                    result.push("Unmet quest slot requirement (slot " + qsIdx + " < " + qsVal + ")");
                }
            }

            // 4. Limited Quantity Shop stock (`item.bLimited` & `item.iQtyRemain` in LPFFrameSimpleListShop.as)
            var isLimited:Bool = (item.bLimited == 1 || item.bLimited == "1" || item.bLimited == true);
            if (isLimited && item.iQtyRemain != null && ApiUtils.parseInt(item.iQtyRemain, 1) <= 0) {
                result.push("Limited quantity item is out of stock");
            }

            // 5. Shop achievement lock (`shopinfo.sField` & `shopinfo.iIndex` in LPFFrameSimpleListShop.as)
            if (w != null && w.shopinfo != null && w.shopinfo.sField != null && Std.string(w.shopinfo.sField) != "" && w.getAchievement != null) {
                var sField:String = Std.string(w.shopinfo.sField);
                var iIndex:Int = (w.shopinfo.iIndex != null) ? ApiUtils.parseInt(w.shopinfo.iIndex, 0) : 0;
                if (Std.int(w.getAchievement(sField, iIndex)) != 1) {
                    result.push("Unmet shop achievement requirement (" + sField + ":" + iIndex + ")");
                }
            }
        } catch (err:Dynamic) {
            result.push("Failed to read requirements: " + err);
        }
        return result;
    }

    private function getDefaultQuantity(item:Dynamic):Int {
        try {
            if (item.iQty != null && ApiUtils.parseInt(item.iQty, 0) > 0) {
                return ApiUtils.parseInt(item.iQty, 1);
            }
            var qty:Dynamic = Reflect.field(item, "qty");
            if (qty != null && ApiUtils.parseInt(qty, 0) > 0) return ApiUtils.parseInt(qty, 1);
        } catch (_:Dynamic) {}
        return 1;
    }
}
