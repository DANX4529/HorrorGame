"""
build_entity — « La Veilleuse », l'antagoniste de RESPIRE.

Technique : squelette d'arêtes + modificateur Skin + Subdivision -> corps
organique décharné, puis crâne sculpté à part, blouse, et armature animée.

ORIENTATION : le personnage regarde vers +Y dans Blender.
L'export glTF (+Y up) applique Blender(x,y,z) -> glTF(x, z, -y), donc +Y Blender
devient -Z glTF, c'est-à-dire l'avant d'un Node3D Godot. C'est bien ce qu'on veut.
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import blib as B
from mathutils import Vector, Matrix, Euler, Quaternion

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "models", "char")
PI = math.pi

# --------------------------------------------------------------------------
#  Squelette : (nom, position, rayon, parent)
#  Silhouette voulue : 2,15 m, épaules hautes et étroites, bras démesurés
#  dont les mains descendent sous le genou, buste voûté vers l'avant.
# --------------------------------------------------------------------------
JOINTS = [
    ("pelvis",     (0.000,  0.000, 1.020), 0.125, None),
    ("spine1",     (0.000,  0.022, 1.255), 0.112, "pelvis"),
    ("spine2",     (0.000,  0.058, 1.480), 0.122, "spine1"),
    ("chest",      (0.000,  0.105, 1.660), 0.142, "spine2"),
    ("neck",       (0.000,  0.150, 1.800), 0.046, "chest"),
    ("head",       (0.000,  0.182, 1.905), 0.072, "neck"),

    ("clav_L",     (0.152,  0.082, 1.678), 0.068, "chest"),
    ("elbow_L",    (0.268,  0.010, 1.318), 0.050, "clav_L"),
    ("wrist_L",    (0.312,  0.118, 0.930), 0.040, "elbow_L"),
    ("hand_L",     (0.330,  0.186, 0.742), 0.030, "wrist_L"),

    ("clav_R",     (-0.152, 0.082, 1.678), 0.068, "chest"),
    ("elbow_R",    (-0.268, 0.010, 1.318), 0.050, "clav_R"),
    ("wrist_R",    (-0.312, 0.118, 0.930), 0.040, "elbow_R"),
    ("hand_R",     (-0.330, 0.186, 0.742), 0.030, "wrist_R"),

    ("knee_L",     (0.108,  0.028, 0.560), 0.068, "pelvis"),
    ("ankle_L",    (0.118, -0.010, 0.108), 0.046, "knee_L"),
    ("toe_L",      (0.118,  0.145, 0.036), 0.042, "ankle_L"),

    ("knee_R",     (-0.108, 0.028, 0.560), 0.068, "pelvis"),
    ("ankle_R",    (-0.118,-0.010, 0.108), 0.046, "knee_R"),
    ("toe_R",      (-0.118, 0.145, 0.036), 0.042, "ankle_R"),
]
JMAP = {j[0]: i for i, j in enumerate(JOINTS)}


# ==========================================================================
#  Corps
# ==========================================================================
def build_body():
    verts = [j[1] for j in JOINTS]
    edges = [(JMAP[j[3]], i) for i, j in enumerate(JOINTS) if j[3]]
    me = bpy.data.meshes.new("veilleuse_body")
    me.from_pydata(verts, edges, [])
    me.update()
    obj = B.link(bpy.data.objects.new("veilleuse_body", me))

    sk = obj.modifiers.new("Skin", "SKIN")
    sk.use_smooth_shade = True
    layer = me.skin_vertices[0].data
    for i, j in enumerate(JOINTS):
        r = j[2]
        # légère asymétrie avant/arrière : torse aplati, membres ronds
        layer[i].radius = (r, r * (0.72 if j[0] in ("chest", "spine2", "pelvis", "spine1") else 0.95))
    layer[JMAP["pelvis"]].use_root = True

    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = sub.render_levels = 2

    dg = bpy.context.evaluated_depsgraph_get()
    baked = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    obj.modifiers.clear()
    obj.data = baked
    bpy.data.meshes.remove(me)
    return obj


# ==========================================================================
#  Crâne — c'est lui qui porte toute l'horreur : yeux recousus
# ==========================================================================
def _gauss(p, c, r):
    """Poids gaussien anisotrope : r est un rayon par axe."""
    dx = (p[0] - c[0]) / r[0]
    dy = (p[1] - c[1]) / r[1]
    dz = (p[2] - c[2]) / r[2]
    return math.exp(-(dx * dx + dy * dy + dz * dz) * 2.2)


def build_head():
    """
    Crâne sculpté sur une surface unique (sphère UV déformée) plutôt que
    composé de primitives : on obtient un volume cohérent, pas un tas de blobs.
    Repère local : origine au centre du crâne, +Y = avant, +Z = haut.
    """
    C = Vector((0.0, 0.182, 1.905))
    bm = B.bm_new()
    faces = B.sphere(bm, 1.0, 40, 28, center=(0, 0, 0), mat=0)
    verts = list({v for f in faces for v in f.verts})

    R = 0.098
    for v in verts:
        d = v.co.copy()
        d.normalize()
        p = Vector((d.x * 0.78, d.y * 1.02, d.z * 1.16)) * R

        # --- mâchoire fuyante : on resserre et on recule le bas du visage ---
        t = max(0.0, min(1.0, (-p.z / R - 0.05) / 0.95))
        p.x *= 1.0 - 0.42 * t * t
        p.y *= 1.0 - 0.30 * t * t
        p.y -= 0.020 * t * t
        # menton légèrement pointu
        p.y += 0.030 * _gauss(p, (0, 0.075, -0.085), (0.040, 0.10, 0.045))
        p.z -= 0.018 * _gauss(p, (0, 0.070, -0.090), (0.045, 0.10, 0.040))

        # --- occiput allongé vers l'arrière, calotte haute ---
        p.y -= 0.030 * _gauss(p, (0, -0.095, 0.045), (0.09, 0.07, 0.09))
        p.z += 0.022 * _gauss(p, (0, -0.020, 0.110), (0.08, 0.09, 0.05))

        # --- tempes creusées (donne le côté décharné) ---
        for sx in (-1, 1):
            w = _gauss(p, (sx * 0.078, 0.020, 0.040), (0.032, 0.055, 0.050))
            p.x -= sx * 0.022 * w
        # --- joues creusées sous les pommettes ---
        for sx in (-1, 1):
            w = _gauss(p, (sx * 0.060, 0.060, -0.048), (0.035, 0.050, 0.040))
            p.x -= sx * 0.016 * w
            p.y -= 0.014 * w

        # --- arcades sourcilières saillantes (une seule barre continue) ---
        brow = _gauss(p, (0, 0.086, 0.040), (0.085, 0.045, 0.020))
        p.y += 0.020 * brow
        p.z += 0.006 * brow

        # --- pommettes ---
        for sx in (-1, 1):
            w = _gauss(p, (sx * 0.062, 0.062, -0.008), (0.030, 0.045, 0.028))
            p.x += sx * 0.011 * w
            p.y += 0.010 * w

        # --- ORBITES : creusées profondément vers l'intérieur ---
        for sx in (-1, 1):
            w = _gauss(p, (sx * 0.044, 0.082, 0.008), (0.031, 0.050, 0.030))
            p.y -= 0.040 * w
            p.x -= sx * 0.006 * w

        # --- arête nasale + pointe ---
        nose = _gauss(p, (0, 0.090, 0.010), (0.014, 0.045, 0.052))
        p.y += 0.030 * nose
        tip = _gauss(p, (0, 0.098, -0.030), (0.017, 0.040, 0.016))
        p.y += 0.022 * tip
        for sx in (-1, 1):   # ailes du nez creusées
            p.y -= 0.016 * _gauss(p, (sx * 0.020, 0.092, -0.036), (0.012, 0.035, 0.014))

        # --- bouche : sillon rentrant, lèvres absentes ---
        p.y -= 0.017 * _gauss(p, (0, 0.080, -0.058), (0.040, 0.045, 0.009))
        p.y -= 0.008 * _gauss(p, (0, 0.078, -0.040), (0.038, 0.040, 0.012))

        v.co = p

    B.jitter(bm, verts, amount=0.0016, seed=31)

    # --- fond d'orbite : coquille sombre enfoncée, visible au fond du creux ---
    for sx in (-1, 1):
        B.sphere(bm, 0.027, 18, 12,
                 center=(sx * 0.044, 0.055, 0.008), scale=(1.05, 0.72, 0.92), mat=1)
    # --- bouche : cavité sombre ---
    B.sphere(bm, 0.030, 16, 10, center=(0, 0.056, -0.058), scale=(1.25, 0.45, 0.30), mat=1)

    # --- LES SUTURES : fils tendus en travers de chaque orbite ---
    for sx in (-1, 1):
        ex = sx * 0.044
        for k in range(6):
            t = (k - 2.5) * 0.0125
            # le fil traverse le creux : entrée haut, sortie bas
            y_in = 0.068 - abs(t) * 0.35
            B.tube(bm, 0.0022, 1, 4,
                   (ex + t * 1.05, y_in + 0.010, 0.030),
                   (ex + t * 0.75, y_in + 0.006, -0.018), mat=2)
            # points de couture : petits bourrelets là où le fil perce la peau
            B.sphere(bm, 0.0034, 6, 5, center=(ex + t * 1.05, y_in + 0.014, 0.031), mat=0)
            B.sphere(bm, 0.0034, 6, 5, center=(ex + t * 0.75, y_in + 0.010, -0.019), mat=0)
        # paupière tirée, plissée par la couture
        B.sphere(bm, 0.030, 14, 8, center=(ex, 0.062, 0.006), scale=(1.05, 0.26, 0.85), mat=0)

    # --- crâne rasé : cicatrice coronale recousue, en écho aux paupières ---
    import random
    rnd = random.Random(19)
    for k in range(17):
        u = (k / 16.0 - 0.5) * 2.0                      # -1 .. 1 d'une oreille à l'autre
        a = u * 1.30
        # la cicatrice suit la calotte d'une tempe à l'autre en passant au sommet
        px = math.sin(a) * 0.082
        pz = 0.070 + math.cos(a) * 0.052
        py = -0.012 - abs(u) * 0.018
        # le fil traverse la ligne de suture perpendiculairement
        n = Vector((px, py, pz)); n.normalize()
        t = Vector((math.cos(a) * 0.082, 0.0, -math.sin(a) * 0.052)); t.normalize()
        p0 = Vector((px, py, pz)) + t * 0.011 + n * 0.002
        p1 = Vector((px, py, pz)) - t * 0.011 + n * 0.002
        B.tube(bm, 0.0016, 1, 4, p0, p1, mat=2)
        B.sphere(bm, 0.0026, 6, 5, center=p0, mat=0)
        B.sphere(bm, 0.0026, 6, 5, center=p1, mat=0)
    # léger bourrelet le long de la cicatrice
    for k in range(13):
        u = (k / 12.0 - 0.5) * 2.0
        a = u * 1.30
        B.sphere(bm, 0.0058, 8, 6,
                 center=(math.sin(a) * 0.082, -0.012 - abs(u) * 0.018,
                         0.070 + math.cos(a) * 0.052),
                 scale=(1.0, 1.0, 0.55), mat=0)

    # recentrage dans le repère du personnage
    import bmesh as _bm
    _bm.ops.translate(bm, verts=list(bm.verts), vec=C)
    B.recalc_normals(bm)
    B.uv_world_box(bm, scale=0.30)
    return B.finish(bm, "veilleuse_head",
                    ["skin_pale", "grime_dark", "metal_rust", "hair_dark"],
                    smooth_angle=True)


# ==========================================================================
#  Blouse déchirée
# ==========================================================================
def build_gown():
    bm = B.bm_new()
    import random
    rnd = random.Random(23)
    # jupe conique, ourlet déchiqueté
    SEG = 32
    top_z, bot_z = 1.52, 0.50
    top_r, bot_r = 0.175, 0.225
    ring_t, ring_b = [], []
    for i in range(SEG):
        a = 2 * PI * i / SEG
        ca, sa = math.cos(a), math.sin(a)
        ring_t.append(bm.verts.new((ca * top_r, sa * top_r * 0.85 + 0.05, top_z)))
        # ourlet irrégulier : déchirures
        z = bot_z + (rnd.random() ** 1.8) * 0.30
        rr = bot_r * (0.92 + rnd.random() * 0.16)
        ring_b.append(bm.verts.new((ca * rr, sa * rr * 0.9 + 0.02, z)))
    for i in range(SEG):
        j = (i + 1) % SEG
        try:
            f = bm.faces.new((ring_t[i], ring_t[j], ring_b[j], ring_b[i]))
            f.material_index = 0
        except ValueError:
            pass
    # corsage
    B.sphere(bm, 0.163, 24, 14, center=(0, 0.075, 1.60), scale=(1.0, 0.80, 1.12), mat=0)
    # tablier
    B.box(bm, size=(0.26, 0.016, 0.52), center=(0, 0.205, 1.38), rot=(0.10, 0, 0), mat=0)
    for s in (-1, 1):   # bretelles
        B.box(bm, size=(0.045, 0.016, 0.30), center=(s * 0.085, 0.175, 1.70),
              rot=(0.12, 0, s * 0.16), mat=0)
    # manches courtes
    for s in (-1, 1):
        B.cylinder(bm, 0.075, 0.22, 14,
                   center=(s * 0.205, 0.050, 1.500), rot=(0.1, s * 0.38, 0), radius_top=0.058, mat=0)
    # ceinture
    B.torus(bm, 0.162, 0.016, 26, 6, center=(0, 0.055, 1.42), rot=(0.06, 0, 0), mat=1)
    B.recalc_normals(bm)
    B.uv_world_box(bm, scale=0.6)
    obj = B.finish(bm, "veilleuse_gown", ["cloth_gown", "metal_rust"], smooth_angle=True)
    # les faces de la jupe sont fines : on les rend visibles des deux côtés
    obj["double_sided"] = True
    return obj


# ==========================================================================
#  Armature
# ==========================================================================
BONES = [
    ("pelvis",   "pelvis",  "spine1",  None),
    ("spine1",   "spine1",  "spine2",  "pelvis"),
    ("spine2",   "spine2",  "chest",   "spine1"),
    ("chest",    "chest",   "neck",    "spine2"),
    ("neck",     "neck",    "head",    "chest"),
    ("head",     "head",    None,      "neck"),
    ("clav_L",   "chest",   "clav_L",  "chest"),
    ("upperarm_L", "clav_L", "elbow_L", "clav_L"),
    ("forearm_L", "elbow_L", "wrist_L", "upperarm_L"),
    ("hand_L",   "wrist_L", "hand_L",  "forearm_L"),
    ("clav_R",   "chest",   "clav_R",  "chest"),
    ("upperarm_R", "clav_R", "elbow_R", "clav_R"),
    ("forearm_R", "elbow_R", "wrist_R", "upperarm_R"),
    ("hand_R",   "wrist_R", "hand_R",  "forearm_R"),
    ("thigh_L",  "pelvis",  "knee_L",  "pelvis"),
    ("shin_L",   "knee_L",  "ankle_L", "thigh_L"),
    ("foot_L",   "ankle_L", "toe_L",   "shin_L"),
    ("thigh_R",  "pelvis",  "knee_R",  "pelvis"),
    ("shin_R",   "knee_R",  "ankle_R", "thigh_R"),
    ("foot_R",   "ankle_R", "toe_R",   "shin_R"),
]


def build_armature():
    pos = {j[0]: Vector(j[1]) for j in JOINTS}
    arm_data = bpy.data.armatures.new("veilleuse_rig")
    arm = B.link(bpy.data.objects.new("veilleuse_rig", arm_data))
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    for bname, head, tail, parent in BONES:
        b = eb.new(bname)
        b.head = pos[head]
        b.tail = pos[tail] if tail else pos[head] + Vector((0, 0.02, 0.135))
        if (b.tail - b.head).length < 1e-4:
            b.tail = b.head + Vector((0, 0, 0.05))
        b.use_connect = False
    for bname, head, tail, parent in BONES:
        if parent:
            eb[bname].parent = eb[parent]
    # Roll uniforme : on aligne l'axe Z local de chaque os sur l'avant du
    # personnage (+Y). Conséquence : une rotation +X fait TOUJOURS partir l'os
    # vers l'avant, quel que soit son orientation de repos. Sans ça, chaque
    # membre tourne dans un plan différent (bras qui montent au lieu d'avancer).
    FWD = Vector((0.0, 1.0, 0.0))
    UP = Vector((0.0, 0.0, 1.0))
    for b in eb:
        d = (b.tail - b.head).normalized()
        # si l'os est déjà quasi parallèle à l'avant (les pieds), le repère
        # serait dégénéré : on prend la verticale comme référence.
        b.align_roll(UP if abs(d.dot(FWD)) > 0.9 else FWD)
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def bind(meshes, arm):
    """Lie les maillages à l'armature (poids automatiques, repli sur distance)."""
    for m in meshes:
        m.select_set(False)
    for m in meshes:
        m.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        return "auto"
    except Exception:
        pass
    # --- repli : pondération par distance au segment osseux ---
    pos = {j[0]: Vector(j[1]) for j in JOINTS}
    segs = [(n, pos[h], pos[t] if t else pos[h] + Vector((0, 0.02, 0.135)))
            for n, h, t, _ in BONES]

    def dist_seg(p, a, b):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
        return (p - (a + ab * t)).length

    for m in meshes:
        for n, _, _ in segs:
            if n not in m.vertex_groups:
                m.vertex_groups.new(name=n)
        for v in m.data.vertices:
            p = m.matrix_world @ v.co
            ds = sorted(((dist_seg(p, a, b), n) for n, a, b in segs))[:3]
            w = [(1.0 / (d + 0.02) ** 3, n) for d, n in ds]
            tot = sum(x[0] for x in w)
            for val, n in w:
                m.vertex_groups[n].add([v.index], val / tot, "REPLACE")
        mod = m.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        m.parent = arm
    return "fallback"


