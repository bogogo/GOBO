"""GOBO logo generator.

Usage:
  Blender -b --factory-startup -P gobo_logo.py -- <concept> <variant> [samples]
    concept: twolights | gobo | orb
    variant: wordmark | icon
Writes renders/<concept>_<variant>.png and blend/<concept>_<variant>.blend
"""
import bpy, sys, math, os
from mathutils import Vector

ROOT = "/Users/bogogo/CLAUDE/GOBO_Logo"
FONT_PATH = "/System/Library/Fonts/Supplemental/Futura.ttc"  # Futura Medium

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
CONCEPT = argv[0] if argv else "twolights"
VARIANT = argv[1] if len(argv) > 1 else "icon"
SAMPLES = int(argv[2]) if len(argv) > 2 else 128

# Brand palette (linear-ish RGB)
BG = (0.010, 0.011, 0.014)
WARM = (1.0, 0.55, 0.22)          # ~2700K warm white
LETTER = (0.82, 0.82, 0.84)
SPECTRUM = [  # curated hue ring: warm -> magenta -> violet -> blue -> cyan -> green -> warm
    (0.00, (1.00, 0.45, 0.10)),
    (0.18, (1.00, 0.10, 0.35)),
    (0.36, (0.55, 0.12, 1.00)),
    (0.54, (0.10, 0.35, 1.00)),
    (0.70, (0.05, 0.85, 0.95)),
    (0.86, (0.35, 1.00, 0.35)),
    (1.00, (1.00, 0.45, 0.10)),
]


# ---------------------------------------------------------------- scene setup
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def setup_render(w, h):
    sc = bpy.context.scene
    try:
        sc.render.engine = 'CYCLES'
    except TypeError as e:
        print("engine:", e)
    prefs = bpy.context.preferences.addons['cycles'].preferences
    try:
        prefs.compute_device_type = 'METAL'
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = 'GPU'
    except Exception as e:
        print("gpu:", e)
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGB'
    sc.view_settings.view_transform = 'AgX'
    looks = [i.identifier for i in sc.view_settings.bl_rna.properties['look'].enum_items]
    for want in ('AgX - Medium High Contrast', 'AgX - Punchy'):
        if want in looks:
            sc.view_settings.look = want
            break
    world = bpy.data.worlds.new("World")
    sc.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs[0].default_value = (*BG, 1)
    bg.inputs[1].default_value = 1.0


def add_glare(threshold=1.0, strength=0.6, size=0.75):
    sc = bpy.context.scene
    sc.use_nodes = True
    nt = sc.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    rl = nt.nodes.new('CompositorNodeRLayers')
    g = nt.nodes.new('CompositorNodeGlare')
    comp = nt.nodes.new('CompositorNodeComposite')
    g.glare_type = 'BLOOM'
    g.quality = 'HIGH'
    for name, val in (('Threshold', threshold), ('Strength', strength), ('Size', size)):
        if name in g.inputs:
            g.inputs[name].default_value = val
    nt.links.new(rl.outputs['Image'], g.inputs['Image'])
    nt.links.new(g.outputs[0], comp.inputs['Image'])


def ortho_camera(scale, loc=(0, -20, 0), rot=(90, 0, 0)):
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = scale
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = loc
    cam.rotation_euler = [math.radians(a) for a in rot]
    bpy.context.scene.camera = cam
    return cam


def persp_camera(lens, loc, target):
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = lens
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = cam
    return cam


def area_light(name, loc, target, energy, size, color=(1, 1, 1)):
    ld = bpy.data.lights.new(name, 'AREA')
    ld.energy, ld.size, ld.color = energy, size, color
    ob = bpy.data.objects.new(name, ld)
    bpy.context.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    return ob


# ---------------------------------------------------------------- materials
def _clear(m):
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    return nt, nt.nodes.new('ShaderNodeOutputMaterial')


