# API coverage from AE_source

This document records API additions made from the current decompiled-client reference.
It distinguishes observed command names from behavior that still needs runtime fixtures.

## Sources

- [Protocol reference](https://github.com/JonasAlv/AE_source/blob/main/docs/PROTOCOL.md)
- [Gameplay systems](https://github.com/JonasAlv/AE_source/blob/main/docs/GAME_SYSTEMS.md)
- [Developer guide](https://github.com/JonasAlv/AE_source/blob/main/docs/DEVELOPER_GUIDE.md)

## Added in this branch

### Social / friends

`com.aqwapi.managers.SocialManager` exposes these observed friend operations:

| API method | Wire command | Notes |
| --- | --- | --- |
| `requestFriend(username)` | `requestFriend` | Sends one username argument |
| `acceptFriend(username)` | `addFriend` | Accepts a pending request |
| `declineFriend(username)` | `declineFriend` | Declines a pending request |
| `removeFriend(username)` | `deleteFriend` | Removes an existing friend |
| `refreshFriends()` | `loadFriendsList` | Refreshes the current friend list |

These command names appear in AE_source's observed client-to-server vocabulary.
The methods return `true` only when dispatch is attempted through an available room
transport; it is **not** a server acknowledgement. Consumers should observe
`GameEvent.SOCIAL_UPDATED` for subsequent responses.

The adapter emits `GameEvent.CHAT_MESSAGE` for the documented chat response family
(`cc`, `chatm`, `whisper`, `em`) rather than routing `cc` through quest updates.

### PvP queue

`com.aqwapi.managers.PvpManager` wraps the documented native
`World.requestPVPQueue` method:

- `requestQueue(queueName)` requests the provided queue/warzone.
- `leaveQueue()` invokes the same game method with `"none"`, the documented leave value.

These return whether the native client method was invoked, not the server's final result.
Observed queue-related responses are surfaced as `GameEvent.PVP_UPDATED`.

### Response event families

The transport now surfaces raw payloads through typed `GameEvent` categories for
chat, social/friends, guild, PvP, and housing. Payloads are kept unmodified because
AE_source notes some shapes are version-sensitive and the adapter should not fabricate
a normalized DTO until the payload contract is validated.

## Deliberate boundaries

- No public wire-packet format is exposed; API consumers use domain-level methods.
- Extension requests are rejected before dispatch when there is no active room. A user
  ID is not used as a substitute for the current room ID.
- Friend command names are source-backed, but live protocol fixtures are still needed
  to verify arguments and acknowledgement semantics across current server versions.
- Guild administration, housing mutations, PvP/dungeon rejoin, and friendship-engine
  conversation APIs remain future implementation work. Their commands are documented
  in AE_source, but not every subcommand argument schema is established by the notes alone.
