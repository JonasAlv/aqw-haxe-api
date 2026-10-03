package;

/** A reactive-combat snapshot: when the last monster hit landed and how it resolved. */
class React {
    public var at:Float;
    public var type:String;
    public var hp:Int;
    public var mmid:String;

    public function new(at:Float, type:String, hp:Int, mmid:String) {
        this.at = at;
        this.type = type;
        this.hp = hp;
        this.mmid = mmid;
    }
}