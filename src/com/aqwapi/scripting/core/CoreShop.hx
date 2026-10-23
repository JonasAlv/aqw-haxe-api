package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreShop {
    public function new() {}
    public function load(shopId:Int):Void if (Api.shop != null) Api.shop.loadShop(shopId);
    public function buy(item:Dynamic, quantity:Int = 1):Void if (Api.shop != null) Api.shop.buyItem(item, quantity);
    public function buyMany(items:Array<Dynamic>):Int return Api.shop != null ? Api.shop.buyItems(items) : 0;
    public function sell(item:Dynamic, quantity:Int = 1):Void if (Api.shop != null) Api.shop.sellItem(item, quantity);
    public function loaded(shopId:Int = -1):Bool return Api.shop != null && Api.shop.isShopLoaded && (shopId < 0 || Api.shop.loadedShopId == shopId);
    public function pendingBuys():Int return Api.shop != null ? Api.shop.getPendingBuyCount() : 0;
}
