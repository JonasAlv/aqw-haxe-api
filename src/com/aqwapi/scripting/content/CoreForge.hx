package com.aqwapi.scripting.content;
import com.aqwapi.Api;
class CoreForge { public function new() {} public function unlocked(special:String):Bool return Api.enhancement != null && Api.enhancement.isForgeUnlocked(special); public function enhance(cape:String = null, helm:String = null, weapon:String = null):Void if (Api.enhancement != null) Api.enhancement.enhanceEquipped("Lucky", cape, helm, weapon); }
