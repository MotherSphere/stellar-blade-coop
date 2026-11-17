# ngm_bl_mixamo_stand.py - Blender 5.2 background. Standing gun set, take 4 (11-17): the Mixamo "Rifle 8-Way Locomotion
# Pack" retargeted onto Eve (UE Format body, Bip001 skeleton). Take 3 (drone legs + NIKKE kneel-cover arms) looked
# scrunched in game.
# Retarget: world-space rotation deltas. For each mapped bone, target_world(t) = D(t) @ calib, D(t) = src_world(t) @
# src_rest^-1, calib = Eve's rest bone swung so its direction matches the Mixamo rest bone's direction (T-pose vs Eve's
# bind pose). Positions come from Eve's own bone lengths (FK done here in Python), hips height scaled by the leg-height ratio,
# the clip's forward travel removed (in place; the game moves the actor).
# Gun props: kept on the right hand as in the NIKKE pose, then turned so the barrel runs right hand -> left hand (the
# Mixamo support hand sits on the handguard).
# Output: NikkeGunBuild\blend\stand4\ (NGM_Stand4.blend, previews, build_log.txt). Same action names as take 3.
import bpy, os, math, importlib
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector
HOME = os.path.expanduser("~")
B = os.path.join(os.environ.get("NGM_TOOLS", os.path.join(HOME, r"Downloads\Modding Tools")), "NikkeGunBuild")
A = os.path.join(B, "anim_export")
MX = os.path.join(B, "mixamo", "src")
OUT = os.path.join(B, "blend", "stand4"); os.makedirs(OUT, exist_ok=True)
log = open(os.path.join(OUT, "build_log.txt"), "w")
def L(*a): log.write(" ".join(str(x) for x in a) + "\n"); log.flush()
CLIPS = {"NGM_Stand_Idle": "idle aiming", "NGM_Stand_WalkF": "walk forward", "NGM_Stand_WalkB": "walk backward",
         "NGM_Stand_WalkL": "walk left", "NGM_Stand_WalkR": "walk right", "NGM_Stand_WalkFR": "walk forward right",
         "NGM_Stand_WalkBL": "walk backward left", "NGM_Stand_WalkFL": "walk forward left", "NGM_Stand_WalkBR": "walk backward right"}
SHOOT_FRAMES = 15
P = "mixamorig:"
MAP = {"Hips": "Bip001-Pelvis", "Spine": "Bip001-Spine", "Spine1": "Bip001-Spine1", "Spine2": "Bip001-Spine2",
       "Neck": "Bip001-Neck", "Head": "Bip001-Head"}
for s, t in (("Left", "L"), ("Right", "R")):
    MAP.update({s + "Shoulder": "Bip001-%s-Clavicle" % t, s + "Arm": "Bip001-%s-UpperArm" % t, s + "ForeArm": "Bip001-%s-Forearm" % t,
                s + "Hand": "Bip001-%s-Hand" % t, s + "UpLeg": "Bip001-%s-Thigh" % t, s + "Leg": "Bip001-%s-Calf" % t,
                s + "Foot": "Bip001-%s-Foot" % t, s + "ToeBase": "Bip001-%s-Toe0" % t})
    for i, fn in enumerate(("Thumb", "Index", "Middle", "Ring", "Pinky")):
        for k, suf in enumerate(("", "1", "2")):
            MAP[s + "Hand%s%d" % (fn, k + 1)] = "Bip001-%s-Finger%d%s" % (t, i, suf)
# direction used for calibration: bone -> this child (both skeletons); bones not listed keep the swing of AIM_FROM
AIM = {"Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head"}
AIM_FROM = {}
for s in ("Left", "Right"):
    AIM.update({s + "Shoulder": s + "Arm", s + "Arm": s + "ForeArm", s + "ForeArm": s + "Hand", s + "Hand": s + "HandMiddle1",
                s + "UpLeg": s + "Leg", s + "Leg": s + "Foot", s + "Foot": s + "ToeBase"})
    for fn in ("Thumb", "Index", "Middle", "Ring", "Pinky"):
        AIM[s + "Hand%s1" % fn] = s + "Hand%s2" % fn; AIM[s + "Hand%s2" % fn] = s + "Hand%s3" % fn
        AIM_FROM[s + "Hand%s3" % fn] = s + "Hand%s2" % fn
    AIM_FROM[s + "ToeBase"] = s + "Foot"
