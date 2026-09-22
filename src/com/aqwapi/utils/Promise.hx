package com.aqwapi.utils;

class Promise<T> {
    private var _callbacks:Array<T->Void> = [];
    private var _resolved:Bool = false;
    private var _value:T;

    public function new(executor:(T->Void)->Void) {
        if (executor != null) {
            try {
                executor(_resolve);
            } catch (e:Dynamic) {}
        }
    }

    private function _resolve(val:T):Void {
        if (_resolved) return;
        _resolved = true;
        _value = val;
        for (cb in _callbacks) {
            if (cb != null) {
                try {
                    cb(_value);
                } catch (e:Dynamic) {}
            }
        }
        _callbacks = [];
    }

    public function then(callback:T->Void):Promise<T> {
        if (callback != null) {
            if (_resolved) {
                try {
                    callback(_value);
                } catch (e:Dynamic) {}
            } else {
                _callbacks.push(callback);
            }
        }
        return this;
    }

    public static function resolve<T>(val:T):Promise<T> {
        var p = new Promise<T>(null);
        p._resolve(val);
        return p;
    }
}
