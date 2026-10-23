package com.aqwapi.scripting.content;
import com.aqwapi.Api;
class CoreVHL { public function new() {} public function unlocked():Bool return Api.quest != null && Api.quest.isCompleted(5895); public function farm():Bool return Api.core != null && Api.core.farm.item("Cultist High Priest", "Void Highlord", 1, "tercessuinotlim"); }
