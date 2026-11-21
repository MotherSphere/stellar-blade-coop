# Porting to a new game build

The native part reads and calls Stellar Blade at fixed addresses of one build, Steam build 26123051 (version 1.5.0).
`check_build()` in `native/src/game/partner/engine.h` refuses any other executable by its PE TimeDateStamp, its
SizeOfImage and 19 code bytes. A game update can move every address. The tools in `tools/port/` keep the list of the
addresses the code uses, so that each one can be found again in the new executable and checked in Ghidra.

[The port, step by step](#the-port-step-by-step) is the procedure for a new build.
[What the signatures cannot find](#what-the-signatures-cannot-find) lists the game facts that the port checks in
another way.

## What the tools are for

`tools/port/addresses.py` reads the C++ sources under `native/src/` and lists every address of the game they use, with
the name it has in the code, its file and its line. It reads the sources only. It needs neither the game nor Ghidra.

`tools/port/signatures.json` has one entry per address. Each entry records what Ghidra shows at that address on build
26123051 (its kind and a short text in `ghidra`), the names the code gives it in `name` and a byte signature that finds
it in the executable. A signature is a short byte pattern with wildcards. The file holds no other bytes of the game.

`tools/port/make_signatures.py` writes the names and the signatures (see [Signatures](#signatures)). It reads the
executable of build 26123051. It refuses any other one by its TimeDateStamp and SizeOfImage, the values
`check_build()` checks.

`tools/port/find.py` reads the executable of another build and looks for every entry of `signatures.json` there with
its signature (see [Finding the addresses in a new build](#finding-the-addresses-in-a-new-build)).

`tests/tools/port_addresses_test.py` compares the code and the file. It fails when the code uses an address that the
file lacks. It also fails when the file lists an address that no code uses. `tests/tools/port_signatures_test.py` runs
`make_signatures.py` and `find.py` on a small executable it builds itself. It also fails when an entry of
`signatures.json` has no signature or a name that differs from the code's. `tools/install.py` runs both with the other
Python tests.

## The port, step by step

Work on a branch made from `dev` and named after the port (`port-<build>`). A found address, an offset or a size goes
into the code only once Ghidra shows it on the new build. The new executable and its Ghidra project stay outside the
repository.

1. Copy the new `SB-Win64-Shipping.exe` from the game folder to `~/Ghidra/stellar-blade/input/<build>/`, the folder
   `port_signatures_test.py` reads. Import it in Ghidra and let the analysis finish. Keep build 26123051 open next to
   it: most steps compare the two. In game, `coop status` gives the build number as `build=...` in `UE4SS.log` (Steam's
   build ID of the app).
2. Run `find.py` on it and keep its output outside the repository:

   ```
   python3 tools/port/find.py ~/Ghidra/stellar-blade/input/<build>/SB-Win64-Shipping.exe > ~/port-<build>.txt
   ```

   A `found` line gives the address that the old signature points to. An `ambiguous` or `missing` line gives none
   (see step 3). The exit code stays 1 while one entry is not found once.
3. Read each entry's address in Ghidra on the new build, the `found` ones included. Ghidra must show there what the
   entry's `ghidra` text and the comment above the constant in `native/src` describe on build 26123051: the same
   function with the same arguments, the same instruction, the same global or vtable. For an entry with `ref`, also
   read the instruction that holds the field (at `ref.from` on build 26123051). For an `ambiguous` or `missing` entry,
   start on build 26123051 from a neighbour of the address: a caller, a callee, a string its code reads or the vtable
   that holds it. Find that neighbour in the new build, then the address from it. Ghidra's Version Tracking tool
   matches the functions of two programs.
4. Write the new addresses. In `native/src`, change each constant and the addresses its comment gives. In
   `signatures.json`, change each key to the new address, its `ghidra` text to what Ghidra shows on the new build and
   `build` to the new build number. `python3 tools/port/addresses.py` then reports no address missing and none unused.
5. Pin the new build. These are the constants `check_build()` compares, in `native/src/game/partner/engine.h`:
   - `kTimeDateStamp` and `kSizeOfImage` are the new PE header's values. As long as `engine.h` pins build 26123051,
     `make_signatures.py` refuses the new executable with a line that gives both:

     ```
     <path>: TimeDateStamp 0x..., SizeOfImage 0x...: not the pinned build
     ```

   - `kPinRva` is the new address of the `kPinRva` entry minus the image base 0x140000000.
   - `kPinBytes` are the 19 bytes at that address, read in Ghidra on the new build. On build 26123051 they are 5
     instructions, from `XORPS XMM0, XMM0` at 0x142bfd488 to a `CALL` through a RIP-relative pointer. The last 4
     bytes are that call's displacement. They change whenever the code or the data moves, even when the instructions
     stay the same.

   `tests/native/game/partner/engine_test.cpp` expects two refusals that hold the pinned stamp and size:
   `build stamp 6ad8eff1 size 00001000` and `build stamp 12345678 size 15fa3000`. Write the new values there.
   `native/src/glue/tick/worker.inc` names the build in the engine's reason (`pinned build 26123051`).
6. Check every offset, slot, size and table row the code uses (see
   [What the signatures cannot find](#what-the-signatures-cannot-find)).
7. Make the signatures again on the new build:

   ```
   python3 tools/port/make_signatures.py ~/Ghidra/stellar-blade/input/<build>/SB-Win64-Shipping.exe
   ```

   It accepts the new executable once `engine.h` pins it. It writes each entry's signature from the new build, so the
   next port starts from this one. In `tests/tools/port_signatures_test.py`, point `EXE` at the new build's copy and
   change the build number in its messages.
8. Update the other texts that give an old address or the old build. Run `grep -rni` for `26123051` and for the offset
   from the image base of each address that moved (`1ca5790` for 0x141ca5790) in `docs/`, `tests/`, `tools/`,
   `native/src/` and `mod/`. The offset also matches the whole address. Some tests write addresses as literals. SB's
   globals in `tests/native/game/globals_test.cpp` and the `static_assert`s of `tests/native/game/sbo_test.cpp`,
   `tests/native/online/lobby/loading_test.cpp` and `tests/native/ui/pause_tab_test.cpp` fail until they hold the new
   ones. `tests/native/rows/rows_test.cpp` expects AddRow's address in the texts that
   `describe()` writes in `native/src/rows/rows.h`. `tests/tools/matchmaking_scan_test.py` holds RunZoneEvent's offset
   alone, `1ca5790`. The internals pages give the pinned build's addresses, as
   [docs/README.md](../README.md#building-and-internals) says. `INSTALL.md` names the build players need. This page's
   numbers (the section ranges, the signature counts) are build 26123051's. A text that names the build a fact was
   read on, such as a table dump, keeps that build until the fact is read again on the new one.
9. Run the tests:

   ```
   python3 tests/tools/port_addresses_test.py
   python3 tests/tools/port_signatures_test.py
   python3 -I tests/tools/modules_test.py
   python3 tools/install.py --dry-run
   ```

   `port_signatures_test.py` finds every entry at its own address in the new build's copy. The last command runs
   every Lua, Python and native test, then builds the DLL. Its exit code must be 0.
10. Read every address, offset, slot and size a second time in Ghidra on the new build and compare each with the code.
11. With the game closed, install the build (`python3 tools/install.py`), then start the game. `coop status` must not
    show `engine=off` with the reason `check_build()` gives (`build stamp ... size ...` or `code bytes differ`). Then
    test each feature. In `coop-status.txt`, the line of a row batch that the new build refuses reads
    `<word>=refused` with its `why=`. A fault turns its feature off for the run and is logged with the part (see
    [Safety](safety.md#safety-design)).

## What the signatures cannot find

A signature finds an address: a function, an instruction, a global, a vtable or the place of a vtable slot in `.link`.
The code also uses numbers that are not addresses. `addresses.py` does not list them and `find.py` does not check them.
A game update can change them all the same. The comment above each one says where it was read on build 26123051,
most often in a function. Read the same place on the new build.

- Offsets inside the game's objects: `kGameInstance = 0x228` in `native/src/game/sbo.h`, `kEntered = 0x54` in
  `native/src/game/slot.h`. Find the function the comment names in the new build, then the instruction that reads or
  writes the field. Its displacement must equal the constant. A field the engine reflects has its offset in its
  property's parameters (see the row fields below).
- Offsets of vtable slots: `kMoveSlot = 0x4a0` in `native/src/game/pilot.h`, `kAddRowSlot = 0x2b0` in
  `native/src/rows/rows.h`. When the vtable and the function are both in `signatures.json`, read the 8 bytes at the
  vtable's new address plus the slot: they must hold the function's new address. On build 26123051, `kTableVtable`
  0x146409530 plus 0x2b0 is 0x1464097e0, which holds `kAddRow` 0x1441815b0. Otherwise find a call through the slot
  (`call qword ptr [rax+0x4a0]`) in the function the comment names and compare its displacement.
- Row sizes and field offsets of the game's tables: the sizes in `kTables` (`native/src/rows/rows.h`), the patch
  offsets in each `*_rows.h`, the `FIELDS` of `tools/mxiii_rows.py` and `tools/teamshop_rows.py`.
  `tools/sbo_lobby_rows.py` writes its offsets in its code. The engine reflects the row structs. Search the struct's
  name among Ghidra's strings and follow its reference to the struct's parameters. On build 26123051,
  `SBShopTableProperty`'s parameters at 0x146db1d60 hold the name's address at +0x18, the size 0xa8 at +0x20
  (`ShopTable` in `kTables`), the property list at +0x30 and its count, 20, at +0x38. The list holds the parameters of
  `ShopItems` at 0x145e197b8: the name's address at +0, the offset 0x38 at +0x24 (the patch offset in
  `native/src/fight/gunmode/nikke_rows.h`). An array field has two entries of its name in the list: its element's
  first (0x145e19738 for `ShopItems`, offset 0), then the array's own. At run time,
  `rows/rows.h` checks each table's row size before any row. A size that differs refuses the batch: its status line
  gives `why=size`, the table and the size read (`detail=`). No such check guards a field offset.
- Strides, counts and flag values: `kItemBytes = 24` and `kPendingKill = 1 << 29` in
  `native/src/game/partner/engine.h`, `kActionStride = 0x14` in `native/src/game/bike.h`. Read them like an offset, in
  the code the comment names.
- Table contents: donor rows, free IDs and row names come from the table exports and dumps of build 26123051.
  `tools/world_rows.py` and `tools/story_rows.py` write their headers from a folder of exports: set their `BUILD` to
  the new build, run them on its exports and read the diff. For the other generators, compare their donor rows and IDs
  in the new exports.
  At run time, `rows/rows.h` refuses an ID that SB already holds (`why=id`).
- Names the Lua scripts look up. UE4SS finds classes, functions, properties and assets by name at run time, so the
  Lua side holds no address. A name that the new build renames or removes is not found: test each feature in game and
  read `UE4SS.log`.

A wrong offset does not always fault. A fault turns its part off for the run. A wrong read that does not fault gives
wrong values with no log line, so each of these numbers is read in Ghidra before the port is done.

## What counts as an address

The tool removes comments, strings and character literals first, so an address that is only written in a comment is
not listed. In the code that is left, an address is:

- a hex literal from the image base 0x140000000 up to 512 MB further (build 26123051's image is 0x15fa3000 bytes);
- the value of a constant whose name ends in `Rva`, added to the image base (`kPinRva = 0x2bfd488` is 0x142bfd488).

Each use is named after its declaration:

- a constant takes its own name: `kSave` in `constexpr uint64_t kSave = 0x141ce8050`;
- an entry of a table takes the table's name and its index: `kSlots[1]` is the second address of `kSlots`;
- a field of a struct in a table takes both indices: `kKinds[0][4]` is the fifth field of the first `kKinds` entry;
- a literal outside a declaration is named `?`. Give it a constant instead.

Offsets inside the game's objects (`kGameInstance = 0x228`) and slot offsets inside a vtable (`kMoveSlot = 0x4a0`)
are not addresses. The tool does not list them.

## Kinds

The kind says what sits at the address in Ghidra on build 26123051. Ghidra names the executable's sections
`.debug$P` for the code (0x140001000 to 0x1455b2fff), `.link` for the read-only data (0x1455b3000 to 0x146bcffff) and
`.sbss` for the writable data (0x146bd0000 to 0x147182fff).

| Kind | What it is | `ghidra` holds |
| --- | --- | --- |
| `function` | The entry of a function in `.debug$P` | The function's name, `FUN_141ce8050` |
| `code` | An address inside a function | The function and the offset, `FUN_141fc8f40+0x101` |
| `global` | A variable in `.sbss` | Its label, `DAT_1470373e8 in .sbss` |
| `rdata` | Read-only data in `.link`: a vtable, a vtable slot, a constant | Its label and the function a slot points to |
| `section` | The first byte of a section | The sections it starts and ends |
| `image` | The image base | `image base, PE header` |

Every `function`, `code`, `global` and `rdata` entry has a signature. The `section` and `image` addresses come from the
PE header of the new executable.

## Signatures

A signature is a run of whole instructions in the code section (`.debug$P`, the image's first section) that occurs
there exactly once. `pattern` lists its bytes in hex with `??` for a wildcard. `mask` has `x` for a byte that must
match and `?` for a wildcard. The wildcards cover the 4-byte field of a relative call or jump (rel32) and the 4-byte
displacement of a RIP-relative operand. Both change as soon as code or data moves. They also cover the 1-byte field of
a short jump (rel8), which changes when the code between the jump and its target changes length. A signature spans at
most 128 bytes and has at least 6 bytes that must match. It stops before an int3 (the padding between functions) and
after a jump out of the code section.

For each address the tool takes the first of these that works:

1. For a function or code address, the shortest run that starts at the address.
2. An instruction whose field gives the address: a call, a jump or a RIP-relative load. The entry gets `ref`. The run
   may start up to 48 bytes before that instruction. A data address that no instruction gives is found through the
   nearest address below it that one gives, up to 0x2000 bytes below. For a vtable slot, every 8 bytes from that
   address to the slot must hold a code address. A function that only a vtable points to is found through that slot,
   with `read`.
3. For a vtable slot that no instruction finds, the run of the code that the slot or a neighbour slot holds. No other
   8-byte aligned place of the data sections may hold that code's address. The entry gets `holder`.
4. For an instruction inside identical copies of a function (template code), a call to the copy that holds it. The
   entry gets `ref` with `then`.

The match is the address where the pattern matches. Each entry gives its address back this way:

| Entry | Address |
| --- | --- |
| No `ref`, no `holder` | The match |
| `ref` | match + `end` + the signed 32-bit value at match + `disp`, plus `add` |
| `ref` with `read` | The 8 bytes stored at the address `ref` gives |
| `ref` with `then` | `then` applied in the same way to the address `ref` gives, the start of the copy |
| `holder` | The only 8-byte aligned place of the data sections that holds the match, plus `add` |

`ref.from` and `then.from` are the addresses of the instructions that hold the field on build 26123051, for a check in
Ghidra. The tool checks that each signature matches once and gives its address back. It exits with 1 when one does
not.

On build 26123051, 170 entries have a run of their own and 110 go through an instruction: 77 directly, 27 with an
`add`, 3 with `then` and 3 with `read`. 4 story vtables get `holder`: only code in `.edata`, the protected code
section, loads them. The tool reads no code there.

## Running it

```
python3 tools/port/addresses.py
python3 tools/port/make_signatures.py <path to SB-Win64-Shipping.exe of build 26123051>
```

`addresses.py` prints one line per use, sorted by address, with the kind from `signatures.json`:

```
0x141ce8050  function  kSave                     native/src/game/sbo.h:45
0x145fe54c0  rdata     kSlots[1]                 native/src/ui/pad.h:293
```

Then it prints the number of uses and addresses, each address the file lacks and each entry no code uses. It exits
with 1 when there is one of either.

`make_signatures.py` rewrites `signatures.json` in place. It keeps `kind` and `ghidra`. It writes `name` and the
signature again. On build 26123051 it takes about 2 minutes and 1 GB of RAM. A second run writes the same file.

## Finding the addresses in a new build

```
python3 tools/port/find.py <path to SB-Win64-Shipping.exe of the new build>
```

`find.py` reads `signatures.json` and the executable. It accepts any build. For each entry it prints the address on
build 26123051, the kind, the name and one of these:

| State | When |
| --- | --- |
| `found` and the new address | The pattern matches once and gives one address |
| `ambiguous` and the number of matches | The pattern matches more than once. For a `holder` entry, also when more than one place holds the code the pattern matches |
| `missing` | The pattern matches nowhere, a field it reads lies outside the file or no place holds a `holder` entry's code |

The `image` entry gives the image base of the new PE header. A `section` entry gives the start of the section that its
`ghidra` text names after "start of". The last line counts the entries found, the ones among them whose address
moved, the ambiguous ones and the missing ones:

```
0x141ce8050  function  kSave                     found 0x141ce8050
287 found (0 moved), 0 ambiguous, 0 missing
```

The exit code is 0 only when every entry is found once. On build 26123051 itself, every entry is found at its own
address in about 10 seconds. A found address is where the old signature points. It is not checked: read each one in
Ghidra on the new build before the code uses it.

## A new address in the code

Read the address in Ghidra on build 26123051 first, as for any game fact. Then add its entry to `signatures.json` in
address order, written in lower-case hex with `0x`, with its kind and what Ghidra shows there:

```
"0x141ce8050": {"kind": "function", "ghidra": "FUN_141ce8050"},
```

Then run `make_signatures.py` on the executable of build 26123051. Search the new entry's pattern in Ghidra: it must
match once in `.debug$P`. Ghidra searches every section. On build 26123051, 5 patterns also match in `.edata`: 4
once, `kWidgetByGuid`'s twice. For an entry with `ref`, look at the instruction at `ref.from`. When the last use of an
address leaves the code, remove its entry. `port_addresses_test.py` and `port_signatures_test.py` fail until it is done.
