import 'package:location/location.dart';

class LocationPermission {
  Future<bool> enable() async {
    Location location = Location.instance;
    bool enable = await location.serviceEnabled();
    if (enable) {
      return true;
    } else {
      bool request = await location.requestService();
      if (request) {
        return true;
      } else {
        return false;
      }
    }
  }
}
