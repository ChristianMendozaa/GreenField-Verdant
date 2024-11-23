import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class HotSpots extends StatefulWidget {
  @override
  _HotSpotsState createState() => _HotSpotsState();
}

class _HotSpotsState extends State<HotSpots> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = Set<Marker>();
  Set<Circle> _circles = Set<Circle>();
  bool _loading = false;
  List<Map<String, dynamic>> _fireLocations = [];
  bool _dataLoaded = false;
  BitmapDescriptor? _fireIcon;
  BitmapDescriptor? _heatIcon;
  BitmapDescriptor? _droughtIcon; // Drought marker icon

  final String firmsApiUrl =
      'https://firms.modaps.eosdis.nasa.gov/api/area/csv/cbbdb5f8e1820c5c2cedd140d2f9283f/VIIRS_SNPP_NRT/world/1/2024-10-05';

  final double brightnessThreshold = 300.0;
  final double frpThreshold = 5.0;
  final double droughtFrpThreshold = 30.0; // Example threshold for drought
  final double droughtBrightnessThreshold =
      310.0; // Example threshold for brightness
  final double searchRadiusKm = 15.0;

  @override
  void initState() {
    super.initState();
    _createIcons();
  }

  /// Crea los íconos personalizados para incendios, focos de calor y sequía.
  Future<void> _createIcons() async {
    _fireIcon =
        await _createCustomIcon(Colors.red, Icons.local_fire_department);
    _heatIcon = await _createCustomIcon(Colors.orange, Icons.wb_sunny);
    _droughtIcon =
        await _createCustomIcon(Colors.yellow, Icons.warning); // Drought icon
  }

  /// Genera un ícono personalizado basado en un color y un ícono de Flutter.
  Future<BitmapDescriptor> _createCustomIcon(Color color, IconData icon) async {
    final PictureRecorder pictureRecorder = PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const Size size = Size(48.0, 48.0);

    final iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 48.0,
        fontFamily: icon.fontFamily,
        color: color,
      ),
    );
    iconPainter.layout();
    iconPainter.paint(canvas, Offset(0.0, 0.0));

    final img = await pictureRecorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final bitmap = data!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bitmap);
  }

  Future<void> _loadFireData() async {
    try {
      print("Fetching fire data from NASA FIRMS API...");
      final response =
          await http.get(Uri.parse(firmsApiUrl)).timeout(Duration(seconds: 20));

      if (response.statusCode == 200) {
        List<List<dynamic>> csvData =
            CsvToListConverter(eol: '\n').convert(response.body);

        List<Map<String, dynamic>> fireLocations = [];

        for (var row in csvData.skip(1)) {
          double latitude = row[0].toDouble();
          double longitude = row[1].toDouble();
          double brightTi4 = row[2].toDouble();
          double frp = row[12].toDouble();

          fireLocations.add({
            "latitude": latitude,
            "longitude": longitude,
            "brightness": brightTi4,
            "frp": frp,
          });
        }

        setState(() {
          _fireLocations = fireLocations;
          _dataLoaded = true;
        });

        print(
            "Fire data loaded successfully. Total locations: ${fireLocations.length}");
      } else {
        print(
            "Failed to connect to NASA API. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching fire data: $e");
    }
  }

  List<Map<String, dynamic>> _filterFireLocations(LatLng tappedPoint) {
    print(
        "Filtering fire locations near: ${tappedPoint.latitude}, ${tappedPoint.longitude}");
    List<Map<String, dynamic>> filteredLocations =
        _fireLocations.where((location) {
      double distance = _calculateDistance(
        tappedPoint.latitude,
        tappedPoint.longitude,
        location['latitude'],
        location['longitude'],
      );
      return distance <= searchRadiusKm;
    }).toList();

    print(
        "Found ${filteredLocations.length} fire locations within ${searchRadiusKm} km.");
    return filteredLocations;
  }

  void _onMapTapped(LatLng tappedPoint) async {
    print("Map tapped at: ${tappedPoint.latitude}, ${tappedPoint.longitude}");

    if (!_dataLoaded) {
      setState(() {
        _loading = true;
      });
      await _loadFireData();
      setState(() {
        _loading = false;
      });
    }

    setState(() {
      _markers.clear();
      _circles.clear();
    });

    // Add marker for tapped location
    _markers.add(
      Marker(
        markerId: MarkerId('selectedPoint'),
        position: tappedPoint,
        infoWindow: InfoWindow(
          title: 'Punto seleccionado',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        ),
      ),
    );

    // Add circle (radius 15 km)
    _circles.add(
      Circle(
        circleId: CircleId('radius'),
        center: tappedPoint,
        radius: searchRadiusKm * 1000, // Convert km to meters
        strokeColor: Colors.blueAccent,
        strokeWidth: 2,
        fillColor: Colors.blueAccent.withOpacity(0.2),
      ),
    );

    List<Map<String, dynamic>> nearbyFires = _filterFireLocations(tappedPoint);

    setState(() {
      _markers.addAll(
        nearbyFires.map((location) {
          BitmapDescriptor icon;
          String title;

          // Distinction between fires, heat spots, and drought
          if (location['frp'] >= droughtFrpThreshold &&
              location['brightness'] >= droughtBrightnessThreshold) {
            // Drought condition
            icon = _droughtIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueYellow,
                );
            title = 'Posible sequía detectada';
          } else if (location['frp'] >= frpThreshold) {
            // Fire condition
            icon = _fireIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                );
            title = 'Incendio detectado';
          } else {
            // Heat spot condition
            icon = _heatIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                );
            title = 'Foco de calor detectado';
          }

          return Marker(
            markerId: MarkerId(location['latitude'].toString() +
                ',' +
                location['longitude'].toString()),
            position: LatLng(location['latitude'], location['longitude']),
            infoWindow: InfoWindow(
              title: title,
              snippet:
                  'Brillo: ${location['brightness']}, FRP: ${location['frp']}',
            ),
            icon: icon,
          );
        }).toSet(),
      );
    });
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) {
    return deg * (pi / 180);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mapa de Incendios, Focos de Calor y Sequía'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(-16.0, -64.0),
              zoom: 5,
            ),
            markers: _markers,
            circles: _circles,
            onTap: _onMapTapped,
            mapType: MapType.hybrid,
          ),
          if (_loading)
            Center(
              child: CircularProgressIndicator(),
            ),
          Positioned(
            top: 10.0,
            left: 10.0,
            child: Container(
              padding: EdgeInsets.all(8.0),
              color: Colors.white.withOpacity(0.7), // Hacer semitransparente
              child: Column(
                // Cambiar Row por Column para hacerlo vertical
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fireplace, color: Colors.red),
                      SizedBox(width: 8.0),
                      Text('Incendios'),
                    ],
                  ),
                  SizedBox(height: 10.0),
                  Row(
                    children: [
                      Icon(Icons.wb_sunny, color: Colors.orange),
                      SizedBox(width: 8.0),
                      Text('Focos de calor'),
                    ],
                  ),
                  SizedBox(height: 10.0),
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.yellow),
                      SizedBox(width: 8.0),
                      Text('Posible sequía'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}