# ==========================================================================
#  Animation
# ==========================================================================
FPS = 30


def _pose(arm, d, frame):
    """Applique un dict {os: (rx,ry,rz)} (+ 'ROOT_LOC') et pose les clés."""
    for bname, val in d.items():
        if bname == "ROOT_LOC":
            pb = arm.pose.bones["pelvis"]
            pb.location = val
            pb.keyframe_insert("location", frame=frame)
            continue
        pb = arm.pose.bones.get(bname)
        if pb is None:
            continue
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = val
        pb.keyframe_insert("rotation_euler", frame=frame)


def _all_bones_zero():
    return {b[0]: (0.0, 0.0, 0.0) for b in BONES}


def _action_fcurves(act):
    """Accès aux F-curves compatible Blender <=4.3 (act.fcurves) et >=4.4 (slots)."""
    if hasattr(act, "fcurves"):
        return list(act.fcurves)
    out = []
    for layer in act.layers:
        for strip in layer.strips:
            for cb in getattr(strip, "channelbags", []):
                out.extend(cb.fcurves)
    return out


def make_action(arm, name, keys, loop=True):
    """keys = [(frame, {os: rotation}), ...]. Retourne l'action créée."""
    if arm.animation_data is None:
        arm.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    # état neutre sur toutes les clés pour éviter les os non pilotés
    base = _all_bones_zero()
    for frame, pose in keys:
        full = dict(base)
        full.update(pose)
        _pose(arm, full, frame)
    for fc in _action_fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            kp.easing = "AUTO"
    arm.animation_data.action = None
    return act


