import 'package:flutter/cupertino.dart';

/// One palette for the whole semester, deliberately alternating dark/light and
/// warm/cool neighbors. Values are opaque sRGB, also used by the color editor.
const coursePalette = <({String name, int rgb})>[
  (name: '湖蓝', rgb: 0x3477B9),
  (name: '向日葵', rgb: 0xF4C94D),
  (name: '松绿', rgb: 0x21765F),
  (name: '玫瑰', rgb: 0xCF567B),
  (name: '晴空', rgb: 0x8CD4ED),
  (name: '朱橙', rgb: 0xCF572B),
  (name: '丁香', rgb: 0xB09AE2),
  (name: '青柠', rgb: 0xACCB55),
  (name: '靛蓝', rgb: 0x40477F),
  (name: '杏桃', rgb: 0xFFB481),
  (name: '绿松石', rgb: 0x42BDB3),
  (name: '紫梅', rgb: 0x88467F),
  (name: '赭金', rgb: 0xAB8037),
  (name: '樱粉', rgb: 0xF2B4D2),
  (name: '石板灰', rgb: 0x66788B),
];

String courseHex(int rgb) =>
    rgb.toRadixString(16).padLeft(6, '0').toUpperCase();

/// Keep unaffected automatic colors. If a manual choice claims one, only the
/// displaced automatic course moves to the first free color in palette order.
Map<String, int> timetableRgb(
    Map<String, int> indices, Map<String, int> overrides) {
  final used = {
    for (final key in indices.keys)
      if (overrides[key] != null) overrides[key]!
  };
  final colors = <String, int>{};
  final displaced = <String>[];
  for (final entry in indices.entries) {
    final custom = overrides[entry.key];
    final base = CourseColors.automaticRgb(entry.value);
    if (custom != null) {
      colors[entry.key] = custom;
    } else if (used.add(base)) {
      colors[entry.key] = base;
    } else {
      displaced.add(entry.key);
    }
  }
  var next = 0;
  for (final key in displaced) {
    int rgb;
    do {
      rgb = CourseColors.automaticRgb(next++);
    } while (!used.add(rgb));
    colors[key] = rgb;
  }
  return colors;
}

class CourseColors {
  final Color fill, ink;
  const CourseColors(this.fill, this.ink);

  static int automaticRgb(int index) {
    final base = coursePalette[index % coursePalette.length].rgb;
    final round = index ~/ coursePalette.length;
    if (round == 0) return base;
    // Keep familiar hues, but do not repeat a fill on the 16th course.
    final target = round.isOdd ? CupertinoColors.white : CupertinoColors.black;
    final amount = .21 + .54 * (1 - 1 / ((round + 1) ~/ 2));
    return Color.lerp(Color(0xFF000000 | base), target, amount)!.toARGB32() &
        0xFFFFFF;
  }

  factory CourseColors.forIndex(int index, Brightness mode) =>
      CourseColors.fromRgb(automaticRgb(index), mode);

  factory CourseColors.fromRgb(int rgb, Brightness mode,
      {bool custom = false}) {
    final seed = Color(0xFF000000 | rgb);
    final fill = !custom && mode == Brightness.dark
        ? Color.lerp(seed, const Color(0xFF171A20), .17)!
        : seed;
    final l = fill.computeLuminance();
    const softBlack = Color(0xFF14191F);
    final ink = (l + .05) / (softBlack.computeLuminance() + .05) >= 4.5
        ? softBlack
        : 1.05 / (l + .05) >= 4.5
            ? CupertinoColors.white
            : CupertinoColors.black;
    return CourseColors(fill, ink);
  }
}
