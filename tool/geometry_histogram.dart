import 'dart:io';

import 'package:vector_tile/vector_tile.dart';

import 'benchmark_fixture.dart';

void main() {
  final bytes = createBenchmarkFixtureBytes();
  final tile = VectorTile.fromBytes(bytes: bytes);

  final geometryTypes = <VectorTileGeomType?, int>{};
  final geometryCommandLengths = <int, int>{};
  var featureCount = 0;
  var totalGeometryCommands = 0;
  var maxGeometryCommands = 0;

  for (final layer in tile.layers) {
    for (final feature in layer.features) {
      featureCount += 1;

      geometryTypes[feature.type] = (geometryTypes[feature.type] ?? 0) + 1;

      final commandCount = feature.geometryList?.length ?? 0;
      totalGeometryCommands += commandCount;
      if (commandCount > maxGeometryCommands) {
        maxGeometryCommands = commandCount;
      }

      final bucket = commandCount < 20
          ? commandCount
          : commandCount < 50
          ? 20
          : commandCount < 100
          ? 50
          : commandCount < 200
          ? 100
          : 200;
      geometryCommandLengths[bucket] =
          (geometryCommandLengths[bucket] ?? 0) + 1;
    }
  }

  stdout.writeln('features=$featureCount');
  stdout.writeln('avgGeometryCommands=${totalGeometryCommands / featureCount}');
  stdout.writeln('maxGeometryCommands=$maxGeometryCommands');

  for (final entry in geometryTypes.entries) {
    stdout.writeln('${entry.key} -> ${entry.value}');
  }

  final buckets = geometryCommandLengths.keys.toList()..sort();
  for (final bucket in buckets) {
    stdout.writeln('commands $bucket -> ${geometryCommandLengths[bucket]}');
  }
}
