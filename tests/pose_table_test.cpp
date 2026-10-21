// The component table and the display file on the build machine: round trips, every refusal one defect at a time,
// the mesh path rule (material paths too), the capture's effect lines and the display's effect boxes, and mutated
// tables, which must re-format to the same bytes whenever they are accepted.
#include "pose_table.h"

#include <cassert>
#include <cstdio>
#include <random>
#include <string>

using namespace coop::pose;

namespace {
const std::string kBody = "/Game/Art/Character/PC/CH_P_EVE_52/CH_P_EVE_52_TypeB.CH_P_EVE_52_TypeB",
                  kFace = "/Game/Art/Character/PC/CH_P_EVE_Head/CH_P_EVE_Face_Jali3.CH_P_EVE_Face_Jali3",
                  kNikke = "/Game/DLC_2/Art/Character/PC/EVE_HR_Nikke_02/EVE_HR_Nikke_02.EVE_HR_Nikke_02",
                  kNier = "/Game/DLC_1/Art/Character/PC/EVE_HR_Nier_01/EVE_HR_Nier_01.EVE_HR_Nier_01",
                  kMods = "/Game/Mods/HD-ATOOL_P/data/cha/Eve/hair/CH_P_EVE_Hair_PonyTail_2.CH_P_EVE_Hair_PonyTail_2",
                  kSkin = "/Game/Art/Character/PC/CH_P_EVE_52/MI_EVE_52_Skin.MI_EVE_52_Skin",
                  kTypeB = "/Game/Art/Character/PC/00_HR/EVE_HR_01/MI_EVE_HR_01_TypeB.MI_EVE_HR_01_TypeB",
                  kTail = "/Game/Art/Character/PC/00_HR/EVE_HR_01/MI_EVE_HR_01_Tail_TypeB.MI_EVE_HR_01_Tail_TypeB";
const std::string kSbt = "SBT " + std::to_string(coop::kProtocol) + "\n";

// EVE as Lua captures her, cut down: the body, the face following it, the hair (a leader on the head socket) with the
// ponytail following it, hidden, and the blade. The blade's mesh comes from a mod, so it travels as '-'. The body and
// the hair are dyed; the hair's slot 1 material comes from a mod, so it does not travel at all. Two of Lua's effect
// systems were found: entries 1 and 19.
const std::string kLocal = "generation 100001\n"
                           "map /game/art/bg/worldmap/level_p/e04\n"
                           "part 0 - - - 1 3 CharacterMesh0 " + kBody + "\n"
                           "material 0 2 " + kSkin + "\n"
                           "names 0 Root Bip001 Bip001-Pelvis\n"
                           "read 0 0x1000 0xC1A55 0xAE5\n"
                           "part 1 0 0 - 1 0 Mesh_Face " + kFace + "\n"
                           "place 1 0 0 0 1 0 0 0 1 1 1\n"
                           "part 2 - 0 Bip001-Head 1 2 SBHair " + kNikke + "\n"
                           "place 2 0 0 0.70710678 0.70710678 1.5 -2 0.25 1 1 1\n"
                           "material 2 0 " + kTypeB + "\n"
                           "material 2 1 /Game/Mods/X.X\n"
                           "material 2 3 " + kTail + "\n"
                           "names 2 Bip001-Head Hair_01\n"
                           "read 2 0x1200 0xc1a55 0xae7\n"
                           "part 3 2 2 - 0 0 SBPonytail " + kNier + "\n"
                           "place 3 0 0 0 1 0 0 0 1 1 1\n"
                           "part 4 - 0 SC_SwordingPoint 1 1 SBSkeletalMeshComponent_7 " + kMods + "\n"
                           "place 4 0 0 0 -1 10.25 0 1e-05 1 1 1\n"
                           "names 4 Root\n"
                           "read 4 0x1400 0xc1a55 0xae8\n"
                           "effects 0xC0FF 0x2f8\n"
                           "effect 1 0x5000\n"
                           "effect 19 0x5100\n";
// Its wire form: no read or effect lines, floats as %.9g, the mod's mesh path as '-', its material left out.
const std::string kWire = kSbt +
                          "generation 100001\n"
                          "map /game/art/bg/worldmap/level_p/e04\n"
                          "part 0 - - - 1 3 CharacterMesh0 " + kBody + "\n"
                          "material 0 2 " + kSkin + "\n"
                          "names 0 Root Bip001 Bip001-Pelvis\n"
                          "part 1 0 0 - 1 0 Mesh_Face " + kFace + "\n"
                          "place 1 0 0 0 1 0 0 0 1 1 1\n"
                          "part 2 - 0 Bip001-Head 1 2 SBHair " + kNikke + "\n"
                          "place 2 0 0 0.707106769 0.707106769 1.5 -2 0.25 1 1 1\n"
                          "material 2 0 " + kTypeB + "\n"
                          "material 2 3 " + kTail + "\n"
                          "names 2 Bip001-Head Hair_01\n"
                          "part 3 2 2 - 0 0 SBPonytail " + kNier + "\n"
                          "place 3 0 0 0 1 0 0 0 1 1 1\n"
                          "part 4 - 0 SC_SwordingPoint 1 1 SBSkeletalMeshComponent_7 -\n"
                          "place 4 0 0 0 -1 10.25 0 9.99999975e-06 1 1 1\n"
                          "names 4 Root\n";

// The text with its first 'from' replaced: from must be there, so each case can only fail for its own defect.
std::string with(std::string text, const std::string &from, const std::string &to) {
  size_t at = text.find(from);
  assert(at != std::string::npos);
  return text.replace(at, from.size(), to);
}

bool same(const Table &a, const Table &b, bool addresses) {
  if (a.generation != b.generation || a.map != b.map || a.eve.size() != b.eve.size() || a.look.size() != b.eve.size() ||
      b.look.size() != b.eve.size())
    return false;
  for (size_t i = 0; i < a.eve.size(); ++i) {
    const Part &p = a.eve[i], &q = b.eve[i];
    const Look &l = a.look[i], &m = b.look[i];
    if (p.bones != q.bones || p.leader != q.leader ||
        (addresses && (p.object != q.object || p.cls != q.cls || p.mesh != q.mesh)))
      return false;
    if (l.name != m.name || l.path != m.path || l.socket != m.socket || l.lead != m.lead || l.parent != m.parent ||
        l.shown != m.shown || l.names != m.names || l.materials != m.materials)
      return false;
    for (int k = 0; k < 10; ++k)
      if (l.place[k] != m.place[k])
        return false;
  }
  return true;
}

// A wire table that must be read, so no case looks into a refused one.
Table wire_table(const std::string &text) {
  auto t = parse_table(text, false);
  assert(t);
  return *t;
}

// The table with part 4's path replaced.
std::string blade(const std::string &path) {
  return with(kWire, "SBSkeletalMeshComponent_7 -\n", "SBSkeletalMeshComponent_7 " + path + "\n");
}
} // namespace

