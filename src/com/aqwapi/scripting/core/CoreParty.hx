package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreParty {
    public function new() {}
    public function inParty():Bool return Api.party != null && Api.party.inParty;
    public function leader():Bool return Api.party != null && Api.party.isLeader;
    public function has(username:String):Bool return Api.party != null && Api.party.isMember(username);
    public function invite(username:String):Void if (Api.party != null) Api.party.invite(username);
    public function summon(username:String):Void if (Api.party != null) Api.party.summon(username);
    public function leave():Void if (Api.party != null) Api.party.leave();
    public function target(username:String):Bool return Api.party != null && Api.party.targetMember(username);
}
