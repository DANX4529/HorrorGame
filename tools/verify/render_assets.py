#!/usr/bin/env python3
"""Rendu de contrôle : importe des .glb et produit une planche contact."""
import os, sys, math, argparse, glob
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "blender"))
import bpy
from mathutils import Vector
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def setup_scene(res=340, samples=32):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    world = bpy.data.worlds.new("W")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.06, 0.065, 0.075, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0


def frame_objects(objs, angle=(1.0, 0.0, 0.78), dist_k=1.9):
    """Place caméra + 3 lampes autour de la boîte englobante."""
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    for o in objs:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector((min(mn[i], w[i]) for i in range(3)))
            mx = Vector((max(mx[i], w[i]) for i in range(3)))
    ctr = (mn + mx) * 0.5
    rad = max((mx - mn).length * 0.5, 0.4)

    cam_d = bpy.data.cameras.new("C"); cam = bpy.data.objects.new("C", cam_d)
    bpy.context.scene.collection.objects.link(cam)
    cam_d.lens = 45
    d = rad * dist_k * 2.2
    az, el = angle[2], angle[0] * 0.45
    cam.location = ctr + Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el),
                                 math.sin(el) + 0.25)) * d
    direction = ctr - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam

    for (dx, dy, dz, e, sz) in ((1.2, -1.4, 1.6, 1.0, 1.4),
                                (-1.6, -0.6, 0.8, 0.35, 2.0),
                                (0.2, 1.6, 1.2, 0.45, 2.0)):
        ld = bpy.data.lights.new("L", "AREA"); ld.energy = e * 120 * (rad ** 2 + 1)
        ld.size = sz * rad
        lo = bpy.data.objects.new("L", ld)
        bpy.context.scene.collection.objects.link(lo)
        lo.location = ctr + Vector((dx, dy, dz)) * d * 0.6
        lo.rotation_euler = (ctr - lo.location).to_track_quat("-Z", "Y").to_euler()


def render_glb(path, out_png, res=340, angle=(1.0, 0.0, 0.78)):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    setup_scene(res)
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = [o for o in bpy.context.scene.objects if o not in before]
    if not objs:
        return False
    # matériau gris neutre pour juger la forme, pas la texture
    m = bpy.data.materials.new("clay"); m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.55, 0.55, 0.56, 1)
    bsdf.inputs["Roughness"].default_value = 0.62
    for o in objs:
        if o.type == "MESH":
            o.data.materials.clear()
            o.data.materials.append(m)
    frame_objects(objs, angle)
    bpy.context.scene.render.filepath = out_png
    bpy.ops.render.render(write_still=True)
    return True


def sheet(pairs, out, cell=340, cols=4):
    rows = (len(pairs) + cols - 1) // cols
    pad, lab = 6, 18
    W = cols * (cell + pad) + pad
    H = rows * (cell + pad + lab) + pad
    img = Image.new("RGB", (W, H), (14, 14, 16))
    d = ImageDraw.Draw(img)
    for i, (name, png) in enumerate(pairs):
        r, c = divmod(i, cols)
        x = pad + c * (cell + pad); y = pad + r * (cell + pad + lab)
        d.text((x, y + 3), name, fill=(200, 205, 195))
        if os.path.exists(png):
            img.paste(Image.open(png).convert("RGB").resize((cell, cell), Image.LANCZOS),
                      (x, y + lab))
    img.save(out)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("glob", help="motif, ex: game/assets/models/env/*.glb")
    ap.add_argument("--out", default="/tmp/sheet.png")
    ap.add_argument("--cell", type=int, default=340)
    ap.add_argument("--cols", type=int, default=4)
    ap.add_argument("--tmp", default="/tmp/_rend")
    a = ap.parse_args()
    os.makedirs(a.tmp, exist_ok=True)
    files = sorted(glob.glob(os.path.join(ROOT, a.glob)))
    pairs = []
    for f in files:
        n = os.path.splitext(os.path.basename(f))[0]
        png = os.path.join(a.tmp, n + ".png")
        if render_glb(f, png, a.cell):
            pairs.append((n, png))
        print("  rendered", n)
    print("sheet ->", sheet(pairs, a.out, a.cell, a.cols))


if __name__ == "__main__":
    main()
