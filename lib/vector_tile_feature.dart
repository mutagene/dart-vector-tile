import 'dart:collection';
import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:vector_tile/raw/raw_vector_tile.dart' as raw;
import 'package:vector_tile/util/command.dart';
import 'package:vector_tile/util/geojson.dart';
import 'package:vector_tile/util/geometry.dart';
import 'package:vector_tile/vector_tile_geom_type.dart';
import 'package:vector_tile/vector_tile_value.dart';

class VectorTileFeature {
  Int64 id;
  List<int> tags;
  VectorTileGeomType? type;
  List<int>? geometryList;

  // Decoded properties
  GeometryType? geometryType;
  Geometry? geometry;
  Map<String, VectorTileValue>? properties;

  // Additional
  int? extent;
  List<String>? keys;
  List<VectorTileValue>? values;

  VectorTileFeature({
    required this.id,
    required this.tags,
    this.type,
    this.geometryList,
    this.extent,
    this.keys,
    this.values,
  });

  raw.VectorTile_Feature toRaw() {
    return raw.VectorTile_Feature(
      id: this.id,
      tags: this.tags,
      type: this.type.toRaw(),
      geometry: this.geometryList,
    );
  }

  /// Decode feature geometry data
  ///
  /// By default geometry doesn't decoded
  /// So you must call this method on-demand if you need it!
  ///
  /// Properties that was decoded through this method:
  /// - feature.geometryType
  /// - feature.geometry
  ///
  /// You must explicit cast Geometry type after got returned data:
  ///    ```
  ///     var geometry = feature.decodeGeometry();
  ///     var coordinates = (geometry as GeometryPoint).coordinates;
  ///    ```
  T? decodeGeometry<T extends Geometry?>() {
    if (this.geometry != null) {
      return this.geometry as T?;
    }

    switch (this.type) {
      case VectorTileGeomType.POINT:
        final coords = this.decodePoint();

        if (coords.length <= 1) {
          this.geometry = Geometry.Point(
            coordinates: _toDoublePoint(coords[0]),
          );
          this.geometryType = GeometryType.Point;
          break;
        }

        this.geometry = Geometry.MultiPoint(coordinates: _toDoubleLine(coords));
        this.geometryType = GeometryType.MultiPoint;
        break;
      case VectorTileGeomType.LINESTRING:
        final coords = this.decodeLineString();

        if (coords.length <= 1) {
          this.geometry = Geometry.LineString(
            coordinates: _toDoubleLine(coords[0]),
          );
          this.geometryType = GeometryType.LineString;
          break;
        }

        this.geometry = Geometry.MultiLineString(
          coordinates: _toDoublePolygon(coords),
        );
        this.geometryType = GeometryType.MultiLineString;
        break;
      case VectorTileGeomType.POLYGON:
        final coords = this.decodePolygon();

        if (coords.length <= 1) {
          this.geometry = Geometry.Polygon(
            coordinates: _toDoublePolygon(coords[0]),
          );
          this.geometryType = GeometryType.Polygon;
          break;
        }

        this.geometry = Geometry.MultiPolygon(
          coordinates: _toDoubleMultiPolygon(coords),
        );
        this.geometryType = GeometryType.MultiPolygon;
        break;
      default:
        print('only implement point type');
    }

    return this.geometry as T?;
  }

  /// Decode properties from feature tags and key/value pairs got from parent layer
  ///
  /// Return key/value pairs
  Map<String, VectorTileValue> decodeProperties() {
    final existingProperties = this.properties;
    if (existingProperties != null) {
      return existingProperties;
    }
    final properties = _FeaturePropertiesMap(
      tags: this.tags,
      keys: this.keys ?? const <String>[],
      values: this.values ?? const <VectorTileValue>[],
    );

    this.properties = properties;
    return properties;
  }

