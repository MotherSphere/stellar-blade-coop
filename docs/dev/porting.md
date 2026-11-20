# Porting to a new game build

The native part reads and calls Stellar Blade at fixed addresses of one build, Steam build 26123051 (version 1.5.0).
`check_build()` in `native/src/game/partner/engine.h` refuses any other executable by its PE TimeDateStamp, its
SizeOfImage and 19 code bytes. A game update can move every address. The tools in `tools/port/` keep the list of the
addresses the code uses, so that each one can be found again in the new executable and checked in Ghidra.

## What the tools are for

`tools/port/addresses.py` reads the C++ sources under `native/src/` and lists every address of the game they use, with
the name it has in the code, its file and its line. It reads the sources only. It needs neither the game nor Ghidra.

`tools/port/signatures.json` has one entry per address. Each entry records what Ghidra shows at that address on build
26123051: its kind and a short text in `ghidra`. The file holds no bytes of the game executable. It has no signatures
yet.

`tests/tools/port_addresses_test.py` compares the two. It fails when the code uses an address that the file lacks,
and when the file lists an address that no code uses. `tools/install.py` runs it with the other Python tests.

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

A byte signature can find a `function` or a `code` address in a new build. The `rdata` entries (vtables and their
slots) are out of scope for byte signatures. They stay on the list so that a port still checks each one. The
`section` and `image` addresses come from the PE header of the new executable.

## Running it

```
python3 tools/port/addresses.py
```

It prints one line per use, sorted by address, with the kind from `signatures.json`:

```
0x141ce8050  function  kSave                     native/src/game/sbo.h:45
0x145fe54c0  rdata     kSlots[1]                 native/src/ui/pad.h:293
```

Then it prints the number of uses and addresses, each address the file lacks and each entry no code uses. It exits
with 1 when there is one of either.

## A new address in the code

Read the address in Ghidra on build 26123051 first, as for any game fact. Then add its entry to `signatures.json` in
address order, written in lower-case hex with `0x`, with its kind and what Ghidra shows there:

```
"0x141ce8050": {"kind": "function", "ghidra": "FUN_141ce8050"},
```

When the last use of an address leaves the code, remove its entry. `port_addresses_test.py` fails until both are done.
