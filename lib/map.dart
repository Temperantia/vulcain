import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:latlong/latlong.dart';
import 'package:photo_view/photo_view.dart';
import 'package:vulcain/db.dart';
import 'package:vulcain/location.dart';
import 'package:vulcain/search.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<Marker> _markers = [];
  MapController _controller = MapController();
  bool _showSearch = false;
  double _latitude = 48.8566;
  double _longitude = 2.3522;
  double _zoom = 7;
  List _tiles = [];
  bool _loading = false;
  bool _newFire = false;
  bool _hasPrivilege = false;
  String _windDirection;
  int _windSpeed = -1;
  final TextEditingController _windSpeedController = TextEditingController();
  var _directionController = PhotoViewController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _windSpeedController.addListener(_onSpeedWindChanged);
    _updateLocation();
  }

  void _onSpeedWindChanged() {
    setState(() {
      _windSpeed = int.tryParse(_windSpeedController.text ?? -1);
    });
  }

  void _onFireDeclared() {
    if (_hasPrivilege) {
      print("save fire to the local DB");
    } else {
      print("just send the notification via sendinblue api");
    }
  }

  void _updateLocation() {
    getLocation().then((locationData) {
      if (locationData != null) {
        _controller.move(
            LatLng(locationData.latitude, locationData.longitude), _zoom);
      }
    });
  }

  void _logout() {
    FirebaseAuth.instance.signOut();
  }

  Widget _declareFire(BuildContext context) {
    return Container(
        height: 220,
        width: 250,
        padding: const EdgeInsets.all(5),
        color: Colors.white,
        child: Column(
          children: <Widget>[
            Text('Direction du vent'),
            Container(
                child: DropdownButton<String>(
              value: _windDirection,
              items: <String>[
                'nord',
                'sud',
                'est',
                'ouest',
                'nord-est',
                'nord-ouest',
                'sud-est',
                'sud-ouest'
              ]
                  .map<DropdownMenuItem<String>>((String value) =>
                      DropdownMenuItem<String>(
                          value: value, child: Text(value)))
                  .toList(),
              onChanged: (String newValue) => setState(() {
                _windDirection = newValue;
              }),
              isExpanded: true,
            )),
            Text('Vitesse du vent en m/s'),
            TextField(
              keyboardType: TextInputType.number,
              controller: _windSpeedController,
              inputFormatters: <TextInputFormatter>[
                WhitelistingTextInputFormatter.digitsOnly
              ],
            ),
            Container(
              padding: const EdgeInsets.all(15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                      child: FlatButton(
                          color: Colors.grey,
                          onPressed: () {
                            _onFireDeclared();
                            setState(() {
                              _newFire = false;
                            });
                          },
                          child: const Text('Valider'))),
                  Container(
                      child: FlatButton(
                          color: Colors.grey,
                          colorBrightness: Brightness.dark,
                          onPressed: () {
                            setState(() {
                              _newFire = false;
                            });
                          },
                          child: const Text('Annuler')))
                ],
              ),
            )
          ],
        ));
  }

  Widget _buildMap() {
    return FlutterMap(
      options: MapOptions(
          onPositionChanged: (pos, gesture) {
            if (_loading) {
              return;
            }
            _loading = true;
            getTiles(_zoom,
                    minLatitude: _controller.bounds.south,
                    maxLatitude: _controller.bounds.north,
                    minLongitude: _controller.bounds.west,
                    maxLongitude: _controller.bounds.east)
                .then((tiles) {
              _loading = false;
              setState(() {
                _tiles = tiles;
                _zoom = _controller.zoom;
              });
            });
          },
          center: LatLng(_latitude, _longitude),
          zoom: _zoom,
          minZoom: 7,
          maxZoom: 12,
          onLongPress: (LatLng point) => setState(() {
                _markers.add(
                  Marker(
                    point: point,
                    builder: (ctx) => Icon(Icons.whatshot),
                  ),
                );
                _newFire = true;
              })),
      layers: [
        TileLayerOptions(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c']),
        PolygonLayerOptions(polygons: [
          for (final tile in _tiles)
            Polygon(
                color:
                    Color((tile['color'] as double).toInt()).withOpacity(0.2),
                points: json
                    .decode(tile['coordinates'])
                    .map<LatLng>((coor) => LatLng(coor[1], coor[0]))
                    .toList())
        ]),
        MarkerLayerOptions(markers: _markers)
      ],
      mapController: _controller,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButton: SpeedDial(
          animatedIcon: AnimatedIcons.menu_close,
          children: [
            SpeedDialChild(
                child: Icon(Icons.power_settings_new),
                label: 'Se déconnecter',
                onTap: () => _logout()),
            SpeedDialChild(
                child: Icon(Icons.my_location),
                label: 'Se géolocaliser',
                onTap: () {
                  _updateLocation();
                }),
            SpeedDialChild(
                child: Icon(Icons.search),
                label: 'Recherche',
                onTap: () {
                  setState(() => _showSearch = !_showSearch);
                }),
          ],
        ),
        body: _showSearch
            ? Search(onUpdate: (latitude, longitude, zoom) {
                setState(() {
                  _latitude = latitude;
                  _longitude = longitude;
                  _zoom = zoom;
                  _showSearch = false;
                });
              })
            : FutureBuilder(
                future: _controller.onReady,
                builder: (context, future) {
                  if (future.connectionState == ConnectionState.waiting) {
                    return FlutterMap(
                        options: MapOptions(
                          center: LatLng(_latitude, _longitude),
                          zoom: _zoom,
                        ),
                        mapController: _controller,
                        layers: []);
                  }
                  return FutureBuilder(
                    future: getTiles(_zoom,
                        minLatitude: _controller.bounds.south,
                        maxLatitude: _controller.bounds.north,
                        minLongitude: _controller.bounds.west,
                        maxLongitude: _controller.bounds.east),
                    builder: (context, future) {
                      if (!future.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }
                      _tiles = future.data;
                      return Stack(children: [
                        _buildMap(),
                        if (_newFire)
                          Align(
                            alignment: Alignment.topCenter,
                            child: _declareFire(context),
                          )

                        // if (!_newFire) _buildMap(),
                        // if (_newFire)
                        //   Center(
                        //     child: Column(
                        //       mainAxisAlignment: MainAxisAlignment.center,
                        //       children: <Widget>[
                        //         Expanded(
                        //           child: PhotoView(
                        //             controller: _directionController,
                        //             initialScale: 1.0,
                        //             minScale: 1.0,
                        //             maxScale: 1.0,
                        //             enableRotation: true,
                        //             imageProvider:
                        //                 AssetImage('assets/compass.jpg'),
                        //           ),
                        //         ),
                        //         Text(
                        //           (_directionController.rotation /
                        //                   pi /
                        //                   2 *
                        //                   360 %
                        //                   360)
                        //               .toString(),
                        //           style: TextStyle(color: Colors.black),
                        //         ),
                        //       ],
                        //     ),
                        //   )
                      ]);
                    },
                  );
                }));
  }
}