def _leg(side, swing, knee, foot=0.0):
    """swing>0 = cuisse vers l'avant ; knee<0 = genou plié (talon vers l'arrière)."""
    s = "_L" if side > 0 else "_R"
    return {f"thigh{s}": (swing, 0, 0), f"shin{s}": (knee, 0, 0), f"foot{s}": (foot, 0, 0)}


def _arm(side, sh, el, hand=0.0, out=0.0):
    """sh>0 = épaule vers l'avant ; el>0 = coude plié, main vers l'avant."""
    s = "_L" if side > 0 else "_R"
    return {f"upperarm{s}": (sh, 0, out * side), f"forearm{s}": (el, 0, 0),
            f"hand{s}": (hand, 0, 0)}


# Somme des coefficients d'inclinaison répartis sur la colonne : sert à savoir
# de combien la tête part vers l'avant quand on voûte le dos, pour la redresser.
SPINE_SUM = 0.10 + 0.30 + 0.45 + 0.30


def _posture(hunch, head_world=0.0, yaw=0.0, tilt=0.0):
    """
    hunch      : intensité du dos voûté (0 = droit, 1 = plié en deux)
    head_world : orientation FINALE de la tête dans le monde
                 (0 = horizontale, <0 = regard relevé, >0 = regard au sol)
    La correction nuque+crâne est calculée pour annuler l'inclinaison du dos :
    on obtient le corps ployé mais le visage tendu vers l'avant, qui est la
    silhouette voulue — et non une créature qui fixe ses pieds.
    """
    corr = head_world - hunch * SPINE_SUM
    return {
        "pelvis": (hunch * 0.10, yaw * 0.20, tilt * 0.50),
        "spine1": (hunch * 0.30, yaw * 0.18, tilt * 0.80),
        "spine2": (hunch * 0.45, yaw * 0.14, tilt * 0.60),
        "chest":  (hunch * 0.30, yaw * 0.24, tilt * 0.50),
        "neck":   (corr * 0.38, yaw * 0.34, 0.0),
        "head":   (corr * 0.62, yaw * 0.52, tilt * 0.60),
    }