def mat_surface(name, color, rough=0.45, metal=0.0, coat=0.0, aniso=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    b.inputs['Coat Weight'].default_value = coat
    if aniso:
        b.inputs['Anisotropic'].default_value = aniso
    return m


def mat_emit(name, color, strength):
    m = bpy.data.materials.new(name)
    nt, out = _clear(m)
    e = nt.nodes.new('ShaderNodeEmission')
    e.inputs['Color'].default_value = (*color, 1)
    e.inputs['Strength'].default_value = strength
    nt.links.new(e.outputs[0], out.inputs[0])
    return m


def _ramp(nt, stops):
    r = nt.nodes.new('ShaderNodeValToRGB')
    els = r.color_ramp.elements
    while len(els) > 1:
        els.remove(els[-1])
    els[0].position, els[0].color = stops[0][0], (*stops[0][1], 1)
    for pos, col in stops[1:]:
        e = els.new(pos)
        e.color = (*col, 1)
    return r


def mat_gradient_emit(name, stops, strength, gtype='RADIAL', axis_rot=0.0):
    """Emission whose color sweeps a ramp around (RADIAL) or along (LINEAR) local coords."""
    m = bpy.data.materials.new(name)
    nt, out = _clear(m)
    tc = nt.nodes.new('ShaderNodeTexCoord')
    mp = nt.nodes.new('ShaderNodeMapping')
    mp.inputs['Rotation'].default_value[2] = axis_rot
    gr = nt.nodes.new('ShaderNodeTexGradient')
    gr.gradient_type = gtype
    r = _ramp(nt, stops)
    e = nt.nodes.new('ShaderNodeEmission')
    e.inputs['Strength'].default_value = strength
    nt.links.new(tc.outputs['Object'], mp.inputs['Vector'])
    nt.links.new(mp.outputs['Vector'], gr.inputs['Vector'])
    nt.links.new(gr.outputs['Fac'], r.inputs['Fac'])
    nt.links.new(r.outputs['Color'], e.inputs['Color'])
    nt.links.new(e.outputs[0], out.inputs[0])
    return m


def assign(ob, m):
    ob.data.materials.clear()
    ob.data.materials.append(m)


# ---------------------------------------------------------------- geometry
_font = None


def font():
    global _font
    if _font is None:
        _font = bpy.data.fonts.load(FONT_PATH)
    return _font


def text_obj(body, size=1.0, extrude=0.03, bevel=0.006, to_mesh=False):
    cu = bpy.data.curves.new(body, 'FONT')
    cu.body = body
    cu.font = font()
    cu.size = size
    cu.extrude = extrude
    cu.bevel_depth = bevel
    cu.bevel_resolution = 3
    cu.resolution_u = 24
    ob = bpy.data.objects.new(body, cu)
    bpy.context.collection.objects.link(ob)
    ob.rotation_euler = (math.radians(90), 0, 0)  # stand up, face -Y (camera)
    bpy.context.view_layer.update()
    if to_mesh:
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.convert(target='MESH')
        ob.select_set(False)
    return ob


def world_bbox(ob):
    bpy.context.view_layer.update()
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def ring(R, r, loc=(0, 0, 0)):
    """Upright torus facing the camera (axis along Y)."""
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r,
                                     major_segments=192, minor_segments=40,
                                     location=loc, rotation=(math.radians(90), 0, 0))
    ob = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    return ob


def backdrop(y=0.6, size=40, color=(0.018, 0.019, 0.024), rough=0.6):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, y, 0), rotation=(math.radians(90), 0, 0))
    ob = bpy.context.active_object
    assign(ob, mat_surface("Backdrop", color, rough=rough))
    return ob


def letter_metrics():
    """Cap height and stroke of Futura Medium at size 1."""
    t = text_obj("H", extrude=0)
    mn, mx = world_bbox(t)
    cap = mx.z - mn.z
    bpy.data.objects.remove(t)
    return cap, cap * 0.155


# ---------------------------------------------------------------- concepts
def build_wordmark_twolights():
    """G and B in satin white; the two O's are light rings: warm white + full color."""
    cap, stroke = letter_metrics()
    R = cap * 0.5 - stroke * 0.5 + cap * 0.02  # optical overshoot
    gap = cap * 0.16
    letter_m = mat_surface("Letter", LETTER, rough=0.35, coat=0.3)
    parts = []
    x = 0.0
    for kind in ("G", "O1", "B", "O2"):
        if kind in ("G", "B"):
            ob = text_obj(kind, extrude=0.04, bevel=0.008)
            assign(ob, letter_m)
            mn, mx = world_bbox(ob)
            ob.location.x += x - mn.x
            ob.location.z += -mn.z
            x += (mx.x - mn.x) + gap
        else:
            d = 2 * (R + stroke / 2)
            ob = ring(R, stroke / 2, loc=(x + d / 2, 0, cap / 2))
            if kind == "O1":
                assign(ob, mat_emit("WarmLight", WARM, 3.2))
            else:
                assign(ob, mat_gradient_emit("ColorLight", SPECTRUM, 3.2, axis_rot=math.radians(90)))
            x += d + gap
        parts.append(ob)
    total = x - gap
    for ob in parts:
        ob.location.x -= total / 2
        ob.location.z -= cap / 2
    return total, cap


def build_icon_twolights():
    """Two overlapping light rings: warm white and full color."""
    R, r = 1.0, 0.16
    a = ring(R, r, loc=(-0.62, 0, 0))
    assign(a, mat_emit("WarmLight", WARM, 3.2))
    b = ring(R, r, loc=(0.62, -0.5, 0))
    assign(b, mat_gradient_emit("ColorLight", SPECTRUM, 3.2, axis_rot=math.radians(90)))


