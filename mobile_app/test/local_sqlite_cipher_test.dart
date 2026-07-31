import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('native sqlite bundle provides sqlite3mc cipher support', () {
    if (kIsWeb) return;

    final database = sqlite3.openInMemory();
    try {
      final rows = database.select('PRAGMA cipher');
      expect(
        rows,
        isNotEmpty,
        reason:
            'Production local storage must fail closed unless sqlite3mc is '
            'bundled by the sqlite3 build hook.',
      );
      expect(rows.first.values.any((value) => '$value'.isNotEmpty), isTrue);
    } finally {
      database.close();
    }
  });
}
