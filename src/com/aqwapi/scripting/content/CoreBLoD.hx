package com.aqwapi.scripting.content;
import com.aqwapi.Api;
class CoreBLoD { public function new() {} public function farm():Bool return Api.core != null && Api.core.farm.item("DoomVault", "Blinding Light of Destiny", 1, "doomvault"); }
