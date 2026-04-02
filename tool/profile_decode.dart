import 'dart:io';
import 'dart:math';

import 'package:vector_tile/raw/raw_vector_tile.dart' as raw;
import 'package:vector_tile/vector_tile.dart';

import 'benchmark_fixture.dart';

const _iterations = 100;

void main() {
  final bytes = createBenchmarkFixtureBytes();
  final rawTile = raw.VectorTile.fromBuffer(bytes);

  _benchmark('raw.VectorTile.fromBuffer', _iterations, () {
    raw.VectorTile.fromBuffer(bytes);
    return 1;
  }, bytes.length);

  _benchmark('VectorTileLayer.fromRaw', _iterations, () {
    var featureCount = 0;
    for (final rawLayer in rawTile.layers) {
      featureCount += VectorTileLayer.fromRaw(
        rawLayer: rawLayer,
      ).features.length;
    }
    return featureCount;
  }, bytes.length);

  _benchmark('decodeProperties', _iterations, () {
    var propertyCount = 0;
    for (final rawLayer in rawTile.layers) {
      final layer = VectorTileLayer.fromRaw(rawLayer: rawLayer);
      for (final feature in layer.features) {
        propertyCount += feature.decodeProperties().length;
      }
    }
    return propertyCount;
  }, bytes.length);

  _benchmark('decodeGeometry', _iterations, () {
    var geometryCount = 0;
    for (final rawLayer in rawTile.layers) {
      final layer = VectorTileLayer.fromRaw(rawLayer: rawLayer);
      for (final feature in layer.features) {
        if (feature.decodeGeometry() != null) {
          geometryCount += 1;
        }
      }
    }
    return geometryCount;
  }, bytes.length);

  _benchmark('decodePolygon commands only', _iterations, () {
    var ringCount = 0;
    for (final rawLayer in rawTile.layers) {
      final layer = VectorTileLayer.fromRaw(rawLayer: rawLayer);
      for (final feature in layer.features) {
        ringCount += feature.decodePolygon().length;
      }
    }
    return ringCount;
  }, bytes.length);

  _benchmark('VectorTile.fromBytes + properties + geometry', _iterations, () {
    final tile = VectorTile.fromBytes(bytes: bytes);
    var decodedCount = 0;
    for (final layer in tile.layers) {
      for (final feature in layer.features) {
        decodedCount += feature.decodeProperties().length;
        if (feature.decodeGeometry() != null) {
          decodedCount += 1;
        }
      }
    }
    return decodedCount;
  }, bytes.length);
}

void _benchmark(
  String label,
  int iterations,
  int Function() run,
  int bytesLength,
) {
  final warmupResult = run();
  if (warmupResult <= 0) {
    throw StateError('$label produced no decoded data');
  }

  final samples = <int>[];
  var result = 0;
  for (var i = 0; i < iterations; i += 1) {
    final stopwatch = Stopwatch()..start();
    result = run();
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds);
  }

  samples.sort();
  final totalMicros = samples.reduce((a, b) => a + b);
  final avgMicros = totalMicros / samples.length;
  final medianMicros = samples[samples.length ~/ 2];
  final p90Micros = samples[(samples.length * 0.9).floor()];
  final mibPerSecond = bytesLength * 1000000 / avgMicros / pow(1024, 2);

  stdout.writeln(
    '$label: result=$result '
    'avg=${avgMicros.toStringAsFixed(1)}us '
    'median=${medianMicros}us '
    'p90=${p90Micros}us '
    'throughput=${mibPerSecond.toStringAsFixed(2)}MiB/s',
  );
}
