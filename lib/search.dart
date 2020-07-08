import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vulcain/db.dart';

class Search extends StatefulWidget {
  const Search({this.onUpdate});
  final Function onUpdate;
  @override
  _SearchState createState() => _SearchState();
}

class _SearchState extends State<Search> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _address = TextEditingController();
  String _errorCode = '';
  String _errorAddress = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Column(
            children: <Widget>[
              TextField(
                controller: _code,
                decoration: InputDecoration(
                    hintText: 'Exemples : NN, NN86, ou encore NN86K8'),
              ),
              Text(_errorCode),
              FlatButton(
                  color: Colors.red,
                  onPressed: () async {
                    var tile = await getTile(_code.text);
                    if (tile == null) {
                      setState(() => _errorCode = 'Erreur');
                      return;
                    }
                    var latitude =
                        (tile['min_latitude'] + tile['max_latitude']) / 2;
                    var longitude =
                        (tile['min_longitude'] + tile['max_longitude']) / 2;
                    var zoom = 7.0;
                    if (_code.text.length == 4) {
                      zoom = 11.0;
                    } else if (_code.text.length == 6) {
                      zoom = 13.0;
                    }
                    widget.onUpdate(latitude, longitude, zoom);
                  },
                  child: Text('Recherche par code')),
            ],
          ),
          Column(
            children: <Widget>[
              TextField(
                controller: _address,
                decoration: InputDecoration(
                    hintText: 'Exemples : Paris, Lyon, Marseille...'),
              ),
              Text(_errorAddress),
              FlatButton(
                  color: Colors.red,
                  onPressed: () async {
                    try {
                      List<Placemark> placemark = await Geolocator()
                          .placemarkFromAddress(_address.text);
                      setState(() => _errorAddress = 'Non trouvé');
                      widget.onUpdate(placemark[0].position.latitude,
                          placemark[0].position.longitude, 13.0);
                    } catch (error) {
                      setState(() => _errorAddress = 'Non trouvé');
                    }
                  },
                  child: Text('Recherche par adresse'))
            ],
          ),
        ],
      ),
    );
  }
}
