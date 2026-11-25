import 'dart:io';
import 'package:celechron/database/course_color_preferences.dart';
import 'package:celechron/page/scholar/course_schedule/course_palette.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:hive/hive.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:celechron/http/zjuServices/grs_new.dart';
import 'package:celechron/model/course.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/semester.dart';
import 'package:celechron/page/scholar/course_schedule/course_schedule_view.dart';
import 'package:celechron/page/scholar/course_detail/course_detail_view.dart';
import 'package:get/get.dart';

import 'package:celechron/model/session.dart';
import 'package:celechron/page/scholar/course_schedule/timetable_card.dart';
import 'package:celechron/page/scholar/course_schedule/timetable_grid.dart';
import 'package:celechron/page/scholar/course_schedule/timetable_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

Session session(String name, List<int> slots,
        {int day = 1, String? id, bool odd = true, bool even = true}) =>
    Session.empty()
      ..name = name
      ..id = id ?? name
      ..teacher = '测试教师'
      ..time = slots
      ..dayOfWeek = day
      ..firstHalf = true
      ..oddWeek = odd
      ..evenWeek = even
      ..location = '东一 203';

void main() {
  test(
      'merge adjacent equal names, not gaps or different weekdays; preserve source records',
      () {
    final a = session('数学', [2, 1]),
        b = session('数学', [3, 4, 5], id: 'other section');
    final c = session('数学', [7, 9]), w = session('数学', [6, 7], day: 3);
    final blocks = layoutTimetableDay([b, c, a]);
    expect(blocks.map((b) => (b.start, b.end)), [(1, 5), (7, 7), (9, 9)]);
    expect(blocks.first.sources, [a, b]);
    expect(a.time, [2, 1]);
    expect(layoutTimetableDay([w]).single.key, blocks.first.key);
    final colors = courseColorIndices([
      a,
      w,
      b,
      session('物理', [1])
    ]);
    expect(colors.length, 2);
    expect(
        colors,
        courseColorIndices([
          session('物理', [3]),
          b,
          w,
          a
        ]));
    expect(
        [
          for (var i = 0; i < 40; i++)
            CourseColors.forIndex(i, Brightness.light).fill.toARGB32()
        ].toSet(),
        hasLength(40));
  });

  test(
      'combine week coverage per slot and retain both courses at overlapping times',
      () {
    final blocks = layoutTimetableDay([
      session('甲', [1, 2, 3], even: false),
      session('甲', [3, 4], odd: false),
      session('乙', [2, 3], odd: false),
      session('丙', [6, 7]),
    ]);
    final merged = blocks.first;
    expect(merged.weeks, [
      CourseWeeks.odd,
      CourseWeeks.odd,
      CourseWeeks.every,
      CourseWeeks.even
    ]);
    expect(merged.laneCount, 2);
    expect(blocks[1].lane, isNot(merged.lane));
    expect(blocks.last.laneCount, 1);
    final custom = session('研讨课', [1])
      ..customRepeat = true
      ..customRepeatWeeks = [2, 4, 6];
    expect(layoutTimetableDay([custom]).single.weeks, [CourseWeeks.even]);
    custom.customRepeatWeeks = [1, 2, 5];
    expect(layoutTimetableDay([custom]).single.weeks, [CourseWeeks.custom]);
  });

  test('retain the actual weeks for each period of the same graduate class',
      () {
    Map<String, dynamic> row(String weeks) => {
          'pyKcbjSjddVOList': [
            {
              'bjbh': '12345678',
              'kcmc': '专题研讨',
              'zc': weeks,
              'cdmc': '教学楼',
              'xm': '教师'
            },
          ]
        };
    final raw = {
      'result': {
        'kcbMap': {
          '1': {
            '1': row('1,3,5'),
            '2': row('1,3,5'),
            '3': row('2,4,6'),
            '4': row('1,3,7'),
            '15': row('2,4,6')
          }
        }
      }
    };
    final sessions = GrsNew.parseTimetable(raw, 11, '课表');
    final semester = Semester('2025-2026春夏');
    for (final s in sessions) {
      semester.addSession(s, '2025-2026春夏', true);
    }
    final blocks = layoutTimetableDay(semester.firstHalfTimetable[1]);
    expect(blocks.map((b) => (b.start, b.end)), [(1, 4), (15, 15)]);
    expect(blocks.first.weeks,
        [CourseWeeks.odd, CourseWeeks.odd, CourseWeeks.even, CourseWeeks.odd]);
    expect(blocks.first.sources, hasLength(3));
  });

  test('custom RGB survives a real database reopen and stays in its semester',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('celechron-course-colors-');
    final id = 'coursecolors';
    try {
      var box = await Hive.openBox(id, path: dir.path);
      await CourseColorPreferences(box, '秋冬').set('数学', 0x18B187);
      await box.close();
      box = await Hive.openBox(id, path: dir.path);
      final prefs = CourseColorPreferences(box, '秋冬');
      expect(prefs.overrides['数学'], 0x18B187);
      expect(CourseColorPreferences(box, '春夏').overrides, isEmpty);
      await prefs.set('数学', null);
      expect(prefs.overrides, isEmpty);
    } finally {
      if (Hive.isBoxOpen(id)) await Hive.box(id).close();
      await dir.delete(recursive: true);
    }
  });

  test('first 15 use palette order; only clashing automatic assignments move',
      () {
    final indices = {for (var i = 0; i < 22; i++) 'c$i': i};
    final automatic = timetableRgb(indices, {});
    expect(automatic.values.take(15), coursePalette.map((t) => t.rgb));
    expect(automatic.values.toSet(), hasLength(22));
    expect(CourseColors.fromRgb(0x03A681, Brightness.dark, custom: true).fill,
        const Color(0xFF03A681));
    final claimed = coursePalette[1].rgb;
    final recolored = timetableRgb(indices, {'c0': claimed});
    expect(recolored['c0'], claimed);
    expect(recolored['c1'], automatic['c0']);
    expect(recolored['c2'], automatic['c2']);
    expect(recolored.values.toSet(), hasLength(22));
    expect(
        timetableRgb(indices, {'c0': claimed, 'c1': claimed})['c1'], claimed);
    for (final mode in Brightness.values) {
      for (final rgb in [...automatic.values, 0xFFFFFF, 0x000000, 0x757575]) {
        final colors = CourseColors.fromRgb(rgb, mode);
        final luminances = [
          colors.fill.computeLuminance(),
          colors.ink.computeLuminance()
        ]..sort();
        expect((luminances.last + .05) / (luminances.first + .05),
            greaterThanOrEqualTo(4.5));
      }
    }
  });

  testWidgets(
      'keep both detail routes for a merged same-name class and switch halves',
      (tester) async {
    final sem = Semester('2025-2026秋冬');
    final a = session('专题研讨', [1, 2], id: 'A'),
        b = session('专题研讨', [3, 4], id: 'B');
    final winter = session('专题研讨', [6, 7], day: 3, id: 'A')
      ..firstHalf = false
      ..secondHalf = true;
    sem.sessions.addAll([a, b, winter]);
    for (final s in [a, b]) {
      sem.courses[s.id!] = Course.fromJson({
        'id': s.id,
        'name': s.name,
        'sessions': [s.toJson()]
      });
    }
    final db = Get.put(DatabaseHelper(), tag: 'db');
    db.optionsBox =
        await Hive.openBox('course-schedule-test', bytes: Uint8List(0));
    addTearDown(Hive.close);
    Get.put((Scholar()..semesters.add(sem)).obs, tag: 'scholar');
    addTearDown(Get.reset);
    await tester
        .pumpWidget(CupertinoApp(home: CourseSchedulePage(sem.name, true)));
    await tester.pumpAndSettle();
    final card = tester.widget<TimetableCard>(find.byType(TimetableCard));
    expect(card.block.end, 4);
    await tester.tap(find.byType(TimetableCard));
    await tester.pumpAndSettle();
    final choices = find.byType(CupertinoActionSheetAction);
    await tester.tap(choices.at(1));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CourseDetailPage>(find.byType(CourseDetailPage))
            .course
            .id,
        'B');
    Future<void> editColor() async {
      await tester.ensureVisible(find.text('课表颜色'));
      await tester.tap(find.text('课表颜色'));
      await tester.pumpAndSettle();
    }

    await editColor();
    await tester.tap(find.byKey(ValueKey(coursePalette[1].rgb)));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(db.timetableColors(sem.name).overrides, isEmpty);
    await editColor();
    await tester.enterText(find.byType(CupertinoTextField), 'FF');
    await tester.pump();
    expect(
        tester
            .widget<CupertinoButton>(find.widgetWithText(CupertinoButton, '完成'))
            .onPressed,
        isNull);
    await tester.enterText(find.byType(CupertinoTextField), '#03A681');
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(db.timetableColors(sem.name).overrides[card.block.key], 0x03A681);
    Navigator.of(tester.element(find.byType(CourseDetailPage))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('冬学期课时'));
    await tester.pumpAndSettle();
    final other = tester.widget<TimetableCard>(find.byType(TimetableCard));
    expect((other.block.start, other.block.end), (6, 7));
    expect(other.colors.fill, const Color(0xFF03A681));
    await tester.tap(find.byType(TimetableCard));
    await tester.pumpAndSettle();
    await editColor();
    await tester.tap(find.text('恢复自动配色'));
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(CourseDetailPage))).pop();
    await tester.pumpAndSettle();
    expect(tester.widget<TimetableCard>(find.byType(TimetableCard)).colors.fill,
        card.colors.fill);
    expect(db.timetableColors(sem.name).overrides, isEmpty);
  });

  testWidgets('paint solid, descending and ascending lines in light and dark',
      (tester) async {
    await tester.runAsync(() async {
      for (final brightness in Brightness.values) {
        final colors = CourseColors.forIndex(0, brightness);
        for (final pattern in [
          CourseWeeks.every,
          CourseWeeks.odd,
          CourseWeeks.even
        ]) {
          final recorder = ui.PictureRecorder();
          CourseSurface(colors, [pattern])
              .paint(Canvas(recorder), const Size(36, 36));
          final picture = recorder.endRecording();
          final image = await picture.toImage(36, 36);
          final data =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          int pixel(int x, int y) => data.getUint32(4 * (36 * y + x));
          // At these pixel centres x-y=0 (descending), or x+y=9 (ascending).
          expect(pixel(2, 2) != pixel(4, 2), pattern == CourseWeeks.odd);
          expect(pixel(6, 2) != pixel(4, 2), pattern == CourseWeeks.even);
          image.dispose();
          picture.dispose();
        }
      }
    });
  });

  testWidgets(
      'merged card opens with all original segments; privacy keeps the colors',
      (tester) async {
    final a = session('线性代数', [1, 2]), b = session('线性代数', [3, 4, 5]);
    final days = List.generate(8, (_) => <Session>[])
      ..[1].addAll([a, b])
      ..[3].add(session('线性代数', [6, 7], day: 3));
    TimetableBlock? opened;
    Widget grid(bool hide) => CupertinoApp(
        home: CupertinoPageScaffold(
            child: SingleChildScrollView(
                child: TimetableGrid(
                    days: days,
                    colorIndices: courseColorIndices([a, b]),
                    hideInformation: hide,
                    onOpen: (block) => opened = block))));
    await tester.pumpWidget(grid(false));
    final cards =
        tester.widgetList<TimetableCard>(find.byType(TimetableCard)).toList();
    expect(cards, hasLength(2));
    expect(cards.first.colors.fill, cards.last.colors.fill);
    await tester.tap(find.byType(TimetableCard).first);
    expect(opened!.sources, [a, b]);
    await tester.pumpWidget(grid(true));
    expect(find.text('线性代数'), findsNothing);
    expect(find.byType(TimetableCard), findsNWidgets(2));
  });
}
