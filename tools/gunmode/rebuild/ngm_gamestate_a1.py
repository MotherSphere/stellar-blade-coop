# Reports whether the game and the crash handler are running and whether the game's window is hung (IsHungAppWindow).
import ctypes, subprocess, os, time
B = os.path.join(os.path.expanduser("~"), r"Downloads\Modding Tools\NikkeGunBuild")
out = []
tl = subprocess.run(["tasklist", "/v", "/fo", "csv"], capture_output=True, text=True, creationflags=0x08000000).stdout
for l in tl.splitlines():
    if any(k in l.lower() for k in ("sb-win64", "crs-", "werfault")): out.append(l)
U = ctypes.windll.user32
res = []
@ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
def cb(h, _):
    n = ctypes.create_unicode_buffer(256); U.GetWindowTextW(h, n, 256)
    if U.IsWindowVisible(h) and n.value: res.append("%s hung=%s" % (n.value, U.IsHungAppWindow(h)))
    return True
U.EnumWindows(cb, 0)
open(os.path.join(B, "gamestate.txt"), "w").write(time.strftime("%H:%M:%S\n") + "\n".join(out) + "\n--\n" + "\n".join(res))
