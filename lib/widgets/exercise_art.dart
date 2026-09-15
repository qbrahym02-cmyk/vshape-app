library;

/// Vector illustrations for every exercise in the plan.
///
/// Why hand-drawn instead of pictures?
///   * 0 KB of assets  -> the APK does not grow, and the content file stays
///     small enough to update over mobile data.
///   * Crisp at any size, and the colours follow the app theme (light/dark).
///   * The poses are part of the *app*, while the exercise text stays part of
///     the remote `content.json` - so content updates never break a picture.
///
/// Coordinate space: a 100 x 100 box, `y = 100` is the floor, and the figure
/// always faces right. Everything is scaled to fit.

import 'dart:math' as math;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Pose data
// ---------------------------------------------------------------------------

class _Pose {
  /// Limb / torso segments: [x1, y1, x2, y2] in the 100x100 space.
  final List<List<double>> lines;

  /// Extra circles: [x, y, r].
  final List<List<double>> dots;

  /// Head: [x, y, r].
  final List<double> head;

  /// Named anchors used to place the equipment (backpack, bottles, bench...).
  final Map<String, List<double>> anchors;

  /// Equipment drawn on top of the figure.
  final List<_Prop> props;


  const _Pose({
    required this.lines,
    required this.head,
    this.dots = const [],
    this.anchors = const {},
    this.props = const [],
  });
}

class _Prop {
  /// 'pack' | 'bottle' | 'table' | 'bench' | 'chair' | 'door' | 'floorPad'
  final String kind;

  /// Anchor name the prop is positioned relative to, or 'abs' for raw coords.
  final String at;

  /// Offset from the anchor, in pose units.
  final double dx;
  final double dy;

  /// Size multiplier (bottles, packs).
  final double scale;

  const _Prop(this.kind, {this.at = 'abs', this.dx = 0, this.dy = 0, this.scale = 1});
}

const _Pose _pikePushup = _Pose(
  head: [22.0, 62.0, 6.5],
  lines: [
    [30.0, 59.0, 52.0, 32.0], // torso up to the hips
    [30.0, 59.0, 26.0, 86.0], // arm
    [52.0, 32.0, 66.0, 56.0], // thigh
    [66.0, 56.0, 70.0, 86.0], // shin
  ],
  anchors: {'hand': [26.0, 86.0], 'hip': [52.0, 32.0], 'foot': [70.0, 86.0]},
  props: [_Prop('floorPad', at: 'hand', dx: -14, dy: 0)],
);

const _Pose _widePushup = _Pose(
  head: [76.0, 58.0, 6.5],
  lines: [
    [68.0, 62.0, 32.0, 70.0], // torso
    [68.0, 62.0, 70.0, 88.0], // arm (front)
    [32.0, 70.0, 22.0, 88.0], // leg
  ],
  dots: [
    [60.0, 88.0, 2.2],
    [78.0, 88.0, 2.2],
  ],
  anchors: {'hand': [66.0, 88.0], 'foot': [22.0, 88.0], 'chest': [56.0, 66.0]},
  props: [_Prop('floorPad', at: 'hand', dx: -20, dy: 0)],
);

const _Pose _diamondPushup = _Pose(
  head: [76.0, 58.0, 6.5],
  lines: [
    [68.0, 62.0, 32.0, 70.0],
    [68.0, 62.0, 62.0, 88.0], // both arms converge under the chest
    [32.0, 70.0, 22.0, 88.0],
  ],
  dots: [
    [58.0, 88.0, 2.6],
    [66.0, 88.0, 2.6],
  ],
  anchors: {'hand': [62.0, 88.0], 'foot': [22.0, 88.0], 'chest': [56.0, 66.0]},
  props: [_Prop('floorPad', at: 'hand', dx: -18, dy: 0)],
);

const _Pose _floorPress = _Pose(
  head: [20.0, 80.0, 6.5],
  lines: [
    [28.0, 84.0, 54.0, 86.0], // torso on the floor
    [54.0, 86.0, 70.0, 72.0], // thigh
    [70.0, 72.0, 74.0, 88.0], // shin down to the floor
    [40.0, 84.0, 42.0, 64.0], // upper arm up
    [42.0, 64.0, 46.0, 50.0], // forearm up (pressing)
  ],
  anchors: {'hand': [46.0, 50.0], 'chest': [40.0, 80.0]},
  props: [
    _Prop('floorPad', at: 'hand', dx: -22, dy: 34),
    _Prop('pack', at: 'hand', dx: -7, dy: -4, scale: 1.05),
  ],
);

