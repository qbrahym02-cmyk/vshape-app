import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/exercise_images.dart';
import 'exercise_art.dart';
import 'scope.dart';

/// Exercise visual: the downloaded photo when it is available, otherwise the
/// built-in vector pose (which also covers offline use, a missing URL and the
/// moment before the first download finishes).
class ExerciseMedia extends StatefulWidget {
  const ExerciseMedia({
    super.key,
    required this.exerciseId,
    this.imageUrl = '',
    this.size = 96,
    this.color,
    this.showFrame = true,
  });

  final String exerciseId;
  final String imageUrl;
  final double size;
  final Color? color;
  final bool showFrame;

  @override
  State<ExerciseMedia> createState() => _ExerciseMediaState();
}

class _ExerciseMediaState extends State<ExerciseMedia> {
  File? _file;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ExerciseMedia old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl || old.exerciseId != widget.exerciseId) {
      _tried = false;
      _file = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    // AppScope.read() does not register an inherited dependency, so it is safe
    // from initState (unlike context.st).
    final st = AppScope.read(context);
    if (!st.photosOn || widget.imageUrl.isEmpty) return;
    await ExerciseImages.prime();
    final hit = await ExerciseImages.cached(widget.exerciseId, url: widget.imageUrl);
    if (!mounted) return;
    if (hit != null) {
      setState(() => _file = hit);
      return;
    }
    if (_tried) return;
    _tried = true;
    final ok = await ExerciseImages.ensure(widget.exerciseId, widget.imageUrl);
    if (!mounted || !ok) return;
    final got = await ExerciseImages.cached(widget.exerciseId, url: widget.imageUrl);
    if (mounted && got != null) setState(() => _file = got);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.color ?? Theme.of(context).colorScheme.primary;

    // also rebuild when the background downloader finishes somewhere else
    return ValueListenableBuilder<int>(
      valueListenable: ExerciseImages.revision,
      builder: (context, _, __) {
        final file = _file ?? ExerciseImages.cachedSync(widget.exerciseId, url: widget.imageUrl);
        if (file == null) {
          return ExerciseArt(
            exerciseId: widget.exerciseId,
            size: widget.size,
            color: widget.color,
            showFrame: widget.showFrame,
          );
        }
        final img = ClipRRect(
          borderRadius: BorderRadius.circular(widget.size * 0.17),
          child: Image.file(
            file,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => ExerciseArt(
              exerciseId: widget.exerciseId,
              size: widget.size,
              color: widget.color,
              showFrame: false,
            ),
          ),
        );
        if (!widget.showFrame) return img;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.size * 0.17),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
            color: C.surface,
          ),
          child: img,
        );
      },
    );
  }
}
