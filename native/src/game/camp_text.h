// Matrix XIII's camp names and records, the native half, free of Windows: 12 entries added to SB's live StringTable_UI,
// so the keys the mxnames rows name (lion/mxiii_rows.h) read as our names on every camp surface, and 50 to
// StringTable_Records (game/record_text.h), the titles and texts the mxrecords rows name. This file names the calls and
// offsets, holds the names, picks the language, says when a pass is due and writes the status lines (camptext=,
// recordtext=). The records' entries are text only and no row of a save without the mxrecords batch names them.
// tests/native/game/camp_text_test.cpp checks it on the build machine. All read from build 24463856's code; it has not
// run in game.
//
// SB's rows hold a key, and FText::FromStringTable (FUN_142862780) looks the key up in the registered table each time
// a display string is read. On a missing key this build shows "<key>" (FUN_142879140), so a row may name a key only
// once the entry exists: matrix13/world/travel.lua asks the mxnames batch only when this file's line reads
// camptext=ready, and a row left with its donor's key shows the donor's name. The build has no
// FStringTable::SetSourceString and ImportStrings clears the table first, so the entry is made by the same out of line
// calls ImportStrings makes. The table is registered in its ctor, before Serialize fills it: only its loaded byte,
// which PostLoad sets, says it holds its rows. FTextLocalizationManager::GetDisplayString (FUN_14287d320) overrides an
// existing display string only under the culture "ko", so a language change assigns the strings directly.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

namespace coop::camp_text {
// The registry's getter, its find (TSharedPtr out, an FName by value), the table's FindEntry (TSharedPtr out; takes the
// table's lock itself), FTextKey from an FString, the text manager's holder, GetDisplayString, FString's copy, the
// entry factory ImportStrings calls, the two map emplaces, FString's assign and FInternationalization's getter.
constexpr uint64_t kRegistry = 0x14285ba90, kFindTable = 0x14285bd10, kFindEntry = 0x142859090, kTextKey = 0x14287ac60,
                   kManagerHolder = 0x142642210, kDisplayString = 0x14287d320, kCopy = 0x140e4b370,
                   kMakeEntry = 0x142857ff0, kAddKey = 0x142888180, kAddDisplay = 0x142888090, kAssign = 0x140e4a330,
                   kInternationalization = 0x14284b150;
// FStringTable: its loaded byte, namespace, KeysToEntries, DisplayStringsToKeys and KeyMappingCS.
constexpr size_t kLoaded = 0x18, kNamespace = 0x20, kKeys = 0x30, kDisplays = 0x80, kTableLock = 0xd0;
// FStringTableEntry: its source and its display string's shared pointer (object, then controller).
constexpr size_t kEntrySource = 0x10, kEntryDisplay = 0x20, kEntryDisplayRef = 0x28;
// The manager in its holder, and the lock over its display strings; the current culture in FInternationalization,
// and its name's characters and count.
constexpr size_t kManager = 0x198, kManagerLock = 8, kCulture = 0x28, kCultureName = 0x28, kCultureNameNum = 0x30;
// The controller of a shared pointer: its strong and weak counts, its vtable's DestroyObject (0) and destructor (1).
constexpr size_t kStrong = 8, kWeak = 0xc;
constexpr uint64_t kCheckMs = 250;
constexpr const wchar_t *kTableId = L"/Game/Local/Localize/StringTable_UI.StringTable_UI";
constexpr const wchar_t *kRecordsTableId = L"/Game/Local/Localize/StringTable_Records.StringTable_Records";

// The region's key is an FName (RegionName): FName would split digits off its end, so it must end in a letter. The camp
// keys are FStrings (CampName), "MX13_Camp_" and the row's name. French, English; \u for what is not ASCII.
struct Entry {
  const char16_t *key, *french, *english;
};
constexpr Entry kEntries[] = {
    {u"MX13_Region", u"Matrice 13", u"Matrix 13"},
    {u"MX13_Camp_DLC02_00_Camp_00", u"Matrice 13", u"Matrix 13"},
    {u"MX13_Camp_DLC02_10_Camp_01", u"T\u00eate d'ascenseur", u"Lift Head"},
    {u"MX13_Camp_DLC02_10_Camp_02", u"Bureau du chef de gare", u"Station Master's Office"},
    {u"MX13_Camp_DLC02_20_Camp_01", u"Sas de la voiture 9", u"Car 9 Airlock"},
    {u"MX13_Camp_DLC02_20_Camp_02", u"Voies de garage", u"Sidings"},
    {u"MX13_Camp_DLC02_20_Camp_03", u"Hall de l'ascenseur", u"Lift Hall"},
    {u"MX13_Camp_DLC02_20_Camp_04", u"Salle des signaux", u"Signal Room"},
    {u"MX13_Camp_DLC02_30_Camp_01", u"Premi\u00e8re halte", u"First Rest Stop"},
    {u"MX13_Camp_DLC02_30_Camp_02", u"Deuxi\u00e8me halte", u"Second Rest Stop"},
    {u"MX13_Camp_DLC02_30_Camp_03", u"Puits de pompage", u"Pump Shaft"},
    {u"MX13_Camp_DLC02_40_Camp_01", u"Salle des pompes", u"Pump Hall"},
};

// French on a culture named fr or fr-*, English on any other. name: an FString's characters, num: its count with the
// NUL (0 and a null name when empty).
inline bool french(const char16_t *name, int32_t num) { return name && num >= 3 && name[0] == u'f' && name[1] == u'r'; }

// When a pass over the table is due: until one has ended, when the language changed since, and when the table no longer
// holds its first entry (holds_first false): the engine collected a table only a Lua LoadAsset held and loaded it again
// without ours [inference: not seen in game].
struct Pass {
  bool filled = false, in_french = false;
  bool due(bool now_french, bool holds_first = true) const {
    return !filled || now_french != in_french || !holds_first;
  }
  void done(bool now_french) { filled = true, in_french = now_french; }
};

// The status line. wait: no pass has ended (the table not loaded yet); ready: every entry exists; fault: the first
// fault ended the passes for the run. No line off the pinned build, so Lua waits there too.
enum class State : uint8_t { wait, ready, fault };
inline std::string line(State s, const char *word = "camptext") {
  return std::string(word) + "=" + (s == State::ready ? "ready" : s == State::fault ? "fault" : "wait");
}
} // namespace coop::camp_text

#include "game/record_text.h"

namespace coop::camp_text {
// The tables a pass writes, each with its own pass, so a table loaded later holds the other back from nothing.
struct TableEntries {
  const wchar_t *id;
  const Entry *entries;
  size_t count;
};
constexpr TableEntries kWrites[] = {{kTableId, kEntries, sizeof kEntries / sizeof *kEntries},
                                    {kRecordsTableId, kRecordEntries, sizeof kRecordEntries / sizeof *kRecordEntries}};
constexpr size_t kWriteCount = sizeof kWrites / sizeof *kWrites;
} // namespace coop::camp_text