const _Pose _chairDips = _Pose(
  head: [42.0, 28.0, 6.5],
  lines: [
    [42.0, 36.0, 46.0, 60.0], // torso
    [42.0, 36.0, 30.0, 50.0], // upper arm back
    [30.0, 50.0, 32.0, 66.0], // forearm down to the chair
    [46.0, 60.0, 66.0, 62.0], // thigh forward
    [66.0, 62.0, 70.0, 88.0], // shin down
  ],
  anchors: {'hand': [32.0, 66.0], 'hip': [46.0, 60.0], 'foot': [70.0, 88.0]},
  props: [
    _Prop('chair', at: 'hand', dx: -6, dy: 0),
    _Prop('floorPad', at: 'foot', dx: -12, dy: 0),
  ],
);

const _Pose _tableRow = _Pose(
  head: [20.0, 62.0, 6.5],
  lines: [
    [28.0, 64.0, 62.0, 70.0], // body hanging under the table
    [36.0, 64.0, 38.0, 50.0], // arm up to the edge
    [62.0, 70.0, 84.0, 84.0], // legs down to the floor
  ],
  anchors: {'hand': [38.0, 50.0], 'chest': [40.0, 66.0]},
  props: [
    _Prop('table', at: 'hand', dx: 0, dy: -4),
    _Prop('floorPad', at: 'hand', dx: 26, dy: 34),
  ],
);

const _Pose _bentRow = _Pose(
  head: [74.0, 40.0, 6.5],
  lines: [
    [68.0, 46.0, 36.0, 56.0], // torso hinged forward
    [36.0, 56.0, 32.0, 88.0], // leg
    [36.0, 56.0, 46.0, 88.0], // leg
    [58.0, 50.0, 56.0, 76.0], // arm pulling down
  ],
  anchors: {'hand': [56.0, 76.0], 'chest': [58.0, 50.0], 'hip': [36.0, 56.0]},
  props: [
    _Prop('floorPad', at: 'hand', dx: -14, dy: 12),
    _Prop('pack', at: 'hand', dx: -6, dy: 2, scale: 0.95),
  ],
);

const _Pose _doorPull = _Pose(
  head: [70.0, 24.0, 6.5],
  lines: [
    [68.0, 32.0, 56.0, 60.0], // torso leaning back
    [68.0, 32.0, 84.0, 46.0], // arm to the frame
    [56.0, 60.0, 50.0, 88.0], // leg
    [56.0, 60.0, 64.0, 88.0], // leg
  ],
  anchors: {'hand': [84.0, 46.0], 'chest': [62.0, 46.0]},
  props: [_Prop('door', at: 'hand', dx: 4, dy: -22)],
);

const _Pose _curl = _Pose(
  head: [50.0, 18.0, 6.5],
  lines: [
    [50.0, 26.0, 50.0, 58.0], // torso
    [50.0, 58.0, 40.0, 88.0], // leg
    [50.0, 58.0, 60.0, 88.0], // leg
    [50.0, 32.0, 48.0, 48.0], // upper arm
    [48.0, 48.0, 56.0, 40.0], // forearm curled up
  ],
  anchors: {'hand': [56.0, 40.0], 'chest': [50.0, 34.0], 'hip': [50.0, 58.0]},
  props: [
    _Prop('floorPad', at: 'hand', dx: -16, dy: 48),
    _Prop('pack', at: 'hand', dx: -4, dy: 2, scale: 0.8),
  ],
);

const _Pose _gobletSquat = _Pose(
  head: [50.0, 16.0, 6.5],
  lines: [
    [50.0, 24.0, 48.0, 54.0], // torso
    [48.0, 54.0, 62.0, 66.0], // thigh
    [62.0, 66.0, 56.0, 90.0], // shin
    [50.0, 30.0, 58.0, 42.0], // arm holding the pack
  ],
  anchors: {'hand': [58.0, 42.0], 'chest': [52.0, 40.0], 'hip': [48.0, 54.0], 'foot': [56.0, 90.0]},
  props: [
    _Prop('pack', at: 'hand', dx: 0, dy: -2, scale: 0.85),
    _Prop('floorPad', at: 'foot', dx: -16, dy: 0),
  ],
);