def gobo_disc(radius=1.0, depth=0.08):
    """Graphite metal disc with a G cut through it, backlit by a warm-to-color glow."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=256, radius=radius, depth=depth,
                                        rotation=(math.radians(90), 0, 0))
    disc = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    cutter = text_obj("G", size=1.0, extrude=0.5, bevel=0, to_mesh=True)
    mn, mx = world_bbox(cutter)
    s = (radius * 1.12) / (mx.z - mn.z)
    cutter.scale = (s, s, s)
    mn, mx = world_bbox(cutter)
    cutter.location -= (mn + mx) / 2
    mod = disc.modifiers.new("Cut", 'BOOLEAN')
    mod.operation, mod.solver, mod.object = 'DIFFERENCE', 'EXACT', cutter
    bpy.context.view_layer.objects.active = disc
    bpy.ops.object.modifier_apply(modifier="Cut")
    bpy.data.objects.remove(cutter)
    bev = disc.modifiers.new("Bevel", 'BEVEL')
    bev.width, bev.segments, bev.limit_method = 0.006, 3, 'ANGLE'
    wn = disc.modifiers.new("WeightedNormal", 'WEIGHTED_NORMAL')
    wn.keep_sharp = True
    disc.select_set(True)
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
    except Exception as e:
        print("autosmooth:", e)
    assign(disc, mat_surface("Graphite", (0.06, 0.062, 0.07), rough=0.38, metal=1.0))
    # glowing panel just behind the cutout
    bpy.ops.mesh.primitive_circle_add(vertices=128, radius=radius * 0.98, fill_type='NGON',
                                      location=(0, depth / 2 + 0.03, 0),
                                      rotation=(math.radians(90), 0, 0))
    glow = bpy.context.active_object
    assign(glow, mat_gradient_emit("GoboGlow", [
        (0.0, (1.0, 0.50, 0.18)), (0.45, (1.0, 0.30, 0.45)),
        (0.75, (0.45, 0.25, 1.0)), (1.0, (0.10, 0.75, 1.0))],
        4.0, gtype='LINEAR', axis_rot=math.radians(45)))
    glow.scale = (1, 1, 1)
    # rescale linear gradient (0..1) across the disc
    mp = next(n for n in glow.active_material.node_tree.nodes if n.type == 'MAPPING')
    mp.inputs['Scale'].default_value = (0.5 / radius, 0.5 / radius, 1)
    mp.inputs['Location'].default_value = (0.5, 0, 0)
    return disc, glow


def build_icon_gobo():
    disc, glow = gobo_disc()
    for ob in (disc, glow):
        ob.rotation_euler.z = math.radians(-18)
    # halo on the wall behind
    backdrop(y=1.2, color=(0.02, 0.021, 0.026))
    pl = bpy.data.lights.new("Halo", 'POINT')
    pl.energy, pl.color, pl.shadow_soft_size = 160, (1.0, 0.55, 0.35), 0.3
    ob = bpy.data.objects.new("Halo", pl)
    bpy.context.collection.objects.link(ob)
    ob.location = (0, 0.35, 0)
    area_light("Key", (-3, -4, 4), (0, 0, 0), 250, 3)
    area_light("Rim", (4, -1, -2), (0, 0, 0), 120, 2, color=(0.6, 0.7, 1.0))


def build_wordmark_gobo():
    disc, glow = gobo_disc(radius=0.62)
    cap, _ = letter_metrics()
    t = text_obj("GOBO", size=1.0, extrude=0.03, bevel=0.006)
    t.data.space_character = 1.12
    assign(t, mat_surface("Letter", LETTER, rough=0.35, coat=0.3))
    mn, mx = world_bbox(t)
    gap = 0.45
    total = 1.24 + gap + (mx.x - mn.x)
    disc.location.x = glow.location.x = -total / 2 + 0.62
    t.location.x += (-total / 2 + 1.24 + gap) - mn.x
    t.location.z += -(mn.z + mx.z) / 2
    backdrop(y=1.0)
    area_light("Key", (-3, -6, 4), (0, 0, 0), 300, 4)
    area_light("Rim", (4, -1, -2), (0, 0, 0), 100, 2, color=(0.6, 0.7, 1.0))
    return total, 1.3


def orb(radius=1.0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=radius)
    ob = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    m = bpy.data.materials.new("OrbLight")
    nt, out = _clear(m)
    tc = nt.nodes.new('ShaderNodeTexCoord')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    mr = nt.nodes.new('ShaderNodeMapRange')
    mr.inputs['From Min'].default_value, mr.inputs['From Max'].default_value = -radius, radius
    r = _ramp(nt, [(0.0, (1.0, 0.48, 0.16)), (0.45, (1.0, 0.25, 0.45)),
                   (0.75, (0.45, 0.22, 1.0)), (1.0, (0.15, 0.7, 1.0))])
    lw = nt.nodes.new('ShaderNodeLayerWeight')
    lw.inputs['Blend'].default_value = 0.35
    inv = nt.nodes.new('ShaderNodeMath')
    inv.operation = 'SUBTRACT'
    inv.inputs[0].default_value = 1.0
    mul = nt.nodes.new('ShaderNodeMath')
    mul.operation = 'MULTIPLY'
    mul.inputs[1].default_value = 2.6
    e = nt.nodes.new('ShaderNodeEmission')
    glass = nt.nodes.new('ShaderNodeBsdfPrincipled')
    glass.inputs['Base Color'].default_value = (0.9, 0.9, 0.92, 1)
    glass.inputs['Roughness'].default_value = 0.15
    glass.inputs['Coat Weight'].default_value = 1.0
    add = nt.nodes.new('ShaderNodeAddShader')
    L = nt.links.new
    L(tc.outputs['Object'], sep.inputs[0])
    L(sep.outputs['Z'], mr.inputs['Value'])
    L(mr.outputs['Result'], r.inputs['Fac'])
    L(r.outputs['Color'], e.inputs['Color'])
    L(lw.outputs['Facing'], inv.inputs[1])
    L(inv.outputs[0], mul.inputs[0])
    L(mul.outputs[0], e.inputs['Strength'])
    L(e.outputs[0], add.inputs[0])
    L(glass.outputs[0], add.inputs[1])
    L(add.outputs[0], out.inputs[0])
    assign(ob, m)
    return ob


def glossy_floor(z):
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, z))
    fl = bpy.context.active_object
    assign(fl, mat_surface("Floor", (0.012, 0.013, 0.016), rough=0.12, coat=0.6))
    return fl


def build_icon_orb():
    o = orb(1.0)
    o.location.z = 1.0
    glossy_floor(0.0)
    area_light("Key", (-3, -4, 6), (0, 0, 1), 120, 4)
    persp_camera(70, (0, -7.2, 1.55), (0, 0, 0.92))


def build_wordmark_orb():
    o = orb(0.55)
    cap, _ = letter_metrics()
    t = text_obj("GOBO", size=1.0, extrude=0.03, bevel=0.006)
    t.data.space_character = 1.12
    assign(t, mat_surface("Letter", LETTER, rough=0.35, coat=0.3))
    mn, mx = world_bbox(t)
    gap = 0.45
    total = 1.1 + gap + (mx.x - mn.x)
    o.location.x = -total / 2 + 0.55
    t.location.x += (-total / 2 + 1.1 + gap) - mn.x
    t.location.z += -(mn.z + mx.z) / 2
    backdrop(y=1.0)
    area_light("Key", (-3, -6, 4), (0, 0, 0), 300, 4)
    return total, 1.2


# ---------------------------------------------------------------- main
def main():
    reset()
    if VARIANT == "icon":
        setup_render(1024, 1024)
        if CONCEPT == "twolights":
            build_icon_twolights()
            backdrop(y=1.5, color=(0.008, 0.009, 0.011))
            ortho_camera(4.6)
        elif CONCEPT == "gobo":
            build_icon_gobo()
            persp_camera(85, (0.4, -7.5, 0.6), (0, 0, 0))
        elif CONCEPT == "orb":
            build_icon_orb()
        add_glare(threshold=1.0, strength=0.35, size=0.6)
    elif VARIANT == "clear":
        # transparent, tightly cropped wordmark for use inside the app
        setup_render(1600, 400)
        bpy.context.scene.render.film_transparent = True
        bpy.context.scene.render.image_settings.color_mode = 'RGBA'
        if CONCEPT != "twolights":
            raise SystemExit("clear variant only built for twolights")
        total, h = build_wordmark_twolights()
        area_light("Key", (-2, -8, 5), (0, 0, 0), 500, 6)
        sc = bpy.context.scene
        sc.render.resolution_y = round(1600 * (h * 1.16) / (total * 1.04))
        ortho_camera(total * 1.04)
    else:
        setup_render(2400, 1000)
        if CONCEPT == "twolights":
            total, h = build_wordmark_twolights()
            backdrop(y=1.5, color=(0.008, 0.009, 0.011))
            area_light("Key", (-2, -8, 5), (0, 0, 0), 500, 6)
        elif CONCEPT == "gobo":
            total, h = build_wordmark_gobo()
        elif CONCEPT == "orb":
            total, h = build_wordmark_orb()
        ortho_camera(total * 1.45)
        add_glare(threshold=1.0, strength=0.3, size=0.55)
    name = f"{CONCEPT}_{VARIANT}"
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(ROOT, "renders", name + ".png")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blend", name + ".blend"))
    bpy.ops.render.render(write_still=True)
    print("WROTE", sc.render.filepath)


main()
