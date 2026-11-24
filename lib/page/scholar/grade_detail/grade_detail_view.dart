import 'package:celechron/design/custom_colors.dart';
import 'package:celechron/model/grade.dart';
import 'package:celechron/model/semester.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/design/two_line_card.dart';
import 'package:celechron/design/persistent_headers.dart';
import 'grade_card.dart';
import 'grade_detail_controller.dart';
import 'package:celechron/utils/gpa_helper.dart';
import 'weighted_gpa_view.dart';

class GradeDetailPage extends StatelessWidget {
  final _gradeDetailController = Get.put(GradeDetailController());

  GradeDetailPage({super.key}) {
    _gradeDetailController.semesterIndex.value = 0;
    _gradeDetailController.customGpaMode.value = false;
  }

  Widget _buildGradeBrief(BuildContext context) {
    final index = _gradeDetailController.semesterIndex.value;
    final year = _gradeDetailController.getYearStats(index);
    final major = _gradeDetailController.getYearMajorGpa(index);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Hero(
                tag: 'gradeBrief',
                child: RoundRectangleCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TwoLineCard(
                                title: '学年学分',
                                content: year.item2.toStringAsFixed(1),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.sand),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TwoLineCard(
                                title: '学年均绩',
                                content: year.item1[0].toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.sakura),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TwoLineCard(
                                title: '学年四分制',
                                content: year.item1[1].toStringAsFixed(2),
                                extraContent: year.item1[2].toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.magenta),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TwoLineCard(
                                title: '学年主修学分',
                                content: major.item2.toStringAsFixed(1),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.peach),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TwoLineCard(
                                title: '学年主修均绩',
                                content: major.item1[0].toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.cyan),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TwoLineCard(
                                title: '学年主修四分制',
                                content: major.item1[1].toStringAsFixed(2),
                                extraContent: major.item1[2].toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.spring),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCustomGpaBrief(BuildContext context) {
    List<Grade> inSelected = [], notSelected = [];
    for (var semester in _gradeDetailController.semestersWithGrades) {
      for (var grade in semester.grades) {
        if (_gradeDetailController.customGpaSelected[grade.id] ?? false) {
          inSelected.add(grade);
        } else {
          notSelected.add(grade);
        }
      }
    }
    var inGpa = GpaHelper.calculateGpa(inSelected);
    var notGpa = GpaHelper.calculateGpa(notSelected);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Hero(
                tag: 'gradeBrief',
                child: RoundRectangleCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TwoLineCard(
                                title: '已选学分',
                                content: inGpa.item2.toStringAsFixed(1),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.sand),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TwoLineCard(
                                title: '已选五分制',
                                content: inGpa.item1[0].toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.sakura),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TwoLineCard(
                                title: '已选四分制',
                                content: inGpa.item1[1].toStringAsFixed(2),
                                extraContent: inGpa.item1[2].toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.magenta),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TwoLineCard(
                                title: '已选百分制',
                                content: inGpa.item1[3].toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.peach),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TwoLineCard(
                                title: '未选五分制',
                                content: notGpa.item1[0].toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.cyan),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TwoLineCard(
                                title: '未选四分制',
                                content: notGpa.item1[1].toStringAsFixed(2),
                                extraContent:
                                    notGpa.item1[2].toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.spring),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  int getSelectedGradeCount(Semester semester) {
    int selectedCount = 0;
    for (var i in semester.grades) {
      if (_gradeDetailController.customGpaSelected[i.id] ?? false) {
        selectedCount++;
      }
    }
    return selectedCount;
  }

  Widget _buildHistory(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: RoundRectangleCard(
                animate: false,
                child: Column(
                  children: [
                    // Horizontal scrollable list to list all semesters
                    SizedBox(
                      height: 81,
                      child: Obx(
                        () => ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              _gradeDetailController.semestersWithGrades.length,
                          itemBuilder: (context, index) {
                            final semester = _gradeDetailController
                                .semestersWithGrades[index];

                            return Obx(
                              () => Row(
                                children: [
                                  Obx(
                                    () => TwoLineCard(
                                      animate: true,
                                      withColoredFont: true,
                                      width: 120,
                                      title:
                                          '${semester.name.substring(2, 5)}${semester.name.substring(7, 11)}',
                                      content: _gradeDetailController
                                              .customGpaMode.value
                                          ? '${getSelectedGradeCount(semester)} / ${semester.grades.length}'
                                          : '${semester.gpa[0].toStringAsFixed(2)}/${semester.credits.toStringAsFixed(1)}',
                                      onTap: () {
                                        _gradeDetailController
                                            .semesterIndex.value = index;
                                        _gradeDetailController.semesterIndex
                                            .refresh();
                                      },
                                      onLongPress: _gradeDetailController
                                              .customGpaMode.value
                                          ? () {
                                              _gradeDetailController
                                                  .semesterIndex.value = index;
                                              _gradeDetailController
                                                  .semesterIndex
                                                  .refresh();
                                              _gradeDetailController
                                                  .toggleSemesterSelection(
                                                      index);
                                            }
                                          : null,
                                      backgroundColor: _gradeDetailController
                                                  .semesterIndex.value ==
                                              index
                                          ? CustomCupertinoDynamicColors.cyan
                                          : CupertinoColors.systemFill,
                                    ),
                                  ),
                                  if (index !=
                                      _gradeDetailController
                                              .semestersWithGrades.length -
                                          1)
                                    const SizedBox(width: 6),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(
          CupertinoColors.systemGroupedBackground, context),
      child: Obx(() {
        if (_gradeDetailController.semestersWithGrades.isEmpty) {
          return const CustomScrollView(slivers: [
            CelechronSliverTextHeader(subtitle: '成绩'),
            SliverFillRemaining(
                hasScrollBody: false, child: Center(child: Text('暂无成绩'))),
          ]);
        }
        final grades = _gradeDetailController
            .semestersWithGrades[_gradeDetailController.semesterIndex.value]
            .grades;
        return CustomScrollView(
          slivers: [
            CelechronSliverTextHeader(
              subtitle: '成绩',
              right: Obx(
                () => Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_gradeDetailController.customGpaMode.value)
                        GestureDetector(
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Text('长按清空'),
                            onPressed: () {},
                          ),
                          onLongPress: () {
                            _gradeDetailController.customGpaSelected.value = {};
                            _gradeDetailController.refreshCustomGpa();
                          },
                        ),
                      if (_gradeDetailController.customGpaMode.value)
                        const SizedBox(width: 8),
                      // 加权绩点入口按钮（仅在非自定义GPA模式下显示）
                      // 点击后跳转到加权绩点页面，可设置各课程的加权比例（0.8-1.2）
                      if (!_gradeDetailController.customGpaMode.value)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Icon(
                            CupertinoIcons.chart_bar_alt_fill,
                            semanticLabel: 'Weighted GPA',
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (context) => WeightedGpaPage(),
                              ),
                            );
                          },
                        ),
                      // if (!_gradeDetailController.customGpaMode.value)
                      //   const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(
                          _gradeDetailController.customGpaMode.value
                              ? CupertinoIcons
                                  .square_fill_line_vertical_square_fill
                              : CupertinoIcons.square_line_vertical_square,
                          semanticLabel: 'Custom GPA',
                        ),
                        onPressed: () {
                          _gradeDetailController.customGpaMode.value =
                              !_gradeDetailController.customGpaMode.value;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          children: [
                            _gradeDetailController.customGpaMode.value
                                ? _buildCustomGpaBrief(context)
                                : _buildGradeBrief(context),
                            _buildHistory(context),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                    ],
                  )
                ],
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 18),
                          Expanded(
                            child: GradeCard(
                              grade: grades[index],
                            ),
                          ),
                          const SizedBox(width: 18),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
                childCount: grades.length,
              ),
            ),
          ],
        );
      }),
    );
  }
}