const _Pose _splitSquat = _Pose(
  head: [46.0, 16.0, 6.5],
  lines: [
    [46.0, 24.0, 46.0, 54.0], // torso upright
    [46.0, 54.0, 62.0, 68.0], // front thigh
    [62.0, 68.0, 62.0, 90.0], // front shin
    [46.0, 54.0, 30.0, 72.0], // back thigh
    [30.0, 72.0, 20.0, 84.0], // back shin onto the bench
  ],
  anchors: {'hip': [46.0, 54.0], 'foot': [62.0, 90.0], 'bench': [20.0, 84.0]},
  props: [
    _Prop('bench', at: 'bench', dx: -4, dy: 0),
    _Prop('floorPad', at: 'foot', dx: -14, dy: 0),
  ],
);

const _Pose _rdl = _Pose(
  head: [70.0, 34.0, 6.5],
  lines: [
    [64.0, 40.0, 40.0, 52.0], // torso hinged
    [40.0, 52.0, 40.0, 72.0], // thigh
    [40.0, 72.0, 42.0, 90.0], // shin
    [58.0, 44.0, 54.0, 70.0], // arm down
  ],
  anchors: {'hand': [54.0, 70.0], 'hip': [40.0, 52.0], 'foot': [42.0, 90.0]},
  props: [
    _Prop('pack', at: 'hand', dx: -4, dy: 2, scale: 0.9),
    _Prop('floorPad', at: 'foot', dx: -16, dy: 0),
  ],
);

const _Pose _legRaise = _Pose(
  head: [18.0, 80.0, 6.5],
  lines: [
    [26.0, 84.0, 52.0, 86.0], // back on the floor
    [52.0, 86.0, 62.0, 62.0], // thigh up
    [62.0, 62.0, 70.0, 40.0], // shin up
  ],
  anchors: {'hip': [52.0, 86.0], 'foot': [70.0, 40.0]},
  props: [_Prop('floorPad', at: 'hip', dx: -26, dy: 4)],
);

const _Pose _lateralRaise = _Pose(
  head: [50.0, 18.0, 6.5],
  lines: [
    [50.0, 26.0, 50.0, 58.0], // torso
    [50.0, 58.0, 42.0, 88.0],
    [50.0, 58.0, 58.0, 88.0],
    [50.0, 32.0, 26.0, 32.0], // arm out to the side
    [50.0, 32.0, 74.0, 32.0], // arm out to the side
  ],
  anchors: {'handL': [26.0, 32.0], 'handR': [74.0, 32.0], 'foot': [50.0, 88.0]},
  props: [
    _Prop('bottle', at: 'handL', dx: -3, dy: 0, scale: 0.95),
    _Prop('bottle', at: 'handR', dx: -3, dy: 0, scale: 0.95),
    _Prop('floorPad', at: 'foot', dx: -16, dy: 0),
  ],
);

const _Pose _ohp = _Pose(
  head: [50.0, 26.0, 6.5],
  lines: [
    [50.0, 34.0, 50.0, 62.0], // torso
    [50.0, 62.0, 42.0, 90.0],
    [50.0, 62.0, 58.0, 90.0],
    [50.0, 38.0, 42.0, 22.0], // upper arm
    [42.0, 22.0, 50.0, 8.0], // forearm pressing overhead
  ],
  anchors: {'hand': [50.0, 8.0], 'foot': [50.0, 90.0]},
  props: [
    _Prop('pack', at: 'hand', dx: -6, dy: -2, scale: 1.0),
    _Prop('floorPad', at: 'foot', dx: -16, dy: 0),
  ],
);

const _Pose _superman = _Pose(
  head: [76.0, 60.0, 6.5],
  lines: [
    [68.0, 64.0, 40.0, 74.0], // torso arching
    [68.0, 64.0, 88.0, 52.0], // arms lifted forward
    [40.0, 74.0, 18.0, 60.0], // legs lifted back
  ],
  anchors: {'hand': [88.0, 52.0], 'chest': [60.0, 68.0]},
  props: [_Prop('floorPad', at: 'chest', dx: -22, dy: 12)],
);

