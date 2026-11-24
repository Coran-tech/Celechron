import 'package:celechron/model/exam.dart';
import 'package:flutter_test/flutter_test.dart';

Exam parse(String text) =>
    Exam.parseExamsFromZdbk({'kssj': text}, 'test', '数学').single;

void main() {
  test('考试周标签和时段在保存和读取后仍保留', () {
    for (final (source, expected) in [
      ('冬考试周第10天(08:00-10:00)', '冬考试周第 10 天 08:00 - 10:00'),
      ('秋考试周第3天(10:30-12:30)', '秋考试周第 3 天 10:30 - 12:30'),
    ]) {
      expect(Exam.fromJson(parse(source).toJson()).chineseTime, expected);
    }
  });
  test('旧格式及补发具体日期优先使用真实日期', () {
    for (final source in [
      '2025年08月23日(14:00-16:40)',
      '冬考试周第10天 2025-08-23（14:00～16:40）',
    ]) {
      final exam = parse(source);
      expect(exam.dateLabel, isNull);
      expect(exam.time,
          [DateTime(2025, 8, 23, 14), DateTime(2025, 8, 23, 16, 40)]);
    }
  });
}
