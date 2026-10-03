package com.aqwapi.combat;

/**
 * A single typed predicate over a signal.
 *
 * Replaces the stringly-typed `Dynamic` rule objects the DSL parser used to emit, so nothing
 * during combat has to inspect a rule's shape or do string comparison on a comparison word.
 */
class Condition {
    /** Registry key - see SignalRegistry. */
    public var signal:String;

    /** One of "<", "<=", ">", ">=", "==", "!=". */
    public var op:String;

    public var value:Dynamic;

    /** Optional payload, e.g. {name: "Tracer Rounds", target: "self"} or {skillId: 3}. */
    public var args:Dynamic;

    /** Inverts the result. */
    public var negate:Bool;

    public function new(signal:String, op:String, value:Dynamic, args:Dynamic = null, negate:Bool = false) {
        this.signal = signal;
        this.op = op;
        this.value = value;
        this.args = args;
        this.negate = negate;
    }

    public function evaluate(ctx:SignalContext):Bool {
        var result:Bool = SignalRegistry.test(this, ctx);
        return negate ? !result : result;
    }

    public function toString():String {
        return (negate ? "!" : "") + signal + " " + op + " " + Std.string(value);
    }
}