  /// Decode LineString geometry
  ///
  /// @docs: https://github.com/mapbox/vector-tile-spec/tree/master/2.1#4342-point-geometry-type
  List<List<int>> decodePoint() {
    final geometryList = this.geometryList;
    if (geometryList == null) {
      return [];
    }

    var length = 0;
    var commandId = 0;
    var x = 0;
    var y = 0;
    var isX = true;
    final coords = <List<int>>[];

    for (var i = 0; i < geometryList.length; i += 1) {
      final commandInt = geometryList[i];
      if (length <= 0) {
        commandId = Command.decodeId(commandInt);
        length = Command.decodeCount(commandInt);
      } else if (commandId != CommandID.ClosePath) {
        if (isX) {
          x += Command.zigZagDecode(commandInt);
          isX = false;
        } else {
          y += Command.zigZagDecode(commandInt);
          coords.add([x, y]);
          length -= 1;
          isX = true;
        }
      }
    }

    return coords;
  }

  /// Decode LineString geometry
  ///
  /// @docs: https://github.com/mapbox/vector-tile-spec/tree/master/2.1#4343-linestring-geometry-type
  List<List<List<int>>> decodeLineString() {
    final geometryList = this.geometryList;
    if (geometryList == null) {
      return [];
    }

    var length = 0;
    var commandId = 0;
    var x = 0;
    var y = 0;
    var isX = true;
    final coords = <List<List<int>>>[];
    var ring = <List<int>>[];

    for (var i = 0; i < geometryList.length; i += 1) {
      final commandInt = geometryList[i];
      if (length <= 0) {
        commandId = Command.decodeId(commandInt);
        length = Command.decodeCount(commandInt);
      } else if (commandId != CommandID.ClosePath) {
        if (isX) {
          x += Command.zigZagDecode(commandInt);
          isX = false;
        } else {
          y += Command.zigZagDecode(commandInt);
          ring.add([x, y]);
          length -= 1;
          isX = true;
        }
      }

      if (length <= 0 && commandId == CommandID.LineTo) {
        coords.add(ring);
        ring = [];
      }
    }

    return coords;
  }

  /// Decode polygon geometry
  ///
  /// @docs: https://github.com/mapbox/vector-tile-spec/tree/master/2.1#4344-polygon-geometry-type
  List<List<List<List<int>>>> decodePolygon() {
    final geometryList = this.geometryList;
    if (geometryList == null) {
      return [];
    }

    var x = 0;
    var y = 0;
    final polygons = <List<List<List<int>>>>[];
    var coords = <List<List<int>>>[];
    var ring = <List<int>>[];

    for (var i = 0; i < geometryList.length;) {
      final commandInt = geometryList[i];
      i += 1;

      final commandId = Command.decodeId(commandInt);
      final commandCount = Command.decodeCount(commandInt);

      if (commandId == CommandID.ClosePath) {
        for (var j = 0; j < commandCount; j += 1) {
          coords.add(ring.reversed.toList(growable: false));
          ring = [];
        }
        continue;
      }

      for (var j = 0; j < commandCount; j += 1) {
        x += Command.zigZagDecode(geometryList[i]);
        y += Command.zigZagDecode(geometryList[i + 1]);
        i += 2;
        ring.add([x, y]);
      }

      if (commandId == CommandID.LineTo) {
        if (coords.isNotEmpty && this._isCCW(ring: ring)) {
          polygons.add(coords);
          coords = [];
        }
      }
    }

    polygons.add(coords);
    return polygons;
  }

  /// Get GeoJson data from this feature
  ///
  /// x, y, z: is tile numbers and tile zoom
  /// x, y, z was used to calculate lon/lat pairs
  ///
  /// Return generic GeoJson type, there are two ways to to read data returned from this method:
  /// - Explicit given a generic type:
  ///    ```
  ///     var geojson = feature.toGeoJson<GeoJsonPoint>(3262, 1923, 12);
  ///     var coordinates = geojson.geometry.coordinates;
  ///    ```
  /// - Cast to specific GeoJson type after got returned data:
  ///    ```
  ///     var geojson = feature.toGeoJson(3262, 1923, 12);
  ///     var coordinates = (geojson as GeoJsonPoint).geometry.coordinates;
  ///    ```
  T? toGeoJson<T extends GeoJson>({
    required int x,
    required int y,
    required int z,
  }) {
    if (this.geometry == null) {
      this.decodeGeometry();
    }

    int size = this.extent! * (pow(2, z) as int);
    int x0 = this.extent! * x;
    int y0 = this.extent! * y;

    return this.toGeoJsonWithExtentCalculated<T>(x0: x0, y0: y0, size: size);
  }

