import 'package:flutter/cupertino.dart';

import '../../../database/course_color_preferences.dart';
import '../course_schedule/course_palette.dart';

class CourseColorRow extends StatelessWidget {
  final CourseColorPreferences preferences;
  final String courseKey, name;
  final Map<String, int> indices;
  const CourseColorRow(
      {super.key,
      required this.preferences,
      required this.courseKey,
      required this.name,
      required this.indices});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: preferences.changes,
        builder: (context, _, __) {
          final others = preferences.overrides;
          final saved = others.remove(courseKey);
          final automatic = timetableRgb(indices, others)[courseKey]!;
          final colors = CourseColors.fromRgb(
              saved ?? automatic, CupertinoTheme.brightnessOf(context),
              custom: saved != null);
          return CupertinoListSection.insetGrouped(
            margin: const EdgeInsets.only(top: 10),
            children: [
              CupertinoListTile(
                title: const Text('课表颜色'),
                additionalInfo: Text(saved == null ? '自动' : '自定义'),
                leading: _Chip(color: colors.fill),
                trailing: const CupertinoListTileChevron(),
                onTap: () => showCupertinoModalPopup<void>(
                    context: context,
                    builder: (_) => CourseColorEditor(
                        name: name,
                        automatic: automatic,
                        saved: saved,
                        onSave: (rgb) => preferences.set(courseKey, rgb))),
              )
            ],
          );
        },
      );
}

class _Chip extends StatelessWidget {
  final Color color;
  const _Chip({required this.color});
  @override
  Widget build(BuildContext context) => Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              width: .6,
              color: CupertinoColors.separator.resolveFrom(context))));
}

class CourseColorEditor extends StatefulWidget {
  final String name;
  final int automatic;
  final int? saved;
  final Future<void> Function(int?) onSave;
  const CourseColorEditor(
      {super.key,
      required this.name,
      required this.automatic,
      required this.saved,
      required this.onSave});

  @override
  State<CourseColorEditor> createState() => _CourseColorEditorState();
}

class _CourseColorEditorState extends State<CourseColorEditor> {
  late int? selected = widget.saved;
  late final hex =
      TextEditingController(text: courseHex(selected ?? widget.automatic));
  bool valid = true, saving = false, saveFailed = false;

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  void choose(int? rgb) {
    FocusScope.of(context).unfocus();
    setState(() {
      selected = rgb;
      valid = true;
      saveFailed = false;
      hex.text = courseHex(rgb ?? widget.automatic);
    });
  }

  void enter(String value) {
    final digits = value.trim().replaceFirst(RegExp(r'^#'), '');
    setState(() {
      valid = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(digits);
      if (valid) selected = int.parse(digits, radix: 16);
      saveFailed = false;
    });
  }

  Future<void> save() async {
    if (!valid || saving) return;
    setState(() => saving = true);
    try {
      await widget.onSave(selected);
      if (mounted && ModalRoute.of(context)?.isCurrent == true)
        Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          saving = false;
          saveFailed = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = CupertinoTheme.brightnessOf(context);
    final colors = CourseColors.fromRgb(selected ?? widget.automatic, mode,
        custom: selected != null);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
            top: false,
            child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: bg,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20))),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              CupertinoButton(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  onPressed: saving
                                      ? null
                                      : () => Navigator.pop(context),
                                  child: const Text('取消')),
                              const Expanded(
                                  child: Text('课表颜色',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600))),
                              CupertinoButton(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  onPressed: valid && !saving ? save : null,
                                  child: saving
                                      ? const CupertinoActivityIndicator()
                                      : const Text('完成')),
                            ]),
                            const SizedBox(height: 6),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                    color: colors.fill,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(widget.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: colors.ink,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600))),
                            const SizedBox(height: 10),
                            for (var row = 0; row < 3; row++)
                              Row(children: [
                                for (final tone
                                    in coursePalette.skip(row * 5).take(5))
                                  Expanded(child: Builder(builder: (context) {
                                    final c = CourseColors.fromRgb(
                                        tone.rgb, mode,
                                        custom: true);
                                    final checked =
                                        valid && selected == tone.rgb;
                                    return Semantics(
                                        key: ValueKey(tone.rgb),
                                        label: tone.name,
                                        selected: checked,
                                        child: CupertinoButton(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 3, vertical: 4),
                                            onPressed: saving
                                                ? null
                                                : () => choose(tone.rgb),
                                            child: Container(
                                                height: 36,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                    color: c.fill,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            7)),
                                                child: checked
                                                    ? Icon(
                                                        CupertinoIcons
                                                            .check_mark,
                                                        size: 20,
                                                        color: c.ink)
                                                    : null)));
                                  }))
                              ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              const Text('自定义色值'),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: CupertinoTextField(
                                      controller: hex,
                                      placeholder: 'RRGGBB',
                                      textAlign: TextAlign.end,
                                      prefix: Padding(
                                          padding:
                                              const EdgeInsets.only(left: 10),
                                          child: Text('#',
                                              style:
                                                  TextStyle(color: secondary))),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 9),
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      enabled: !saving,
                                      onChanged: enter,
                                      onSubmitted: (_) {
                                        if (valid) save();
                                      })),
                            ]),
                            if (!valid || saveFailed)
                              Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                      saveFailed
                                          ? '颜色未保存，请重试。'
                                          : '请输入 6 位十六进制色值，例如 3477B9。',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: CupertinoColors.systemRed
                                              .resolveFrom(context)))),
                            const SizedBox(height: 6),
                            CupertinoButton(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                onPressed: saving || (selected == null && valid)
                                    ? null
                                    : () => choose(null),
                                child: Text(selected == null && valid
                                    ? '已使用自动配色'
                                    : '恢复自动配色')),
                          ]),
                    ),
                  ),
                ))));
  }
}
