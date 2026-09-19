import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'technical_shape.dart';

// Transport diagnostics can arrive as ServerFailure.message, not just as a
// NetworkFailure. Keep these probes shared by the library and module guards.
const List<({String name, Failure failure})> realisticFailures = <({String name, Failure failure})>[
  (
    name: 'transport non typé par Dio',
    failure: ServerFailure(
      'SocketException: Failed host lookup: \'api.certigo.invalid\' '
      '(OS Error: nodename nor servname provided, errno = 8)',
    ),
  ),
  (
    name: 'délai Dio',
    failure: ServerFailure(
      'DioException [connection timeout]: The request connection took longer '
      'than 0:00:30.000000 and it was aborted.',
      statusCode: null,
    ),
  ),
  (
    name: '500 avec detail technique',
    failure: ServerFailure(
      'Unhandled exception: NullReferenceException at Certigo.Api.Functions',
      statusCode: 500,
    ),
  ),
  (name: '404', failure: NotFoundFailure()),
  (name: '401', failure: AuthFailure()),
  (name: 'hors ligne', failure: NetworkFailure()),
  (name: 'délai de réponse', failure: NetworkFailure.responseTimeout()),
  (name: 'contrat rompu', failure: ParseFailure('Expected a JSON object')),
  (name: 'non qualifié', failure: UnknownFailure('Instance of \'_Exception\'')),
];

List<String> renderedText(WidgetTester tester) {
  final List<String> out = <String>[];
  for (final Widget widget in tester.allWidgets) {
    if (widget is Text) {
      final String? data = widget.data;
      if (data != null) out.add(data);
      final InlineSpan? span = widget.textSpan;
      if (span != null) out.add(span.toPlainText());
    } else if (widget is SelectableText) {
      final String? data = widget.data;
      if (data != null) out.add(data);
      final TextSpan? span = widget.textSpan;
      if (span != null) out.add(span.toPlainText());
    }
  }
  return out;
}

void expectNoTechnicalText(WidgetTester tester, {required String context}) {
  for (final String text in renderedText(tester)) {
    final String? shape = technicalShapeIn(text);
    expect(
      shape,
      isNull,
      reason: '$context : un détail technique atteint l\u2019écran.\n'
          '  forme détectée : $shape\n'
          '  texte rendu    : ${text.replaceAll('\n', ' ⏎ ')}',
    );
  }
}
