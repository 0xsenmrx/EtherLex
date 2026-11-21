import 'package:flutter/widgets.dart';

import '../../design_system/ether/icons.dart';

class NavDestination {
  const NavDestination(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}

/// Order matches Alt+1..6.
const List<NavDestination> kDestinations = [
  NavDestination('Assignments', '/assignments', EIcons.assignments),
  NavDestination('Activity', '/activity', EIcons.activity),
  NavDestination('Calendar', '/calendar', EIcons.calendar),
  NavDestination('Grades', '/grades', EIcons.grades),
  NavDestination('Files', '/files', EIcons.files),
  NavDestination('Assistant', '/chat', EIcons.sparkles),
];

int destinationIndexFor(String location) {
  final i = kDestinations.indexWhere((d) => location.startsWith(d.path));
  return i < 0 ? 0 : i;
}
