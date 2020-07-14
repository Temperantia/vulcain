class FireStart {
  FireStart({this.id, this.windDirection, this.windSpeed, this.latitude, this.longitude});

  int id;
  String windDirection;
  int windSpeed;
  double latitude;
  double longitude;

  FireStart.fromMap(Map<String, dynamic> map) {
    id = map['id'];
    windDirection = map['windDirection'];
    windSpeed = map['windSpeed'];
    latitude = map['latitude'];
    longitude = map['longitude'];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'windDirection' : windDirection,
      'windSpeed' : windSpeed,
      'latitude' : latitude,
      'longitude' : longitude,
    };
  }

}