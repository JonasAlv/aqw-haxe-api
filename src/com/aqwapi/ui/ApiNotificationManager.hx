package com.aqwapi.ui;

import com.aqwapi.AqwApi;
import com.aqwapi.events.ApiEvent;

#if flash
import flash.display.Sprite;
#end

class ApiNotificationManager {
    private static var _instance:ApiNotificationManager;
    public static var instance(get, never):ApiNotificationManager;
    @:getter(instance)
    public static function get_instance_prop():ApiNotificationManager { return get_instance(); }
    public static function get_instance():ApiNotificationManager {
        if (_instance == null) _instance = new ApiNotificationManager();
        return _instance;
    }

    public static function notify(message:String):Void {
        if (message == null || message == "") return;
        if (instance._initialized) {
            instance.showNotification(null, message, false);
        } else {
            instance._pendingMessages.push({ id: null, message: message, sticky: false });
        }
    }

    #if flash
    private var _container:Sprite;
    private var _notifications:Array<ApiNotification> = [];
    #end
    private var _initialized:Bool = false;
    private var _pendingMessages:Array<{ id:String, message:String, sticky:Bool }> = [];

    public function new() {
        AqwApi.dispatcher.addEventListener(ApiEvent.NOTIFICATION, onApiNotification);
        AqwApi.dispatcher.addEventListener(ApiEvent.STICKY_NOTIFICATION, onStickyNotification);
        AqwApi.dispatcher.addEventListener(ApiEvent.REMOVE_STICKY, onRemoveSticky);
        AqwApi.dispatcher.addEventListener(ApiEvent.COMBAT_TOGGLED, onApiNotification);
        AqwApi.dispatcher.addEventListener(ApiEvent.SCRIPT_STARTED, onApiNotification);
        AqwApi.dispatcher.addEventListener(ApiEvent.SCRIPT_STOPPED, onApiNotification);
    }

    #if flash
    public function init(container:Sprite):Void {
        if (_initialized) return;
        _initialized = true;
        _container = container;
        for (item in _pendingMessages) {
            showNotification(item.id, item.message, item.sticky);
        }
        _pendingMessages = [];
    }
    #else
    public function init(container:Dynamic):Void {
        _initialized = true;
    }
    #end

    private function onApiNotification(e:ApiEvent):Void {
        if (e == null || e.message == null || e.message == "") return;
        if (_initialized) {
            showNotification(null, e.message, false);
        } else {
            _pendingMessages.push({ id: null, message: e.message, sticky: false });
        }
    }

    private function onStickyNotification(e:ApiEvent):Void {
        var id:String = (e.data != null && Reflect.hasField(e.data, "id")) ? Reflect.field(e.data, "id") : "default_sticky";
        if (_initialized) {
            createSticky(id, e.message);
        } else {
            _pendingMessages.push({ id: id, message: e.message, sticky: true });
        }
    }

    private function onRemoveSticky(e:ApiEvent):Void {
        var id:String = (e.data != null && Reflect.hasField(e.data, "id")) ? Reflect.field(e.data, "id") : "default_sticky";
        if (_initialized) {
            removeSticky(id);
        } else {
            var i = _pendingMessages.length - 1;
            while (i >= 0) {
                if (_pendingMessages[i].id == id) {
                    _pendingMessages.splice(i, 1);
                }
                i--;
            }
        }
    }

    public function createSticky(id:String, message:String):Void {
        if (id != null) {
            removeSticky(id);
        }
        showNotification(id, message, true);
    }

    public function removeSticky(id:String):Void {
        #if flash
        var i = _notifications.length - 1;
        while (i >= 0) {
            var notif = _notifications[i];
            if (notif.id == id) {
                notif.destroy();
                _notifications.splice(i, 1);
                positionNotifications();
                return;
            }
            i--;
        }
        #end
    }

    private function showNotification(id:String, message:String, sticky:Bool):Void {
        #if flash
        if (_container == null) return;
        var notif = new ApiNotification(id, message, sticky);
        notif.setOnDismiss(onDismiss);
        _notifications.push(notif);
        _container.addChild(notif);
        positionNotifications();
        #end
    }

    #if flash
    private function onDismiss(notif:ApiNotification):Void {
        var idx = _notifications.indexOf(notif);
        if (idx != -1) {
            _notifications.splice(idx, 1);
        }
        positionNotifications();
    }

    private function positionNotifications():Void {
        var currentY:Float = 0;
        for (notif in _notifications) {
            notif.y = currentY;
            currentY += notif.height + 6;
        }
        if (_container != null && _container.stage != null && _notifications.length > 0) {
            _container.x = (_container.stage.stageWidth - 280) / 2;
            _container.y = 10;
        }
    }
    #end

    public function destroy():Void {
        #if flash
        for (notif in _notifications) {
            notif.destroy();
        }
        _notifications = [];
        if (_container != null && _container.parent != null) {
            _container.parent.removeChild(_container);
        }
        _container = null;
        #end
        _initialized = false;
    }
}
