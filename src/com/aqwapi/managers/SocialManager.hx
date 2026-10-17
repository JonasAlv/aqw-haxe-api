package com.aqwapi.managers;

import com.aqwapi.Api;
import com.aqwapi.Game;
import com.aqwapi.utils.ApiLogger;

/**
 * SocialManager exposes the friend operations observed in the current AQW client.
 *
 * A true return means the request was dispatched to the connected game transport;
 * it does not mean the server accepted the friend action. Observe GameEvent.SOCIAL_UPDATED
 * for subsequent server responses/state updates.
 *
 * Command vocabulary and response families are documented in AE_source/docs/PROTOCOL.md
 * and AE_source/docs/GAME_SYSTEMS.md. User-name argument shapes follow the current
 * client's direct friend-command pattern and should be rechecked when the client changes.
 */
class SocialManager {
    private var _game:Game;

    public function new(gameReference:Game) {
        _game = gameReference;
    }

    private inline function _g():Game {
        return (_game != null) ? _game : Api.game;
    }

    /**
     * Requests to add a player as a friend.
     * Returns false when the request cannot be dispatched (for example, before joining a room).
     */
    public function requestFriend(username:String):Bool {
        var name = normalizeUsername(username);
        if (name == "") return false;
        if (Api.player != null && Api.player.username != "" &&
            name.toLowerCase() == Api.player.username.toLowerCase()) return false;
        return sendFriendCommand("requestFriend", name);
    }

    /**
     * Accepts a pending friend request using the observed addFriend command.
     * A true return confirms dispatch only, not server-side acceptance.
     */
    public function acceptFriend(username:String):Bool {
        var name = normalizeUsername(username);
        if (name == "") return false;
        return sendFriendCommand("addFriend", name);
    }

    /** Declines a pending friend request. A true return confirms dispatch only. */
    public function declineFriend(username:String):Bool {
        var name = normalizeUsername(username);
        if (name == "") return false;
        return sendFriendCommand("declineFriend", name);
    }

    /** Removes a friend using the observed deleteFriend command. */
    public function removeFriend(username:String):Bool {
        var name = normalizeUsername(username);
        if (name == "") return false;
        return sendFriendCommand("deleteFriend", name);
    }

    /**
     * Asks the client/server to refresh the friend list.
     * The subsequent data arrives asynchronously through social response events.
     */
    public function refreshFriends():Bool {
        return sendFriendCommand("loadFriendsList", null);
    }

    private function normalizeUsername(username:String):String {
        return (username != null) ? StringTools.trim(username) : "";
    }

    private function sendFriendCommand(command:String, username:Null<String>):Bool {
        var g = _g();
        if (g == null || g.sfc == null) return false;

        // The AE client protocol expects the active room id for extension commands.
        // Never substitute myUserId: it is a different identifier and can produce bad frames.
        if (g.sfc.activeRoomId == null) return false;

        var args:Array<Dynamic> = [];
        if (username != null) args.push(username);

        try {
            if (Api.transport != null) {
                Api.transport.sendExtensionCommand(command, args);
            } else {
                g.sfc.sendXtMessage("zm", command, args, "str", g.sfc.activeRoomId);
            }
            ApiLogger.debug("Social", "Dispatched friend command=" + command);
            return true;
        } catch (e:Dynamic) {
            ApiLogger.warn("Social", "Could not dispatch friend command=" + command + ": " + Std.string(e));
            return false;
        }
    }
}
