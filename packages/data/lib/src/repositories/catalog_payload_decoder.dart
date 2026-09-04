import '../models/track_summary.dart';

const String _appCatalogSchema = 'certigo.app-certification-catalog/v2';
const String _canonicalCatalogSchema = 'certigo.certification-catalog/v1';

List<TrackSummary> decodeTrackSummaries(Map<String, dynamic> json) {
  final String? schema = json['schema'] as String?;
  final String? sourceSchema = json['sourceSchema'] as String?;
  if (schema != _appCatalogSchema) {
    throw FormatException('Unsupported app catalog schema: $schema');
  }
  if (sourceSchema != _canonicalCatalogSchema) {
    throw FormatException('Unsupported source catalog schema: $sourceSchema');
  }
  final List<dynamic> tracks = json['tracks'] as List<dynamic>? ?? <dynamic>[];
  return tracks.map((dynamic value) {
    return TrackSummary.fromJson(value as Map<String, dynamic>);
  }).toList();
}
