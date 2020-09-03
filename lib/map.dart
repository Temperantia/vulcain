import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:latlong/latlong.dart';
import 'package:vulcain/db.dart';
import 'package:vulcain/location.dart';
import 'package:vulcain/search.dart';

import 'package:http/http.dart' as http;
import 'package:vulcain/fire_start.dart';

import 'db.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<Marker> _markers = [];
  List<Marker> _surfaces = [];
  List<Polyline> _polylines = [];
  List<Polygon> _polygones = [];
  MapController _controller = MapController();
  bool _showSearch = false;
  double _latitude = 48.8566;
  double _longitude = 2.3522;
  double _zoom = 7;
  List _tiles = [];
  bool _loading = false;
  bool _newPoint = false;
  bool _showSurfaces = false;
  LatLng _firePosition;
  LatLng _pointPosition;
  bool _hasPrivilege = true;

  String _typeOfPoint = "départ de feu";
  String _windDirection;
  int _windSpeed = -1;
  final TextEditingController _windSpeedController = TextEditingController();

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

  Future<String> doPost(FireStart fstart) async {
    var url = 'https://api.sendinblue.com/v3/smtp/email';
    var body = jsonEncode({
      "sender": {
        "name": "Application vulcain",
        "email": "robin.despouys@gmail.com"
      },
      "to": [
        {"email": "appvulcain@gmail.com", "name": "app Vulcain"}
      ],
      "subject": "Voici une notification de Vulcain",
      "htmlContent":
          "<html><head></head><body><p>Bonjour, Ceci est une alerte d'incendie venant de l'application Vulcain <br><br> latitude ${fstart.latitude} <br> longitude ${fstart.longitude} <br> vitesse du vent en km/h : ${fstart.windSpeed} <br> direction du vent : ${fstart.windDirection}</p></body></html>"
    });
    final http.Response response = await http.post(url,
        headers: {
          "accept": "application/json",
          "api-key":
              "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",
          "Content-Type": "application/json"
        },
        body: body.toString());
    final int statusCode = response.statusCode;
    if (statusCode < 200 || statusCode > 400 || json == null) {
      print('statuscode is : ' + statusCode.toString());
      print('content is : ' + response.toString());
      print('body is : ' + response.body);
      throw Exception('Error while fetching stupid data');
    }
    return 'status code : ' +
        statusCode.toString() +
        ' body response : ' +
        response.body;
  }

  Polyline _getTriangleFromMediane(
      LatLng _originPoint, double _distance, String _windDirection) {
    double angle60AsRadian = (60 * pi) / 180;
    double angle15AsRadian = (15 * pi) / 180;
    double angle30AsRadian = (30 * pi) / 180;
    double angle75AsRadian = (75 * pi) / 180;

    double latitudeAsRadian = (_originPoint.latitude * pi) / 180;
    double estim1MinuteAngle = 1000 * 40075 * cos(latitudeAsRadian) / 360 / 60;

    var _distanceLatitude = _distance;
    var _distanceLongitude = _distance * 1810 / estim1MinuteAngle;

    var cLat = _distanceLatitude / sin(angle60AsRadian);
    var cLong = _distanceLongitude / sin(angle60AsRadian);

    var longx = cos(angle15AsRadian) * cLong;
    var latx = sin(angle15AsRadian) * cLat;
    var longx2 = cos(angle75AsRadian) * cLong;
    var latx2 = cos(pi / 4) * _distanceLongitude;

    switch (_windDirection) {
      case 'sud-ouest':
        {
          longx = -longx;
          latx = -latx;
          longx2 = -longx2;
          latx2 = -latx2;
        }
        break;
      case 'sud-est':
        {
          longx = longx;
          latx = -latx;
          longx2 = longx2;
          latx2 = -latx2;
        }
        break;
      case 'nord-ouest':
        {
          longx = -longx;
          latx = latx;
          longx2 = -longx2;
          latx2 = latx2;
        }
        break;
      case 'nord-est':
        {
          longx = longx;
          latx = latx;
          longx2 = longx2;
          latx2 = latx2;
        }
        break;
      case 'nord':
        {
          longx = _distanceLongitude / tan(angle60AsRadian);
          latx = _distanceLatitude;

          longx2 = -_distanceLongitude / tan(angle60AsRadian);
          latx2 = _distanceLatitude;
        }
        break;
      case 'sud':
        {
          longx = -_distanceLongitude / tan(angle60AsRadian);
          latx = -_distanceLatitude;
          longx2 = _distanceLongitude / tan(angle60AsRadian);
          latx2 = -_distanceLatitude;
        }
        break;

      case 'est':
        {
          longx = _distanceLongitude;
          latx = _distanceLatitude * tan(angle30AsRadian);
          longx2 = _distanceLongitude;
          latx2 = -_distanceLatitude * tan(angle30AsRadian);
        }
        break;
      case 'ouest':
        {
          longx = -_distanceLongitude;
          latx = _distanceLatitude / tan(angle60AsRadian);
          longx2 = -_distanceLongitude;
          latx2 = -_distanceLatitude / tan(angle60AsRadian);
        }
        break;
    }

    LatLng x1 =
        LatLng(_originPoint.latitude + latx, _originPoint.longitude + longx);

    LatLng x2 =
        LatLng(_originPoint.latitude + latx2, _originPoint.longitude + longx2);

    var points = <LatLng>[
      LatLng(x2.latitude, x2.longitude),
      LatLng(_originPoint.latitude, _originPoint.longitude),
      LatLng(x1.latitude, x1.longitude),
    ];
    return Polyline(points: points, strokeWidth: 2.0, color: Colors.orange);
  }

  List<double> _propagationEstimation(int _windSpeed) {
    List<double> estimations = [];
    int metrePerHour = _windSpeed * 30;
    double estim15 = 0.017 * metrePerHour / (4 * 1810);
    double estim45 = estim15 * 3;
    estimations.add(estim15); // result in minutes
    estimations.add(0.017 * metrePerHour / (2 * 1810));
    estimations.add(estim45);
    estimations.add(0.017 * metrePerHour / (1810));
    return estimations;
  }

  List<double> _propagationEstimationMeters(int _windSpeed) {
    List<double> estimations = [];
    int metrePerHour = _windSpeed * 30;
    double estim15 = metrePerHour / 4;
    double estim45 = estim15 * 3;
    estimations.add(estim15); // result in meters
    estimations.add(metrePerHour / 2);
    estimations.add(estim45);
    estimations.add(metrePerHour / 1);
    return estimations;
  }

  void _showSurfaceMarkers() {
    setState(() {
      for (final marker in _surfaces) {
        _markers.add(marker);
      }
    });
  }

  void _hideSurfaceMarkers() {
    setState(() {
      for (final marker in _surfaces) {
        _markers.removeWhere((element) => element.point == marker.point);
      }
    });
  }

  Marker _getSurfaceMarker(
      List<LatLng> triangle, double distance, String legende) {
    double _latitude =
        (triangle[0].latitude + triangle[1].latitude + triangle[2].latitude) /
            3;
    double _longitude = (triangle[0].longitude +
            triangle[1].longitude +
            triangle[2].longitude) /
        3;
    double _surface = pi * distance * distance / (6 * 10000);
    print(distance / 500000);
    print(_latitude);
    return Marker(
        point: LatLng(_latitude + distance / 500000, _longitude),
        width: 250,
        height: 40,
        builder: (context) => Container(
            child: Text(" $legende : ${_surface.toInt().toString()} ha",
                style: TextStyle(color: Colors.white))));
  }

  void _drawFireConePropagation(FireStart fstart) {
    LatLng _origin = LatLng(fstart.latitude, fstart.longitude);

    List<double> estimations = _propagationEstimation(fstart.windSpeed);
    List<double> estimationsMeters =
        _propagationEstimationMeters(fstart.windSpeed);

    Polyline _polyline = _getTriangleFromMediane(
        _origin, estimations[3] * 1.2, fstart.windDirection);
    Polyline _polyline1 =
        _getTriangleFromMediane(_origin, estimations[0], fstart.windDirection);
    Polyline _polyline2 =
        _getTriangleFromMediane(_origin, estimations[1], fstart.windDirection);
    Polyline _polyline3 =
        _getTriangleFromMediane(_origin, estimations[2], fstart.windDirection);
    Polyline _polyline4 =
        _getTriangleFromMediane(_origin, estimations[3], fstart.windDirection);
    Polygon _polygone1 = Polygon(
        color: Color.fromARGB(60, 80, 100, 20), points: _polyline1.points);
    Polygon _polygone2 = Polygon(
        color: Color.fromARGB(200, 240, 100, 60), points: _polyline2.points);
    Polygon _polygone3 = Polygon(
        color: Color.fromARGB(400, 480, 100, 90), points: _polyline3.points);
    Polygon _polygone4 = Polygon(
        color: Color.fromARGB(800, 800, 100, 120), points: _polyline4.points);

    Marker _marker1 =
        _getSurfaceMarker(_polygone1.points, estimationsMeters[0], "T+15 min");
    Marker _marker2 =
        _getSurfaceMarker(_polygone2.points, estimationsMeters[1], "T+30 min");
    Marker _marker3 =
        _getSurfaceMarker(_polygone3.points, estimationsMeters[2], "T+45 min");
    Marker _marker4 =
        _getSurfaceMarker(_polygone4.points, estimationsMeters[3], "T+60 min");

    setState(() {
      _polylines.add(_polyline);
      _polygones.add(_polygone4);
      _polygones.add(_polygone3);
      _polygones.add(_polygone2);
      _polygones.add(_polygone1);

      _surfaces.add(_marker1);
      _surfaces.add(_marker2);
      _surfaces.add(_marker3);
      _surfaces.add(_marker4);
    });

    if (_showSurfaces) {
      setState(() {
        _markers.add(_marker1);
        _markers.add(_marker2);
        _markers.add(_marker3);
        _markers.add(_marker4);
      });
    }
  }

  void _sendMailNotification(FireStart fireStart) async {
    final String res = await doPost(fireStart);
    print("resultat de la requête post $res");
  }

  void _onFireDeclared() async {
    FireStart fs = FireStart(
        id: null,
        latitude: _firePosition.latitude,
        longitude: _firePosition.longitude,
        windDirection: _windDirection,
        windSpeed: _windSpeed);
    _drawFireConePropagation(fs);
    if (_hasPrivilege) {
      print("save fireStart to the local DB");
      await createFireEntry(fs);
      print("db entry created");
    }
    _sendMailNotification(fs);
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
        height: 420,
        width: 250,
        padding: const EdgeInsets.all(5),
        color: Colors.white,
        child: Column(
          children: <Widget>[
            if (_hasPrivilege) Text('Type de point'),
            if (_hasPrivilege)
              Container(
                  child: DropdownButton<String>(
                value: _typeOfPoint,
                items: <String>[
                  'départ de feu',
                  'point sensible',
                  'hydrant',
                  'point de transit',
                  'emplacement PC'
                ]
                    .map<DropdownMenuItem<String>>((String value) =>
                        DropdownMenuItem<String>(
                            value: value, child: Text(value)))
                    .toList(),
                onChanged: (String newValue) => setState(() {
                  _typeOfPoint = newValue;
                }),
                isExpanded: true,
              )),
            if (_typeOfPoint == 'départ de feu') Text('Direction du vent'),
            if (_typeOfPoint == 'départ de feu')
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
            if (_typeOfPoint == 'départ de feu')
              Text('Vitesse du vent en km/h'),
            if (_typeOfPoint == 'départ de feu')
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
                            Icon _iconPoint;
                            switch (_typeOfPoint) {
                              case 'départ de feu':
                                _iconPoint = Icon(Icons.whatshot);
                                _firePosition = _pointPosition;
                                _onFireDeclared();
                                break;
                              case 'point sensible':
                                _iconPoint = Icon(Icons.warning);
                                break;
                              case 'hydrant':
                                _iconPoint = Icon(Icons.ac_unit);
                                break;
                              case 'point de transit':
                                _iconPoint = Icon(Icons.directions);
                                break;
                              case 'emplacement PC':
                                _iconPoint = Icon(Icons.business);
                                break;
                            }
                            setState(() {
                              _markers.add(
                                Marker(
                                  point: _pointPosition,
                                  builder: (ctx) => _iconPoint,
                                ),
                              );
                              _newPoint = false;
                            });
                          },
                          child: const Text('Valider'))),
                  Container(
                      child: FlatButton(
                          color: Colors.grey,
                          colorBrightness: Brightness.dark,
                          onPressed: () {
                            setState(() {
                              _newPoint = false;
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
          maxZoom: 15,
          onLongPress: (LatLng point) => setState(() {
                // _markers.add(
                //   Marker(
                //     point: point,
                //     builder: (ctx) => Icon(Icons.whatshot),
                //   ),
                // );
                // _firePosition = point;
                _pointPosition = point;
                _newPoint = true;
              })),
      layers: [
        TileLayerOptions(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c']),
        PolylineLayerOptions(polylines: _polylines),
        PolygonLayerOptions(
            polygons: _polygones +
                [
                  for (final tile in _tiles)
                    Polygon(
                        color: Color((tile['color'] as double).toInt())
                            .withOpacity(0.2),
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
            /*  SpeedDialChild(
                child: Icon(Icons.my_location),
                label: _hasPrivilege
                    ? 'Passer au mode gratuit'
                    : 'Passer au mode payant',
                onTap: () {
                  setState(() {
                    _hasPrivilege = !_hasPrivilege;
                    _typeOfPoint = "départ de feu";
                  }); 
                }), */
            SpeedDialChild(
                child: Icon(Icons.change_history),
                label: _showSurfaces
                    ? 'Cacher les détails'
                    : 'Afficher les détails',
                onTap: () {
                  if (!_showSurfaces) {
                    _showSurfaceMarkers();
                    _showSurfaces = true;
                  } else {
                    _hideSurfaceMarkers();
                    _showSurfaces = false;
                  }
                })
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
                        if (_newPoint)
                          Align(
                            alignment: Alignment.topCenter,
                            child: _declareFire(context),
                          ),

                        // if (!_newPoint) _buildMap(),
                        // if (_newPoint)
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
