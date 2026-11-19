# After a game crash: copy the newest crash folder's log into NikkeGunBuild\crash_spike.txt, then end the crash handler
# without reporting (same as "Don't report") and confirm the game is gone.
import os, subprocess, time, glob
HOME = os.path.expanduser("~"); B = os.path.join(HOME, r"Downloads\Modding Tools\NikkeGunBuild")
o = open(os.path.join(B, "crash_spike.txt"), "w")
C = os.path.join(HOME, r"AppData\Local\SB\Saved\Crashes")
ds = sorted(glob.glob(os.path.join(C, "*")), key=os.path.getmtime)[-1:]
for d in ds:
    o.write("CRASH %s %s\n" % (time.strftime("%H:%M:%S", time.localtime(os.path.getmtime(d))), os.path.basename(d)))
    for lg in glob.glob(os.path.join(d, "*.log")):
        t = open(lg, errors="replace").read(); i = t.find("Fatal error")
        o.write(t[max(0, i - 300):i + 4000] if i >= 0 else t[-4000:])
for n in ("crs-handler.exe", "crs-uploader.exe", "CrashReportClient.exe", "SB-Win64-Shipping.exe"):
    r = subprocess.run(["taskkill", "/IM", n, "/F"], capture_output=True, text=True, creationflags=0x08000000); o.write("kill %s: %s\n" % (n, r.stdout.strip()[:80]))
time.sleep(3)
tl = subprocess.run(["tasklist"], capture_output=True, text=True, creationflags=0x08000000).stdout.lower()
o.write("game running %s, crs %s\nFINISHED\n" % ("sb-win64-shipping" in tl, "crs-handler" in tl)); o.close()
