import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:vulcain/utils.dart';

Database database;

Future openDb() async {
  database = await openDatabase(
    join(await getDatabasesPath(), 'vulcain.db'),
    onCreate: (db, version) async {
      await insertTiles(db, 'dfci_level_1');
      await insertTiles(db, 'dfci_level_2');
      await insertTiles(db, 'dfci_level_3');
    },
    version: 1,
  );
  return database;
}

Future insertTiles(db, table) async {
  if (db == null) {
    db = database;
  }
  await db.execute(
    'CREATE TABLE ' +
        table +
        '(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT, color REAL, min_latitude REAL, max_latitude REAL, min_longitude REAL, max_longitude REAL, coordinates TEXT)',
  );
  Map data =
      json.decode(await rootBundle.loadString('assets/' + table + '.json'));
  Batch batch = db.batch();

  var index = 0;
  for (var tile in data.entries) {
    if (index % 10000 == 0 && index != 0) {
      print('batch start ' + index.toString());
      await batch.commit();
      batch = db.batch();
    }

    List value = tile.value;
    var coordinates = value.map<List<double>>((coordinates) {
      return coordinates.cast<double>();
    }).toList();
    double minLatitude = coordinates[0][1];
    double maxLatitude = coordinates[0][1];
    double minLongitude = coordinates[0][0];
    double maxLongitude = coordinates[0][0];
    for (var coordinate in coordinates) {
      if (coordinate[1] < minLatitude) {
        minLatitude = coordinate[1];
      }
      if (coordinate[1] > maxLatitude) {
        maxLatitude = coordinate[1];
      }
      if (coordinate[0] < minLongitude) {
        minLongitude = coordinate[0];
      }
      if (coordinate[0] > maxLongitude) {
        maxLongitude = coordinate[0];
      }
    }

    batch.insert(
      table,
      {
        'code': tile.key,
        'color': (Random().nextDouble() * 0xFFFFFF).toInt(),
        'min_latitude': minLatitude,
        'max_latitude': maxLatitude,
        'min_longitude': minLongitude,
        'max_longitude': maxLongitude,
        'coordinates': json.encode(coordinates)
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    index++;
  }
  await batch.commit();
  print('loaded ' + index.toString());
}

Future getTiles(double zoom,
    {double minLatitude,
    double maxLatitude,
    double minLongitude,
    double maxLongitude}) async {
  var table = 'dfci_level_1';
  var km = 100.0;
  if (zoom >= 8 && zoom < 12) {
    table = 'dfci_level_2';
    km = 20.0;
  } else if (zoom >= 12) {
    table = 'dfci_level_3';
    km = 2.0;
  }
  minLatitude -= kmToLatitude(km);
  maxLatitude += kmToLatitude(km);
  minLongitude -= kmToLongitude(minLatitude, km);
  maxLongitude += kmToLongitude(maxLatitude, km);
  return database.transaction((txn) {
    return txn.query(table,
        where:
            'min_latitude >= ? AND max_latitude <= ? AND min_longitude >= ? AND max_longitude <= ?',
        whereArgs: [minLatitude, maxLatitude, minLongitude, maxLongitude]);
  });
}

Future getTile(String code) async {
  var table = 'dfci_level_1';
  if (code.length == 4) {
    table = 'dfci_level_2';
  } else if (code.length == 6) {
    table = 'dfci_level_3';
  }
  final List<Map<String, dynamic>> tiles =
      await database.query(table, where: 'code = ?', whereArgs: [code]);
  return tiles.isEmpty ? null : tiles[0];
}
