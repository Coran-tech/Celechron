import 'package:celechron/design/custom_colors.dart';
import '../course_detail/course_detail_view.dart';
import 'package:celechron/model/session.dart';
import 'package:celechron/design/persistent_headers.dart';
import 'course_schedule_controller.dart';
import 'package:get/get.dart';
import 'package:celechron/design/animate_button.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/design/two_line_card.dart';
import 'timetable_grid.dart';
import 'timetable_layout.dart';
import 'package:flutter/cupertino.dart';

class CourseSchedulePage extends StatelessWidget {
  late final CourseScheduleController _courseScheduleController;

  CourseSchedulePage(String name, bool first, {super.key}) {
    bool initialHideCourseInfomation = false;
    try {
      initialHideCourseInfomation =
          Get.find<CourseScheduleController>().hideCourseInfomation.value;
    } catch (e) {
      // not initialized
    }
    Get.delete<CourseScheduleController>();
    _courseScheduleController = Get.put(CourseScheduleController(
      initialName: name,
      initialFirstOrSecondSemester: first,
      initialHideCourseInfomation: initialHideCourseInfomation,
    ));
  }

  Widget _semesterPicker(BuildContext context) {
    return RoundRectangleCard(
      animate: false,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _courseScheduleController.semesters.length,
                    itemBuilder: (context, index) {
                      final semester =
                          _courseScheduleController.semesters[index];
                      return Obx(
                        () => Stack(
                          children: [
                            AnimateButton(
                              text:
                                  '${semester.name.substring(2, 5)}${semester.name.substring(7, 11)}',
                              onTap: () {
                                _courseScheduleController.semesterIndex.value =
                                    index;
                                _courseScheduleController.semesterIndex
                                    .refresh();
                              },
                              backgroundColor: _courseScheduleController
                                          .semesterIndex.value ==
                                      index
                                  ? CustomCupertinoDynamicColors.cyan
                                  : CupertinoColors.systemFill,
                            ),
                            const SizedBox(width: 90),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Obx(
            () => Hero(
              tag: 'courseSchedule',
              child: Row(
                children: [
                  Expanded(
                    child: TwoLineCard(
                        animate: true,
                        onTap: () {
                          _courseScheduleController
                              .firstOrSecondSemester.value = true;
                        },
                        title:
                            '${_courseScheduleController.semester.firstHalfName}学期课时',
                        content:
                            '${_courseScheduleController.semester.firstHalfSessionCount}节/两周',
                        backgroundColor: _courseScheduleController
                                .firstOrSecondSemester.value
                            ? _courseScheduleController.semester.name[9] == '春'
                                ? CustomCupertinoDynamicColors.spring
                                : CustomCupertinoDynamicColors.autumn
                            : CupertinoColors.systemFill,
                        withColoredFont: true),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TwoLineCard(
                        animate: true,
                        onTap: () {
                          _courseScheduleController
                              .firstOrSecondSemester.value = false;
                        },
                        title:
                            '${_courseScheduleController.semester.secondHalfName}学期课时',
                        content:
                            '${_courseScheduleController.semester.secondHalfSessionCount}节/两周',
                        backgroundColor: _courseScheduleController
                                .firstOrSecondSemester.value
                            ? CupertinoColors.systemFill
                            : _courseScheduleController.semester.name[9] == '春'
                                ? CustomCupertinoDynamicColors.summer
                                : CustomCupertinoDynamicColors.winter,
                        withColoredFont: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBlock(BuildContext context, TimetableBlock block) async {
    final courses = _courseScheduleController.semester.courses;
    final entries = <String?, List<Session>>{};
    for (final s in block.sources) {
      entries.putIfAbsent(s.id, () => []).add(s);
    }
    var id = entries.keys.first;
    if (entries.length > 1 || !courses.containsKey(id)) {
      String describe(Session s) => [
            '第${s.time.join('、')}节',
            if (s.teacher.isNotEmpty) s.teacher,
            if (s.location?.isNotEmpty == true) s.location!,
            if (s.customRepeat) '第${s.customRepeatWeeks.join('、')}周',
          ].join(' · ');
      id = await showCupertinoModalPopup<String>(
          context: context,
          builder: (sheet) => CupertinoActionSheet(
                title: Text(block.name),
                message: entries.values
                        .any((group) => !courses.containsKey(group.first.id))
                    ? Text([
                        for (final s in block.sources)
                          if (!courses.containsKey(s.id)) describe(s)
                      ].join('\n'))
                    : null,
                actions: [
                  for (final entry in entries.entries)
                    if (courses.containsKey(entry.key))
                      CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(sheet, entry.key),
                          child: Text(entry.value.map(describe).join('\n'))),
                ],
                cancelButton: CupertinoActionSheetAction(
                    onPressed: () => Navigator.pop(sheet),
                    child: const Text('返回')),
              ));
    }
    final course = courses[id];
    if (!context.mounted || course == null) return;
    await Navigator.of(context).push(CupertinoPageRoute(
      title: course.name,
      builder: (_) => CourseDetailPage.forCourse(course),
    ));
  }

  Widget _courseSchedule(BuildContext context) => RoundRectangleCard(
        animate: false,
        child: Obx(() => TimetableGrid(
              days: _courseScheduleController.sessionsByDayOfWeek,
              colorIndices: courseColorIndices(
                  _courseScheduleController.semester.sessions),
              hideInformation:
                  _courseScheduleController.hideCourseInfomation.value,
              onOpen: (block) => _openBlock(context, block),
            )),
      );

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(
          CupertinoColors.systemGroupedBackground, context),
      child: CustomScrollView(
        slivers: [
          const CelechronSliverTextHeader(subtitle: '课表'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _semesterPicker(context),
                  const SizedBox(height: 8),
                  _courseSchedule(context),
                  const SizedBox(height: 20),
                  Obx(
                    () => CupertinoListSection.insetGrouped(
                      margin: const EdgeInsetsDirectional.fromSTEB(
                          0.0, 0.0, 0.0, 10.0),
                      additionalDividerMargin: 2,
                      children: <CupertinoListTile>[
                        CupertinoListTile(
                            title: const Text('隐藏课程信息'),
                            trailing: CupertinoSwitch(
                              value: _courseScheduleController
                                  .hideCourseInfomation.value,
                              onChanged: (value) async {
                                _courseScheduleController
                                    .hideCourseInfomation.value = value;
                              },
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