def anim_idle(arm):
    """À l'arrêt, à l'écoute. Le buste respire, la tête balaye lentement."""
    K = []
    for i, f in enumerate((1, 30, 60, 90, 120)):
        ph = i / 4.0 * 2 * PI
        d = _posture(0.36 + 0.04 * math.sin(ph), -0.06 + 0.03 * math.sin(ph),
                     yaw=0.30 * math.sin(ph * 0.5))
        d["ROOT_LOC"] = (0, 0.004 * math.sin(ph * 2), 0)
        d.update(_arm(1, 0.03 * math.sin(ph), 0.16, 0.04, 0.04))
        d.update(_arm(-1, 0.03 * math.sin(ph + 0.5), 0.16, 0.04, 0.04))
        d.update(_leg(1, 0, -0.04))
        d.update(_leg(-1, 0, -0.04))
        K.append((f, d))
    return make_action(arm, "idle", K)


def anim_walk(arm):
    """Patrouille : pas long et traînant, bras ballants qui contre-balancent."""
    K = []
    N = 8
    for i in range(N + 1):
        f = 1 + i * 6                               # 48 images ~ 1,6 s
        ph = (i % N) / N * 2 * PI
        sw = math.sin(ph)
        d = _posture(0.42, -0.04, yaw=0.18 * math.sin(ph * 0.5), tilt=0.10 * sw)
        d["ROOT_LOC"] = (0, -0.018 + 0.018 * abs(math.cos(ph)), 0)
        for sgn in (1, -1):
            p = ph if sgn > 0 else ph + PI
            d.update(_leg(sgn,
                          0.42 * math.sin(p),                                # cuisse
                          -0.10 - 0.60 * max(0.0, math.sin(p - 0.9)),        # genou
                          0.14 * math.cos(p)))                               # cheville
        d.update(_arm(1, -0.24 * sw, 0.20, 0.06, 0.05))
        d.update(_arm(-1, 0.24 * sw, 0.20, 0.06, 0.05))
        K.append((f, d))
    return make_action(arm, "walk", K)


