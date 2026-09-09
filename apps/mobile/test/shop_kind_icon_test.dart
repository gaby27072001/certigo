import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:certigo/features/shop/presentation/shop_screen.dart';

/// Icon coverage for every shop kind the server can actually emit.
///
/// `shopKindIcon` is fed `ShopItemDto.kind`, which the API builds with
/// `i.Kind.ToString()` (`GamificationServices.cs:37`) — the .NET enum member
/// name. Rather than mirroring `ShopItemKind` by hand, this test **reads the
/// enum out of the C# source**, so the day someone adds a member server-side
/// the coverage test goes red on its own instead of the app quietly rendering
/// a generic shopping bag.
///
/// The parser proves itself before it is trusted: `the enum parser finds
/// members` is the positive control, and a coverage pass over an empty list
/// would be meaningless without it.
void main() {
  const IconData generic = Icons.shopping_bag_rounded;
  final List<String> serverKinds = _readServerShopItemKinds();

  test('the enum parser finds members', () {
    // Control: an empty parse would make every coverage assertion below pass
    // vacuously. If this fails, the source moved — fix the path, do not relax
    // the coverage test.
    expect(serverKinds, isNotEmpty);
  });

  test('every server shop kind maps to a specific icon', () {
    for (final String kind in serverKinds) {
      expect(shopKindIcon(kind), isNot(generic), reason: '$kind falls back to the generic icon');
    }
  });

  test('the wire spelling is matched whatever its form', () {
    // Four spellings of this one concept have coexisted in this repository:
    // the server value, the value the screen used to expect, the value the
    // widget test used to seed, and a short alias.
    const List<String> forms = <String>[
      'StreakFreeze',
      'streak_freeze',
      'streakFreeze',
      'STREAK-FREEZE',
    ];
    for (final String form in forms) {
      expect(shopKindIcon(form), Icons.ac_unit_rounded, reason: form);
    }
  });

  test('an unknown kind still falls back to the generic icon', () {
    // Normalisation absorbs a change of form, never a change of name: a real
    // server-side rename has to stay visible.
    expect(shopKindIcon('StreakProtection'), generic);
    expect(shopKindIcon(''), generic);
  });
}

/// Reads the members of `ShopItemKind` from the backend source.
List<String> _readServerShopItemKinds() {
  final File source = File('../../backend/src/Certigo.Domain/Gamification/ShopCatalog.cs');
  if (!source.existsSync()) {
    throw StateError('ShopItemKind source not found at ${source.path}');
  }
  final RegExp block = RegExp(r'enum\s+ShopItemKind\s*\{([^}]*)\}');
  final RegExpMatch? match = block.firstMatch(source.readAsStringSync());
  if (match == null) {
    throw StateError('ShopItemKind declaration not found in ${source.path}');
  }
  return match
      .group(1)!
      .split(',')
      .map((String member) => member.replaceAll(RegExp('//.*'), ''))
      .map((String member) => member.split('=').first.trim())
      .where((String member) => member.isNotEmpty)
      .toList();
}
