import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/grade.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/semester.dart';
import 'package:celechron/page/scholar/grade_detail/grade_detail_controller.dart';
import 'package:celechron/page/scholar/grade_detail/grade_detail_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Db extends DatabaseHelper {
  @override
  Map<String, bool> getCustomGpa() => {};
}

Grade grade(String name, int credit, String score, double gpa) =>
    Grade({'xkkh': name, 'kcmc': name, 'xf': credit, 'cj': score, 'jd': gpa});

void main() {
  test('无课时学期不会导致学业页读取当前学期时报错', () {
    final scholar = Scholar();
    final spring = Semester('2025-2026春夏'), autumn = Semester('2025-2026秋冬');
    expect(scholar.thisSemester.name, '未刷新');
    scholar.semesters = [spring, autumn];
    expect(scholar.thisSemester, same(spring));
    final now = DateTime.now();
    autumn.periods.add(Period(startTime: now, endTime: now));
    expect(scholar.thisSemester, same(autumn));
  });

  testWidgets('空成绩、新成绩、学期切换与刷新清空', (tester) async {
    final scholar = Get.put(Scholar().obs, tag: 'scholar');
    Get.put<DatabaseHelper>(_Db(), tag: 'db');
    addTearDown(Get.reset);
    await tester.pumpWidget(CupertinoApp(home: GradeDetailPage()));
    await tester.pumpAndSettle();
    expect(find.text('暂无成绩'), findsOneWidget);
    final spring = Semester('2025-2026春夏')..grades.add(grade('通过', 2, '85', 4));
    final autumn = Semester('2025-2026秋冬')
      ..grades.add(grade('未通过', 2, '55', 0));
    final previous = Semester('2024-2025秋冬')
      ..grades.add(grade('往年', 4, '90', 5));
    autumn.grades.add(grade('通过制', 3, '合格', 1));
    scholar.value.semesters = [spring, autumn, previous];
    scholar.refresh();
    await tester.pumpAndSettle();
    final ctrl = Get.find<GradeDetailController>();
    final stats = ctrl.getYearStats(0);
    expect(stats.item1.first, 2);
    expect(stats.item2, 5);
    expect(find.text('学年均绩'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Custom GPA'));
    await tester.pumpAndSettle();
    expect(find.text('已选百分制'), findsOneWidget);
    ctrl.semesterIndex.value = 2;
    await tester.pumpAndSettle();
    scholar.value.semesters = [spring];
    scholar.refresh();
    await tester.pumpAndSettle();
    expect(ctrl.semesterIndex.value, 0);
    scholar.value.semesters.clear();
    scholar.refresh();
    await tester.pumpAndSettle();
    expect(find.text('暂无成绩'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
