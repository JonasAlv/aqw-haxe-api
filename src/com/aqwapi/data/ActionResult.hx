package com.aqwapi.data;

/** Result of an API action that waits for observable client state to confirm completion. */
class ActionResult {
    public var operation:String;
    public var status:String;
    public var success:Bool;
    public var message:String;
    public var elapsedMs:Float;

    public function new(operation:String, status:String, message:String, elapsedMs:Float) {
        this.operation = operation;
        this.status = status;
        this.success = status == "success";
        this.message = message;
        this.elapsedMs = elapsedMs;
    }
}
