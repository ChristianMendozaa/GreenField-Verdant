import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'save_area_page.dart';

class AddInterestAreaPage extends StatefulWidget {
  const AddInterestAreaPage({Key? key}) : super(key: key);

  @override
  _AddInterestAreaPageState createState() => _AddInterestAreaPageState();
}

class _AddInterestAreaPageState extends State<AddInterestAreaPage> {
  final List<LatLng> _polygonPoints = [];
  final List<Marker> _markers = [];
  final List<Polygon> _polygons = [];
  final Set<Polygon> _userPolygons = {}; // Áreas guardadas del usuario
  final Set<Marker> _userMarkers = {}; // Marcadores de áreas guardadas
  GoogleMapController? mapController;
  LatLng? userLocation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadUserAreas(); // Cargar áreas guardadas
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor habilita los servicios de ubicación'),
        ),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permisos de ubicación denegados'),
          ),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Los permisos de ubicación están denegados permanentemente'),
        ),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      userLocation = LatLng(position.latitude, position.longitude);
    });

    mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLocation!, 15));
  }

  Future<BitmapDescriptor> _createCustomMarker(Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 50.0;

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<void> _loadUserAreas() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario no autenticado')),
      );
      return;
    }

    try {
      // Obtener las áreas desde Firebase filtradas por UID
      final areasSnapshot = await FirebaseFirestore.instance
          .collection('areas')
          .where('userId', isEqualTo: user.uid)
          .get();

      final Set<Polygon> userPolygons = {};
      final Set<Marker> userMarkers = {};

      for (var doc in areasSnapshot.docs) {
        final data = doc.data();
        final List<dynamic> pointsData = data['points'];
        final String colorHex = data['color'];
        final String name = data['name'];
        final Map<String, dynamic> centroidData = data['centroid'];
        final color = Color(int.parse('0xff$colorHex'));

        final List<LatLng> points = pointsData
            .map((point) => LatLng(point['latitude'], point['longitude']))
            .toList()
            .cast<LatLng>();

        // Crear polígono
        userPolygons.add(
          Polygon(
            polygonId: PolygonId(doc.id),
            points: points,
            strokeColor: Colors.black,
            strokeWidth: 3,
            fillColor: color.withOpacity(0.3),
            onTap: () {
              _showAreaInfoDialog(name, color, centroidData);
            },
          ),
        );

        // Crear marcadores personalizados para cada punto
        for (var point in points) {
          final icon = await _createCustomMarker(color);
          userMarkers.add(
            Marker(
              markerId: MarkerId(point.toString()),
              position: point,
              icon: icon,
            ),
          );
        }
      }

      setState(() {
        _userPolygons.addAll(userPolygons);
        _userMarkers.addAll(userMarkers);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar áreas: $e')),
      );
    }
  }

  void _showAreaInfoDialog(
      String name, Color color, Map<String, dynamic> centroidData) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Información del Área'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nombre: $name'),
              Text('Color: ${color.toString()}'),
              Text(
                  'Centroide: (${centroidData['latitude']}, ${centroidData['longitude']})'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _onMapTapped(LatLng position) async {
    // Mantener la lógica actual para agregar puntos a una nueva área
    final existingIndex = _polygonPoints.indexWhere((point) =>
        (point.latitude - position.latitude).abs() < 1e-6 &&
        (point.longitude - position.longitude).abs() < 1e-6);

    if (existingIndex != -1) {
      setState(() {
        _polygonPoints.removeAt(existingIndex);
        _markers.removeAt(existingIndex);
        _reorderPolygon();
      });
    } else {
      final customIcon = await _createCustomMarker(Colors.red);
      setState(() {
        _polygonPoints.add(position);
        _markers.add(
          Marker(
            markerId: MarkerId(position.toString()),
            position: position,
            icon: customIcon,
            onTap: () {
              _onMapTapped(position);
            },
          ),
        );
        _reorderPolygon();
      });
    }
  }

  void _reorderPolygon() {
    if (_polygonPoints.length > 2) {
      final LatLng centroid = _calculateCentroid(_polygonPoints);

      // Calcular ángulos para cada punto
      final List<Map<String, dynamic>> pointsWithAngles = List.generate(
        _polygonPoints.length,
        (index) => {
          'point': _polygonPoints[index],
          'marker': _markers[index],
          'angle': _calculateAngle(centroid, _polygonPoints[index]),
        },
      );

      // Ordenar por ángulo en sentido antihorario
      pointsWithAngles.sort((a, b) => a['angle'].compareTo(b['angle']));

      // Actualizar _polygonPoints y _markers en el nuevo orden
      _polygonPoints
        ..clear()
        ..addAll(pointsWithAngles.map((entry) => entry['point'] as LatLng));
      _markers
        ..clear()
        ..addAll(pointsWithAngles.map((entry) => entry['marker'] as Marker));
    }
    _updatePolygon();
  }

  double _calculateAngle(LatLng center, LatLng point) {
    return atan2(point.longitude - center.longitude, point.latitude - center.latitude);
  }

  void _updatePolygon() {
    if (_polygonPoints.isNotEmpty) {
      final polygon = Polygon(
        polygonId: const PolygonId('polygon'),
        points: _polygonPoints,
        strokeColor: Colors.black,
        strokeWidth: 3,
        fillColor: Colors.blue.withOpacity(0.3),
      );
      _polygons.clear();
      _polygons.add(polygon);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Área de Interés'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _polygonPoints.length < 3
                ? null
                : () {
                    LatLng centroid = _calculateCentroid(_polygonPoints);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SaveAreaPage(
                          points: _polygonPoints,
                          centroid: centroid,
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: userLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar lugar',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onSubmitted: (query) async {
                      // Buscar ubicación por texto (puedes implementar si es necesario)
                    },
                  ),
                ),
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: userLocation!,
                      zoom: 15,
                    ),
                    onMapCreated: (controller) => mapController = controller,
                    markers: Set.from(_markers)..addAll(_userMarkers),
                    polygons: Set.from(_polygons)..addAll(_userPolygons),
                    onTap: _onMapTapped,
                  ),
                ),
              ],
            ),
    );
  }

  LatLng _calculateCentroid(List<LatLng> points) {
    double latSum = 0.0;
    double lngSum = 0.0;

    for (var point in points) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }

    return LatLng(latSum / points.length, lngSum / points.length);
  }
}