def anim_hunt(arm):
    """Chasse : course désarticulée, buste plongeant, bras tendus vers l'avant."""
    K = []
    N = 6
    for i in range(N + 1):
        f = 1 + i * 4                               # 24 images = 0,8 s
        ph = (i % N) / N * 2 * PI
        sw = math.sin(ph)
        d = _posture(0.58, -0.10, tilt=0.16 * sw)
        d["ROOT_LOC"] = (0, -0.05 + 0.04 * abs(math.cos(ph)), 0)
        for sgn in (1, -1):
            p = ph if sgn > 0 else ph + PI
            d.update(_leg(sgn,
                          0.80 * math.sin(p),
                          -0.24 - 1.00 * max(0.0, math.sin(p - 0.7)),
                          0.22 * math.cos(p)))
        # les deux bras tendus devant, coudes à peine fléchis, mains en crochet
        d.update(_arm(1, 1.05 + 0.16 * sw, 0.34, 0.35, 0.24))
        d.update(_arm(-1, 1.05 - 0.16 * sw, 0.34, 0.35, 0.24))
        K.append((f, d))
    return make_action(arm, "hunt", K)


def anim_listen(arm):
    """Investigation : le corps se fige, la tête pivote par à-coups secs."""
    K = []
    seq = [(1, 0.0, -0.12), (12, 0.0, -0.12), (16, -0.75, -0.06), (46, -0.75, -0.06),
           (52, 0.68, -0.20), (84, 0.68, -0.20), (90, 0.0, -0.12), (110, 0.0, -0.12)]
    for f, yaw, pitch in seq:
        d = _posture(0.36, pitch, yaw=yaw)
        d.update(_arm(1, 0.02, 0.14, 0, 0.03))
        d.update(_arm(-1, 0.02, 0.14, 0, 0.03))
        d.update(_leg(1, 0, -0.04))
        d.update(_leg(-1, 0, -0.04))
        K.append((f, d))
    return make_action(arm, "listen", K)