int main() {
  // The capture file: every field, the addresses from its read lines.
  auto local = parse_table(kLocal, true);
  assert(local && local->generation == 100001 && local->map == "/game/art/bg/worldmap/level_p/e04");
  assert(local->eve.size() == 5 && local->look.size() == 5);
  const Part &body = local->eve[0];
  assert(body.object == 0x1000 && body.cls == 0xc1a55 && body.mesh == 0xae5 && body.bones == 3 && body.leader);
  assert(!local->eve[1].leader && local->eve[1].bones == 0 && !local->eve[1].object && local->eve[4].object == 0x1400);
  const Look &hair = local->look[2], &tail = local->look[3];
  assert(local->look[0].parent == -1 && local->look[0].lead == -1 && local->look[0].path == kBody);
  assert(hair.socket == "Bip001-Head" && hair.parent == 0 && hair.lead == -1 && hair.path == kNikke && hair.shown);
  assert(hair.names == (std::vector<std::string>{"Bip001-Head", "Hair_01"}) && hair.place[2] == 0.70710678f);
  assert(tail.lead == 2 && tail.parent == 2 && tail.socket.empty() && !tail.shown && tail.path == kNier);
  assert(local->look[4].path.empty() && local->look[4].place[3] == -1 && local->look[4].place[9] == 1);
  using Materials = std::vector<std::pair<uint8_t, std::string>>;
  assert(local->look[0].materials == (Materials{{2, kSkin}}) && local->look[1].materials.empty());
  assert(hair.materials == (Materials{{0, kTypeB}, {3, kTail}})); // The mod's slot 1 dropped, the hair's own kept.
  assert(local->fx.cls == 0xc0ff && local->fx.asset == 0x2f8 && local->fx.assets[1] == 0x5000 &&
         local->fx.assets[19] == 0x5100);
  for (size_t k = 0; k <= kMaxEffectAssets; ++k)
    assert(k == 1 || k == 19 || !local->fx.assets[k]);

  // Round trip: the capture formats to the wire form, which reads back to the same table without the addresses and
  // formats to the same bytes again.
  assert(format_table(*local) == kWire);
  auto wire = parse_table(kWire, false);
  assert(wire && same(*wire, *local, false) && !wire->eve[0].object && format_table(*wire) == kWire && !wire->fx.cls);
  assert(!parse_table(kWire, true) && !parse_table(kLocal, false)); // Each form only where it belongs.

  // Refused: the good wire table with exactly one defect each.
  const std::string p0 = "part 0 - - - 1 3 CharacterMesh0 " + kBody + "\n", n0 = "names 0 Root Bip001 Bip001-Pelvis\n",
                    flat = " 0 0 0 1 0 0 0 1 1 1\n";
  std::string sixteen = kWire, seventeen;
  for (int i = 5; i < 16; ++i)
    sixteen += "part " + std::to_string(i) + " 0 0 - 1 0 Extra -\nplace " + std::to_string(i) + flat;
  seventeen = sixteen + "part 16 0 0 - 1 0 Extra -\nplace 16" + flat;
  std::string names_1000 = "names 0";
  for (int b = 0; b < 1000; ++b)
    names_1000 += " b";
  const std::string long_path = "/" + std::string(70000, 'x'); // Over 64 KiB with it, under without.
  std::string materials_16, materials_17; // The cap with the last slot, and one line past the cap.
  for (int k = 0; k < 17; ++k) {
    if (k < 16)
      materials_16 += "material 1 " + std::to_string(48 + k) + " " + kSkin + "\n";
    materials_17 += "material 1 " + std::to_string(k) + " " + kSkin + "\n";
  }
  for (const std::string &bad : {
           with(kWire, kSbt, ""),                                                                // no SBT line
           with(kWire, kSbt, "SBT " + std::to_string(coop::kProtocol + 1) + "\n"),               // another protocol
           with(kWire, "generation 100001\n", ""),                                               // no generation
           with(kWire, "generation 100001", "generation 0"),                                     // generation 0
           with(kWire, "generation 100001", "generation 9007199254740993"),                      // over 2^53
           with(kWire, "generation 100001", "generation 0x10"),                                  // not decimal
           with(kWire, "map /game/art/bg/worldmap/level_p/e04\n", ""),                           // no map
           with(kWire, "map /game/art", "map /game/Art"),                                        // map not lowercased
           with(kWire, "map /game/art", "map game/art"),                                         // map not a path
           with(kWire, "map /game/art", "map /game.art"),                                        // map: another byte
           with(kWire, "map /game/art", "map /" + std::string(128, 'a') + "/art"),               // map over 128 bytes
           with(kWire, "generation 100001\nmap /game/art/bg/worldmap/level_p/e04\n",
                "map /game/art/bg/worldmap/level_p/e04\ngeneration 100001\n"),                   // out of order
           kWire + "bogus\n",                                                                    // an unknown line
           with(kWire, n0, n0 + n0),                                                             // a repeated line
           kSbt + "generation 100001\nmap /game\n",                                              // no parts
           seventeen,                                                                            // 17 parts
           with(kWire, "part 1 0 0", "part 2 0 0"),                                              // index gap
           with(kWire, "place 1 0", "place 2 0"),                                                // place index
           with(kWire, "part 0 - - -", "part 0 0 - -"),                                          // part 0 a follower
           with(kWire, "part 0 - - -", "part 0 - 0 -"),                                          // part 0 hung
           with(kWire, "part 1 0 0", "part 1 1 0"),                                              // lead not before
           with(kWire, "part 3 2 2", "part 3 1 2"),                                              // lead a follower
           with(kWire, "part 1 0 0 - 1 0", "part 1 0 0 - 1 3"),                                  // a follower's bones
           with(with(kWire, "1 1 SBSkeletalMesh", "1 0 SBSkeletalMesh"), "names 4 Root", "names 4"), // a leader's 0
           // pose_size refuses a leader over 903 bones, but not one whose names count, 2 + bones, wraps to 1.
           with(with(kWire, "1 1 SBSkeletalMesh", "1 18446744073709551615 SBSkeletalMesh"), "names 4 Root",
                "names"),                                                                        // > kMaxBones
           with(with(kWire, "1 3 CharacterMesh0", "1 1000 CharacterMesh0"), n0, names_1000 + "\n"), // pose > 16 KiB
           with(kWire, "part 1 0 0", "part 1 0 -"),                                              // part 1 unhung
           with(kWire, "part 2 - 0", "part 2 - 2"),                                              // parent not before
           with(kWire, "Bip001-Head 1 2", "Bip001-Head 2 2"),                                    // shown not 0 or 1
           with(kWire, "SBHair", std::string(65, 'n')),                                          // name over 64
           with(kWire, "Bip001-Head 1 2", std::string(65, 's') + " 1 2"),                        // socket over 64
           with(kWire, "Hair_01", std::string(65, 'b')),                                         // bone name over 64
           with(kWire, "SBHair", "SB\tHair"),                                                    // a control byte
           with(kWire, "SBHair", "SB\xc3\xa4Hair"),                                              // a byte over '~'
           with(kWire, "SBHair", "SB Hair"),                                                     // a word too many
           with(kWire, "part 0 - -", "part 0  - -"),                                             // two spaces
           with(kWire, n0, "names 0 Root Bip001 Bip001-Pelvis \n"),                              // a trailing space
           with(kWire, kSbt, kSbt + "\n"),                                                       // an empty line
           with(kWire, "part 1 0 0 -", "part 1 0 0 "),                                           // an empty socket
           with(kWire, "SBSkeletalMeshComponent_7 -\n", "SBSkeletalMeshComponent_7 \n"),         // an empty path
           with(kWire, kSbt, "SBT " + std::to_string(coop::kProtocol) + "\r\n"),                 // CRLF
           kWire.substr(0, kWire.size() - 1),                                                    // cut short
           blade(long_path),                                                                     // over 64 KiB
           with(kWire, "1.5 -2", "1.5x -2"),                                                     // not a number
           with(kWire, "1.5 -2", "+1.5 -2"),                                                     // a sign C++ refuses
           with(kWire, "1.5 -2", "nan -2"),                                                      // NaN
           with(kWire, "1.5 -2", "inf -2"),                                                      // infinite
           with(kWire, "1.5 -2", "1e39 -2"),                                                     // over a float
           with(kWire, "1.5 -2", "100000.01 -2"),                                                // |t| over 1e5
           with(kWire, "place 1 0 0 0 1", "place 1 0 0 0 0.9"),                                  // |q|^2 0.81
           with(kWire, "place 1 0 0 0 1", "place 1 0 0 0 1.05"),                                 // |q|^2 1.1025
           with(kWire, "0.25 1 1 1", "0.25 1 1 100.5"),                                          // |s| over 100
           with(kWire, "place 1 0 0 0 1 0 0 0 1 1 1", "place 1 0 0 0 1 0 0 0 1 1"),              // 9 floats
           with(kWire, p0, p0 + "place 0" + flat),                                               // place on part 0
           with(kWire, "place 1" + flat, ""),                                                    // no place
           with(kWire, n0, ""),                                                                  // no names
           with(kWire, n0, "names 0 Root Bip001\n"),                                             // names short
           with(kWire, "place 1" + flat, "place 1" + flat + "names 1 Root\n"),                   // a follower's names
           with(kWire, n0, n0 + "read 0 0x1000 0xc1a55 0xae5\n"),                                // a read line
           with(kWire, "material 2 3 ", "material 2 64 "),                                       // slot over 63
           with(kWire, "material 2 3 ", "material 2 0 "),                                        // a repeated slot
           with(kWire, "material 2 0 ", "material 2 5 "),                                        // a falling slot
           with(kWire, "material 2 0 ", "material 1 0 "),                                        // material index
           with(kWire, "material 2 0 ", "material 2 x "),                                        // slot not a number
           with(kWire, "material 2 0 " + kTypeB, "material 2 0 " + kTypeB + " x"),               // a word too many
           with(kWire, "material 2 0 " + kTypeB, "material 2 0"),                                // no path
           with(kWire, "material 2 0 " + kTypeB, "material 2 0 /" + std::string(255, 'x')),      // path of 256
           with(with(kWire, "material 2 3 " + kTail + "\n", ""), "Hair_01\n",
                "Hair_01\nmaterial 2 3 " + kTail + "\n"),                                       // after names
           with(kWire, "place 1" + flat, "material 1 0 " + kSkin + "\nplace 1" + flat),           // before place
           with(kWire, "place 1" + flat, "place 1" + flat + materials_17),                       // 17 on one part
           kWire + "effects 0xC0FF 0x2f8\n",                                                     // effects on the wire
           kWire + "effects 0xC0FF 0x2f8\neffect 1 0x5000\n",                                   // and an effect
       })
    assert(!parse_table(bad, false));
  for (const std::string &bad : {
           with(kLocal, "read 0 0x1000 0xC1A55 0xAE5\n", ""),                       // no read line
           with(kLocal, "read 0 0x1000", "read 0 0x0"),                             // a null object
           with(kLocal, "read 0 0x1000 0xC1A55 0xAE5", "read 0 0x1000 0x0 0xAE5"),  // a null class
           with(kLocal, "0xC1A55 0xAE5", "0xC1A55 0x0"),                            // a null mesh
           with(kLocal, "read 0 0x1000", "read 0 1000"),                            // not hex
           with(kLocal, "read 0 0x1000", "read 0 0x12345678901234567"),             // over 64 bits
           with(kLocal, "read 2 0x1200", "read 0 0x1200"),                          // read index
           with(kLocal, "place 1 0 0 0 1 0 0 0 1 1 1\n",
                "place 1 0 0 0 1 0 0 0 1 1 1\nread 1 0x1100 0xc1a55 0xae6\n"),      // a follower's read line
           kSbt + kLocal,                                                           // an SBT line
           with(kLocal, "0xC0FF 0x2f8", "0x0 0x2f8"),                               // no effect class
           with(kLocal, "0x2f8", "0xff"),                                           // an offset under 0x100
           with(kLocal, "0x2f8", "0x1001"),                                         // over 0x1000
           with(kLocal, "0x2f8", "0x104"),                                          // not a multiple of 8
           with(kLocal, "0x2f8", "760"),                                            // not hex
           with(kLocal, "effects 0xC0FF 0x2f8", "effects 0xC0FF"),                  // no offset
           with(kLocal, "effect 1 ", "effect 0 "),                                  // k 0
           with(kLocal, "effect 19 ", "effect 33 "),                                // k over 32
           with(kLocal, "effect 1 0x5000\neffect 19 0x5100\n",
                "effect 19 0x5100\neffect 1 0x5000\n"),                             // a falling k
           with(kLocal, "effect 19 ", "effect 1 "),                                 // a repeated k
           with(kLocal, "effect 1 0x5000", "effect 1 0x0"),                         // a null system
           with(kLocal, "effect 1 0x5000", "effect 1 5000"),                        // not hex
           with(kLocal, "effect 1 0x5000", "effect 1 0x5000 0x1"),                  // a word too many
           with(kLocal, "effects 0xC0FF 0x2f8\n", ""),                              // effect without effects
           kLocal + "effects 0xC0FF 0x2f8\n",                                       // effects twice
           kLocal + "part 5 0 0 - 1 0 Extra -\nplace 5" + flat,                     // a part after them
           with(kLocal, "part 4 ", "effects 0xC0FF 0x2f8\npart 4 "),                // effects before the last part
       })
    assert(!parse_table(bad, true));
  // Effects at their edges: offsets 0x100 and 0x1000, entry 32, none found, and no effect lines at all.
  const std::string no_effects = kLocal.substr(0, kLocal.find("effects "));
  assert(parse_table(with(kLocal, "0x2f8", "0x100"), true)->fx.asset == 0x100);
  assert(parse_table(with(kLocal, "0x2f8", "0x1000"), true)->fx.asset == 0x1000);
  assert(parse_table(with(kLocal, "effect 19 ", "effect 32 "), true)->fx.assets[32] == 0x5100);
  auto none_found = parse_table(no_effects + "effects 0xC0FF 0x2f8\n", true);
  assert(none_found && none_found->fx.cls == 0xc0ff && none_found->fx.assets == decltype(none_found->fx.assets){});
  auto no_read = parse_table(no_effects, true);
  assert(no_read && !no_read->fx.cls && format_table(*no_read) == kWire);
  // The edges just inside, and the forms the rules allow.
  assert(parse_table(with(kWire, "generation 100001", "generation 9007199254740992"), false));
  const std::string map_128 = "/" + std::string(127, 'a');
  assert(wire_table(with(kWire, "/game/art/bg/worldmap/level_p/e04", map_128)).map == map_128);
  assert(parse_table(with(kWire, "map /game/art/bg/worldmap/level_p/e04", "map /"), false));
  assert(wire_table(sixteen).eve.size() == 16);
  assert(parse_table(with(kWire, "SBHair", std::string(64, 'n')), false));
  assert(parse_table(with(kWire, "1.5 -2", "100000 -2"), false));
  assert(parse_table(with(kWire, "place 1 0 0 0 1", "place 1 0 0 0 0.95"), false));
  assert(parse_table(with(kWire, "0.25 1 1 1", "0.25 1 -100 1"), false));
  // Materials: 16 on a follower up to slot 63, a path of 255 bytes, one the rule refuses dropped from the wire form.
  auto follower = wire_table(with(kWire, "place 1" + flat, "place 1" + flat + materials_16));
  assert(follower.look[1].materials.size() == 16 && follower.look[1].materials.back().first == 63);
  assert(format_table(follower) == with(kWire, "place 1" + flat, "place 1" + flat + materials_16));
  const std::string p255_material = "/Game/Art/Character/" + std::string(33, 'F') + "/" + std::string(100, 'M') + "." +
                                    std::string(100, 'M');
  assert(wire_table(with(kWire, kTail, p255_material)).look[2].materials[1].second == p255_material);
  auto dropped = wire_table(with(kWire, "material 2 0 " + kTypeB, "material 2 0 /Game/Mods/X.X"));
  assert(dropped.look[2].materials == (Materials{{3, kTail}}));
  assert(format_table(dropped) == with(kWire, "material 2 0 " + kTypeB + "\n", ""));
  // Material lines (5), effect slots (6), channel 2 (7), chat (8), deltas (9), scale (10), same-place enemies (11).
  assert(kSbt == "SBT 11\n");
  // Text that is not canonical is read, and passed on in the canonical form only.
  auto loose = parse_table(with(kWire, "generation 100001", "generation 0100001"), false);
  assert(loose && format_table(*loose) == kWire);

  // The mesh path rule: base, NieR (DLC_1) and NIKKE (DLC_2) meshes, the base sword, 255 bytes.
  const std::string folder = "/Game/Art/Character/" + std::string(33, 'F') + "/", asset = std::string(100, 'A');
  const std::string p255 = folder + asset + "." + asset;
  assert(p255.size() == 255);
  const std::string sword = "/Game/Art/Character/Weapon/Sword/CH_W_Sword_01/CH_W_Sword_01.CH_W_Sword_01",
                    dlc_12 = "/Game/DLC_12/Art/Character/PC/X/X.X";
  for (const std::string &good : {kBody, kFace, kNikke, kNier, p255, sword, dlc_12})
    assert(path_allowed(good));
  for (const std::string &bad : {
           kMods,
           std::string("/Game/Mods/Art/Character/PC/X/X.X"),
           std::string("/Game/Art/Character/PC/../../Mods/X/X.X"),
           std::string("/Game/Art/Character/PC/..X/X.X"),
           std::string("/Game/Art/Character/PC//X/X.X"),
           std::string("/Game/Art/Character//PC/X.X"),
           std::string("/Game/Art/Character/PC\\X/X.X"),
           "/Game/Art/Character/" + std::string(34, 'F') + "/" + asset + "." + asset, // 256 bytes
           std::string("/Game/Art/Character/PC/CH_P_EVE_52/CH_P_EVE_52_TypeB.CH_P_EVE_08"), // not its own asset
           std::string("/Game/Art/Character/PC/CH_P_EVE_52/CH_P_EVE_52_TypeB"),             // a package, no object
           std::string("/Game/Art/Character/PC/X/X.X:Sub"),
           std::string("/Game/Art/Character/PC/X/X.X.X"),
           std::string("/Game/Art/Character/X.X"), // no folder
           std::string("/Game/Art/Character/PC/X/.X"),
           std::string("/Game/Art/Character/PC/X/"),
           std::string("/Game/DLC_123/Art/Character/PC/X/X.X"),
           std::string("/Game/DLC_/Art/Character/PC/X/X.X"),
           std::string("/Game/DLC_1Art/Character/PC/X/X.X"),
           std::string("/Game/Art/Character/PC/X-1/X.X"),
           std::string("/game/art/character/pc/x/x.x"),
           std::string("Game/Art/Character/PC/X/X.X"),
           std::string("/Game/Art/CharacterX/PC/X/X.X"),
           std::string("-"),
           std::string(),
       }) {
    assert(!path_allowed(bad));
    // In a table, a refused path is no refusal: the part is drawn on a fallback.
    if (!bad.empty()) {
      auto t = parse_table(blade(bad), false);
      assert(t && t->look[4].path.empty() && format_table(*t) == kWire);
    }
  }
  assert(wire_table(blade(kNier)).look[4].path == kNier);
  assert(wire_table(blade("/" + std::string(60000, 'x'))).look[4].path.empty()); // Long, under 64 KiB.

  // Under 64 KiB as read but over it as the wire form (".1" comes back as "0.100000001"): refused, as a peer could
  // not read it back. The same table with floats that do not grow passes.
  std::string near_cap = kSbt + "generation 1\nmap /m\npart 0 - - - 1 900 Body " + p255 + "\nnames 0";
  for (int b = 0; b < 900; ++b)
    near_cap += " " + std::string(64, 'b');
  near_cap += "\n";
  for (int i = 1; i < 16; ++i)
    near_cap += "part " + std::to_string(i) + " 0 0 " + std::string(64, 's') + " 1 0 " + std::string(64, 'n') + " " +
                p255 + "\nplace " + std::to_string(i) + " .1 0 0 .995 0 0 0 1 1 1\n";
  std::string still = near_cap;
  for (size_t at; (at = still.find(" .1 0 0 .995")) != std::string::npos;)
    still.replace(at, 12, " 0 0 0 1");
  assert(near_cap.size() <= kMaxTable && !parse_table(near_cap, false));
  assert(format_table(wire_table(still)).size() <= kMaxTable);

  // The display file: part 0 on a 4-bone fallback mapped by name, the hair driven as it came, the blade left out.
  const std::string display = "display 100001\n"
                              "mailbox 0x2000 0x5c0\n"
                              "drive 0 0x3000 0xc2 0xa08 4\n"
                              "remap 0 0 1 -1 2\n"
                              "drive 2 0x3200 0xC2 0xae7 2\n";
  auto d = parse_display(display, *wire);
  assert(d && d->generation == 100001 && d->mailbox == 0x2000 && d->mailbox_class == 0x5c0);
  assert(d->puppet.size() == 5 && d->remap.size() == 5);
  const Part &p = d->puppet[0], &h = d->puppet[2];
  assert(p.object == 0x3000 && p.cls == 0xc2 && p.mesh == 0xa08 && p.bones == 4 && p.leader);
  assert(d->remap[0] == (std::vector<int16_t>{0, 1, -1, 2}));
  assert(h.object == 0x3200 && h.cls == 0xc2 && h.bones == 2 && d->remap[2].empty());
  assert(!d->puppet[1].object && !d->puppet[3].object && !d->puppet[4].object); // Followers, and the blade not drawn.
  auto direct = parse_display("display 100001\nmailbox 0x2000 0x5c0\ndrive 0 0x3000 0xc2 0xae5 3\n", *wire);
  assert(direct && direct->remap[0].empty());
  for (uint64_t box : d->effects)
    assert(!box); // No effects line: no boxes.
  // The effect boxes, right after the mailbox: each its own, never 0 or the mailbox.
  const std::string boxes = "effects 0x2100 0x2200 0x2300 0x2400\n",
                    display_fx = with(display, "0x5c0\n", "0x5c0\n" + boxes);
  auto fx = parse_display(display_fx, *wire);
  assert(fx && fx->effects[0] == 0x2100 && fx->effects[1] == 0x2200 && fx->effects[2] == 0x2300 &&
         fx->effects[3] == 0x2400 && fx->puppet[0].object == 0x3000);
  for (const std::string &bad : {
           with(display, "0x5c0\n", "0x5c0\n" + boxes + boxes),                   // twice
           with(display, "display 100001\n", "display 100001\n" + boxes),         // before the mailbox
           display + boxes,                                                       // after the drive lines
           with(display, "drive 2 ", boxes + "drive 2 "),                         // between them
           with(display_fx, "0x2300", "0x2100"),                                  // a repeated box
           with(display_fx, "0x2400", "0x2000"),                                  // the mailbox
           with(display_fx, "0x2200", "0x0"),                                     // a null box
           with(display_fx, " 0x2400", ""),                                       // three boxes
           with(display_fx, "0x2400", "0x2400 0x2500"),                           // five
           with(display_fx, "0x2400", "2400"),                                    // not hex
       })
    assert(!parse_display(bad, *wire));
  for (const std::string &bad : {
           with(display, "display 100001", "display 100000"),                       // a stale generation
           with(display, "display 100001\n", ""),                                   // no display line
           with(display, "mailbox 0x2000 0x5c0\n", ""),                             // no mailbox
           with(display, "mailbox 0x2000", "mailbox 0x0"),                          // a null mailbox
           with(display, "0x2000 0x5c0", "0x2000 0x0"),                             // a null mailbox class
           display + "drive 2 0x3300 0xc2 0xae7 2\n",                               // a repeated index
           with(display, "-1 2\n", "-1 3\n"),                                       // a remap past the remote bones
           with(display, "0 1 -1", "0 1 -2"),                                       // a remap under -1
           with(display, "remap 0 0 1 -1 2", "remap 0 0 1 -1"),                     // a remap short of the bones
           with(display, "remap 0 0 1 -1 2", "remap 0 0 1 -1 2 2"),                 // a remap past the bones
           with(display, "0xae7 2", "0xae7 3"),                                     // a direct drive's count
           with(display, "drive 0 0x3000 0xc2 0xa08 4\nremap 0 0 1 -1 2\n", ""),    // no part 0
           display + "drive 1 0x3100 0xc2 0xae6 1\nremap 1 -1\n",                   // a follower
           display + "drive 5 0x3500 0xc2 0xae6 1\n",                               // no such part
           with(display, "drive 0 0x3000", "drive 0 0x0"),                          // a null object
           with(display, "0x3000 0xc2", "0x3000 0x0"),                              // a null class
           with(display, "0xc2 0xa08", "0xc2 0x0"),                                 // a null mesh
           with(display, "0xa08 4\nremap 0 0 1 -1 2", "0xa08 0\nremap 0"),          // no bones
           with(display, "remap 0 ", "remap 2 "),                                   // a remap for another part
           with(display, "drive 0 0x3000 0xc2 0xa08 4\nremap 0 0 1 -1 2\n",
                "remap 0 0 1 -1 2\ndrive 0 0x3000 0xc2 0xa08 4\n"),                 // a remap before its drive
           display + "bogus\n",                                                     // an unknown line
           display.substr(0, display.size() - 1),                                   // cut short
           display + "remap\n",                                                     // a remap of one word, last
           display + "drive 4 0x3400 0xc2 0xae8 18446744073709551615\nremap\n",     // > kMaxBones
       })
    assert(!parse_display(bad, *wire));

  // A display fits only the layout it was checked against. A part hung elsewhere, shown, hidden or placed elsewhere
  // keeps the ghost; a part more, a leader's bones, a follower's leader or a mesh is a new ghost, generation or not.
  assert(same_layout(*wire, wire_table(with(kWire, "SC_SwordingPoint 1", "SC_Back 0"))));
  assert(same_layout(*wire, wire_table(with(kWire, "1.5 -2 0.25", "3 -2 0.25"))));
  assert(!same_layout(*wire, wire_table(kWire + "part 5 0 0 - 1 0 Extra -\nplace 5" + flat)));
  assert(!same_layout(*wire, wire_table(with(with(kWire, " 1 2 SBHair", " 1 1 SBHair"), "Bip001-Head Hair_01\n",
                                             "Bip001-Head\n"))));
  assert(!same_layout(*wire, wire_table(with(kWire, "part 3 2 2", "part 3 0 2"))));
  assert(!same_layout(*wire, wire_table(with(kWire, "SBPonytail " + kNier, "SBPonytail " + kNikke))));
  assert(!same_layout(*wire, Table()));
  assert(same_layout(*wire, dropped)); // Materials change only with a new generation, and never the layout.

  // Fuzz: mutated wire tables and capture files never crash, and whatever is accepted formats to a wire form that
  // reads back to the same table and the same bytes, with only allowed paths in it.
  std::mt19937_64 rng(11);
  std::uniform_int_distribution<int> any(0, 255);
  const std::string alphabet = "0123456789-.e /\n_x0";
  auto mutate = [&](std::string text) { // One to three bytes changed, added or removed, mostly from the grammar's own.
    for (int edits = 1 + any(rng) % 3; edits--;) {
      size_t at = size_t(any(rng) * 256 + any(rng)) % text.size();
      char c = any(rng) % 8 ? alphabet[size_t(any(rng)) % alphabet.size()] : char(any(rng));
      switch (any(rng) % 4) {
      case 0: text.insert(text.begin() + long(at), c); break;
      case 1: text.erase(at, 1); break;
      default: text[at] = c;
      }
    }
    return text;
  };
  size_t accepted = 0;
  for (int round = 0; round < 200000; ++round) {
    const bool is_local = round % 2;
    auto t = parse_table(mutate(is_local ? kLocal : kWire), is_local);
    if (!t)
      continue;
    ++accepted;
    const std::string canonical = format_table(*t);
    auto again = parse_table(canonical, false);
    assert(again && same(*again, *t, false) && format_table(*again) == canonical);
    assert(is_local || !t->fx.cls);
    assert(!t->fx.assets[0] && (t->fx.cls ? t->fx.asset >= 0x100 && t->fx.asset <= 0x1000 && t->fx.asset % 8 == 0
                                          : !t->fx.asset && t->fx.assets == decltype(t->fx.assets){}));
    for (const Look &l : t->look) {
      assert(l.path.empty() || path_allowed(l.path));
      for (const auto &[slot, path] : l.materials)
        assert(slot < kMaxSlots && path_allowed(path));
    }
  }
  std::printf("pose_table: fuzz accepted %zu of 200000 mutated tables, each re-formatted to the same bytes\n",
              accepted);

  // The display file too: an accepted one drives part 0 and remote leaders only, each on the remote bones or on a remap
  // as long as its mesh's bones, every entry a remote bone or -1.
  size_t drawn = 0;
  for (int round = 0; round < 100000; ++round) {
    auto got = parse_display(mutate(round % 2 ? display_fx : display), *wire);
    if (!got)
      continue;
    ++drawn;
    assert(got->puppet.size() == 5 && got->remap.size() == 5 && got->puppet[0].object);
    const uint64_t *box = got->effects; // None, or four of their own.
    assert(!box[0] ? !box[1] && !box[2] && !box[3]
                   : box[0] && box[1] && box[2] && box[3] && box[0] != box[1] && box[0] != box[2] && box[0] != box[3] &&
                         box[1] != box[2] && box[1] != box[3] && box[2] != box[3] && box[3] != got->mailbox &&
                         box[0] != got->mailbox && box[1] != got->mailbox && box[2] != got->mailbox);
    for (size_t i = 0; i < 5; ++i) {
      const Part &part = got->puppet[i];
      const std::vector<int16_t> &map = got->remap[i];
      assert(!part.object ||
             (wire->eve[i].leader && (map.empty() ? part.bones == wire->eve[i].bones : map.size() == part.bones)));
      for (int16_t k : map)
        assert(part.object && k >= -1 && k < int(wire->eve[i].bones));
    }
  }
  std::printf("pose_table: fuzz accepted %zu of 100000 mutated display files, all within the remote table\n", drawn);
  std::puts("pose_table_test: all passed");
}
