import 'dart:ui' as ui;
import 'package:alerta_punk/utils/recommendation_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late GoogleMapController _mapController;
  final Location _location = Location();
  LatLng _initialLocation = const LatLng(-16.0, -68);
  Set<Polygon> _polygons = {}; // Polígonos que se dibujarán en el mapa
  Set<Marker> _markers =
      {}; // Marcadores personalizados para los puntos del área

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadUserAreas(); // Cargar áreas guardadas
  }

  Future<void> _getUserLocation() async {
    final hasPermission = await _checkLocationPermission();

    if (hasPermission) {
      final userLocation = await _location.getLocation();
      setState(() {
        _initialLocation =
            LatLng(userLocation.latitude!, userLocation.longitude!);
      });
      _mapController.moveCamera(
        CameraUpdate.newLatLng(_initialLocation),
      );
    }
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return false;
      }
    }

    return true;
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
      final String droughtPrediction = data['droughtPrediction'] ?? '';
      final String floodPrediction = data['floodPrediction'] ?? '';
      final String firePrediction = data['firePrediction'] ?? '';
    final String crop = data['selectedCrop'] ?? '';
      final String cropProbability = data['cropProbability'] ?? '';
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
        ),
      );

      // Crear marcadores personalizados para los nodos del área
      for (var point in points) {
        final icon = await _createCustomMarker(color);
        userMarkers.add(
          Marker(
            markerId: MarkerId(point.toString()),
            position: point,
            icon: icon,
            onTap: () {
              // Mostrar popup con detalles del área
              _showAreaDetailPopup(
                name: name,
                color: color,
                centroid: centroidData,
                droughtPrediction: droughtPrediction,
                floodPrediction: floodPrediction,
                firePrediction: firePrediction,
                area: _calculateArea(points),
                selectedCrop: crop,
                cropProbability: cropProbability,

              );
            },
          ),
        );
      }
    }

    setState(() {
      _polygons = userPolygons;
      _markers = userMarkers;
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al cargar áreas: $e')),
    );
  }
}


 void _showAreaDetailPopup({
  required String name,
  required Color color,
  required Map<String, dynamic> centroid,
  required String droughtPrediction,
  required String floodPrediction,
  required String firePrediction,
  required double area,
  String? selectedCrop, // Cultivo seleccionado
  String? cropProbability, // Probabilidad del cultivo
}) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Color del área
              Row(
                children: [
                  const Text(
                    'Color:',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Predicción de sequía
              const Text(
                'Predicción de Sequía:',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                droughtPrediction.isNotEmpty
                    ? getDroughtRecommendation(droughtPrediction)
                    : 'No hay datos de predicción de sequía.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),

              // Predicción de inundación
              const Text(
                'Predicción de Inundación:',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                floodPrediction.isNotEmpty
                    ? getFloodRecommendation(floodPrediction)
                    : 'No hay datos de predicción de inundación.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),

              // Predicción de incendios
              const Text(
                'Predicción de Incendios:',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                firePrediction.isNotEmpty
                    ? getFireRecommendation(firePrediction)
                    : 'No hay datos de predicción de incendios.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),

              // Detalle de cultivo seleccionado
              if (selectedCrop != null && selectedCrop.isNotEmpty) ...[
                const Text(
                  'Cultivo Seleccionado:',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  selectedCrop,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 5),
                if (cropProbability != null)
                  Text(
                    'Probabilidad: ${cropProbability}%',
                    style: const TextStyle(fontSize: 16),
                  ),
                const SizedBox(height: 10),
              ] else
                const Text(
                  'No hay datos de cultivo seleccionado.',
                  style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                ),
            ],
          ),
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



  double _calculateArea(List<LatLng> points) {
    if (points.length < 3) return 0.0;

    double area = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      area += points[i].longitude * points[i + 1].latitude -
          points[i + 1].longitude * points[i].latitude;
    }
    area += points.last.longitude * points.first.latitude -
        points.first.longitude * points.last.latitude;

    return area.abs() / 2.0; // Devuelve el área aproximada
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _initialLocation,
          zoom: 15,
        ),
        myLocationEnabled: true, // Habilitar icono de ubicación
        myLocationButtonEnabled: true, // Botón para centrar la ubicación
        zoomControlsEnabled: false, // Deshabilitar botones de zoom
        polygons: _polygons, // Dibujar los polígonos en el mapa
        markers: _markers, // Dibujar los marcadores personalizados
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
      ),
    );
  }
}
