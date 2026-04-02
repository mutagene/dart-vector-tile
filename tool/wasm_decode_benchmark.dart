import 'dart:typed_data';

import 'package:vector_tile/vector_tile.dart';

import 'benchmark_fixture.dart';

void main(List<String> args) {
  final iterations = args.isNotEmpty ? int.parse(args[0]) : 5000;
  final warmupIterations = args.length > 1 ? int.parse(args[1]) : 500;
  final fixtureBytes = createBenchmarkFixtureBytes();

  _runBenchmark(
    fixtureBytes: fixtureBytes,
    iterations: iterations,
    warmupIterations: warmupIterations,
  );
}

void _runBenchmark({
  required Uint8List fixtureBytes,
  required int iterations,
  required int warmupIterations,
}) {
  final warmupCounts = _decodeTile(fixtureBytes);
  _checkCounts(counts: warmupCounts, expectedCounts: warmupCounts);

  for (var i = 1; i < warmupIterations; i += 1) {
    _checkCounts(
      counts: _decodeTile(fixtureBytes),
      expectedCounts: warmupCounts,
    );
  }

  var checksum = 0;
  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < iterations; i += 1) {
    final counts = _decodeTile(fixtureBytes);
    _checkCounts(counts: counts, expectedCounts: warmupCounts);
    checksum +=
        counts.featureCount + counts.propertyCount + counts.geometryCount;
  }
  stopwatch.stop();

  final averageDecodeMicros = stopwatch.elapsedMicroseconds / iterations;
  final mibPerSecond =
      fixtureBytes.length *
      iterations *
      1000000 /
      stopwatch.elapsedMicroseconds /
      (1024 * 1024);

  print(
    'iterations=$iterations warmup=$warmupIterations '
    'fixtureBytes=${fixtureBytes.length} '
    'avgMicros=${averageDecodeMicros.toStringAsFixed(2)} '
    'throughputMiBPerSecond=${mibPerSecond.toStringAsFixed(2)} '
    'checksum=$checksum',
  );
}

({int featureCount, int propertyCount, int geometryCount}) _decodeTile(
  Uint8List fixtureBytes,
) {
  final tile = VectorTile.fromBytes(bytes: fixtureBytes);

  var featureCount = 0;
  var propertyCount = 0;
  var geometryCount = 0;

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
    propertyCount: propertyCount,
    geometryCount: geometryCount,
  );
}

void _checkCounts({
  required ({int featureCount, int propertyCount, int geometryCount}) counts,
  required ({int featureCount, int propertyCount, int geometryCount})
  expectedCounts,
}) {
  if (counts != expectedCounts) {
    throw StateError(
      'Unexpected decode counts: '
      'features=${counts.featureCount}, '
      'properties=${counts.propertyCount}, '
      'geometries=${counts.geometryCount}; '
      'expected features=${expectedCounts.featureCount}, '
      'properties=${expectedCounts.propertyCount}, '
      'geometries=${expectedCounts.geometryCount}',
    );
  }
}
