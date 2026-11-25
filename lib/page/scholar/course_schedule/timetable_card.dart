import 'package:flutter/cupertino.dart';

import 'timetable_layout.dart';

class CourseColors {
  final Color fill, ink;
  const CourseColors(this.fill, this.ink);

  factory CourseColors.forIndex(int index, Brightness brightness) {
    // Visit widely separated hues before introducing intermediate shades.
    final hue = (170.0 + index * 137.507764) % 360;
    final dark = brightness == Brightness.dark;
    Color tone(double saturation, double lightness) =>
        HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
    return CourseColors(tone(dark ? .37 : .51, dark ? .235 : .854),
        tone(dark ? .65 : .58, dark ? .90 : .18));
  }
}

class CourseSurface extends CustomPainter {
  final CourseColors colors;
  final List<CourseWeeks> weeks;
  const CourseSurface(this.colors, this.weeks);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.fill);
    final stroke = Paint()
      ..color = colors.ink.withValues(alpha: .20)
      ..strokeWidth = 1.35;
    for (var i = 0; i < weeks.length;) {
      final first = i, repeat = weeks[i++];
      while (i < weeks.length && weeks[i] == repeat) {
        i++;
      }
      if (repeat == CourseWeeks.every) continue;
      final top = size.height * first / weeks.length;
      final bottom = size.height * i / weeks.length;
      final h = bottom - top;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, top, size.width, bottom));
      if (repeat == CourseWeeks.custom) {
        for (double x = 4; x < size.width; x += 8) {
          for (double y = top + 4; y < bottom; y += 8) {
            canvas.drawCircle(Offset(x, y), 1.1, stroke);
          }
        }
      } else {
        for (double x = -h; x < size.width; x += 9) {
          final down = repeat == CourseWeeks.odd;
          canvas.drawLine(Offset(x, down ? top : bottom),
              Offset(x + h, down ? bottom : top), stroke);
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CourseSurface old) =>
      old.weeks != weeks ||
      old.colors.fill != colors.fill ||
      old.colors.ink != colors.ink;
}

class TimetableCard extends StatelessWidget {
  final TimetableBlock block;
  final CourseColors colors;
  final bool hideInformation;
  final VoidCallback onPressed;
  const TimetableCard(
      {super.key,
      required this.block,
      required this.colors,
      required this.hideInformation,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final locations = block.sources
        .map((s) => s.location?.trim())
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .join(' / ');
    final patterns = block.weeks.toSet().map((p) => p.label).join('、');
    final label = '第${block.start}–${block.end}节，$patterns';
    return Semantics(
      button: true,
      onTap: onPressed,
      label: hideInformation ? label : '${block.name}，$label，$locations',
      child: ExcludeSemantics(
          child: Padding(
        padding: const EdgeInsets.all(1),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onPressed,
          child: SizedBox.expand(
              child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: CustomPaint(
              painter: CourseSurface(colors, block.weeks),
              child: LayoutBuilder(builder: (context, bounds) {
                if (hideInformation) return const SizedBox.expand();
                final wide = bounds.maxWidth >= 72;
                final showPlace = locations.isNotEmpty &&
                    (bounds.maxHeight >= 68 || wide && bounds.maxHeight >= 38);
                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: wide ? 7 : 2, vertical: 3),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                            child: Text(block.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: wide ? 3 : 5,
                                style: TextStyle(
                                    color: colors.ink,
                                    fontSize: wide ? 13 : 11,
                                    height: 1.18,
                                    fontWeight: FontWeight.w600))),
                        if (showPlace) ...[
                          const SizedBox(height: 2),
                          Text(locations,
                              overflow: TextOverflow.ellipsis,
                              maxLines: wide ? 1 : 2,
                              style: TextStyle(
                                  color: colors.ink.withValues(alpha: .85),
                                  fontSize: wide ? 11 : 9,
                                  height: 1.13)),
                        ],
                      ]),
                );
              }),
            ),
          )),
        ),
      )),
    );
  }
}
