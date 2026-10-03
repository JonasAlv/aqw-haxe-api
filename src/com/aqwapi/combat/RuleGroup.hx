package com.aqwapi.combat;

/**
 * A conjunction (or disjunction) of typed conditions.
 *
 * Replaces the `multiAuraOperator` string that used to be re-read from a `Dynamic` on every
 * 100ms tick.
 */
class RuleGroup {
    public var conditions:Array<Condition>;

    /** true = ANY passes, false = ALL must pass. */
    public var isOr:Bool;

    public function new(conditions:Array<Condition>, isOr:Bool) {
        this.conditions = (conditions != null) ? conditions : [];
        this.isOr = isOr;
    }

    public function isEmpty():Bool return conditions.length == 0;

    public function evaluate(ctx:SignalContext):Bool {
        if (conditions.length == 0) return true;

        if (isOr) {
            for (c in conditions) {
                if (c.evaluate(ctx)) return true;
            }
            return false;
        }

        for (c in conditions) {
            if (!c.evaluate(ctx)) return false;
        }
        return true;
    }

    public function toString():String {
        if (conditions.length == 0) return "(no rules)";
        var out = "";
        for (i in 0...conditions.length) {
            if (i > 0) out += isOr ? " OR " : " AND ";
            out += Std.string(conditions[i]);
        }
        return out;
    }
}