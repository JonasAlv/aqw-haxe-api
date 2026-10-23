package com.aqwapi.scripting.content;
import com.aqwapi.Api;
class CoreUltras { public function new() {} public function engage(boss:String, mapName:String):Bool return Api.core != null && Api.core.boss.engage(boss, mapName); public function stopOnShield(aura:String):Bool return Api.core != null && Api.core.boss.stopOnShield(aura); }
