import 'package:celechron/database/database_helper.dart';
import 'package:get/get.dart';

import 'package:celechron/model/semester.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/utils/gpa_helper.dart';

class GradeDetailController extends GetxController {
  final scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final semesterIndex = 0.obs;
  final customGpaMode = false.obs;
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  final RxMap<String, bool> customGpaSelected = RxMap();
  final semestersWithGrades = <Semester>[].obs;
  late final Worker _semesterWorker;

  @override
  void onInit() {
    super.onInit();
    refreshSemesters();
    _semesterWorker = ever(scholar, (_) => refreshSemesters());
    customGpaSelected.value = _db.getCustomGpa();
  }

  @override
  void onClose() {
    _semesterWorker.dispose();
    super.onClose();
  }

  void refreshSemesters() {
    final previous =
        semestersWithGrades.elementAtOrNull(semesterIndex.value)?.name;
    final updated =
        scholar.value.semesters.where((s) => s.grades.isNotEmpty).toList();
    final index = updated.indexWhere((s) => s.name == previous);
    semesterIndex.value = index < 0 ? 0 : index;
    semestersWithGrades.assignAll(updated);
  }

  Tuple<List<double>, double> getYearStats(int index) {
    final year = semestersWithGrades[index].name.substring(0, 9);
    return GpaHelper.calculateGpa(semestersWithGrades
        .where((s) => s.name.startsWith(year))
        .expand((s) => s.grades));
  }

  void refreshCustomGpa() {
    _db.setCustomGpa(customGpaSelected);
  }

  Tuple<List<double>, double> getYearMajorGpa(int semesterIndex) {
    // 提取当前学期的学年 ID，例如 "2022-2023"
    final yearId = semestersWithGrades[semesterIndex].name.substring(0, 9);

    // 获取该学年的所有主修课程
    final majorGrades = scholar.value.grades.values
        .expand((g) => g)
        .where((g) => g.major && g.semesterId.contains(yearId))
        .toList();

    // 如果该学年没有主修课程，返回 0.0, 0.0, 0.0
    if (majorGrades.isEmpty) {
      return Tuple([0.0, 0.0, 0.0], 0.0);
    }

    return GpaHelper.calculateGpa(majorGrades);
  }

  /// 检查指定学期的所有课程是否已全选
  bool isSemesterAllSelected(int semesterIndex) {
    if (semesterIndex < 0 || semesterIndex >= semestersWithGrades.length) {
      return false;
    }
    final semester = semestersWithGrades[semesterIndex];
    if (semester.grades.isEmpty) {
      return false;
    }
    for (var grade in semester.grades) {
      if (customGpaSelected[grade.id] != true) {
        return false;
      }
    }
    return true;
  }

  /// 全选指定学期的所有课程
  void selectAllGradesInSemester(int semesterIndex) {
    if (semesterIndex < 0 || semesterIndex >= semestersWithGrades.length) {
      return;
    }
    final semester = semestersWithGrades[semesterIndex];
    for (var grade in semester.grades) {
      customGpaSelected[grade.id] = true;
    }
    refreshCustomGpa();
  }

  /// 清空指定学期的所有课程选择
  void clearGradesInSemester(int semesterIndex) {
    if (semesterIndex < 0 || semesterIndex >= semestersWithGrades.length) {
      return;
    }
    final semester = semestersWithGrades[semesterIndex];
    for (var grade in semester.grades) {
      customGpaSelected[grade.id] = false;
    }
    refreshCustomGpa();
  }

  /// 切换指定学期的选择状态：如果已全选则清空，否则全选
  void toggleSemesterSelection(int semesterIndex) {
    if (isSemesterAllSelected(semesterIndex)) {
      clearGradesInSemester(semesterIndex);
    } else {
      selectAllGradesInSemester(semesterIndex);
    }
  }
}
