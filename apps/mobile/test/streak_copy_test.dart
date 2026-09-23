import 'package:certigo/features/streak/presentation/streak_copy.dart';
import 'package:certigo/shared/errors/error_copy.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/error_message.dart';
import 'support/technical_shape.dart';

void main() {
  group('plurals follow French: 0 and 1 are singular', () {
    test('days', () {
      expect(StreakLabels.days(0), '0 jour');
      expect(StreakLabels.days(1), '1 jour');
      expect(StreakLabels.days(12), '12 jours');
    });

    test('gems', () {
      expect(StreakLabels.gems(1), '1 gemme');
      expect(StreakLabels.gems(50), '50 gemmes');
    });
  });

  group('dates', () {
    const DefaultMaterialLocalizations l10n = DefaultMaterialLocalizations();

    test('a calendar day is formatted from its own fields, not shifted by a zone', () {
      // Stored as UTC midnight; converting it to local time first would name the
      // 2nd for every learner west of Greenwich.
      expect(formatStreakDay(l10n, DateTime.utc(2025, 1, 3)), 'Friday, January 3, 2025');
    });

    test('the deadline names the day and the hour it closes, in either clock', () {
      final DateTime local = DateTime(2025, 1, 12, 1);

      final String h24 = formatRepairDeadline(l10n, local, alwaysUse24HourFormat: true);
      final String h12 = formatRepairDeadline(l10n, local, alwaysUse24HourFormat: false);

      expect(h24, contains('12'));
      expect(h24, contains('01:00'));
      expect(h12, contains('1:00'));
      expect(technicalShapeIn(h24), isNull);
    });
  });

  group('a status that cannot be read says the cause and the action', () {
    for (final probe in realisticFailures) {
      test('${probe.name}: never technical, never silent', () {
        final ErrorCopy copy = streakStatusErrorCopy(probe.failure);

        expect(technicalShapeIn(copy.title), isNull);
        expect(technicalShapeIn(copy.message), isNull);
        expect(copy.message.trim(), isNotEmpty);
        expect(copy.actionLabel.trim(), isNotEmpty);
      });
    }

    test('a retryable cause names « ta série » and offers the retry', () {
      final ErrorCopy copy = streakStatusErrorCopy(const NetworkFailure());

      expect(copy.retryResolves, isTrue);
      expect(copy.message, contains('ta série'));
      expect(copy.actionLabel, 'Réessayer');
    });

    test('a dead end leads Home, never to the library a streak has nothing to do with', () {
      for (final Failure failure in <Failure>[const NotFoundFailure(), const ParseFailure()]) {
        final ErrorCopy copy = streakStatusErrorCopy(failure);

        expect(copy.retryResolves, isFalse, reason: '$failure');
        expect(copy.actionLabel, StreakLabels.backHome, reason: '$failure');
        expect(copy.actionIcon, isNot(Icons.refresh_rounded));
        expect(copy.message, isNot(contains('bibliothèque')), reason: '$failure');
      }
    });

    test('the copy is invariant to the text a failure carries', () {
      final ErrorCopy clean = streakStatusErrorCopy(
        const ServerFailure('Erreur serveur', statusCode: 500),
      );
      final ErrorCopy noisy = streakStatusErrorCopy(
        const ServerFailure('NullReferenceException at Certigo.Api', statusCode: 500),
      );

      expect(noisy.message, clean.message);
      expect(noisy.title, clean.title);
    });

    test('a bare exception is never rendered as-is', () {
      final ErrorCopy copy = streakStatusErrorCopy(
        StateError('boom at package:certigo/app/providers.dart:648'),
      );

      expect(copy.kind, ErrorKind.unexpected);
      expect(technicalShapeIn(copy.title), isNull);
      expect(technicalShapeIn(copy.message), isNull);
      expect(copy.retryResolves, isTrue);
    });
  });

  group('a repair that got no ruling says the cause, the action, and the promise', () {
    final List<Object> failures = <Object>[
      for (final probe in realisticFailures) probe.failure,
      const ServerFailure('Conflict', statusCode: 409),
      const ServerFailure('Too Many Requests', statusCode: 429),
      StateError('boom at package:data/src/api/client.dart:42'),
    ];

    for (final Object failure in failures) {
      test('$failure', () {
        final ({String title, String message, bool retryResolves}) copy =
            repairFailureCopy(failure);

        expect(technicalShapeIn(copy.title), isNull);
        expect(technicalShapeIn(copy.message), isNull);
        expect(copy.message.trim().length, greaterThanOrEqualTo(20));
        // The promise is only made where it is true: a retry replays the key.
        expect(copy.message.contains(StreakLabels.neverTwice), copy.retryResolves);
      });
    }

    test('a lost reply does not accuse a network that just worked', () {
      final String message = repairFailureCopy(const NetworkFailure.responseTimeout()).message;

      expect(message, isNot(contains('Wi-Fi')));
      expect(message, contains('serveur'));
    });

    test('a reply this version cannot read asks for an update, not a retry', () {
      final ({String title, String message, bool retryResolves}) copy =
          repairFailureCopy(const ParseFailure());

      expect(copy.retryResolves, isFalse);
      expect(copy.message, contains('à jour'));
    });

    test('the classification ignores the failure text', () {
      expect(
        repairFailureCopy(const NetworkFailure('OS Error: errno = 8')).message,
        repairFailureCopy(const NetworkFailure()).message,
      );
    });
  });

  group('a refusal names its cause, and « nothing charged » only when the server says so', () {
    test('each documented cause has its own sentence', () {
      final Map<String, String> messages = <String, String>{
        for (final String error in <String>[
          'insufficientGems',
          'intact',
          'expired',
          'noStreak',
          'conflict',
        ])
          error: refusalMessage(
            StreakRepairResult(
              success: false,
              streakDays: 12,
              gemsSpent: 0,
              gemsBalance: 30,
              error: error,
            ),
          ),
      };

      expect(messages['insufficientGems'], contains('30 gemmes'));
      expect(messages.values.toSet(), hasLength(messages.length));
      for (final String message in messages.values) {
        expect(message, contains(StreakLabels.notCharged));
        expect(technicalShapeIn(message), isNull);
      }
    });

    test('no « nothing charged » without the server figure behind it', () {
      final String message = refusalMessage(
        const StreakRepairResult(
          success: false,
          streakDays: 12,
          gemsSpent: 50,
          gemsBalance: 0,
          error: 'conflict',
        ),
      );

      expect(message, isNot(contains(StreakLabels.notCharged)));
    });

    test('an unknown cause is still a readable refusal', () {
      final String message = refusalMessage(
        const StreakRepairResult(
          success: false,
          streakDays: 12,
          gemsSpent: 0,
          gemsBalance: 30,
          error: 'somethingNew',
        ),
      );

      expect(message, startsWith(StreakLabels.refusedOther));
    });
  });

  test('none of the fixed copy has a technical shape', () {
    final List<String> copy = <String>[
      StreakLabels.title,
      StreakLabels.pausedTitle(12),
      StreakLabels.offerTitle,
      StreakLabels.offerBody(12),
      StreakLabels.beforeGoal,
      StreakLabels.price(50),
      StreakLabels.balance(120),
      StreakLabels.noDeadline,
      StreakLabels.repair,
      StreakLabels.repairAnyway,
      StreakLabels.checking,
      StreakLabels.missing(20),
      StreakLabels.missingHint,
      StreakLabels.missingFreezeHint,
      StreakLabels.unverifiedTitle,
      StreakLabels.unverifiedBody,
      StreakLabels.recheck,
      StreakLabels.freezeTitle,
      StreakLabels.freezeBody(12),
      StreakLabels.freezeRepairNote,
      StreakLabels.grantedTitle,
      StreakLabels.grantedBody(12),
      StreakLabels.newBalance(70),
      StreakLabels.intactTitle(12),
      StreakLabels.intactBody,
      StreakLabels.freezeReserve(2),
      StreakLabels.expiredTitle(30),
      StreakLabels.expiredBody,
      StreakLabels.noneTitle,
      StreakLabels.noneBody,
      StreakLabels.unavailableTitle,
      StreakLabels.unavailableBody,
      StreakLabels.statusMissingTitle,
      StreakLabels.statusMissingBody,
      StreakLabels.bannerTitle(12),
      StreakLabels.bannerBody(50, null),
      StreakLabels.bannerFreezeTitle,
      StreakLabels.bannerFreezeBody(12),
    ];

    for (final String text in copy) {
      expect(technicalShapeIn(text), isNull, reason: text);
      expect(text.trim(), isNotEmpty);
    }
  });
}