  /// Get GeoJson data from this feature
  ///
  /// x0, y0, size: is tile numbers and tile zoom that already calculated with layer extent
  /// x0, y0, size was used to calculate lon/lat pairs
  ///
  /// Return generic GeoJson type, there are two ways to to read data returned from this method:
  /// - Explicit given a generic type:
  ///    ```
  ///     var geojson = feature.toGeoJson<GeoJsonPoint>(3262, 1923, 12);
  ///     var coordinates = geojson.geometry.coordinates;
  ///    ```
  /// - Cast to specific GeoJson type after got returned data:
  ///    ```
  ///     var geojson = feature.toGeoJson(3262, 1923, 12);
  ///     var coordinates = (geojson as GeoJsonPoint).geometry.coordinates;
  ///    ```
  T? toGeoJsonWithExtentCalculated<T extends GeoJson>({
    required int x0,
    required int y0,
    required int size,
  }) {
    if (this.geometry == null) {
      this.decodeGeometry();
    }
    if (this.properties == null) {
      this.decodeProperties();
    }

    switch (this.geometryType) {
      case GeometryType.Point:
        final geometryPoint = this.geometry as GeometryPoint;

        geometryPoint.coordinates = this._projectPoint(
          size,
          x0,
          y0,
          geometryPoint.coordinates,
        );

        return GeoJsonPoint(
              geometry: geometryPoint,
              properties: this.properties,
            )
            as T;
      case GeometryType.MultiPoint:
        final geometryMultiPoint = this.geometry as GeometryMultiPoint;

        geometryMultiPoint.coordinates = this._project(
          size,
          x0,
          y0,
          geometryMultiPoint.coordinates,
        );

        return GeoJsonMultiPoint(
              geometry: geometryMultiPoint,
              properties: this.properties,
            )
            as T;
      case GeometryType.LineString:
        final geometryLineString = this.geometry as GeometryLineString;

        geometryLineString.coordinates = this._project(
          size,
          x0,
          y0,
          geometryLineString.coordinates,
        );

        return GeoJsonLineString(
              geometry: geometryLineString,
              properties: this.properties,
            )
            as T;

      case GeometryType.MultiLineString:
        final geometryLineString = this.geometry as GeometryMultiLineString;

        geometryLineString.coordinates = geometryLineString.coordinates
            .map((line) => this._project(size, x0, y0, line))
            .toList(growable: false);

        return GeoJsonMultiLineString(
              geometry: geometryLineString,
              properties: this.properties,
            )
            as T;
      case GeometryType.Polygon:
        final geometryPolygon = this.geometry as GeometryPolygon;

        geometryPolygon.coordinates = geometryPolygon.coordinates
            .map((line) => this._project(size, x0, y0, line))
            .toList(growable: false);

        return GeoJsonPolygon(
              geometry: geometryPolygon,
              properties: this.properties,
            )
            as T;
      case GeometryType.MultiPolygon:
        final geometryMultiPolygon = this.geometry as GeometryMultiPolygon;

        geometryMultiPolygon.coordinates = geometryMultiPolygon.coordinates
            ?.map(
              (polygon) => polygon
                  .map((ring) => this._project(size, x0, y0, ring))
                  .toList(growable: false),
            )
            .toList(growable: false);

        return GeoJsonMultiPolygon(
              geometry: geometryMultiPolygon,
              properties: this.properties,
            )
            as T;
      default:
    }

    return null;
  }

  /// Convert list of point into lon/lat points
  List<List<double>> _project(
    num size,
    num x0,
    num y0,
    List<List<double>> line,
  ) {
    // Deep clone
    List<List<double>> result = line
        .map((point) => point.map((val) => val).toList(growable: false))
        .toList(growable: false);

    for (var i = 0; i < line.length; i++) {
      List<double> point = line[i];
      result[i] = this._projectPoint(size, x0, y0, point);
    }

    return result;
  }

