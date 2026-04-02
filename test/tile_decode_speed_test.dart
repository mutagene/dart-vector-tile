import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vector_tile/vector_tile.dart';

import '../tool/benchmark_fixture.dart';

const _iterations = 500;

({int featureCount, int geometryCount, int propertyCount}) _decodeTile(
  Uint8List bytes,
) {
  final tile = VectorTile.fromBytes(bytes: bytes);

  var featureCount = 0;
  var geometryCount = 0;
  var propertyCount = 0;

  for (final layer in tile.layers) {
    featureCount += layer.features.length;
    for (final feature in layer.features) {
      propertyCount += feature.decodeProperties().length;
      if (feature.decodeGeometry() != null) {
        geometryCount += 1;
      }
    }
  }

  return (
    featureCount: featureCount,
    geometryCount: geometryCount,
    propertyCount: propertyCount,
  );
}

void main() {
  test(
    'profiles synthetic multipolygon tile decode speed',
    () async {
      final fixtureBytes = createBenchmarkFixtureBytes();

      final warmupCounts = _decodeTile(fixtureBytes);
      expect(warmupCounts.featureCount, benchmarkFixtureFeatureCount);
      expect(warmupCounts.geometryCount, warmupCounts.featureCount);
      expect(warmupCounts.propertyCount, greaterThan(0));

      final warmupTile = VectorTile.fromBytes(bytes: fixtureBytes);
      final warmupGeometry = warmupTile.layers.single.features.first
          .decodeGeometry();
      expect(warmupGeometry, isA<GeometryMultiPolygon>());

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < _iterations; i += 1) {
        final counts = _decodeTile(fixtureBytes);
        expect(counts, warmupCounts);
      }
      stopwatch.stop();

      final averageDecodeMicros = stopwatch.elapsedMicroseconds / _iterations;
      final mibPerSecond =
          fixtureBytes.length *
          _iterations *
          1000000 /
          stopwatch.elapsedMicroseconds /
          (1024 * 1024);

      print(
        'Decoded ${fixtureBytes.length} fixture bytes x$_iterations in '
        '${stopwatch.elapsedMilliseconds} ms; '
        'avg ${averageDecodeMicros.toStringAsFixed(1)} us/decode; '
        '${mibPerSecond.toStringAsFixed(2)} MiB/s; '
        '${warmupCounts.featureCount} features, '
        '${warmupCounts.propertyCount} properties.',
      );
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
