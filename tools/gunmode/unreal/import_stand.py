# ngm_ue_stand5.py (= ngm_ue_stand + game-path replacements, RENAME)
# ngm_ue_stand.py - UE 4.26 headless (SBOutfitProject, -run=pythonscript). Imports NikkeGunBuild\fbx\NGM_Stand_*.fbx as
# animations on the CH_P_EVE_01_Skeleton stand-in into /Game/OutfitMods/NikkeGunMode/Anim (30 fps, in place, no curves).
# Touches nothing else. Log: NikkeGunBuild\ue_stand_log.txt (ends with "ALL DONE").
import unreal, os, glob, traceback
B = os.path.join(os.environ.get("NGM_TOOLS", os.path.join(os.path.expanduser("~"), r"Downloads\Modding Tools")), "NikkeGunBuild")
FBX = os.path.join(B, "fbx")
LOGF = open(os.path.join(B, "ue_stand_log.txt"), "w")
def log(*a):
    s = " ".join(str(x) for x in a); unreal.log(s); LOGF.write(s + "\n"); LOGF.flush()
AT = unreal.AssetToolsHelpers.get_asset_tools(); EAL = unreal.EditorAssetLibrary
SKEL_PATH = "/Game/Art/Character/PC/CH_P_EVE_01/CH_P_EVE_01_Skeleton"
DEST = "/Game/OutfitMods/NikkeGunMode/Anim"
# v5: game-path replacements (FBX name -> (folder, asset name))
RENAME = {"NGM_Stand_Shoot": ("/Game/DLC_2/Art/Character/PC/CH_P_EVE_01/Animation", "P_Eve_GunNikke_Shoot")}
def sep(obj, **kw):
    for k, v in kw.items():
        try: obj.set_editor_property(k, v)
        except Exception as e: log("  (option %s not set: %s)" % (k, e))
try:
    skel = unreal.load_asset(SKEL_PATH)
    if skel is None: raise Exception("stand-in skeleton missing: " + SKEL_PATH)
    if EAL.does_directory_exist(DEST):
        for a in EAL.list_assets(DEST, recursive=True): EAL.delete_asset(a)
    files = sorted(glob.glob(os.path.join(FBX, "NGM_Stand_*.fbx")))
    log("fbx", [os.path.basename(f) for f in files])
    for f in files:
        name = os.path.splitext(os.path.basename(f))[0]
        dest = DEST
        if name in RENAME: dest, name = RENAME[name]
        if dest != DEST and EAL.does_asset_exist(dest + "/" + name): EAL.delete_asset(dest + "/" + name)
        t = unreal.AssetImportTask()
        sep(t, filename=f, destination_path=dest, destination_name=name, automated=True, replace_existing=True, save=False)
        o = unreal.FbxImportUI()
        sep(o, import_mesh=False, import_as_skeletal=True, import_animations=True, import_materials=False, import_textures=False,
            skeleton=skel, mesh_type_to_import=unreal.FBXImportType.FBXIT_ANIMATION, create_physics_asset=False,
            automated_import_should_detect_type=False, original_import_type=unreal.FBXImportType.FBXIT_ANIMATION)
        ad = o.get_editor_property("anim_sequence_import_data")
        sep(ad, animation_length=unreal.FBXAnimationLengthImportType.FBXALIT_EXPORTED_TIME, import_bone_tracks=True,
            remove_redundant_keys=False, convert_scene=True, force_front_x_axis=False, convert_scene_unit=False,
            use_default_sample_rate=False, custom_sample_rate=30, import_custom_attribute=False, import_meshes_in_bone_hierarchy=False,
            do_not_import_curve_with_zero=True, delete_existing_morph_target_curves=True, set_material_drive_parameter_on_custom_attribute=False,
            preserve_local_transform=False, import_uniform_scale=1.0)   # the FBX is already in cm (Blender export at unit scale 0.01)
        t.set_editor_property("options", o)
        AT.import_asset_tasks([t])
        seq = unreal.load_asset(dest + "/" + name)
        if seq is None:
            log("IMPORT FAILED", name, t.get_editor_property("imported_object_paths")); continue
        sep(seq, enable_root_motion=False, force_root_lock=False)
        try: n_tracks = len(unreal.AnimationLibrary.get_animation_track_names(seq))
        except Exception as e: n_tracks = "?" + str(e)
        try: nf = unreal.AnimationLibrary.get_num_frames(seq)
        except Exception: nf = "?"
        pose = []
        for bn in ("Root", "Bip001", "Bip001-Pelvis", "Bip001-L-Thigh", "Bip001-R-Hand", "Bip001-Prop1"):
            try:
                tr = unreal.AnimationLibrary.get_bone_pose_for_frame(seq, bn, 0, False)
                pose.append("%s t=(%.2f,%.2f,%.2f) r=(%.3f,%.3f,%.3f,%.3f)" % (bn, tr.translation.x, tr.translation.y, tr.translation.z,
                            tr.rotation.x, tr.rotation.y, tr.rotation.z, tr.rotation.w))
            except Exception as e: pose.append("%s ? %s" % (bn, e))
        try: curves = len(unreal.AnimationLibrary.get_animation_curve_names(seq, unreal.RawCurveTrackTypes.RCT_FLOAT))
        except Exception as e: curves = "?" + str(e)
        log("ANIM", name, "len %.4f" % seq.get_editor_property("sequence_length"), "frames", nf, "tracks", n_tracks, "curves", curves)
        log("   ", " | ".join(pose))
        EAL.save_loaded_asset(seq)
    # v6: aim offset poses = local-space additives on NGM_Stand_Aim_Base frame 0 (as the vanilla Aim_* on their base)
    base = unreal.load_asset(DEST + "/NGM_Stand_Aim_Base")
    if base is not None:
        for a in EAL.list_assets(DEST, recursive=False):
            nm = a.split("/")[-1].split(".")[0]
            if not nm.startswith("NGM_Stand_Aim_") or nm == "NGM_Stand_Aim_Base": continue
            seq = unreal.load_asset(DEST + "/" + nm)
            sep(seq, additive_anim_type=unreal.AdditiveAnimationType.AAT_LOCAL_SPACE_BASE,
                ref_pose_type=unreal.AdditiveBasePoseType.ABPT_ANIM_FRAME, ref_pose_seq=base, ref_frame_index=0)
            log("ADDITIVE", nm, seq.get_editor_property("additive_anim_type"), seq.get_editor_property("ref_pose_type"))
            EAL.save_loaded_asset(seq)
    else: log("no NGM_Stand_Aim_Base - aim offset not built")
    EAL.save_directory(DEST, only_if_is_dirty=False, recursive=True)
    for d_, n_ in RENAME.values():
        if EAL.does_asset_exist(d_ + "/" + n_): EAL.save_asset(d_ + "/" + n_, only_if_is_dirty=False); log("saved", d_ + "/" + n_)
    log("saved", [str(a) for a in EAL.list_assets(DEST, recursive=True)])
    log("ALL DONE")
except Exception:
    log("Exception", traceback.format_exc())
LOGF.close()
