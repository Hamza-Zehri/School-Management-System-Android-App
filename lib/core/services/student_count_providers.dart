import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/extended_database_helper.dart';

final classStudentCountsProvider = FutureProvider<Map<int, int>>((ref) {
  return ExtendedDatabaseHelper.instance.getClassStudentCounts();
});

final sectionStudentCountsProvider = FutureProvider<Map<int, int>>((ref) {
  return ExtendedDatabaseHelper.instance.getSectionStudentCounts();
});
