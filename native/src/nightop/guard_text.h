// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The Xion guard's lines (nightop/guard_text.lua), the native half, free of Windows: his 12 keys with their Korean
// sources, the 23 cultures, the guardtext request's check, what the game thread writes and the guardtext= line.
// tests/native/nightop/guard_text_test.cpp checks it on the build machine; tests/lua/nightop/recruiter_text_test.lua
// checks that the keys, sources, lines and cultures match nightop/recruiter_text.lua. The glue is
// nightop/guard_text_game.inc.
//
// His 12 texts (speaker title, question, Join, Cancel, three replies) are keyed FText literals in namespace "", and no
// Game.locres of the 23 cultures names them, so every culture shows the Korean source. Each one's live display string
// comes from FTextLocalizationManager::GetDisplayString (FUN_142882dd0), which finds the entry by namespace and key and
// stores the hash of the source (FUN_141c47fb0) with it. The source here must be the asset's byte for byte: under the
// culture "ko", a hash that differs makes SB write the source back over the display string.
#pragma once

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>

#include "link/protocol.h" // chat_clean

namespace coop::guard_text {

// The lines, by index: T (the title), Q, J (Join), C (Cancel), A1, A2, A3.
constexpr size_t kLineCount = 7, kKeyCount = 12, kCultureCount = 23;

// A key (namespace ""), its Korean source as the asset holds it, and the line it shows.
struct Key {
  const char16_t *key, *source;
  uint8_t line;
};
constexpr Key kKeys[kKeyCount] = {
    {u"1369C3D149FBA96B3A868A8DDB37F6DB", u"\uc790\uc774\uc628 \ubaa8\ubcd1\uad00", 0},
    {u"17655DF64FCD86F91529FDB6E28F85DA", u"(\uc784\uc2dc) \ucde8\uc18c", 3},
    {u"1D919BC54814EE9DEA9B86A353B9FB1A", u"(\uc784\uc2dc) \uc790\uc774\uc628 \ubaa8\ubcd1\uad00", 0},
    {u"1EC542C44399E9B5B68A5281A10096DA", u"(\uc784\uc2dc) \uc57c\uac04\uc791\uc804\uc5d0 \ucc38\uc5ec\ud55c\ub2e4(\uba40\ud2f0\ud50c\ub808\uc774 \ucc38\uc5ec)", 2},
    {u"4ED6720D4C01A463E14958BA0EFD74F3", u"\uc57c\uac04\uc791\uc804\uc5d0 \ucc38\uc5ec\ud558\uc2dc\uaca0\uc2b5\ub2c8\uae4c?", 1},
    {u"782D3CF24282FF4209C210AD8B19578C", u"(\uc784\uc2dc) \uc57c\uac04\uc791\uc804\uc5d0 \ucc38\uc5ec\ud55c\ub2e4(\uba40\ud2f0\ud50c\ub808\uc774 \ucc38\uc5ec)", 2},
    {u"845B85444BEB4A1DC834AC970B04E051", u"\uc790\uc774\uc628 \ubaa8\ubcd1\uad00", 0},
    {u"8684A0504021287B7FB80FA6BDE723B6", u"(\uc784\uc2dc) \ucde8\uc18c", 3},
    {u"90E21C7C499D1388F4FE8398516ADE70", u"\uc790\uc774\uc628 \ubaa8\ubcd1\uad00", 0},
    {u"9B0147424996337B530492A5E2F71030", u"(\uc784\uc2dc) \ud604\uc7ac \ub124\ud2b8\uc6cc\ud06c \uc5f0\uacb0\uc774 \ubd88\uac00\ub2a5\ud569\ub2c8\ub2e4. \uc635\uc158\uc5d0\uc11c \ud65c\uc131 \ud574\uc8fc\uc138\uc694", 6},
    {u"D0D5606146CF2F72244711A2943E8E11", u"\ud589\uc6b4\uc744 \ube55\ub2c8\ub2e4.", 4},
    {u"D476C7694FDE4C24A96661809D99F648", u"(\uc784\uc2dc) \uc900\ube44\uac00 \ub418\uba74 \ub2e4\uc2dc \uc54c\ub824\uc8fc\uc138\uc694.", 5},
};

// The game's text cultures (its 23 Game.locres), the names nightop/recruiter_text.lua's culture() gives.
constexpr const char *kCultures[kCultureCount] = {
    "ar", "da", "de", "en", "en-GB", "es", "es-MX", "fi", "fr", "it", "ja", "ko",
    "nl", "no", "pl", "pt", "pt-BR", "ru", "sv", "th", "tr", "zh-Hans", "zh-Hant"};

// A request's lines: culture indexes kCultures, text holds the seven lines in kLineCount's order.
struct Lines {
  uint8_t culture = 0;
  std::array<std::u16string, kLineCount> text;
};

// text: what follows "guardtext ", a culture and seven lines, each after a tab. True when the culture is one of
// kCultures exactly and each line is non-empty and unchanged by chat_clean (well-formed UTF-8, no control or invisible
// format character, no space at an edge, at most kMaxChat bytes); only then is out written, each line in UTF-16 (a
// character past U+FFFF as a surrogate pair).
inline bool parse(std::string_view text, Lines &out) {
  if (static_cast<size_t>(std::count(text.begin(), text.end(), '\t')) != kLineCount)
    return false;
  std::string_view f[kLineCount + 1];
  for (size_t i = 0, at = 0; i <= kLineCount; ++i) {
    const size_t tab = text.find('\t', at); // npos for the last field: substr then takes the rest.
    f[i] = text.substr(at, tab - at);
    at = tab + 1;
  }
  uint8_t culture = kCultureCount;
  for (uint8_t c = 0; c < kCultureCount; ++c)
    if (f[0] == kCultures[c])
      culture = c;
  if (culture == kCultureCount)
    return false;
  for (size_t i = 1; i <= kLineCount; ++i)
    if (f[i].empty() || chat_clean(f[i]) != f[i])
      return false;
  out.culture = culture;
  for (size_t i = 0; i < kLineCount; ++i) {
    const std::string_view s = f[i + 1];
    std::u16string &t = out.text[i];
    t.clear();
    for (size_t at = 0; at < s.size();) { // Well-formed: chat_clean kept every byte.
      const unsigned lead = static_cast<unsigned char>(s[at]);
      const size_t len = lead < 0x80 ? 1 : lead < 0xE0 ? 2 : lead < 0xF0 ? 3 : 4;
      uint32_t c = len == 1 ? lead : lead & (0x7F >> len);
      for (size_t k = 1; k < len; ++k)
        c = c << 6 | (static_cast<unsigned char>(s[at + k]) & 0x3F);
      if (c > 0xFFFF)
        t += char16_t(0xD800 + ((c - 0x10000) >> 10)), t += char16_t(0xDC00 + (c & 0x3FF));
      else
        t += char16_t(c);
      at += len;
    }
  }
  return true;
}

// wait: no lines written yet; ready: a culture's lines are in his 12 display strings; off: coop off ran, nothing is
// written again; fault: a write faulted.
enum class State : uint8_t { wait, ready, off, fault };
// What the game thread writes: nothing, the lines it holds, or the 12 Korean sources back.
enum class Write : uint8_t { none, lines, sources };

// undo: coop off asked for the sources; due: new lines wait. The sources go back only over written lines.
constexpr Write next(bool undo, bool due, State state) {
  return undo ? (state == State::ready ? Write::sources : Write::none)
              : (due && state != State::off ? Write::lines : Write::none);
}

// The state and the culture index in one word, for the status line: the state in the low byte, the culture above.
constexpr uint16_t word(State state, uint8_t culture) {
  return static_cast<uint16_t>(static_cast<uint8_t>(state) | culture << 8);
}

// The status line: guardtext=wait, guardtext=ready <culture>, guardtext=off or guardtext=fault, with where after a
// fault when known. A ready word whose culture is not in kCultures reads wait.
inline std::string line(uint16_t word, const std::string &where) {
  const auto state = static_cast<State>(word & 0xff);
  const size_t culture = word >> 8;
  if (state == State::ready && culture < kCultureCount)
    return std::string("guardtext=ready ") + kCultures[culture];
  if (state == State::off)
    return "guardtext=off";
  if (state == State::fault)
    return where.empty() ? "guardtext=fault" : "guardtext=fault " + where;
  return "guardtext=wait";
}

} // namespace coop::guard_text
