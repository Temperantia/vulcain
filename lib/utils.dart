import 'dart:math';

double kmToLatitude(double km) {
  return km / 110.574;
}

double kmToLongitude(double latitude, double km) {
  return km / (111.320 * cos(latitude / 57.2958));
}
