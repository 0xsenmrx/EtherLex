import 'package:flutter/widgets.dart';

import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../courses/domain/course.dart';

/// Asks which course is meant, from [courses] (sorted by label). Null when cancelled.
Future<Course?> pickCourse(BuildContext context, List<Course> courses) {
  final sorted = [...courses]..sort((a, b) => a.shortLabel.toLowerCase().compareTo(b.shortLabel.toLowerCase()));
  return showEtherDialog<Course>(context, (_) => CoursePick(sorted), maxWidth: 460);
}

class CoursePick extends StatelessWidget {
  const CoursePick(this.courses);

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return EDialog(
      title: 'Which course?',
      body: courses.isEmpty
          ? Padding(padding: const EdgeInsets.all(16), child: Text('No courses yet.', style: t.meta))
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final course in courses)
                      ETap(
                        onTap: () => Navigator.of(context).pop(course),
                        builder: (context, s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(color: s.hovered ? c.hover : const Color(0x00000000), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(course.shortLabel, style: t.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (course.name != course.shortLabel) Text(course.name, style: t.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      actions: [EButton(label: 'Cancel', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop())],
    );
  }
}
