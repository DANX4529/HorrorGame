"""
blib — boîte à outils Blender (bpy) pour la construction procédurale des assets de RESPIRE.

Tout passe par bmesh plutôt que bpy.ops : pas de dépendance au contexte,
donc parfaitement fiable en exécution headless.

Convention : Blender est en Z-up, Godot en Y-up. L'exportateur glTF fait la
conversion (+Y up) automatiquement. On modélise donc en Z-up, mètres réels.
"""
import math
import bpy
import bmesh
from mathutils import Vector, Matrix, Euler

TAU = math.pi * 2


# ==========================================================================
#  Scène
# ==========================================================================
def scene_reset():
    """Vide complètement le fichier .blend en mémoire."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for coll in (bpy.data.meshes, bpy.data.objects, bpy.data.materials,
                 bpy.data.armatures, bpy.data.actions, bpy.data.images):
        for item in list(coll):
            try:
                coll.remove(item)
            except Exception:
                pass


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


# ==========================================================================
#  Primitives bmesh
# ==========================================================================
def bm_new():
    return bmesh.new()


def _transform_faces(bm, faces, mat):
    verts = {v for f in faces for v in f.verts}
    bmesh.ops.transform(bm, matrix=mat, verts=list(verts))


def box(bm, size=(1, 1, 1), center=(0, 0, 0), rot=(0, 0, 0), mat=0):
    """Pavé droit. size = dimensions complètes (X,Y,Z). Retourne les faces créées."""
    res = bmesh.ops.create_cube(bm, size=1.0)
    faces = res["verts"][0].link_faces[:] if False else None
    verts = res["verts"]
    faces = list({f for v in verts for f in v.link_faces})
    m = (Matrix.Translation(Vector(center))
         @ Euler(rot, "XYZ").to_matrix().to_4x4()
         @ Matrix.Diagonal(Vector(size).to_4d()))
    bmesh.ops.transform(bm, matrix=m, verts=verts)
    for f in faces:
        f.material_index = mat
    return faces


def cylinder(bm, radius=0.5, depth=1.0, segments=16, center=(0, 0, 0),
             rot=(0, 0, 0), mat=0, cap=True, radius_top=None):
    """Cylindre (axe Z local). radius_top permet de faire un cône tronqué."""
    rt = radius if radius_top is None else radius_top
    res = bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=segments,
                                radius1=radius, radius2=rt, depth=depth)
    verts = res["verts"]
    faces = list({f for v in verts for f in v.link_faces})
    m = Matrix.Translation(Vector(center)) @ Euler(rot, "XYZ").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=m, verts=verts)
    for f in faces:
        f.material_index = mat
    return faces


def tube(bm, radius=0.05, length=1.0, segments=10, p0=(0, 0, 0), p1=(0, 0, 1), mat=0):
    """Cylindre entre deux points de l'espace."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    ln = d.length
    if ln < 1e-6:
        return []
    faces = cylinder(bm, radius=radius, depth=ln, segments=segments, mat=mat)
    verts = list({v for f in faces for v in f.verts})
    rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    m = Matrix.Translation((a + b) * 0.5) @ rot
    bmesh.ops.transform(bm, matrix=m, verts=verts)
    return faces


def sphere(bm, radius=0.5, segments=16, rings=8, center=(0, 0, 0), scale=(1, 1, 1), mat=0):
    res = bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    verts = res["verts"]
    faces = list({f for v in verts for f in v.link_faces})
    m = Matrix.Translation(Vector(center)) @ Matrix.Diagonal(Vector(scale).to_4d())
    bmesh.ops.transform(bm, matrix=m, verts=verts)
    for f in faces:
        f.material_index = mat
    return faces


