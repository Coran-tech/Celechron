import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Local presentation preferences, separate from the replaceable Scholar cache.
class CourseColorPreferences {
  final Box _box;
  final String _key;
  CourseColorPreferences(this._box, String semester)
      : _key = 'timetableColors:$semester';

  ValueListenable<Box> get changes => _box.listenable(keys: [_key]);
  Map<String, int> get overrides =>
      Map<String, int>.from(_box.get(_key) ?? const {});

  Future<void> set(String key, int? rgb) {
    final colors = overrides;
    if (rgb == null) {
      colors.remove(key);
    } else {
      colors[key] = rgb;
    }
    return colors.isEmpty ? _box.delete(_key) : _box.put(_key, colors);
  }
}
