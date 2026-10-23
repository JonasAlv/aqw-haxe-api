package com.aqwapi.scripting.content;
import com.aqwapi.Api;
class CoreLR { public function new() {} public function farm():Bool return Api.core != null && Api.core.farm.item("Legion Fenrir", "Legion Revenant", 1, "underworld"); }