def torus(bm, major=0.3, minor=0.02, major_seg=24, minor_seg=8,
          center=(0, 0, 0), rot=(0, 0, 0), mat=0):
    """Tore construit explicitement (jantes, cerceaux, joints). Axe Z local."""
    rings = []
    for i in range(major_seg):
        a = TAU * i / major_seg
        ca, sa = math.cos(a), math.sin(a)
        ring = []
        for j in range(minor_seg):
            b = TAU * j / minor_seg
            rr = major + minor * math.cos(b)
            ring.append(bm.verts.new((rr * ca, rr * sa, minor * math.sin(b))))
        rings.append(ring)
    bm.verts.index_update()
    faces = []
    for i in range(major_seg):
        i2 = (i + 1) % major_seg
        for j in range(minor_seg):
            j2 = (j + 1) % minor_seg
            try:
                f = bm.faces.new((rings[i][j], rings[i2][j], rings[i2][j2], rings[i][j2]))
                f.material_index = mat
                faces.append(f)
            except ValueError:
                pass
    m = Matrix.Translation(Vector(center)) @ Euler(rot, "XYZ").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=m, verts=[v for r in rings for v in r])
    return faces


def grid_plane(bm, size=(1, 1), center=(0, 0, 0), rot=(0, 0, 0), subdiv=1, mat=0):
    """Plan subdivisé (utile pour déformer : sol affaissé, tissu…)."""
    res = bmesh.ops.create_grid(bm, x_segments=subdiv, y_segments=subdiv, size=0.5)
    verts = res["verts"]
    faces = list({f for v in verts for f in v.link_faces})
    m = (Matrix.Translation(Vector(center)) @ Euler(rot, "XYZ").to_matrix().to_4x4()
         @ Matrix.Diagonal(Vector((size[0], size[1], 1.0)).to_4d()))
    bmesh.ops.transform(bm, matrix=m, verts=verts)
    for f in faces:
        f.material_index = mat
    return faces


# ==========================================================================
#  Opérations
# ==========================================================================
def bevel(bm, faces=None, width=0.01, segments=2, geom=None):
    """Chanfreine les arêtes. Sans argument, chanfreine tout le maillage."""
    if geom is None:
        if faces is None:
            geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        else:
            es = {e for f in faces for e in f.edges}
            vs = {v for f in faces for v in f.verts}
            geom = list(vs) + list(es) + list(faces)
    try:
        bmesh.ops.bevel(bm, geom=geom, offset=width, segments=segments,
                        profile=0.5, affect="EDGES", clamp_overlap=True)
    except Exception:
        pass


def bevel_sharp(bm, width=0.008, segments=1, angle=0.6):
    """Chanfreine uniquement les arêtes vives (> `angle` radians)."""
    edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > angle]
    if not edges:
        return
    verts = list({v for e in edges for v in e.verts})
    try:
        bmesh.ops.bevel(bm, geom=verts + edges, offset=width, segments=segments,
                        profile=0.5, affect="EDGES", clamp_overlap=True)
    except Exception:
        pass


def inset(bm, faces, thickness=0.02, depth=0.0):
    r = bmesh.ops.inset_region(bm, faces=faces, thickness=thickness, depth=depth,
                               use_even_offset=True)
    return r["faces"]


def extrude(bm, faces, vec):
    r = bmesh.ops.extrude_face_region(bm, geom=faces)
    nv = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=nv, vec=Vector(vec))
    return [f for f in r["geom"] if isinstance(f, bmesh.types.BMFace)]


def jitter(bm, verts=None, amount=0.004, seed=0):
    """Perturbe légèrement les sommets — casse l'aspect « CAO parfaite »."""
    import random
    rnd = random.Random(seed)
    for v in (verts if verts is not None else bm.verts):
        v.co.x += (rnd.random() - 0.5) * amount
        v.co.y += (rnd.random() - 0.5) * amount
        v.co.z += (rnd.random() - 0.5) * amount


def recalc_normals(bm):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))


