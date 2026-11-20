# Porting to a new game build

The native part reads and calls Stellar Blade at fixed addresses of one build, Steam build 26123051 (version 1.5.0).
`check_build()` in `native/src/game/partner/engine.h` refuses any other executable by its PE TimeDateStamp, its
SizeOfImage and 19 code bytes. A game update can move every address. The tools in `tools/port/` keep the list of the
addresses the code uses, so that each one can be found again in the new executable and checked in Ghidra.

## What the tools are for

`tools/port/addresses.py` reads the C++ sources under `native/src/` and lists every address of the game they use, with
the name it has in the code, its file and its line. It reads the sources only. It needs neither the game nor Ghidra.

`tools/port/signatures.json` has one entry per address. Each entry records what Ghidra shows at that address on build
26123051 (its kind and a short text in `ghidra`), the names the code gives it in `name` and a byte signature that finds
it in the executable. A signature is a short byte pattern with wildcards. The file holds no other bytes of the game.

`tools/port/make_signatures.py` writes the names and the signatures (see [Signatures](#signatures)). It reads the
executable of build 26123051. It refuses any other one by its TimeDateStamp and SizeOfImage, the values
`check_build()` checks.

`tests/tools/port_addresses_test.py` compares the code and the file. It fails when the code uses an address that the
file lacks. It also fails when the file lists an address that no code uses. `tests/tools/port_signatures_test.py` runs
`make_signatures.py` on a small executable it builds itself. It also fails when an entry of `signatures.json` has no
signature or a name that differs from the code's. `tools/install.py` runs both with the other Python tests.

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
displacement of a RIP-relative operand. Both change as soon as code or data moves. A signature spans at most 128 bytes
and has at least 6 bytes that must match. It stops before an int3 (the padding between functions) and after a jump out
of the code section.

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

On build 26123051, 145 entries have a run of their own and 85 go through an instruction: 67 directly, 15 with an
`add`, 2 with `then` and 1 with `read`. 4 story vtables get `holder`: only code in `.edata`, the protected code
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

## A new address in the code

Read the address in Ghidra on build 26123051 first, as for any game fact. Then add its entry to `signatures.json` in
address order, written in lower-case hex with `0x`, with its kind and what Ghidra shows there:

```
"0x141ce8050": {"kind": "function", "ghidra": "FUN_141ce8050"},
```

Then run `make_signatures.py` on the executable of build 26123051. Search the new entry's pattern in Ghidra: it must
match once in `.debug$P`. Ghidra searches every section. On build 26123051, 5 patterns also match once in `.edata`.
For an entry with `ref`, look at the instruction at `ref.from`. When the last use of an address leaves the
code, remove its entry. `port_addresses_test.py` and `port_signatures_test.py` fail until it is done.