def anim_attack(arm):
    """Saisie : armé bref, puis détente des deux bras droit vers le joueur."""
    K = []
    #        image  buste  épaule  coude   tête
    seq = [(1,     0.50,  0.65,   0.50,  -0.08),
           (6,     0.62,  0.20,   1.30,   0.10),   # armé : les bras se replient
           (12,    0.20,  1.42,   0.14,  -0.16),   # détente : bras droit devant
           (20,    0.16,  1.50,   0.10,  -0.20),
           (30,    0.44,  0.95,   0.45,  -0.04)]
    for f, hunch, sh, el, hd in seq:
        d = _posture(hunch, hd)
        d.update(_arm(1, sh, el, 0.55, 0.34))
        d.update(_arm(-1, sh, el, 0.55, 0.34))
        d.update(_leg(1, 0.24, -0.34))
        d.update(_leg(-1, -0.20, -0.22))
        K.append((f, d))
    return make_action(arm, "attack", K, loop=False)


def push_nla(arm, actions):
    """Range chaque action sur sa propre piste NLA -> une animation glTF par action."""
    ad = arm.animation_data
    ad.action = None
    for i, act in enumerate(actions):
        tr = ad.nla_tracks.new()
        tr.name = act.name
        tr.strips.new(act.name, 1, act)
        tr.mute = True


# ==========================================================================
def build():
    B.scene_reset()
    body = build_body()
    head = build_head()
    gown = build_gown()
    arm = build_armature()
    mode = bind([body, head, gown], arm)
    acts = [anim_idle(arm), anim_walk(arm), anim_hunt(arm),
            anim_listen(arm), anim_attack(arm)]
    push_nla(arm, acts)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "veilleuse.glb")
    B.export_glb([arm, body, head, gown], path, anim=True)
    return path, mode, B.tri_count([body, head, gown]), [a.name for a in acts]


if __name__ == "__main__":
    p, mode, tris, names = build()
    print(f"  veilleuse.glb  {tris} tris  liaison={mode}  anims={names}")
    print(f"  {os.path.getsize(p)/1024:.1f} KB -> {p}")
