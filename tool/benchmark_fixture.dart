import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:vector_tile/raw/raw_vector_tile.dart' as raw;
import 'package:vector_tile/util/command.dart';

const benchmarkFixtureFeatureCount = 1024;

Uint8List createBenchmarkFixtureBytes() {
  return raw
      .createVectorTile(
        layers: [
          raw.createVectorTileLayer(
            name: 'synthetic_parcels',
            extent: 4096,
            version: 2,
            keys: const ['name', 'category', 'zone', 'rank'],
            values: [
              for (var i = 0; i < benchmarkFixtureFeatureCount; i += 1)
                raw.createVectorTileValue(stringValue: 'Parcel $i'),
              raw.createVectorTileValue(stringValue: 'synthetic-parcel'),
              raw.createVectorTileValue(stringValue: 'Zone A'),
              raw.createVectorTileValue(stringValue: 'Zone B'),
              for (var rank = 0; rank < 4; rank += 1)
                raw.createVectorTileValue(intValue: Int64(rank)),
            ],
            features: [
              for (var i = 0; i < benchmarkFixtureFeatureCount; i += 1)
                raw.createVectorTileFeature(
                  id: Int64(i + 1),
                  type: raw.VectorTile_GeomType.POLYGON,
                  tags: [
                    0,
                    i,
                    1,
                    benchmarkFixtureFeatureCount,
                    2,
                    benchmarkFixtureFeatureCount + 1 + (i & 1),
                    3,
                    benchmarkFixtureFeatureCount + 3 + (i & 3),
                  ],
                  geometry: _encodeFeatureGeometry(i),
                ),
            ],
          ),
        ],
      )
      .writeToBuffer();
}

List<int> _encodeFeatureGeometry(int index) {
  final tileColumn = index % 32;
  final tileRow = index ~/ 32;
  final originX = 32 + tileColumn * 126;
  final originY = 32 + tileRow * 126;

  return _encodePolygonGeometry([
    [
      [originX, originY],
      [originX + 84, originY],
      [originX + 84, originY + 84],
      [originX, originY + 84],
    ],
    [
      [originX + 18, originY + 18],
      [originX + 18, originY + 44],
      [originX + 44, originY + 44],
      [originX + 44, originY + 18],
    ],
    [
      [originX + 92, originY + 30],
      [originX + 116, originY + 30],
      [originX + 116, originY + 54],
      [originX + 92, originY + 54],
    ],
  ]);
}

List<int> _encodePolygonGeometry(List<List<List<int>>> rings) {
  final geometry = <int>[];
  var cursorX = 0;
  var cursorY = 0;

  for (final ring in rings) {
    geometry.add((1 << 3) | CommandID.MoveTo);
    geometry.add(Command.zigZagEncode(ring[0][0] - cursorX));
    geometry.add(Command.zigZagEncode(ring[0][1] - cursorY));
    cursorX = ring[0][0];
    cursorY = ring[0][1];

    geometry.add(((ring.length - 1) << 3) | CommandID.LineTo);
    for (var i = 1; i < ring.length; i += 1) {
      geometry.add(Command.zigZagEncode(ring[i][0] - cursorX));
      geometry.add(Command.zigZagEncode(ring[i][1] - cursorY));
      cursorX = ring[i][0];
      cursorY = ring[i][1];
    }

    geometry.add((1 << 3) | CommandID.ClosePath);
  }

  return geometry;
}
