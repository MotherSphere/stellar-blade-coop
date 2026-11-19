# Bring the UE 4.26 editor window to the front, moved onto a non-primary monitor (SteamVR's window sits on the primary)
# and maximized there. Arg-free; writes NikkeGunBuild\focus_ue.txt with the monitors seen.
import ctypes, ctypes.wintypes as W, os, subprocess, sys
B = os.path.join(os.path.expanduser("~"), r"Downloads\Modding Tools\NikkeGunBuild")
u = ctypes.windll.user32
out = open(os.path.join(B, "focus_ue.txt"), "w")
mons = []
class MI(ctypes.Structure): _fields_ = [("cbSize", W.DWORD), ("rcMonitor", W.RECT), ("rcWork", W.RECT), ("dwFlags", W.DWORD)]
def mcb(hm, hdc, rc, lp):
    mi = MI(); mi.cbSize = ctypes.sizeof(MI); u.GetMonitorInfoW(hm, ctypes.byref(mi))
    r = mi.rcWork; mons.append((r.left, r.top, r.right, r.bottom, bool(mi.dwFlags & 1))); return True
u.EnumDisplayMonitors(0, 0, ctypes.WINFUNCTYPE(ctypes.c_bool, W.HMONITOR, W.HDC, ctypes.POINTER(W.RECT), W.LPARAM)(mcb), 0)
out.write("monitors %s\n" % mons)
pids = set()
for l in subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True, creationflags=0x08000000).stdout.splitlines():
    p = l.strip('"').split('","')
    if p and p[0].lower() == "ue4editor.exe": pids.add(int(p[1]))
found = []
def cb(h, _):
    pid = W.DWORD(); u.GetWindowThreadProcessId(h, ctypes.byref(pid))
    if pid.value in pids and u.IsWindowVisible(h):
        n = ctypes.create_unicode_buffer(256); u.GetWindowTextW(h, n, 256)
        r = W.RECT(); u.GetWindowRect(h, ctypes.byref(r))
        found.append((h, n.value, (r.left, r.top, r.right, r.bottom)))
    return True
u.EnumWindows(ctypes.WINFUNCTYPE(ctypes.c_bool, W.HWND, W.LPARAM)(cb), 0)
out.write("windows %s\n" % [(f[1], f[2]) for f in found])
target = [m for m in mons if not m[4]]
target = sorted(target, key=lambda m: m[0])[int(os.environ.get("NGM_MON", "-1"))] if target else None
pref = [f for f in found if os.environ.get("NGM_WIN", "ABP_") in f[1]]
main = (pref or [max(found, key=lambda f: (f[2][2] - f[2][0]) * (f[2][3] - f[2][1]))])[0] if found else None
if main and target:
    h = main[0]
    u.ShowWindow(h, 9)
    u.SetWindowPos(h, 0, target[0], target[1], target[2] - target[0], target[3] - target[1], 0x0040)
    u.ShowWindow(h, 3)
    u.keybd_event(0x12, 0, 0, 0); u.keybd_event(0x12, 0, 2, 0)
    out.write("moved %r to %s, foreground %s\n" % (main[1], target, bool(u.SetForegroundWindow(h))))
out.close()
