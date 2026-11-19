# Dev test input: holds the right mouse button (aim) for 12 s and pitches the camera: up, down past centre, back.
import ctypes, time, os
B = os.path.join(os.path.expanduser("~"), r"Downloads\Modding Tools\NikkeGunBuild")
rep = open(os.path.join(B, "holdpitch.txt"), "w")
def P(s): rep.write(time.strftime("%H:%M:%S ") + s + "\n"); rep.flush()
U = ctypes.windll.user32
def move(dy, n=30):
    for i in range(n): U.mouse_event(0x0001, 0, int(dy / n), 0, 0); time.sleep(0.02)
try:
    time.sleep(2); U.mouse_event(0x0008, 0, 0, 0, 0); P("RMB down")
    time.sleep(2.5); move(-1600); P("pitched up"); time.sleep(2.5)
    move(3200); P("pitched down"); time.sleep(2.5)
    move(-1600); P("centre"); time.sleep(1.5)
finally:
    U.mouse_event(0x0010, 0, 0, 0, 0); P("RMB up"); P("FINISHED"); rep.close()
