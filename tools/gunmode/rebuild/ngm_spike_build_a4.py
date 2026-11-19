# Rifle layer pak: cook SBOutfitProject, stage /Game/Mods/NGM (the layer) and CH_P_EVE_01/Animation/NGM (the rifle clips), retoc to-zen -> zNGMSpike_P, install into a
# ~mods subfolder (NGM_SUB; only if the game is closed). Report NikkeGunBuild\spike_build.txt (ends FINISHED; SPIKE OK on success).
import os, glob, shutil, subprocess, time
HOME = os.path.expanduser("~"); T = os.path.join(HOME, r"Downloads\Modding Tools")
OW = os.path.join(T, "OutfitWork"); B = os.path.join(T, "NikkeGunBuild")
UE = r"C:\Program Files\Epic Games\UE_4.26\Engine\Binaries\Win64\UE4Editor-Cmd.exe"
UP = os.path.join(T, "SBOutfitProject", "SB.uproject")
RETOC = os.path.join(T, r"retoc_cli-x86_64-pc-windows-msvc\retoc.exe")
MODS = os.path.join(r"C:\Program Files (x86)\Steam\steamapps\common\StellarBlade\SB\Content\Paks\~mods", os.environ.get("NGM_SUB", "NikkeGunModeSpike"))
NAME = os.environ.get("NGM_PAK", "zNGMSpike_P"); RELS = os.environ.get("NGM_REL", "Mods/NGM").split(";")
W = os.path.join(B, "spike"); os.makedirs(W, exist_ok=True); os.makedirs(MODS, exist_ok=True)
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
    stage = os.path.join(W, "stage")
    if os.path.exists(stage): shutil.rmtree(stage)
    for REL in RELS:
        src = next((r for r, d, f in os.walk(CK) if r.replace("\\", "/").endswith("Content/" + REL)), None)
        if not src: raise Exception("no %s in the cook output %s" % (REL, CK))
        dst = os.path.join(stage, "SB", "Content", *REL.split("/")); shutil.copytree(src, dst)
        P("staged %s: %d files" % (REL, len(os.listdir(dst))))
    pk = os.path.join(W, "pak"); os.makedirs(pk, exist_ok=True)
    for f in glob.glob(os.path.join(pk, "*")): os.remove(f)
    rc = run([RETOC, "to-zen", stage, os.path.join(pk, NAME + ".utoc"), "--version", "UE4_26"], "retoc_zen", timeout=1800)
    outs = {f: os.path.getsize(os.path.join(pk, f)) for f in sorted(os.listdir(pk))}
    P("pak %s rc %s" % (outs, rc))
    if rc != 0 or not any(f.endswith(".utoc") for f in outs): raise Exception("to-zen failed")
    tl = subprocess.run(["tasklist"], capture_output=True, text=True, creationflags=0x08000000).stdout.lower()
    if "sb-win64-shipping" in tl: P("game running: not installed")
    else:
        root = os.path.dirname(MODS)
        for f in outs:
            if os.path.exists(os.path.join(root, f)): os.remove(os.path.join(root, f)); P("removed stale root %s" % f)
            shutil.copyfile(os.path.join(pk, f), os.path.join(MODS, f)); P("installed %s" % os.path.join(MODS, f))
    P("SPIKE OK")
except Exception:
    import traceback; P("ERROR " + traceback.format_exc())
P("FINISHED"); rep.close()
