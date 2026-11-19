# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
# Phase 1 spike pak: cook SBOutfitProject, stage /Game/Mods/NGM/ABP_NGM_Spike, retoc to-zen -> zNGMSpike_P, install into
# ~mods (only if the game is closed). Report NikkeGunBuild\spike_build.txt (ends FINISHED; SPIKE OK on success).
import os, glob, shutil, subprocess, time
HOME = os.path.expanduser("~"); T = os.path.join(HOME, r"Downloads\Modding Tools")
OW = os.path.join(T, "OutfitWork"); B = os.path.join(T, "NikkeGunBuild")
UE = r"C:\Program Files\Epic Games\UE_4.26\Engine\Binaries\Win64\UE4Editor-Cmd.exe"
UP = os.path.join(T, "SBOutfitProject", "SB.uproject")
RETOC = os.path.join(T, r"retoc_cli-x86_64-pc-windows-msvc\retoc.exe")
MODS = r"C:\Program Files (x86)\Steam\steamapps\common\StellarBlade\SB\Content\Paks\~mods"
NAME = os.environ.get("NGM_PAK", "zNGMSpike_P"); REL = os.environ.get("NGM_REL", "Mods/NGM")
W = os.path.join(B, "spike"); os.makedirs(W, exist_ok=True)
rep = open(os.path.join(B, "spike_build.txt"), "w")
def P(s): rep.write(time.strftime("%H:%M:%S ") + str(s) + "\n"); rep.flush()
def run(a, name, timeout=3600):
    with open(os.path.join(W, name + "_out.txt"), "w", errors="replace") as f:
        r = subprocess.run(a, stdout=f, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, timeout=timeout, creationflags=0x08000000)
    P("> %s rc=%s" % (name, r.returncode)); return r.returncode
try:
    CK = os.path.join(W, "cook_" + time.strftime("%m%d_%H%M%S"))
    run([UE, UP, "-run=cook", "-targetplatform=WindowsNoEditor", "-unversioned", "-unattended", "-nopause", "-stdout", "-NoSound",
         "-CookAll", "-OutputDir=" + CK], "cook")
    src = next((r for r, d, f in os.walk(CK) if r.replace("\\", "/").endswith("Content/" + REL)), None)
    if not src: raise Exception("no %s in the cook output %s" % (REL, CK))
    stage = os.path.join(W, "stage")
    if os.path.exists(stage): shutil.rmtree(stage)
    dst = os.path.join(stage, "SB", "Content", *REL.split("/")); shutil.copytree(src, dst)
    P("staged %s" % sorted(os.listdir(dst)))
    pk = os.path.join(W, "pak"); os.makedirs(pk, exist_ok=True)
    for f in glob.glob(os.path.join(pk, "*")): os.remove(f)
    rc = run([RETOC, "to-zen", stage, os.path.join(pk, NAME + ".utoc"), "--version", "UE4_26"], "retoc_zen", timeout=1800)
    outs = {f: os.path.getsize(os.path.join(pk, f)) for f in sorted(os.listdir(pk))}
    P("pak %s rc %s" % (outs, rc))
    if rc != 0 or not any(f.endswith(".utoc") for f in outs): raise Exception("to-zen failed")
    tl = subprocess.run(["tasklist"], capture_output=True, text=True, creationflags=0x08000000).stdout.lower()
    if "sb-win64-shipping" in tl: P("game running: not installed")
    else:
        for f in outs: shutil.copyfile(os.path.join(pk, f), os.path.join(MODS, f)); P("installed %s" % f)
    P("SPIKE OK")
except Exception:
    import traceback; P("ERROR " + traceback.format_exc())
P("FINISHED"); rep.close()
