class Course {
  const Course({required this.id, required this.name, required this.code});

  final int id;
  final String name;
  final String code;

  String get label => code.isEmpty ? name : '$code · $name';

  /// Compact name for tight spaces: the code if it is short, else the name.
  String get shortLabel => (code.isNotEmpty && code.length <= 14) ? code : name;
}
