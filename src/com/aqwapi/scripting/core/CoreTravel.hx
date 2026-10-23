package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreTravel {
    public var context:CoreContext;
    public function new(context:CoreContext) this.context = context;
    public function at(mapName:String, cell:String = null):Bool return Api.map != null && Api.map.isAt(mapName, cell);
    public function ensure(mapName:String, cell:String = null, pad:String = null):Bool { if (Api.map == null || mapName == null || mapName == "") return false; Api.map.usePrivateRoom = context.privateRooms; Api.map.privateRoomNumber = context.privateRoomNumber; return Api.map.ensure(mapName, cell, pad); }
    public function join(mapName:String, cell:String = null, pad:String = null):Void if (Api.map != null) Api.map.join(mapName, cell, pad);
    public function jump(cell:String, pad:String = null):Void if (Api.map != null) Api.map.jump(cell, pad);
    public function ensureCell(cell:String, pad:String = null):Bool return Api.map != null && Api.map.ensureCell(cell, pad);
    public function reload(pad:String = null):Void if (Api.map != null) Api.map.reload(pad);
    public function travelToPlayer(username:String):Bool return Api.map != null && Api.map.gotoPlayer(username);
    public function ensureTercess(destination:String = "nulgath", pad:String = null):Bool return Api.map != null && Api.map.ensureTercess(destination, pad);
}
