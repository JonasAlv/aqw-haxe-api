package com.aqwapi.scripting.content;
import com.aqwapi.Api;
class CoreAwe { public function new() {} public function unlocked():Bool return Api.enhancement != null && Api.enhancement.isAweUnlocked(); public function enhance():Void if (Api.enhancement != null) Api.enhancement.enhanceEquipped("Lucky", null, null, "Awe Blast"); }
