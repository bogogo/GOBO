"""Looping background animation of the Two Lights mark.

Usage:
  Blender -b --factory-startup -P gobo_anim.py -- [samples] [render]
Writes blend/twolights_loop.blend and, with "render", frames to renders/loop/####.png
"""
import bpy, sys, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "gobo_logo.py")).read()
src = src[:src.rindex("\nmain()")]  # reuse helpers without running the still renders
exec(compile(src, "gobo_logo.py", "exec"))

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SAMPLES_ANIM = int(args[0]) if args else 48
DO_RENDER = "render" in sys.argv[sys.argv.index("--"):] if "--" in sys.argv else False

FPS, SECONDS = 30, 8
FRAMES = FPS * SECONDS


def key_loop(ob, path, index, values):
    """Keyframe values evenly across the loop; last value must equal first."""
    for i, v in enumerate(values):
        f = 1 + round(i * FRAMES / (len(values) - 1))
        prop = getattr(ob, path)
        prop[index] = v
        ob.keyframe_insert(path, index=index, frame=f)


def linear(idblock):
    ad = idblock.animation_data
    for fc in ad.action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = 'LINEAR'


def build():
    reset()
    setup_render(720, 1280)
    sc = bpy.context.scene
    sc.cycles.samples = SAMPLES_ANIM
    sc.render.fps = FPS
    sc.frame_start, sc.frame_end = 1, FRAMES

    R, r = 1.0, 0.16
    warm = ring(R, r, loc=(0, 0, 0.62))
    assign(warm, mat_emit("WarmLight", WARM, 3.2))
    color = ring(R, r, loc=(0, -0.5, -0.62))
    cm = mat_gradient_emit("ColorLight", SPECTRUM, 3.2, axis_rot=math.radians(90))
    assign(color, cm)
    backdrop(y=1.5, color=(0.008, 0.009, 0.011))
    ortho_camera(6.4)

    # each ring sways gently about the vertical axis, half a cycle apart
    for ob, phase in ((warm, 0.0), (color, math.pi)):
        steps = 24
        key_loop(ob, "rotation_euler", 2,
                 [0.45 * math.sin(phase + 2 * math.pi * i / steps) for i in range(steps + 1)])
        linear(ob)

    # colors flow around the color ring once per loop
    mp = next(n for n in cm.node_tree.nodes if n.type == 'MAPPING')
    sock = mp.inputs['Rotation']
    for i in range(5):
        sock.default_value[2] = math.radians(90) + 2 * math.pi * i / 4
        sock.keyframe_insert("default_value", index=2, frame=1 + i * FRAMES // 4)
    linear(cm.node_tree)

    # warm ring breathes twice per loop
    em = next(n for n in warm.active_material.node_tree.nodes if n.type == 'EMISSION')
    for i, s in enumerate([3.2, 1.8, 3.2, 1.8, 3.2]):
        em.inputs['Strength'].default_value = s
        em.inputs['Strength'].keyframe_insert("default_value", frame=1 + i * FRAMES // 4)

    add_glare(threshold=1.0, strength=0.35, size=0.6)
    os.makedirs(os.path.join(ROOT, "renders", "loop"), exist_ok=True)
    sc.render.filepath = os.path.join(ROOT, "renders", "loop", "####")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blend", "twolights_loop.blend"))


build()
if DO_RENDER:
    # frame FRAMES+1 would equal frame 1, so the clip ends one frame early to loop seamlessly
    bpy.context.scene.frame_end = FRAMES
    bpy.ops.render.render(animation=True)
