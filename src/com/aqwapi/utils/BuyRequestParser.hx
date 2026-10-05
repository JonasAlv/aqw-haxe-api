package com.aqwapi.utils;

/**
 * Parses one entry of a bulk purchase list into `{item, quantity}`.
 *
 * Kept free of any Flash dependency so it can be exercised without a Flash runtime, and separate from
 * the queue that paces the sends.
 *
 * Accepted forms:
 *   `{item: "50k Gold Voucher", quantity: 5}`
 *   `{name: "Stealth"}`                        quantity defaults to 1
 *   `["25k Gold Voucher", 2]`                  positional pair
 *   anything else, or an entry with no usable name, yields null and is rejected by the caller.
 */
class BuyRequestParser {

    public static function parse(raw:Dynamic):Dynamic {
        var name:String = null;
        var qty:Int = 1;

        if (raw == null) return null;

        if (Std.isOfType(raw, Array)) {
            var pair:Array<Dynamic> = cast raw;
            if (pair.length > 0 && pair[0] != null) name = Std.string(pair[0]);
            if (pair.length > 1 && pair[1] != null) qty = toInt(pair[1]);
        } else {
            if (raw.item != null) name = Std.string(raw.item);
            else if (raw.name != null) name = Std.string(raw.name);
            if (raw.quantity != null) qty = toInt(raw.quantity);
            else if (raw.qty != null) qty = toInt(raw.qty);
        }

        if (name == null) return null;
        name = StringTools.trim(name);
        if (name.length == 0) return null;
        if (qty < 1) qty = 1;
        return {item: name, quantity: qty};
    }

    /** Tolerates a numeric string, since script authors write `"5"` as often as `5`. */
    private static function toInt(v:Dynamic):Int {
        if (v == null) return 1;
        // Std.int returns Null<Int> - it yields null rather than 0 for input it cannot read, so the
        // nullability has to be handled explicitly or the quantity ends up null.
        var direct:Null<Int> = Std.int(v);
        if (direct != null) return direct;
        var parsed:Null<Int> = Std.parseInt(Std.string(v));
        return (parsed != null) ? parsed : 1;
    }
}