import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as lat_lng2;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocationProvider(),
      child: MaterialApp(
        title: 'OpenStreetMap Navigation',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MapScreen(),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  lat_lng2.LatLng? _startPoint;
  lat_lng2.LatLng? _endPoint;

  void _searchAndNavigate() async {
    if (_startController.text.isNotEmpty && _endController.text.isNotEmpty) {
      var startResponse = await http.get(Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${_startController.text}.json?access_token=pk.eyJ1Ijoic21pbHloeGMiLCJhIjoiY2x3aXpkbWExMHFwcTJrcHB1cGk0cHZ6cSJ9.ly840HMC2TwMAhCnhK4kmQ'));
      var endResponse = await http.get(Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${_endController.text}.json?access_token=pk.eyJ1Ijoic21pbHloeGMiLCJhIjoiY2x3aXpkbWExMHFwcTJrcHB1cGk0cHZ6cSJ9.ly840HMC2TwMAhCnhK4kmQ'));

      var startLocation = json.decode(startResponse.body);
      var endLocation = json.decode(endResponse.body);

      double startLat = startLocation['features'][0]['center'][1];
      double startLng = startLocation['features'][0]['center'][0];
      double endLat = endLocation['features'][0]['center'][1];
      double endLng = endLocation['features'][0]['center'][0];

      setState(() {
        _startPoint = lat_lng2.LatLng(startLat, startLng);
        _endPoint = lat_lng2.LatLng(endLat, endLng);
      });

      // Move map to show both points (adjust manually)
      _mapController.move(
        lat_lng2.LatLng(
          (startLat + endLat) / 2,
          (startLng + endLng) / 2,
        ),
        13.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OpenStreetMap Navigation'),
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startController,
                  decoration: InputDecoration(hintText: 'Start Location'),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _endController,
                  decoration: InputDecoration(hintText: 'End Location'),
                ),
              ),
              IconButton(
                icon: Icon(Icons.search),
                onPressed: _searchAndNavigate,
              ),
            ],
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: lat_lng2.LatLng(51.5, -0.09),
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                ),
                if (_startPoint != null && _endPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: _startPoint!,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                        ),
                      ),
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: _endPoint!,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;

  Position? get currentPosition => _currentPosition;

  Future<void> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    _currentPosition = await Geolocator.getCurrentPosition();
    notifyListeners();
  }
}
