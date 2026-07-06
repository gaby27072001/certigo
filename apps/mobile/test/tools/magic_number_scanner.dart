// Committed source scanner used by the magic-number ratchet guard test.
//
// Detects hardcoded (non-zero) spacing/radius numeric literals inside
// EdgeInsets.* and *Radius.circular constructor calls under
// apps/mobile/lib/features. It ignores comments and string literals, and
// excludes the parallel onboarding/auth ("Luma") session's files so this
// guard never breaks their pull requests.
//
// Pure Dart (dart:io only) so it can also be run standalone:
//   dart run apps/mobile/test/tools/magic_number_scanner.dart [featuresRoot]
import 'dart:io';

/// Constructor call prefixes whose numeric arguments encode spacing/radius.
const List<String> kTriggers = <String>[
  'EdgeInsets.all',
  'EdgeInsets.symmetric',
  'EdgeInsets.only',
  'EdgeInsets.fromLTRB',
  'BorderRadius.circular',
  'Radius.circular',
];

/// Feature sub-paths excluded from the guard because they are owned by the
/// parallel onboarding/auth ("Luma") session. Keeping them out means this
/// guard never breaks their PRs, and the ratchet can still reach zero on the
/// screens we own.
const List<String> kExcludedPaths = <String>[
  '/features/auth/',
  '/features/onboarding/',
  '/features/path/presentation/cert_picker_sheet.dart',
];

/// Matches an int or decimal literal not preceded by a word char, '.', or '$'
/// (so member access and interpolation are not mistaken for a literal).
final RegExp _numberLiteral = RegExp(r'(?<![\w.$])\d+(?:\.\d+)?');

/// A single hardcoded spacing/radius literal found in the scanned sources.
class Violation {
  Violation(this.file, this.line, this.trigger, this.value);

  final String file;
  final int line;
  final String trigger;
  final String value;

  @override
  String toString() => '$file:$line  $trigger(...) -> $value';
}

bool _isExcluded(String path) {
  final String p = path.replaceAll(r'\', '/');
  for (final String e in kExcludedPaths) {
    if (p.contains(e)) {
      return true;
    }
  }
  return false;
}

bool _isIdentifierChar(String ch) {
  final int code = ch.codeUnitAt(0);
  final bool digit = code >= 0x30 && code <= 0x39;
  final bool upper = code >= 0x41 && code <= 0x5A;
  final bool lower = code >= 0x61 && code <= 0x7A;
  return digit || upper || lower || code == 0x5F || code == 0x24;
}

bool _isSpace(String ch) => ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r';

/// Replaces line/block comments and string literals with spaces (preserving
/// newlines) so their contents are never scanned for triggers or numbers.
String _stripNoise(String src) {
  final StringBuffer out = StringBuffer();
  final int n = src.length;
  var i = 0;
  while (i < n) {
    final String c = src[i];
    final String c2 = (i + 1 < n) ? src[i + 1] : '';
    if (c == '/' && c2 == '/') {
      while (i < n && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && c2 == '*') {
      i += 2;
      while (i < n && !(src[i] == '*' && (i + 1 < n) && src[i + 1] == '/')) {
        if (src[i] == '\n') {
          out.write('\n');
        }
        i++;
      }
      i += 2;
      continue;
    }
    var raw = false;
    var start = i;
    if (c == 'r' && (c2 == "'" || c2 == '"')) {
      raw = true;
      start = i + 1;
    }
    final String q = raw ? src[start] : c;
    if (q == "'" || q == '"') {
      final bool triple = (start + 2 < n) && src[start + 1] == q && src[start + 2] == q;
      final int delimLen = triple ? 3 : 1;
      var j = start + delimLen;
      while (j < n) {
        if (!raw && src[j] == r'\') {
          if (src[j] == '\n') {
            out.write('\n');
          }
          j += 2;
          continue;
        }
        if (triple) {
          if (src[j] == q && (j + 2 < n) && src[j + 1] == q && src[j + 2] == q) {
            j += 3;
            break;
          }
        } else {
          if (src[j] == q) {
            j += 1;
            break;
          }
          if (src[j] == '\n') {
            break;
          }
        }
        if (src[j] == '\n') {
          out.write('\n');
        }
        j++;
      }
      i = j;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Returns the balanced-parenthesis argument region starting at [openParen].
String _regionAfter(String src, int openParen) {
  var depth = 0;
  final StringBuffer sb = StringBuffer();
  for (var k = openParen; k < src.length; k++) {
    final String ch = src[k];
    if (ch == '(') {
      depth++;
      if (depth == 1) {
        continue;
      }
    } else if (ch == ')') {
      depth--;
      if (depth == 0) {
        break;
      }
    }
    sb.write(ch);
  }
  return sb.toString();
}

int _lineAt(String src, int index) => '\n'.allMatches(src.substring(0, index)).length + 1;

/// Scans every non-excluded `.dart` file under [featuresRoot] and returns the
/// list of hardcoded, non-zero spacing/radius literals found.
List<Violation> scanFeatureMagicNumbers(String featuresRoot) {
  final List<Violation> violations = <Violation>[];
  final Directory dir = Directory(featuresRoot);
  if (!dir.existsSync()) {
    return violations;
  }
  final List<File> files = <File>[];
  for (final FileSystemEntity entity in dir.listSync(recursive: true)) {
    if (entity is! File) {
      continue;
    }
    if (!entity.path.endsWith('.dart')) {
      continue;
    }
    if (_isExcluded(entity.path)) {
      continue;
    }
    files.add(entity);
  }
  files.sort((File a, File b) => a.path.compareTo(b.path));
  for (final File f in files) {
    final String clean = _stripNoise(f.readAsStringSync());
    for (final String trig in kTriggers) {
      var from = 0;
      while (true) {
        final int idx = clean.indexOf(trig, from);
        if (idx < 0) {
          break;
        }
        from = idx + trig.length;
        // Left identifier boundary: skips Radius.circular nested inside
        // BorderRadius.circular so it is not double-counted.
        if (idx > 0 && _isIdentifierChar(clean[idx - 1])) {
          continue;
        }
        var p = idx + trig.length;
        while (p < clean.length && _isSpace(clean[p])) {
          p++;
        }
        if (p >= clean.length || clean[p] != '(') {
          continue;
        }
        final String region = _regionAfter(clean, p);
        final int line = _lineAt(clean, idx);
        for (final Match m in _numberLiteral.allMatches(region)) {
          final String raw = m.group(0)!;
          // Zero is not a magic dimension (it means "none"), so skip it.
          if (double.parse(raw) == 0) {
            continue;
          }
          violations.add(Violation(f.path, line, trig, raw));
        }
      }
    }
  }
  return violations;
}

void main(List<String> args) {
  final String root = args.isNotEmpty ? args[0] : 'apps/mobile/lib/features';
  final List<Violation> violations = scanFeatureMagicNumbers(root);
  for (final Violation v in violations) {
    stdout.writeln(v.toString());
  }
  stdout.writeln('COUNT=${violations.length}');
}
