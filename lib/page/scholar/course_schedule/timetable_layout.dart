import 'package:celechron/model/session.dart';

const timetablePeriods = 13;

enum CourseWeeks {
  every('每周'),
  odd('单周'),
  even('双周'),
  custom('指定周');

  final String label;
  const CourseWeeks(this.label);
}

// 教务网有时混用全角、半角括号；未知课程不要仅因为同名占位符而合并。
String courseKey(Session s) {
  final name = s.name.trim().replaceAll('(', '（').replaceAll(')', '）');
  return (name.isEmpty || name == '未知课程') && s.id != null
      ? '$name:${s.id}'
      : name;
}

/// Assign colors once for BOTH halves rather than cycling colors per day.
Map<String, int> courseColorIndices(Iterable<Session> sessions) {
  final keys = sessions
      .where((s) => s.confirmed && s.showOnTimetable)
      .map(courseKey)
      .toSet()
      .toList()
    ..sort();
  return {for (var i = 0; i < keys.length; i++) keys[i]: i};
}

CourseWeeks _weeks(Iterable<Session> sessions) {
  var odd = false, even = false;
  final dates = <int>{};
  for (final s in sessions) {
    if (s.customRepeat && s.customRepeatWeeks.isNotEmpty) {
      dates.addAll(s.customRepeatWeeks);
    } else {
      odd |= s.oddWeek;
      even |= s.evenWeek;
    }
  }
  if (odd && even) return CourseWeeks.every;
  dates.removeWhere((w) => w.isOdd ? odd : even);
  if (dates.isEmpty) {
    return odd
        ? CourseWeeks.odd
        : even
            ? CourseWeeks.even
            : CourseWeeks.custom;
  }
  if (!even && dates.every((w) => w.isOdd)) return CourseWeeks.odd;
  if (!odd && dates.every((w) => w.isEven)) return CourseWeeks.even;
  final ordered = dates.toList()..sort();
  if (!odd && !even && ordered.last - ordered.first + 1 == ordered.length) {
    return CourseWeeks.every;
  }
  return CourseWeeks.custom;
}

class TimetableBlock {
  final String key;
  final int start;
  final List<CourseWeeks> weeks;
  final List<Session> sources;
  int lane = 0, laneCount = 1;

  TimetableBlock(this.key, this.start, this.weeks, this.sources);
  int get end => start + weeks.length - 1;
  String get name => sources.first.name;
}

List<TimetableBlock> layoutTimetableDay(Iterable<Session> day) {
  final courses = <String, Map<int, Set<Session>>>{};
  for (final s in day) {
    final slots = courses.putIfAbsent(courseKey(s), () => {});
    for (final p in s.time) {
      if (p >= 1 && p <= 15) {
        slots.putIfAbsent(p, () => {}).add(s);
      }
    }
  }

  final blocks = <TimetableBlock>[];
  for (final entry in courses.entries) {
    final slots = entry.value;
    for (var p = 1; p <= 15;) {
      if (!slots.containsKey(p)) {
        p++;
        continue;
      }
      final start = p, weeks = <CourseWeeks>[], sources = <Session>{};
      while (slots.containsKey(p)) {
        final rows = slots[p++]!;
        weeks.add(_weeks(rows));
        sources.addAll(rows);
      }
      blocks.add(TimetableBlock(entry.key, start, weeks, sources.toList()));
    }
  }
  blocks.sort((a, b) {
    final d = a.start.compareTo(b.start);
    return d == 0 ? a.key.compareTo(b.key) : d;
  });
  // Overlapping different courses keep their own color, texture and tap target.
  for (var i = 0; i < blocks.length;) {
    final first = i, laneEnds = <int>[];
    var last = blocks[i].end;
    while (i < blocks.length && blocks[i].start <= last) {
      final b = blocks[i++];
      final free = laneEnds.indexWhere((end) => end < b.start);
      b.lane = free < 0 ? laneEnds.length : free;
      if (free < 0) {
        laneEnds.add(b.end);
      } else {
        laneEnds[free] = b.end;
      }
      if (b.end > last) last = b.end;
    }
    for (var j = first; j < i; j++) {
      blocks[j].laneCount = laneEnds.length;
    }
  }
  return blocks;
}
