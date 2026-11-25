import 'package:celechron/model/session.dart';
import 'package:flutter/cupertino.dart';

import 'timetable_card.dart';
import 'timetable_layout.dart';

class TimetableGrid extends StatelessWidget {
  final List<List<Session>> days;
  final Map<String, int> colorIndices;
  final bool hideInformation;
  final ValueChanged<TimetableBlock> onOpen;
  const TimetableGrid(
      {super.key,
      required this.days,
      required this.colorIndices,
      required this.hideInformation,
      required this.onOpen});

  static const _times = [
    '08:00',
    '08:50',
    '10:00',
    '10:50',
    '11:40',
    '13:25',
    '14:15',
    '15:05',
    '16:15',
    '17:05',
    '18:50',
    '19:40',
    '20:30'
  ];
  static const _rowHeight = 44.0;
  static const _gutter = 34.0;

  @override
  Widget build(BuildContext context) {
    final columns = [
      for (final sessions in days.skip(1)) layoutTimetableDay(sessions)
    ];
    final rows = columns.expand((day) => day).fold(timetablePeriods,
        (count, block) => block.end > count ? block.end : count);
    final dark = CupertinoTheme.brightnessOf(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final line =
        CupertinoColors.separator.resolveFrom(context).withValues(alpha: .13);
    final patterns = [
      CourseWeeks.every,
      CourseWeeks.odd,
      CourseWeeks.even,
      if (columns
          .expand((c) => c)
          .any((b) => b.weeks.contains(CourseWeeks.custom)))
        CourseWeeks.custom
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(alignment: WrapAlignment.end, spacing: 12, runSpacing: 4, children: [
        for (final p in patterns)
          Row(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: CustomPaint(
                    size: const Size(19, 13),
                    painter:
                        CourseSurface(CourseColors.forIndex(0, dark), [p]))),
            const SizedBox(width: 4),
            Text(p.label, style: TextStyle(color: secondary, fontSize: 12)),
          ]),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        const SizedBox(width: _gutter),
        for (final d in '一二三四五六日'.split(''))
          Expanded(
              child: Text(d,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)))
      ]),
      const SizedBox(height: 6),
      SizedBox(
          height: rows * _rowHeight,
          child: Stack(children: [
            for (var i = 0; i < rows; i++)
              Positioned(
                  top: i * _rowHeight,
                  left: _gutter,
                  right: 0,
                  child: Container(height: .6, color: line)),
            Row(children: [
              SizedBox(
                  width: _gutter,
                  child: Column(children: [
                    for (var i = 0; i < rows; i++)
                      Expanded(
                          child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          if (i < _times.length)
                            Text(_times[i],
                                style: TextStyle(fontSize: 9, color: secondary))
                        ],
                      )),
                  ])),
              for (final day in columns)
                Expanded(
                    child: LayoutBuilder(
                        builder: (context, size) =>
                            Stack(fit: StackFit.expand, children: [
                              for (final b in day)
                                Positioned(
                                  left: size.maxWidth * b.lane / b.laneCount,
                                  width: size.maxWidth / b.laneCount,
                                  top: (b.start - 1) * _rowHeight,
                                  height: b.weeks.length * _rowHeight,
                                  child: TimetableCard(
                                      block: b,
                                      colors: CourseColors.forIndex(
                                          colorIndices[b.key]!, dark),
                                      hideInformation: hideInformation,
                                      onPressed: () => onOpen(b)),
                                ),
                            ]))),
            ]),
          ])),
    ]);
  }
}