const _Pose _reverseAngels = _Pose(
  head: [74.0, 66.0, 6.5],
  lines: [
    [66.0, 70.0, 38.0, 78.0], // torso prone
    [38.0, 78.0, 20.0, 84.0], // legs
    [62.0, 70.0, 46.0, 56.0], // arm sweeping out
    [54.0, 64.0, 74.0, 52.0], // other arm
  ],
  dots: [
    [46.0, 56.0, 2.4],
    [74.0, 52.0, 2.4],
  ],
  anchors: {'hand': [46.0, 56.0], 'chest': [56.0, 72.0]},
  props: [_Prop('floorPad', at: 'chest', dx: -24, dy: 10)],
);

const _Pose _plank = _Pose(
  head: [80.0, 58.0, 6.5],
  lines: [
    [72.0, 62.0, 34.0, 70.0], // body straight
    [72.0, 62.0, 68.0, 88.0], // forearm down
    [34.0, 70.0, 24.0, 88.0], // leg down
  ],
  anchors: {'hand': [68.0, 88.0], 'foot': [24.0, 88.0]},
  props: [_Prop('floorPad', at: 'hand', dx: -22, dy: 0)],
);

const _Pose _rest = _Pose(
  head: [50.0, 26.0, 7.0],
  lines: [
    [50.0, 34.0, 50.0, 62.0],
    [50.0, 62.0, 42.0, 88.0],
    [50.0, 62.0, 58.0, 88.0],
    [50.0, 40.0, 36.0, 54.0],
    [50.0, 40.0, 64.0, 54.0],
  ],
  anchors: {'foot': [50.0, 88.0]},
  props: [_Prop('floorPad', at: 'foot', dx: -18, dy: 0)],
);

/// exercise id -> pose.  Ids come from `content.json`; a missing id falls back
/// to a neutral standing figure so the UI never shows a hole.
const Map<String, _Pose> _poses = {
  'pike_pushup': _pikePushup,
  'wide_pushup': _widePushup,
  'diamond_pushup': _diamondPushup,
  'bag_floor_press': _floorPress,
  'chair_dips': _chairDips,
  'table_row': _tableRow,
  'table_row2': _tableRow,
  'bag_row': _bentRow,
  'doorframe_pull': _doorPull,
  'bag_curl': _curl,
  'bag_curl2': _curl,
  'goblet_squat': _gobletSquat,
  'bulgarian_split': _splitSquat,
  'bag_rdl': _rdl,
  'leg_raise': _legRaise,
  'lateral_raise': _lateralRaise,
  'bag_ohp': _ohp,
  'superman': _superman,
  'reverse_angels': _reverseAngels,
  'plank': _plank,
};

/// Ids of every pose the app knows how to draw (used by the tests).
Set<String> get exerciseArtIds => _poses.keys.toSet();

bool hasExerciseArt(String id) => _poses.containsKey(id);

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// The illustration for one exercise, drawn with [CustomPaint].
class ExerciseArt extends StatelessWidget {
  const ExerciseArt({
    super.key,
    required this.exerciseId,
    this.size = 96,
    this.color,
    this.equipmentColor,
    this.showFrame = true,
  });

  final String exerciseId;
  final double size;
  final Color? color;
  final Color? equipmentColor;
  final bool showFrame;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    final paint = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PosePainter(
          pose: _poses[exerciseId] ?? _rest,
          accent: accent,
          body: theme.brightness == Brightness.dark
              ? const Color(0xFFE8ECF8)
              : const Color(0xFF10162B),
          gear: equipmentColor ?? accent,
        ),
      ),
    );
    if (!showFrame) return paint;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: paint,
    );
  }
}

class _PosePainter extends CustomPainter {
  _PosePainter({
    required this.pose,
    required this.accent,
    required this.body,
    required this.gear,
  });

  final _Pose pose;
  final Color accent;
  final Color body;
  final Color gear;

  static const double _space = 100;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / _space;
    final ox = (size.width - _space * s) / 2;
    final oy = (size.height - _space * s) / 2;

    canvas.save();
    canvas.translate(ox, oy);
    canvas.scale(s, s);