def r3(m): return m.to_3x3().normalized()
try:
    import addon_utils
    mod = None
    for m in addon_utils.modules():
        if m.__name__.endswith("io_scene_ueformat"): mod = m.__name__; addon_utils.enable(mod, default_set=False)
    ctx = importlib.import_module(mod + ".importer.import_context"); opts = importlib.import_module(mod + ".options")
    for o in list(bpy.data.objects): bpy.data.objects.remove(o)
    try: mo = opts.UEModelOptions(import_sockets=False)
    except TypeError: mo = opts.UEModelOptions(); mo.import_sockets = False
    ctx.UEFormatImport(mo).import_file(Path(os.path.join(A, "CH_P_EVE_01_Body.uemodel")))
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    eve_objs = set(bpy.data.objects)
    scn = bpy.context.scene; vl = bpy.context.view_layer; scn.render.fps = 30
    if arm.animation_data is None: arm.animation_data_create()
    PB = arm.pose.bones; BN = arm.data.bones
    for p_ in PB: p_.rotation_mode = "QUATERNION"
    mwT = arm.matrix_world.copy(); RT = r3(mwT); sT = mwT.to_scale()[0]
    def tw(n): return mwT @ BN[n].matrix_local   # Eve rest, world
    # --- NIKKE reference for the props (gun on the right hand) ---
    def load_ue(name):
        before = set(bpy.data.actions.keys())
        ctx.UEFormatImport(opts.UEAnimOptions(override_skeleton=arm)).import_file(Path(os.path.join(A, name + ".ueanim")))
        return bpy.data.actions[[a for a in bpy.data.actions.keys() if a not in before][0]]
    def use(act):
        arm.animation_data.action = act
        try:
            if act and act.slots: arm.animation_data.action_slot = act.slots[0]
        except Exception: pass
    hand_r, hand_l = "Bip001-R-Hand", "Bip001-L-Hand"
    props = [n for n in ("Bip001-Prop1", "Bip001-Prop2") if n in PB]
    # v8: the grip reference is the NIKKE SHOT (rifle aimed level with both hands), not the cover idle (rifle held upright,
    # which put the gun vertical in game, 11-17 13:52)
    nik = load_ue(os.environ.get("NGM_GRIP_SRC", "P_Eve_GunNikke_Shoot")); use(nik); scn.frame_set(int(os.environ.get("NGM_GRIP_FRAME", "3")))
    NM = {n: p.matrix.copy() for n, p in PB.items()}   # armature space
    prop_rel = {pn: NM[hand_r].inverted() @ NM[pn] for pn in props}
    cr = NM["Bip001-R-Clavicle"].translation - NM["Bip001-L-Clavicle"].translation; cr.z = 0; cr.normalize()
    cf = Vector((0, 0, 1)).cross(cr)          # NIKKE aim (chest forward), armature space
    g0 = r3(NM[props[0]]); axes = [(s * g0.col[i], i, s) for i in range(3) for s in (1, -1)]
    barrel = max(axes, key=lambda a: a[0].dot(cf)); gup = max(axes, key=lambda a: a[0].dot(Vector((0, 0, 1))))
    L("props", props, "barrel axis", "+-"[barrel[2] < 0] + "XYZ"[barrel[1]], "dot %.2f" % barrel[0].dot(cf),
      "up axis", "+-"[gup[2] < 0] + "XYZ"[gup[1]], "dot %.2f" % gup[0].dot(Vector((0, 0, 1))))
    BAX = Vector([0, 0, 0]); BAX[barrel[1]] = barrel[2]
    GUP = Vector([0, 0, 0]); GUP[gup[1]] = gup[2]
    P12 = (NM[props[0]].inverted() @ NM[props[1]]) if len(props) > 1 else None
    # v10: the rifle mesh rides on SC_WeaponConstraint (child of R-Hand) - the helper copy gave it the drone walks' upright
    # weapon mount (vertical rifle in game). Placed from the NIKKE shot relative to the gun frame instead.
    WPN = "SC_WeaponConstraint" if "SC_WeaponConstraint" in PB else None
    WPN_REL = (NM[props[0]].inverted() @ NM[WPN]) if WPN else None
    use(None)
    for p_ in PB: p_.matrix_basis = Matrix.Identity(4)
    # --- hierarchy (Eve) ---
    order = []
    def walk(b):
        order.append(b.name)
        for c in b.children: walk(c)
    for b in BN:
        if b.parent is None: walk(b)
    inv_map = {v: k for k, v in MAP.items()}
    VAN = {"NGM_Stand_Idle": "P_Eve_Gun_Normal_Idle", "NGM_Stand_WalkF": "P_Eve_Gun_WalkFw", "NGM_Stand_WalkB": "P_Eve_Gun_WalkBw",
           "NGM_Stand_WalkL": "P_Eve_Gun_WalkLw", "NGM_Stand_WalkR": "P_Eve_Gun_WalkRw", "NGM_Stand_WalkFR": "P_Eve_Gun_WalkFRw",
           "NGM_Stand_WalkBL": "P_Eve_Gun_WalkBLw", "NGM_Stand_WalkFL": "P_Eve_Gun_WalkFLw", "NGM_Stand_WalkBR": "P_Eve_Gun_WalkBRw"}
    skip = set(MAP.values()) | {"Root", "Bip001", "Bip001-Footsteps"}
    for pn in props:
        skip.add(pn)
        for c in BN[pn].children_recursive: skip.add(c.name)
    HELPERS = [n for n in order if n not in skip and "Finger" not in n and n != "SC_WeaponConstraint"]
    L("helper bones copied from the game's gun walks:", len(HELPERS))
    def van_frames(src):
        if not os.path.exists(os.path.join(A, src + ".ueanim")): L("missing vanilla", src); return None
        act = load_ue(src); use(act); n = int(act.frame_range[1]); out = []
        for f in range(n + 1):
            scn.frame_set(f); d = {h: PB[h].matrix_basis.copy() for h in HELPERS}
            d["_pelvis"] = r3(PB["Bip001-Pelvis"].matrix); d["_ppos"] = PB["Bip001-Pelvis"].matrix.translation.copy()
            d["_legs"] = {n: r3(PB[n].matrix) for n in LEGS_V}
            d["_thR"], d["_thL"] = PB["Bip001-R-Thigh"].head.copy(), PB["Bip001-L-Thigh"].head.copy()
            out.append(d)
        r = out[0]["_thR"] - out[0]["_thL"]; r.z = 0; r.normalize()
        vf = r.cross(Vector((0, 0, 1)))                    # same (backward) convention as make_calib
        ef = RT.inverted() @ calib["eve_fwd"]; ef.z = 0; ef.normalize()
        yv = math.atan2(ef.y, ef.x) - math.atan2(vf.y, vf.x)
        global VAN_YAW
        if VAN_YAW is None: VAN_YAW = round(yv / (math.pi / 2)) * (math.pi / 2); L("  vanilla yaw fixed at %.0f deg (measured %.1f)" % (math.degrees(VAN_YAW), math.degrees(yv)))
        yv = VAN_YAW
        for d in out: d["_yv"] = Matrix.Rotation(yv, 3, "Z")
        L("  vanilla facing yaw correction %.1f deg" % math.degrees(yv))
        use(None)
        for p_ in PB: p_.matrix_basis = Matrix.Identity(4)
        # which helpers really move (diagnostic)
        mv = []
        for h in HELPERS:
            a = max(out[0][h].to_quaternion().rotation_difference(o[h].to_quaternion()).angle for o in out)
            r = max(o[h].to_quaternion().angle for o in out)
            if r > math.radians(3): mv.append("%s(%.0f/%.0f)" % (h, math.degrees(r), math.degrees(a)))
        L("  vanilla", src, "frames", n + 1, "helpers off rest:", " ".join(mv[:40]))
        return out
    # --- per clip ---
    def import_mx(name):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=os.path.join(MX, name + ".fbx"), automatic_bone_orientation=False)
        new = [o for o in bpy.data.objects if o not in before]
        return [o for o in new if o.type == "ARMATURE"][0], new
    calib = None; RIGHT_A = None
    def make_calib(sarm):
        mwS = sarm.matrix_world; SB = sarm.data.bones
        sw = lambda n: mwS @ SB[P + n].matrix_local
        # facing correction src -> Eve (yaw), from the thighs
        def fwd(mL, mR):
            r = mR - mL; r.z = 0; r.normalize(); return r.cross(Vector((0, 0, 1)))
        fs = fwd(sw("LeftUpLeg").translation, sw("RightUpLeg").translation)
        ft = fwd(tw("Bip001-L-Thigh").translation, tw("Bip001-R-Thigh").translation)
        yaw = math.atan2(ft.y, ft.x) - math.atan2(fs.y, fs.x)
        Y = Matrix.Rotation(yaw, 3, "Z")
        c = {}
        for s, t in MAP.items():
            if t not in BN: continue
            trest = r3(tw(t))
            src = AIM.get(s); frm = s
            if src is None and s in AIM_FROM: frm = AIM_FROM[s]; src = AIM[frm]
            if src is None or MAP.get(src) not in BN: c[s] = trest; continue
            ds = Y @ (sw(src).translation - sw(frm).translation).normalized()
            dt = (tw(MAP[src]).translation - tw(MAP[frm]).translation).normalized()
            q = dt.rotation_difference(ds).to_matrix()
            c[s] = q @ trest
        hs = sw("Hips").translation.z; ht = tw("Bip001-Pelvis").translation.z
        L("calib: yaw src->eve %.1f deg, src fwd %s, eve fwd %s, hips %.3f / %.3f -> ratio %.3f" % (math.degrees(yaw), tuple(round(x, 2) for x in fs), tuple(round(x, 2) for x in ft), hs, ht, ht / hs))
        return {"rot": c, "Y": Y, "ratio": ht / hs, "eve_fwd": ft}
    PELVIS_VAN = os.environ.get("NGM_PELVIS_SRC", "vanilla") == "vanilla"
    LEGS_VAN = os.environ.get("NGM_LEGS_SRC", "vanilla") == "vanilla"     # Eve's own legs (feminine walk) from the game's gun walks
    LEGS_V = ["Bip001-L-Thigh","Bip001-L-Calf","Bip001-L-Foot","Bip001-L-Toe0","Bip001-R-Thigh","Bip001-R-Calf","Bip001-R-Foot","Bip001-R-Toe0"]
    VAN_YAW = None
    TWIST_PELVIS = float(os.environ.get("NGM_TWIST_PELVIS", "0.3"))
    AIM_FIX = os.environ.get("NGM_AIM_FIX", "1") == "1"   # rifle exactly forward + level in every clip   # share of the hip->chest twist the pelvis+legs take
    SPINE_CHAIN = ["Bip001-Spine", "Bip001-Spine1", "Bip001-Spine2"]
    TILT = math.radians(float(os.environ.get("NGM_PELVIS_TILT", "0" if PELVIS_VAN else "14")))   # anterior pelvic tilt (feminine hips; X Bot is tucked)
    RAISE = float(os.environ.get("NGM_HIP_RAISE", "0.5"))     # part of the clip's crouch removed (legs IK'd, feet stay)
    NARROW = float(os.environ.get("NGM_NARROW", "0.3"))       # feet pulled this part of the way to the centre line
    def fk(fw, rec, raise_a, over):
        Y = calib["Y"]; ratio = calib["ratio"]; des = {}; hrest = fw["_hips_rest"]; vb = fw.get("_van")
        for n in order:
            b = BN[n]
            rest_rel = (b.parent.matrix_local.inverted() @ b.matrix_local) if b.parent else b.matrix_local
            par = des[b.parent.name] if b.parent else Matrix.Identity(4)
            m = par @ rest_rel
            s = inv_map.get(n)
            if n in over:
                m = Matrix.Translation(m.translation) @ over[n].to_4x4()
            elif vb is not None and LEGS_VAN and n in vb["_legs"]:
                m = Matrix.Translation(m.translation) @ (vb["_yv"] @ vb["_legs"][n]).to_4x4()
            elif vb is not None and n in HELPERS:
                m = m @ vb[n]          # corrective / helper bone: the game's own local motion (glutes, twist, cloth)
            elif s and s in fw:
                srot, _ = fw[s]; srest = fw["_rest"][s]
                D = Y @ (srot @ srest.inverted()) @ Y.inverted()          # world delta, Eve facing
                wrot = D @ calib["rot"][s]
                if rec and n in rec: wrot = rec[n] @ wrot
                arot = RT.inverted() @ wrot
                m = Matrix.Translation(m.translation) @ arot.to_4x4()
                if s == "Hips":
                    if vb is not None and PELVIS_VAN:
                        arot = vb["_yv"] @ vb["_pelvis"]      # Eve's own pelvis (the game's gun walk), facing-aligned
                    arot = Matrix.Rotation(-TILT, 3, RIGHT_A) @ arot
                    if "_pelvis_pre" in over: arot = over["_pelvis_pre"] @ arot
                    off = Y @ (fw["Hips"][1] - hrest) * ratio
                    pos = (mwT.inverted() @ (tw(n).translation + off)) + raise_a
                    if vb is not None and LEGS_VAN:
                        pos = Vector((pos.x, pos.y, (vb["_yv"] @ vb["_ppos"]).z))   # her own hip height / bob (legs are hers)
                    m = Matrix.Translation(pos) @ arot.to_4x4()
            des[n] = m
        return des
    def yaw_of(R, n):   # yaw (deg) of the bone's rest->now turn applied to the character forward, armature space
        tf = RT.inverted() @ (-calib["eve_fwd"]); tf.z = 0; tf.normalize()
        v = R @ r3(BN[n].matrix_local).inverted() @ tf; return math.degrees(math.atan2(v.y, v.x))
    GRIP_HAND = os.environ.get("NGM_GRIP_HAND", "1") == "1"
    HAND_SUB = ["Bip001-R-Hand"]
    def _hs(b):
        for c in b.children:
            if c.name not in props: HAND_SUB.append(c.name)
            _hs(c)
    _hs(BN["Bip001-R-Hand"])
    CHEST_SUB = []
    def _sub(b):
        for c in b.children:
            if c.name in inv_map: CHEST_SUB.append(c.name)
            _sub(c)
    CHEST_SUB.append("Bip001-Spine2"); _sub(BN["Bip001-Spine2"])
    def untwist(fw, rec, raise_a, over, des):
        """1) aim fix: turn the chest and everything above it so the rifle (right hand -> left hand) points exactly at the
        character's forward, level - the same upper body in every clip; 2) spread the remaining pelvis->chest yaw:
        pelvis+legs take TWIST_PELVIS, Spine/Spine1 ramp up to the chest."""
        if fw.get("_van") is None: return des, 0.0
        tf = RT.inverted() @ (-calib["eve_fwd"]); tf.z = 0; tf.normalize()
        b = (des[hand_l].translation - des[hand_r].translation).normalized()
        rfix = b.rotation_difference(tf).to_matrix() if AIM_FIX else Matrix.Identity(3)
        o1 = dict(over)
        for n in CHEST_SUB: o1[n] = rfix @ r3(des[n])
        des = fk(fw, rec, raise_a, o1)
        d = (yaw_of(r3(des["Bip001-Spine2"]), "Bip001-Spine2") - yaw_of(r3(des["Bip001-Pelvis"]), "Bip001-Pelvis") + 540) % 360 - 180
        zp = Matrix.Rotation(math.radians(d * TWIST_PELVIS), 3, "Z")
        o2 = dict(o1)
        o2["_pelvis_pre"] = zp
        for n in LEGS_V: o2[n] = zp @ (o2[n] if n in o2 else r3(des[n]))
        rest = d * (1 - TWIST_PELVIS)
        for i, n in enumerate(SPINE_CHAIN[:2]):
            o2[n] = Matrix.Rotation(math.radians(-rest * (2 - i) / 3.0), 3, "Z") @ r3(des[n])
        return fk(fw, rec, raise_a, o2), d
    def leg_ik(dA, dB, side):
        th, ca, fo = "Bip001-%s-Thigh" % side, "Bip001-%s-Calf" % side, "Bip001-%s-Foot" % side
        a = (dA[ca].translation - dA[th].translation).length; b = (dA[fo].translation - dA[ca].translation).length
        F = dA[fo].translation.copy(); P0 = dA["Bip001-Pelvis"].translation
        F -= RIGHT_A * ((F - P0).dot(RIGHT_A) * NARROW)
        H2, K1, FB = dB[th].translation, dB[ca].translation, dB[fo].translation
        v = F - H2; d = max(abs(a - b) + 1e-4, min(v.length, 0.999 * (a + b))); u = v.normalized()
        pole = K1 - H2; pp = (pole - u * pole.dot(u)).normalized()
        x = (a * a - b * b + d * d) / (2 * d); h = math.sqrt(max(0.0, a * a - x * x))
        K2 = H2 + u * x + pp * h; F2 = H2 + u * d
        q1 = (K1 - H2).normalized().rotation_difference((K2 - H2).normalized()).to_matrix()
        q2 = (q1 @ (FB - K1)).normalized().rotation_difference((F2 - K2).normalized()).to_matrix()
        return {th: q1 @ r3(dB[th]), ca: q2 @ q1 @ r3(dB[ca])}
    def subtree(n):
        out = [n]
        for c in BN[n].children_recursive: out.append(c.name)
        return out
    SUBS = {}
    def post_rot(des, specs):
        """rotate each listed bone's whole subtree about that bone (armature space); the gun props (children of Bip001)
        ride with Spine2. Specs are applied in order, so Spine, Spine1, Spine2 steps accumulate up the chain."""
        for bn, axis, ang in specs:
            if bn not in SUBS:
                SUBS[bn] = subtree(bn) + (props if bn in ("Bip001-Spine", "Bip001-Spine1", "Bip001-Spine2") else [])
            pv = des[bn].translation.copy()
            m = Matrix.Translation(pv) @ Matrix.Rotation(ang, 4, axis) @ Matrix.Translation(-pv)
            for n in SUBS[bn]: des[n] = m @ des[n]
        return des
    def aim_specs(pitch, yaw):
        """aim offset pose: pitch about the character's right axis, yaw about up, spread evenly over Spine/Spine1/Spine2"""
        sp = []
        for n in ("Bip001-Spine", "Bip001-Spine1", "Bip001-Spine2"):
            if yaw: sp.append((n, Vector((0, 0, 1)), yaw / 3.0))
            if pitch: sp.append((n, RIGHT_A, pitch / 3.0))
        return sp
    def bake(name, frames_world, recoil=None, raise_w=0.0, post=None):
        """frames_world: list of dicts src bone -> (world rot 3x3, world pos) incl. Hips pos (already in place)."""
        act = bpy.data.actions.new(name)
        arm.animation_data.action = act
        try: arm.animation_data.action_slot = act.slots.new(id_type="OBJECT", name="Slot_" + arm.name)
        except Exception: pass
        raise_a = RT.inverted() @ Vector((0, 0, raise_w)) / sT
        for fi, fw in enumerate(frames_world):
            rec = recoil[fi] if recoil else None
            dA = fk(fw, rec, Vector((0, 0, 0)), {})
            dB = fk(fw, rec, raise_a, {})
            over = {}
            if not (LEGS_VAN and fw.get("_van") is not None):
                over.update(leg_ik(dA, dB, "L")); over.update(leg_ik(dA, dB, "R"))
            des = fk(fw, rec, raise_a, over)
            if TWIST_PELVIS < 1.0:
                des, tw_d = untwist(fw, rec, raise_a, over, des)
                if fi == 0: L("  %s hip->chest twist %.1f deg (pelvis+legs take %.0f%%)" % (name, tw_d, TWIST_PELVIS * 100))
            # props: hand-attached (NIKKE grip), barrel turned to right hand -> left hand
            if props:
                hr = des[hand_r]; hl = des[hand_l]
                p0 = hr @ prop_rel[props[0]]                       # grip point from the NIKKE shot
                tf = RT.inverted() @ (-calib["eve_fwd"]); tf.z = 0; tf.normalize()
                want = tf if AIM_FIX else (hl.translation - hr.translation).normalized()
                up = Vector((0, 0, 1)); up = (up - want * up.dot(want)).normalized()
                Sm = Matrix((BAX, GUP, BAX.cross(GUP))).transposed()   # columns: local barrel / top / side
                Dm = Matrix((want, up, want.cross(up))).transposed()
                g = (Dm @ Sm.transposed()).to_4x4(); g.translation = p0.translation
                # v9: the rifle mesh rides on the RIGHT HAND (the props alone left it vertical in game, 13:52): turn the
                # hand (and its fingers) about the wrist so hand->gun is the NIKKE shot's grip with the gun at g
                if GRIP_HAND:
                    hn = g @ prop_rel[props[0]].inverted()          # the hand matrix that puts Prop1 at g
                    delta = r3(hn) @ r3(hr).inverted()
                    pv = hr.translation.copy()
                    dm = Matrix.Translation(pv) @ delta.to_4x4() @ Matrix.Translation(-pv)
                    for n in HAND_SUB: des[n] = dm @ des[n]
                    hr = des[hand_r]
                    g = hr @ prop_rel[props[0]]
                des[props[0]] = g
                if P12 is not None: des[props[1]] = g @ P12
                if WPN:
                    des[WPN] = g @ WPN_REL
                    def redo_w(b):
                        for c in b.children:
                            des[c.name] = des[b.name] @ (b.matrix_local.inverted() @ c.matrix_local); redo_w(c)
                    redo_w(BN[WPN])
                # their children again
                def redo(b):
                    for c in b.children:
                        des[c.name] = des[b.name] @ (b.matrix_local.inverted() @ c.matrix_local); redo(c)
                for pn in props: redo(BN[pn])
                if fi == 0:
                    L("  %s gun barrel vs facing %.1f deg (pitch %.1f), hands apart %.1f cm" % (name,
                      math.degrees((RT @ want).to_2d().angle_signed(calib["eve_fwd"].to_2d(), 0)), math.degrees(math.asin(max(-1, min(1, (RT @ want).z)))),
                      (hl.translation - hr.translation).length * sT * 100))
            if post and post[fi]: des = post_rot(des, post[fi])
            for n in order:
                b = BN[n]
                rest_rel = (b.parent.matrix_local.inverted() @ b.matrix_local) if b.parent else b.matrix_local
                par = des[b.parent.name] if b.parent else Matrix.Identity(4)
                basis = rest_rel.inverted() @ par.inverted() @ des[n]
                p = PB[n]; lo, ro, _sc = basis.decompose()
                p.location = lo; p.rotation_quaternion = ro
                p.keyframe_insert("location", frame=fi); p.keyframe_insert("rotation_quaternion", frame=fi)
        act.use_fake_user = True
        L("baked", name, "frames", len(frames_world))
        return act
    built = {}
    for new, clip in CLIPS.items():
        sarm, objs = import_mx(clip)
        if calib is None:
            calib = make_calib(sarm)
            TF = -calib["eve_fwd"]                      # eve_fwd from make_calib points backward (right x up)
            RIGHT_A = (RT.inverted() @ TF.cross(Vector((0, 0, 1)))).normalized()
            L("true forward", tuple(round(x, 2) for x in TF), "right (arm space)", tuple(round(x, 2) for x in RIGHT_A))
        mwS = sarm.matrix_world; sa = sarm.animation_data.action
        f0, f1 = int(sa.frame_range[0]), int(sa.frame_range[1])
        frames = list(range(f0, f1))   # last frame = first (loop), dropped
        rest = {s: r3(mwS @ sarm.data.bones[P + s].matrix_local) for s in MAP if P + s in sarm.data.bones}
        hrest = (mwS @ sarm.data.bones[P + "Hips"].matrix_local).translation
        scn.frame_set(f0); h0 = (mwS @ sarm.pose.bones[P + "Hips"].matrix).translation.copy()
        scn.frame_set(f1); h1 = (mwS @ sarm.pose.bones[P + "Hips"].matrix).translation.copy()
        trav = h1 - h0; trav.z = 0
        fws = []
        for f in frames:
            scn.frame_set(f)
            fw = {s: (r3(mwS @ sarm.pose.bones[P + s].matrix), None) for s in rest}
            hp = (mwS @ sarm.pose.bones[P + "Hips"].matrix).translation.copy() - trav * ((f - f0) / (f1 - f0))
            # keep the hips over the feet: remove the clip's start offset in xy
            hp.x -= h0.x - hrest.x; hp.y -= h0.y - hrest.y
            fw["Hips"] = (fw["Hips"][0], hp); fw["_rest"] = rest; fw["_hips_rest"] = hrest
            fws.append(fw)
        vf = van_frames(VAN[new]) if os.environ.get("NGM_HELPERS", "1") == "1" else None
        if vf:
            if LEGS_VAN:   # her walk cycle sets the length; the Mixamo upper body is sampled by phase
                fws = [dict(fws[int(i * len(fws) / len(vf)) % len(fws)]) for i in range(len(vf))]
                for i, fw in enumerate(fws): fw["_van"] = vf[i]
            else:
                for i, fw in enumerate(fws): fw["_van"] = vf[int(round(i * len(vf) / len(fws))) % len(vf)]
        L("clip", clip, "frames", len(fws), "travel %.2f m" % trav.length)
        if vf:
            def sag(R):   # pelvis up-axis tilt toward forward (deg, + = top forward); up axis = the bone axis nearest world up at rest
                up_rest = r3(BN["Bip001-Pelvis"].matrix_local)
                ax = max(range(3), key=lambda i: abs(up_rest.col[i].dot(Vector((0, 0, 1)))))
                sg = 1 if up_rest.col[ax].z > 0 else -1
                u = (R.col[ax] * sg); tf = RT.inverted() @ (-calib["eve_fwd"]); tf.z = 0; tf.normalize()
                return math.degrees(math.atan2(u.dot(tf), u.z))
            fw0 = fws[0]; dmx = fk(dict(fw0, _van=None), None, Vector((0, 0, 0)), {})
            L("  pelvis tilt fwd: mixamo-retarget %.1f deg | eve vanilla %.1f deg | eve rest %.1f deg" % (
              sag(r3(dmx["Bip001-Pelvis"])), sag(fw0["_van"]["_yv"] @ fw0["_van"]["_pelvis"]), sag(r3(BN["Bip001-Pelvis"].matrix_local))))
        hz = sum(f["Hips"][1].z for f in fws) / len(fws)
        rz = max(0.0, RAISE * (hrest.z - hz) * calib["ratio"])
        L("  hips mean %.3f rest %.3f -> raise %.3f m" % (hz, hrest.z, rz))
        built[new] = bake(new, fws, None, rz)
        if new == "NGM_Stand_Idle":
            # v11 standing shot: the recoil as subtree rotations (the old per-bone recoil was overridden by the aim fix): a sharp
            # kick (chest up/back, shoulder push) that settles; a small pelvis bump so her body physics react to every shot
            post = []
            for i in range(SHOOT_FRAMES):
                k = (i / 1.5) if i < 2 else math.exp(-(i - 1.5) / 2.5)
                post.append([("Bip001-Pelvis", RIGHT_A, math.radians(1.2) * k),
                             ("Bip001-Spine1", RIGHT_A, math.radians(2.5) * k), ("Bip001-Spine2", RIGHT_A, math.radians(3.0) * k),
                             ("Bip001-R-Clavicle", Vector((0, 0, 1)), math.radians(-3.0) * k)])
            built["NGM_Stand_Shoot"] = bake("NGM_Stand_Shoot", [fws[0]] * SHOOT_FRAMES, None, rz, post)
            # v11 aim offset set (replaces the drone-aim additives in Aim_BS): base + 8 poses, 2 identical frames each.
            # X = yaw (-1 left .. 1 right), Y = pitch (-1 down .. 1 up), as the vanilla Aim_BS grid.
            AP, AY = math.radians(float(os.environ.get("NGM_AO_PITCH", "55"))), math.radians(float(os.environ.get("NGM_AO_YAW", "40")))
            AIMS = {"Base": (0, 0), "Up": (1, 0), "Down": (-1, 0), "Left": (0, 1), "Right": (0, -1),
                    "UpLeft": (1, 1), "UpRight": (1, -1), "DownLeft": (-1, 1), "DownRight": (-1, -1)}
            for an, (py, yw) in AIMS.items():
                sp = aim_specs(py * AP, yw * AY)
                built["NGM_Stand_Aim_" + an] = bake("NGM_Stand_Aim_" + an, [fws[0]] * 2, None, rz, [sp, sp])
        for o in objs: bpy.data.objects.remove(o)
    # previews (gun marker on Prop1 along the barrel axis)
    use(None)
    fdir = calib["eve_fwd"]; side = Vector((-fdir.y, fdir.x, 0))
    gun = bpy.data.objects.new("gunmark", bpy.data.meshes.new("gunmark")); scn.collection.objects.link(gun)
    import bmesh
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0); bm.to_mesh(gun.data); bm.free()
    scn.render.engine = "BLENDER_WORKBENCH"; scn.render.resolution_x = 420; scn.render.resolution_y = 560
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
    sel = os.environ.get("NGM_PREVIEW_ONLY", "NGM_Stand_Idle,NGM_Stand_WalkF,NGM_Stand_WalkL,NGM_Stand_WalkB,NGM_Stand_Shoot").split(",")
    for view, off in (("front", fdir * 3.2 + Vector((0, 0, 1.2))), ("side", side * 3.4 + Vector((0, 0, 1.1))), ("back", -fdir * 3.0 + side * 0.8 + Vector((0, 0, 1.5)))):
        cam.location = off; d = Vector((0, 0, 0.95)) - off; cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        for name in sel:
            act = built.get(name)
            if not act: continue
            use(act); n = int(act.frame_range[1])
            for k, f in enumerate((0, n // 3, (2 * n) // 3)):
                scn.frame_set(f)
                if props:
                    pm = arm.matrix_world @ PB[props[0]].matrix
                    gun.matrix_world = Matrix.Translation(pm.translation + r3(pm) @ BAX * 0.3) @ r3(pm).to_4x4() @ Matrix.Diagonal((
                        *[0.6 if i == barrel[1] else 0.04 for i in range(3)], 1))
                scn.render.filepath = os.path.join(OUT, "pv_%s_%s_%d.png" % (name, view, k))
                bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(gun)
    use(None)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "NGM_Stand4.blend"))
    L("DONE")
except Exception:
    import traceback; L("ERROR", traceback.format_exc())
log.close()
