# Dev test input: turns the game camera by moving the mouse sideways (SendInput relative moves), NGM_DX px in total
# (read from camturn_dx.txt next to this script, default 600), over about a second.
import ctypes, time, os
here = os.path.dirname(os.path.abspath(__file__))
try: dx = int(open(os.path.join(here, "camturn_dx.txt")).read().strip())
except Exception: dx = 600
U = ctypes.windll.user32
steps = 40
for i in range(steps):
    U.mouse_event(0x0001, int(dx / steps), 0, 0, 0); time.sleep(0.025)
