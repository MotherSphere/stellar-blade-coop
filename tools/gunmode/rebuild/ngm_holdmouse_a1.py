# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
# Dev test input: after 3 s, holds the right mouse button (gun mode's aim) for 12 s; the left button (fire) is held
# from +6 s to +9 s. Plain SendInput, no installs. Report NikkeGunBuild\holdmouse.txt.
import ctypes, time, os
B = os.path.join(os.path.expanduser("~"), r"Downloads\Modding Tools\NikkeGunBuild")
rep = open(os.path.join(B, "holdmouse.txt"), "w")
def P(s): rep.write(time.strftime("%H:%M:%S ") + s + "\n"); rep.flush()
U = ctypes.windll.user32
RD, RU, LD, LU = 0x0008, 0x0010, 0x0002, 0x0004
def ev(f): U.mouse_event(f, 0, 0, 0, 0)
try:
    time.sleep(3); ev(RD); P("RMB down")
    time.sleep(3); ev(LD); P("LMB down")
    time.sleep(3); ev(LU); P("LMB up")
    time.sleep(6); ev(RU); P("RMB up")
finally:
    ev(LU); ev(RU); P("FINISHED"); rep.close()
