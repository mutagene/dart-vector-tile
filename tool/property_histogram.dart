import 'dart:io';

import 'package:vector_tile/vector_tile.dart';

import 'benchmark_fixture.dart';

void main() {
  final bytes = createBenchmarkFixtureBytes();
  final tile = VectorTile.fromBytes(bytes: bytes);

  final histogram = <int, int>{};
  var featureCount = 0;
  var emptyProperties = 0;

  for (final layer in tile.layers) {
    for (final feature in layer.features) {
      final propertyCount = feature.tags.length ~/ 2;
      histogram[propertyCount] = (histogram[propertyCount] ?? 0) + 1;
      featureCount += 1;
      if (propertyCount == 0) {
        emptyProperties += 1;
      }
    }
  }

  stdout.writeln('features=$featureCount emptyProperties=$emptyProperties');

  final propertyCounts = histogram.keys.toList()..sort();
  for (final propertyCount in propertyCounts) {
    stdout.writeln('$propertyCount -> ${histogram[propertyCount]}');
  }
}
