// The native pose path's Windows side, between the worker thread (glue/steam.cpp) and the game thread (coop_tick).
#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <string>
#include <vector>

#include "link/protocol.h" // Request, State, Vitals, Life
#include "save/slot.h"     // Saves

namespace coop::pose {
// Worker thread, every pass: pins the build once; reads coop-session.txt, coop-components.txt (EVE's capture, sent on
// as the wire table) and coop-display.txt (the ghost Lua built for the remote table) when they change, the last one at
// every pass while the ghost for a new remote table is awaited; logs what the game thread produced (write refusals,
// faults, counters every 60 s) through event; while the Night Operation poller is on, samples it every 100 ms into
// nightop-probe.txt (it stops on coop off).
void worker_poll(const std::wstring &folder, uint64_t now_ms, const std::function<void(const std::string &)> &event);
// Worker thread: coop-state.txt as last read (every 250 ms): whether a save is loaded, the send rate, the synced photo
// mode's fields (ours, photo_sync and photo_freeze_max); its defaults until Lua wrote one.
coop::State lua_state();
// Worker thread, every pass after worker_poll: sends the newest encoded pose, hands what the loopback's delay line and
// the replay have due to the receiving side, and stops a recording at its cap. True while the loopback, a recording, a
// replay or a linked friend runs (the worker then passes every 5 ms, not 50).
bool worker_stream();
// Worker, every pass after the link's tick: whether a friend passed the handshake both ways, and how to reach her.
void peer(bool linked, uint64_t now_ms, void (*send)(const uint8_t *, size_t, bool));
// Worker, from the link's channel-1 receive (a handshaken lobby member only): her table or pose.
void peer_receive(const uint8_t *data, size_t size);
// Worker thread. Each returns the line for the log: what was asked, or why not. The loopback and the replay never run
// together, and either takes over from a linked friend until it is off; turning either off removes the remote table,
// so the ghost goes with it.
std::string ask_loopback(bool on, uint32_t delay_ms, uint32_t jitter_ms, uint32_t loss_percent);
std::string ask_record(bool on);  // EVE's capture and poses into coop-record.bin, written at the stop.
std::string ask_replay(bool on);  // coop-record.bin played in a loop as the remote side.
// Worker thread: the nightop request (Phase 6). Starts the read-only poller on the pinned build (no-op when on) and,
// with rule, arms its verdict 60 s later, once a run. Returns the line for the log.
std::string ask_nightop(bool rule, uint64_t now_ms);
void block(); // coop off: no engine access until the game restarts.
// Worker thread: coop loopback runs (its line in status() says loopback=), so with no friend linked the chat echoes
// and our vitals stand in for hers (UI-DESIGN 5.4).
bool loopback();
// Worker thread, every 100 ms in a chat session: our EVE's vitals for the friend's partner card (fight/engine.h's
// vitals()); false off the pinned build, after coop off, or when they cannot be read (no world, a load). took_us: the
// read's time (0 when none ran), whose worst goes in a 60 s line (UI-DESIGN 7.3).
bool local_vitals(coop::Vitals &out, uint64_t &took_us);
// Worker thread, every 250 ms: the save slot the game entered (client +0x54, save/slot.h), or slot::kUnread on another
// build or after coop off, which read nothing.
int loaded_slot();
// Worker thread, every 250 ms with loaded_slot: which save files the game uses, from the GameSaveFileName entry read
// back (save/slot.h's Names), or slot::Saves::off on another build, which reads nothing. After coop off: the last value
// read, with no new read, since the game keeps the name until it exits.
slot::Saves saves();
// Worker thread: the read-only probe's line for the log (save/slot.h's probe), or why it read nothing.
std::string saves_probe();
// Worker thread: why saves() reads off or unread (another build, coop off, or the name's walk), or empty.
std::string saves_why();
// Worker thread: the title's load mode (client +0x86c, save/slot.h's not_title), or slot::kUnread on another build or
// after coop off.
int load_mode();
// Worker thread: switches the save name to the co-op copies' (coop) or back (save/slot.h's Names::swap: one 8-byte
// compare-and-swap in the game's heap, under SEH). Empty once switched, else why not. On the pinned build, before coop
// off only; the caller checks the title first.
std::string saves_switch(bool coop);
// Worker thread, Phase 11's shared fight (fight/engine.h's Worker). A coop fight request (Command::fight): on, probe,
// record or replay with the charIds it shares (fight_chars; none: every Monster), off, status or a probe's test;
// marker: the slot StellarCoopSlot.txt names. A mode starts only on the pinned build and before coop off, else is
// refused with why; probe, record and replay also need a co-op save (slot=coop) then. It runs while a save is loaded
// and our player is not in SB's photo mode (and, for on, a friend is linked and the save is a co-op one). record and
// replay use coop-fight-record.txt in the mod folder. Returns the line for the log.
std::string ask_fight(const coop::Request &request, int marker);
// Worker, every pass after the link's tick. lines: her channel-2 lines; send: ours to her (hp unreliable, false when
// not queued); hosting: we own the lobby. Hands her lines to the job and its lines to send (or to the recording), logs
// its events, its probe census, a fault and a stats line each second its counts move; starts, pauses or stops it for
// the gates (on waits for a co-op save; the solo tools stop off one), tells her our state while we do not share, and
// leaves it off until asked again once it latched. mate: her life (Link::mate_life()), for the job's group rules. True
// while the job runs (the worker then passes every 5 ms, not 50). Also logs the Lion's answers (ask_lion's).
bool fight_pass(uint64_t now_ms, bool linked, bool hosting, int marker, const std::vector<std::string> &lines,
                bool (*send)(const std::string &, bool), coop::Life mate);
// Worker: coop-status.txt's fight line (fight/engine.h's Worker::detail).
std::string fight_status();
// The shared quests' record beside each co-op slot, in this account's save folder (glue/steam.cpp's, through
// save/twins.h's name check and put): load gives "" when there is none and false when it cannot be read; save writes
// the whole file.
struct QuestFiles {
  std::function<bool(int slot, std::string &text, size_t max)> load;
  std::function<bool(int slot, const std::string &text)> save;
};
// Worker thread, the shared quests (Phase 12, quest/engine.h's Worker): a coop quests request (Command::quests),
// refused off the pinned build and after coop off. Returns the line for the log.
std::string ask_quests(const coop::Request &request);
// Worker, every pass after the link's tick and before fight_pass: takes her SBQ lines out of lines (the rest are the
// shared fight's), hands the game thread the save-slot line its gate reads, starts and stops the side for the asks and
// the gates, and sends, logs and writes what the game thread's passes made (coop-quests.log, the record beside the
// co-op slot through files, coop-quests-record.txt in the mod folder). hosting: we own the lobby; partner: her SteamID
// while she is linked, else 0; send: a line to her on channel 2, reliable (false when it cannot go); marker: the slot
// StellarCoopSlot.txt names.
void quest_pass(uint64_t now_ms, bool hosting, uint64_t partner, int marker, std::vector<std::string> &lines,
                bool (*send)(const std::string &), const QuestFiles &files);
// Worker thread, the follow's travel (game/travel.h): Lua's travel request, the camp's FName for the game thread's next
// frame, which calls SB's fast travel once game/travel.h's guard passes. Refused off the pinned build, after coop off
// and after the travel latch's fault. Returns the line for the log; the call's own line follows from worker_poll.
std::string ask_travel(const coop::Request &request);
// Worker thread, coop lion (lion/rows.h): Lua's lion rows request, the 12 tables' addresses for the game thread, which
// adds the Lion's rows through SB's AddRow once its gate holds. Refused off the pinned build, after coop off and after
// the Lion's fault, and not asked again once every row is in. Returns the line for the log; fight_pass logs the game
// thread's answer.
std::string ask_lion(const coop::Request &request);
// Worker thread, coop gift (game/items.h): Lua's items request, how many of one item our EVE carries, read now through
// ReadProcessMemory; the answer goes in the engine line's items= (status()). Refused off the pinned build, after coop
// off and with no EVE read. Returns the line for the log.
std::string ask_items(const coop::Request &request);
// Worker: coop-status.txt's lion line (lion/rows.h's status_line): "lion=off", or the state (waiting, rows, refused,
// fault) with added=<n>/<N>, asks=<a>, spawns=<s> and that state's own fields.
std::string lion_status();
// Worker: coop-status.txt's shared quests lines (quest/engine.h's Worker::status), each ending in a line break.
std::string quest_status();
// Worker: coop-status.txt's pilot line (same-place enemies): "pilot=on piloted=<n> owned=<n> drawn=<n>",
// "pilot=off why=<word>", "pilot=stopped" or "pilot=refused why=<why>", with " probe=on" and " test=<how far>" before
// the why.
std::string pilot_status();
// The synced photo mode's pause (game/photo_freeze.h), which the game thread holds as our own tag in SB's pause set.
// Worker thread. Whether this game can hold it: the pinned build, before coop off, no fault so far.
bool can_freeze();
// Every pass after the link's tick. sync: the friend's photo mode asks for our pause (Link::photo_freeze()). Ends a
// coop freeze whose time is up, logs what the game thread did (a hold a new world ended, a pause applied again, a
// fault) and returns a line for the player's screen (the fault's), or empty.
std::string freeze_pass(bool sync, uint64_t now_ms);
// Worker: our pause tag is held (coop-status.txt's frozen=).
bool frozen();
// The coop freeze request (the solo tests): on, our pause tag held for ms, until coop freeze off, coop off or the
// world it paused is gone (a load); or off. On the pinned build only. Returns the line for the log.
std::string ask_freeze(bool on, uint64_t ms, uint64_t now_ms);
// SB's developer gates (game/debug_keys.h), worker thread. The coop fly or coop slowmo request (Command::gate): on
// until off, coop off or the next Lua load; refused off the pinned build, after coop off and after the gates' fault.
// Returns the line for the log.
std::string ask_gate(const coop::Request &request);
// Every pass after the link's tick: hands the game thread the gates to set (the asks, on a co-op save, slow motion with
// no friend linked; marker: the slot StellarCoopSlot.txt names), logs what its passes did and returns a line for the
// player's screen (a refusal, a fault), or empty.
std::string debug_pass(bool linked, int marker, uint64_t now_ms);
// "engine=on" (plus " loopback=on <delay> <jitter> <loss>" or " loopback=waiting", " record=on", " replay=on",
// " remote=<generation> <tables written> <loopback|replay|peer>") or "engine=off reason=...", then " fight=on <count>",
// " fight=probe", " fight=waiting" or " fight=stopped" while the shared fight is asked or latched, then " nightop=on"
// or " nightop=rule" (once the rule was asked) last while the poller runs: no per-frame counters.
std::string status();
// A complete file: written beside it, then renamed over it (glue/steam.cpp).
bool write_text(const std::wstring &path, const std::string &bytes);
// At most about max bytes of a file, shared for delete; exists says whether it opened (glue/tick.cpp). Shared with
// glue/steam.cpp: the co-op marker.
std::string read_file(const std::wstring &path, bool &exists, size_t max);
} // namespace coop::pose
