#!/usr/bin/env python3
"""Bande-film d'une animation d'un .glb riggé — contrôle visuel du mouvement."""
import os, sys, math, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from PIL import Image, ImageDraw
from render_assets import setup_scene


def strip(glb, anim, out, frames=6, res=280, az=0.95, clay=True):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    setup_scene(res, 24)
    bpy.ops.import_scene.gltf(filepath=glb)
    objs = [o for o in bpy.context.scene.objects]
    arm = next((o for o in objs if o.type == "ARMATURE"), None)
    if arm is None:
        raise SystemExit("pas d'armature dans " + glb)

    act = bpy.data.actions.get(anim)
    if act is None:
        cands = [a for a in bpy.data.actions if anim in a.name]
        act = cands[0] if cands else None
    if act is None:
        raise SystemExit(f"action '{anim}' introuvable: {[a.name for a in bpy.data.actions]}")
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    if hasattr(arm.animation_data, "action_slot") and act.slots:
        arm.animation_data.action_slot = act.slots[0]

    if clay:
        m = bpy.data.materials.new("clay")
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (0.60, 0.58, 0.56, 1)
        b.inputs["Roughness"].default_value = 0.55
        for o in objs:
            if o.type == "MESH":
                o.data.materials.clear(); o.data.materials.append(m)

    ctr = Vector((0, 0, 1.05)); d = 4.2
    cd = bpy.data.cameras.new("C"); cd.lens = 50
    cam = bpy.data.objects.new("C", cd); bpy.context.scene.collection.objects.link(cam)
    cam.location = ctr + Vector((math.cos(az), math.sin(az), 0.20)) * d
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    for (o2, e, sz) in ((Vector((1.3, 1.6, 1.5)), 900, 2.0), (Vector((-1.8, 0.6, 0.7)), 260, 2.5),
                        (Vector((0.2, -1.9, 1.0)), 340, 2.5)):
        ld = bpy.data.lights.new("L", "AREA"); ld.energy = e; ld.size = sz
        lo = bpy.data.objects.new("L", ld); bpy.context.scene.collection.objects.link(lo)
        lo.location = ctr + o2 * 2.0
        lo.rotation_euler = (ctr - lo.location).to_track_quat("-Z", "Y").to_euler()

    fr = act.frame_range
    f0, f1 = int(fr[0]), int(fr[1])
    picks = [f0 + round((f1 - f0) * i / max(frames - 1, 1)) for i in range(frames)]
    shots = []
    tmp = "/tmp/_anim"
    os.makedirs(tmp, exist_ok=True)
    for i, f in enumerate(picks):
        bpy.context.scene.frame_set(f)
        p = f"{tmp}/{anim}_{i:02d}.png"
        bpy.context.scene.render.filepath = p
        bpy.ops.render.render(write_still=True)
        shots.append((f, p))

    pad, lab = 4, 16
    W = frames * (res + pad) + pad
    img = Image.new("RGB", (W, res + lab + pad * 2), (14, 14, 16))
    dr = ImageDraw.Draw(img)
    dr.text((pad, 2), f"{anim}  (images {f0}-{f1})", fill=(200, 205, 195))
    for i, (f, p) in enumerate(shots):
        img.paste(Image.open(p).convert("RGB"), (pad + i * (res + pad), lab + pad))
    img.save(out)
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("glb"); ap.add_argument("anims", nargs="+")
    ap.add_argument("--out", default="/tmp/anim.png")
    ap.add_argument("--frames", type=int, default=6)
    ap.add_argument("--res", type=int, default=280)
    a = ap.parse_args()
    parts = []
    for an in a.anims:
        p = f"/tmp/_anim/strip_{an}.png"
        strip(a.glb, an, p, a.frames, a.res)
        parts.append(p)
    ims = [Image.open(p) for p in parts]
    W = max(i.width for i in ims); H = sum(i.height for i in ims)
    sheet = Image.new("RGB", (W, H), (14, 14, 16))
    y = 0
    for i in ims:
        sheet.paste(i, (0, y)); y += i.height
    sheet.save(a.out)
    print("sheet ->", a.out)
