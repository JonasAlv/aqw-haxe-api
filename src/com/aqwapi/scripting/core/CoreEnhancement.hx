package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreEnhancement {
    public function new() {}
    public function smart(className:String = null, force:Bool = false):Void if (Api.enhancement != null) Api.enhancement.smartEnhance(className, force);
    public function equipped(base:String = "Lucky", cape:String = null, helm:String = null, weapon:String = null):Void if (Api.enhancement != null) Api.enhancement.enhanceEquipped(base, cape, helm, weapon);
    public function unlocked(special:String):Bool return Api.enhancement != null && Api.enhancement.isForgeUnlocked(special);
    public function busy():Bool return Api.enhancement != null && Api.enhancement.isBusy;
    public function cancel():Void if (Api.enhancement != null) Api.enhancement.cancel();
}
