import 'dart:convert';
import 'dart:io';

import 'package:certigo/features/lesson/application/answer_grading.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Replays docs/contracts/learning-journey/v1/answer-grading.vectors.json, also read
/// by backend/tests/Certigo.Domain.Tests/AnswerGradingVectorTests.cs: the client's
/// immediate feedback must grade every shared case exactly like the server.
void main() {
  final Map<String, dynamic> document = jsonDecode(
    File('../../docs/contracts/learning-journey/v1/answer-grading.vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('the shared vectors use the expected schema', () {
    expect(document['schema'], 'certigo.answer-grading-vectors/v1');
  });

  for (final dynamic raw in document['vectors'] as List<dynamic>) {
    final Map<String, dynamic> vector = raw as Map<String, dynamic>;
    test('client grading: ${vector['name']}', () {
      final ItemType type = itemTypeFrom(vector['type'] as String);
      expect(type, isNot(ItemType.unknown));

      expect(
        gradeSelection(
          type,
          List<String>.from(vector['selected'] as List<dynamic>),
          List<String>.from(vector['correct'] as List<dynamic>),
        ),
        vector['expected'] as bool,
      );
    });
  }
}