# ==========================================================================
#  UV : projection cubique à l'échelle du monde
# ==========================================================================
def uv_world_box(bm, scale=1.0, offset=(0.0, 0.0)):
    """
    Dépliage UV par projection sur l'axe dominant de chaque face, à l'échelle
    du monde : `scale` mètres = 1 répétition de texture.
    Les faces conservent des proportions réelles, donc pas d'étirement.
    """
    uv = bm.loops.layers.uv.verify()
    s = 1.0 / max(scale, 1e-6)
    for f in bm.faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in f.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:        # face ~horizontale -> plan XY
                u, v = co.x, co.y
            elif ax >= ay:                   # face ~normale X   -> plan YZ
                u, v = co.y, co.z
            else:                            # face ~normale Y   -> plan XZ
                u, v = co.x, co.z
            loop[uv].uv = ((u * s) + offset[0], (v * s) + offset[1])


def uv_world_box_faces(bm, faces, scale=1.0, offset=(0.0, 0.0)):
    """Même chose mais restreint à un sous-ensemble de faces."""
    uv = bm.loops.layers.uv.verify()
    s = 1.0 / max(scale, 1e-6)
    for f in faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in f.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:
                u, v = co.x, co.y
            elif ax >= ay:
                u, v = co.y, co.z
            else:
                u, v = co.x, co.z
            loop[uv].uv = ((u * s) + offset[0], (v * s) + offset[1])


# ==========================================================================
#  Matériaux (slots nommés — remplacés côté Godot par des .tres)
# ==========================================================================
_MAT_CACHE = {}


def get_material(name):
    """Matériau porteur du seul nom : Godot remplacera par res://assets/materials/<name>.tres"""
    key = f"mat_{name}"
    if key in _MAT_CACHE and key in bpy.data.materials:
        return bpy.data.materials[key]
    m = bpy.data.materials.get(key) or bpy.data.materials.new(key)
    m.diffuse_color = (0.6, 0.6, 0.6, 1.0)
    _MAT_CACHE[key] = m
    return m


def finish(bm, name, mat_names, smooth_angle=None, obj_scale=1.0):
    """Transforme un bmesh en objet Blender avec ses slots de matériaux."""
    recalc_normals(bm)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if me.uv_layers:                      # nom canonique attendu par les moteurs
        me.uv_layers[0].name = "UVMap"
    obj = bpy.data.objects.new(name, me)
    for mn in mat_names:
        obj.data.materials.append(get_material(mn))
    if smooth_angle is not None:
        for p in me.polygons:
            p.use_smooth = True
        # Blender 4.1+ : l'auto-smooth passe par un modificateur de normales
        mod = obj.modifiers.new("SmoothByAngle", "NODES")
        try:
            ng = bpy.data.node_groups.get("Smooth by Angle")
            if ng is None:
                bpy.ops.object.modifier_remove(modifier=mod.name)
                raise RuntimeError
            mod.node_group = ng
        except Exception:
            obj.modifiers.remove(mod) if mod.name in obj.modifiers else None
    link(obj)
    if obj_scale != 1.0:
        obj.scale = (obj_scale,) * 3
    return obj


# ==========================================================================
#  Export
# ==========================================================================
def export_glb(objects, filepath, apply_modifiers=True, anim=False):
    """Exporte une liste d'objets en .glb (géométrie + UV, matériaux nommés)."""
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    kw = dict(
        filepath=filepath,
        export_format="GLB",
        use_selection=True,
        export_apply=apply_modifiers,
        export_yup=True,
        export_normals=True,
        export_tangents=False,
        export_materials="EXPORT",
        export_image_format="NONE",      # les textures sont câblées côté Godot
        export_cameras=False,
        export_lights=False,
        export_extras=False,
    )
    if anim:
        kw.update(export_animations=True, export_frame_range=False,
                  export_anim_slide_to_zero=False, export_bake_animation=True)
    else:
        kw.update(export_animations=False)
    bpy.ops.export_scene.gltf(**kw)
    return filepath


def tri_count(objs):
    n = 0
    for o in objs:
        if o.type == "MESH":
            o.data.calc_loop_triangles()
            n += len(o.data.loop_triangles)
    return n
