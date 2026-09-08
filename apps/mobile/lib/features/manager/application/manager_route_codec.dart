String decodeManagerOrganizationIdSegment(String encodedSegment) {
  return Uri.decodeComponent(encodedSegment);
}

String managerOrganizationIdFromUri(Uri uri) {
  final String rawUri = uri.toString();
  final Iterable<int> suffixIndexes = <int>[
    rawUri.indexOf('?'),
    rawUri.indexOf('#'),
  ].where((int index) => index >= 0);
  final int pathEnd = suffixIndexes.isEmpty
      ? rawUri.length
      : suffixIndexes.reduce((int left, int right) => left < right ? left : right);
  final String rawPath = rawUri.substring(0, pathEnd);
  final int segmentStart = rawPath.lastIndexOf('/') + 1;
  if (segmentStart == 0 || segmentStart == rawPath.length) {
    throw const FormatException('Manager organization route segment is missing.');
  }
  return decodeManagerOrganizationIdSegment(rawPath.substring(segmentStart));
}
