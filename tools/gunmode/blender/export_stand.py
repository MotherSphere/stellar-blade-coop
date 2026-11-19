# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
# ngm_bl_export_stand2.py - (= export_stand + the source .blend from NGM_STAND_BLEND, default stand3\NGM_Stand3.blend)
# Opens NikkeGunBuild\blend\stand2\NGM_Stand.blend, imports a clean body armature (sockets OFF, as the SB FBX README says),
# moves every NGM_Stand_* action onto it, keeps the anims in place (Root translation flattened; the character movement
# component moves Eve in gun mode, not root motion), and writes one FBX per action with OutfitWork\sbfbx_5 (the same patched
# exporter and axis settings the Project Evie meshes use) -> NikkeGunBuild\fbx\NGM_Stand_*.fbx + fbx\export_log.txt
import bpy, os, sys, importlib, importlib.util
from pathlib import Path
from bpy_extras.io_utils import axis_conversion
HOME = os.path.expanduser("~")
MT = os.environ.get("NGM_TOOLS", os.path.join(HOME, r"Downloads\Modding Tools"))
B = os.path.join(MT, "NikkeGunBuild"); A = os.path.join(B, "anim_export")
OUT = os.path.join(B, "fbx"); os.makedirs(OUT, exist_ok=True)
log = open(os.path.join(OUT, "export_log.txt"), "w")
def L(*a): log.write(" ".join(str(x) for x in a) + "\n"); log.flush()
INPLACE = os.environ.get("NGM_INPLACE", "1") == "1"
try:
    bpy.ops.wm.open_mainfile(filepath=os.environ.get("NGM_STAND_BLEND", os.path.join(B, "blend", "stand3", "NGM_Stand3.blend")))
    import addon_utils
    mod = None
    for m in addon_utils.modules():
        if m.__name__.endswith("io_scene_ueformat"): mod = m.__name__; addon_utils.enable(mod, default_set=False)
    ctx = importlib.import_module(mod + ".importer.import_context"); opts = importlib.import_module(mod + ".options")
    acts = [a for a in bpy.data.actions if a.name.startswith("NGM_Stand_")]
    L("actions", [(a.name, tuple(a.frame_range)) for a in acts])
    for o in list(bpy.data.objects): bpy.data.objects.remove(o)
    try: mo = opts.UEModelOptions(import_sockets=False)
    except TypeError:
        mo = opts.UEModelOptions(); mo.import_sockets = False
    L("model options", {k: getattr(mo, k) for k in dir(mo) if not k.startswith("_") and not callable(getattr(mo, k))})
    ctx.UEFormatImport(mo).import_file(Path(os.path.join(A, "CH_P_EVE_01_Body.uemodel")))
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    for o in [o for o in bpy.data.objects if o is not arm]: bpy.data.objects.remove(o)
    arm.name = "Armature"; arm.data.name = "Armature"
    PB = arm.pose.bones
    for p in PB: p.rotation_mode = "QUATERNION"
    roots = [b.name for b in arm.data.bones if b.parent is None]
    L("armature bones", len(PB), "roots", roots, "scale", tuple(arm.scale), "fps", bpy.context.scene.render.fps)
    names = set(PB.keys())
    if arm.animation_data is None: arm.animation_data_create()
    sb = importlib.util.spec_from_file_location("sbfbx5", os.path.join(MT, "OutfitWork", "sbfbx_5", "io_scene_fbx", "__init__.py"),
                                                submodule_search_locations=[os.path.join(MT, "OutfitWork", "sbfbx_5", "io_scene_fbx")])
    sbm = importlib.util.module_from_spec(sb); sys.modules["sbfbx5"] = sbm; sb.loader.exec_module(sbm)
    from sbfbx5 import export_fbx_bin
    class Op:
        def report(self, t, m): L("REPORT", t, m)
    class Ctx:
        def __init__(self, sel): self.selected_objects = sel
        def __getattr__(self, k): return getattr(bpy.context, k)
    scn = bpy.context.scene
    # centimetres like the Project Evie pipeline (export19.finish): scene unit 0.01, armature x100 applied into the rest pose,
    # and every pose-bone location key x100 below (they are bone-local offsets, transform_apply does not touch them)
    scn.unit_settings.scale_length = 0.01
    arm.scale = (100.0, 100.0, 100.0); bpy.context.view_layer.update()
    for o in scn.objects: o.select_set(False)
    arm.select_set(True); bpy.context.view_layer.objects.active = arm
    _w = bpy.context.window_manager.windows
    _ov = dict(window=_w[0], screen=_w[0].screen) if _w else {}
    with bpy.context.temp_override(selected_objects=[arm], selected_editable_objects=[arm], active_object=arm, object=arm, **_ov):
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    L("after x100: scale", tuple(arm.scale), "Bip001 rest head z", round(arm.data.bones["Bip001"].head_local.z, 2))
    scn.render.fps = 30; scn.render.fps_base = 1.0   # the game anims are 30 fps (Chat_Lockon_Walk_Forward: 35 frames / 1.1333 s)
    L("Prop bones in armature", [n for n in names if "Prop" in n])
    def fcurves(act):
        # Blender 5.x layered actions: channelbag per slot; fall back to legacy act.fcurves
        try:
            out = []
            for layer in act.layers:
                for strip in layer.strips:
                    for cb in strip.channelbags: out += list(cb.fcurves)
            if out: return out
        except Exception: pass
        return list(getattr(act, "fcurves", []))
    for act in acts:
        fcs = fcurves(act)
        bones_in = {fc.data_path.split('"')[1] for fc in fcs if fc.data_path.startswith("pose.bones")}
        missing = sorted(bones_in - names)
        for bn in ("Root", "Bip001"):
            loc = [fc for fc in fcs if fc.data_path == 'pose.bones["%s"].location' % bn]
            rng = [round(max(k.co[1] for k in fc.keyframe_points) - min(k.co[1] for k in fc.keyframe_points), 4) for fc in sorted(loc, key=lambda f: f.array_index)]
            L(act.name, bn, "location travel per axis", rng)
            if INPLACE and bn == "Root":
                for fc in loc:
                    v0 = fc.keyframe_points[0].co[1]
                    for k in fc.keyframe_points: k.co[1] = v0; k.handle_left[1] = v0; k.handle_right[1] = v0
                    fc.update()
        nloc = 0
        for fc in fcs:
            if fc.data_path.startswith("pose.bones") and fc.data_path.endswith(".location"):
                for k in fc.keyframe_points:
                    k.co[1] *= 100.0; k.handle_left[1] *= 100.0; k.handle_right[1] *= 100.0
                fc.update(); nloc += 1
        L(act.name, "location curves x100:", nloc)
        arm.animation_data.action = act
        try:
            if act.slots: arm.animation_data.action_slot = act.slots[0]
        except Exception as e: L("slot", e)
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        scn.frame_start, scn.frame_end = f0, f1
        scn.frame_set(f1 // 2); bpy.context.view_layer.update()
        L(act.name, "frames", f0, f1, "bones keyed", len(bones_in), "not in armature", missing[:10], len(missing),
          "pelvis z mid", round((arm.matrix_world @ PB["Bip001-Pelvis"].head).z, 3))
        for o in scn.objects: o.select_set(False)
        arm.select_set(True); bpy.context.view_layer.objects.active = arm
        path = os.path.join(OUT, act.name + ".fbx")
        gm = axis_conversion(to_forward='-Z', to_up='Y').to_4x4()
        export_fbx_bin.save(Op(), Ctx([arm]), filepath=path, use_selection=True, global_matrix=gm,
            apply_unit_scale=True, global_scale=1.0, apply_scale_options='FBX_SCALE_NONE', axis_up='Y', axis_forward='-Z',
            object_types={'ARMATURE'}, use_mesh_modifiers=False, add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X',
            use_armature_deform_only=False, armature_nodetype='NULL', path_mode='AUTO', embed_textures=False,
            bake_anim=True, bake_anim_use_all_bones=True, bake_anim_use_nla_strips=False, bake_anim_use_all_actions=False,
            bake_anim_step=1.0, bake_anim_simplify_factor=0.0, bake_anim_force_startend_keying=True,
            stellar_blade_fix=False, stellar_blade_skeleton="EVE", stellar_blade_show_log=False)
        L("exported", path, os.path.getsize(path))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "NGM_Stand_export.blend"))
    L("EXPORT DONE")
except Exception:
    import traceback; L("ERROR", traceback.format_exc())
log.close()
