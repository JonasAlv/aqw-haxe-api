package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreBoost {
    public function new() {}
    public function active(boostType:String):Bool return Api.player != null && Api.player.isBoostActive(boostType);
    public function remaining(boostType:String):Int return Api.player != null ? Api.player.getBoostRemaining(boostType) : 0;
    public function use(item:Dynamic):Bool return Api.player != null && Api.player.useBoost(item);
    public function enable(boostType:String, enabled:Bool = true):Void if (Api.player != null) Api.player.setAutoBoost(boostType, enabled);
    public function ensure(boostType:String, item:Dynamic):Bool { if (active(boostType)) return true; return use(item); }
}
