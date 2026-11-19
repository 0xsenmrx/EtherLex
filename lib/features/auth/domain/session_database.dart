import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'auth_provider.dart';

/// One cache database per signed-in Canvas account; null for sample mode.
final appDatabaseProvider = Provider<AppDatabase?>((ref) {
  final session = ref.watch(authProvider.select((a) => a.value));
  if (session == null || session.isSample) return null;
  final db = AppDatabase.forAccount(session.baseUrl);
  ref.onDispose(db.close);
  return db;
});