  /// Convert given point into lon/lat point
  ///
  /// See `Tile numbers to lon./lat.` section in documentation link below
  /// @docs: https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames
  List<double> _projectPoint(num size, num x0, num y0, List<double> point) {
    double y2 = 180 - (point[1] + y0) * 360 / size;

    return [
      (point[0] + x0) * 360 / size - 180,
      360 / pi * atan(exp(y2 * pi / 180)) - 90,
    ];
  }

  /// Implements https://en.wikipedia.org/wiki/Shoelace_formula
  bool _isCCW({required List<List<int>> ring}) {
    final ringLength = ring.length;
    var sum = 0;
    for (var i = 0, j = ringLength - 1; i < ringLength; j = i++) {
      sum += (ring[i][0] - ring[j][0]) * (ring[i][1] + ring[j][1]);
    }
    return sum < 0;
  }
}

class _FeaturePropertiesMap extends MapBase<String, VectorTileValue> {
  final List<int> _tags;
  final List<String> _keys;
  final List<VectorTileValue> _values;
  Map<String, VectorTileValue>? _materialized;

  _FeaturePropertiesMap({
    required List<int> tags,
    required List<String> keys,
    required List<VectorTileValue> values,
  }) : _tags = tags,
       _keys = keys,
       _values = values;

  @override
  VectorTileValue? operator [](Object? key) {
    final materialized = _materialized;
    if (materialized != null) {
      return materialized[key];
    }
    if (key is! String) {
      return null;
    }

    for (var i = _tags.length - 2; i >= 0; i -= 2) {
      if (_keys[_tags[i]] == key) {
        return _values[_tags[i + 1]];
      }
    }
    return null;
  }

  @override
  void operator []=(String key, VectorTileValue value) {
    _ensureMaterialized()[key] = value;
  }

  @override
  void clear() {
    _ensureMaterialized().clear();
  }

  @override
  Iterable<String> get keys {
    return _ensureMaterialized().keys;
  }

  @override
  int get length {
    final materialized = _materialized;
    if (materialized != null) {
      return materialized.length;
    }
    return _tags.length ~/ 2;
  }

  @override
  bool get isEmpty {
    final materialized = _materialized;
    if (materialized != null) {
      return materialized.isEmpty;
    }
    return _tags.isEmpty;
  }

  @override
  VectorTileValue? remove(Object? key) {
    return _ensureMaterialized().remove(key);
  }

  Map<String, VectorTileValue> _ensureMaterialized() {
    final materialized = _materialized;
    if (materialized != null) {
      return materialized;
    }

    final properties = <String, VectorTileValue>{};
    for (var i = 0; i < _tags.length; i += 2) {
      properties[_keys[_tags[i]]] = _values[_tags[i + 1]];
    }
    _materialized = properties;
    return properties;
  }
}

List<double> _toDoublePoint(List<int> point) {
  return [point[0].toDouble(), point[1].toDouble()];
}

List<List<double>> _toDoubleLine(List<List<int>> line) {
  final result = List<List<double>>.filled(
    line.length,
    const <double>[],
    growable: false,
  );
  for (var i = 0; i < line.length; i += 1) {
    result[i] = _toDoublePoint(line[i]);
  }
  return result;
}

List<List<List<double>>> _toDoublePolygon(List<List<List<int>>> polygon) {
  final result = List<List<List<double>>>.filled(
    polygon.length,
    const <List<double>>[],
    growable: false,
  );
  for (var i = 0; i < polygon.length; i += 1) {
    result[i] = _toDoubleLine(polygon[i]);
  }
  return result;
}

List<List<List<List<double>>>> _toDoubleMultiPolygon(
  List<List<List<List<int>>>> multiPolygon,
) {
  final result = List<List<List<List<double>>>>.filled(
    multiPolygon.length,
    const <List<List<double>>>[],
    growable: false,
  );
  for (var i = 0; i < multiPolygon.length; i += 1) {
    result[i] = _toDoublePolygon(multiPolygon[i]);
  }
  return result;
}
