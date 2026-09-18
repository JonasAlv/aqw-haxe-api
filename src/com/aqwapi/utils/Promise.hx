package com.aqwapi.utils;

class Promise<T> {
    private var _onResolve:T->Void;
    private var _resolved:Bool = false;
    private var _value:T;

    public function new(executor:(T->Void)->Void) {
        executor(resolve);
    }

    private function resolve(val:T):Void {
        if (_resolved) return;
        _resolved = true;
        _value = val;
        if (_onResolve != null) _onResolve(_value);
    }

    public function then(callback:T->Void):Void {
        if (_resolved) {
            callback(_value);
        } else {
            _onResolve = callback;
        }
    }
}
