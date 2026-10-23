package com.aqwapi.scripting.content;
import com.aqwapi.Api;
class CoreNSoD { public function new() {} public function farm():Bool return Api.core != null && Api.core.farm.item("Nulgath", "Necrotic Sword of Doom", 1, "tercessuinotlim"); }