    final limb = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = body;
    final gearPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..color = gear;
    final gearFill = Paint()
      ..style = PaintingStyle.fill
      ..color = gear.withValues(alpha: 0.35);
    final soft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.35);

    Offset p(List<double> v, [int i = 0]) => Offset(v[i], v[i + 1]);
    Offset anchor(String name, double dx, double dy) {
      final a = pose.anchors[name];
      if (a == null) return Offset(50 + dx, 50 + dy);
      return Offset(a[0] + dx, a[1] + dy);
    }

    // ---- equipment behind the figure -------------------------------------
    for (final pr in pose.props) {
      final o = anchor(pr.at, pr.dx, pr.dy);
      switch (pr.kind) {
        case 'floorPad':
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(o.dx - 6, o.dy - 1.6, 44, 3.2),
              const Radius.circular(1.6),
            ),
            Paint()..color = accent.withValues(alpha: 0.22),
          );
          break;
        case 'table':
          canvas.drawLine(Offset(o.dx - 26, o.dy), Offset(o.dx + 30, o.dy), gearPaint);
          canvas.drawLine(Offset(o.dx - 22, o.dy), Offset(o.dx - 26, o.dy + 34), soft);
          canvas.drawLine(Offset(o.dx + 26, o.dy), Offset(o.dx + 30, o.dy + 34), soft);
          break;
        case 'bench':
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(o.dx - 12, o.dy, 26, 5),
              const Radius.circular(2),
            ),
            gearFill,
          );
          canvas.drawLine(Offset(o.dx - 8, o.dy + 5), Offset(o.dx - 9, o.dy + 16), soft);
          canvas.drawLine(Offset(o.dx + 10, o.dy + 5), Offset(o.dx + 11, o.dy + 16), soft);
          break;
        case 'chair':
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(o.dx - 12, o.dy, 24, 4.5),
              const Radius.circular(2),
            ),
            gearFill,
          );
          canvas.drawLine(Offset(o.dx - 10, o.dy), Offset(o.dx - 13, o.dy - 20), gearPaint);
          canvas.drawLine(Offset(o.dx - 9, o.dy + 4.5), Offset(o.dx - 10, o.dy + 22), soft);
          canvas.drawLine(Offset(o.dx + 9, o.dy + 4.5), Offset(o.dx + 10, o.dy + 22), soft);
          break;
        case 'door':
          canvas.drawLine(Offset(o.dx, o.dy - 26), Offset(o.dx, o.dy + 46), gearPaint);
          canvas.drawLine(Offset(o.dx, o.dy - 26), Offset(o.dx - 12, o.dy - 26), soft);
          break;
        case 'pack':
          _backpack(canvas, o, pr.scale, gearFill, gearPaint);
          break;
        case 'bottle':
          _bottle(canvas, o, pr.scale, gearFill, gearPaint);
          break;
      }
    }

    // ---- figure ----------------------------------------------------------
    for (final l in pose.lines) {
      canvas.drawLine(p(l, 0), p(l, 2), limb);
    }
    for (final d in pose.dots) {
      canvas.drawCircle(Offset(d[0], d[1]), d[2], Paint()..color = gear);
    }
    // joints
    for (final l in pose.lines) {
      canvas.drawCircle(p(l, 0), 2.0, Paint()..color = body.withValues(alpha: 0.55));
    }
    // head
    canvas.drawCircle(
      Offset(pose.head[0], pose.head[1]),
      pose.head[2],
      Paint()..color = accent,
    );
    canvas.drawCircle(
      Offset(pose.head[0], pose.head[1]),
      pose.head[2] + 2.4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent.withValues(alpha: 0.35),
    );

    canvas.restore();
  }

  void _backpack(Canvas canvas, Offset o, double scale, Paint fill, Paint stroke) {
    final w = 15.0 * scale;
    final h = 18.0 * scale;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, w, h), Radius.circular(3.5 * scale)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, w, h), Radius.circular(3.5 * scale)),
      stroke,
    );
    canvas.drawLine(
      Offset(o.dx + w * 0.25, o.dy + h * 0.35),
      Offset(o.dx + w * 0.75, o.dy + h * 0.35),
      stroke,
    );
  }

  void _bottle(Canvas canvas, Offset o, double scale, Paint fill, Paint stroke) {
    final w = 6.5 * scale;
    final h = 15.0 * scale;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, w, h), Radius.circular(2.5 * scale)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, w, h), Radius.circular(2.5 * scale)),
      stroke,
    );
    canvas.drawRect(
      Rect.fromLTWH(o.dx + w * 0.25, o.dy - 3 * scale, w * 0.5, 3 * scale),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_PosePainter old) =>
      old.pose != pose || old.accent != accent || old.body != body || old.gear != gear;
}
