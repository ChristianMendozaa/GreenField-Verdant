import 'dart:ui' as ui;

import 'package:alerta_punk/pages/saved_areas/chat.dart';
import 'package:alerta_punk/utils/recommendation_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AreaDetailPage extends StatefulWidget {
  final Map<String, dynamic> area;

  const AreaDetailPage({Key? key, required this.area}) : super(key: key);

  @override
  _AreaDetailPageState createState() => _AreaDetailPageState();
}

class _AreaDetailPageState extends State<AreaDetailPage> {
  Set<Polygon> _polygons = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializePolygonAndMarkers();
  }

  void _initializePolygonAndMarkers() {
    final points = widget.area['points'] as List<dynamic>;
    final Color color = widget.area['color'];

    final List<LatLng> latLngPoints = points
        .map((point) => LatLng(point['latitude'], point['longitude']))
        .toList()
        .cast<LatLng>();

    _polygons = {
      Polygon(
        polygonId: const PolygonId('area'),
        points: latLngPoints,
        strokeColor: Colors.black,
        strokeWidth: 3,
        fillColor: color.withOpacity(0.3),
      ),
    };

    _createCustomMarkers(latLngPoints, color).then((markers) {
      setState(() {
        _markers = markers;
      });
    });
  }

  Future<Set<Marker>> _createCustomMarkers(
      List<LatLng> points, Color color) async {
    final List<Marker> customMarkers = [];
    for (var point in points) {
      final icon = await _createColoredMarker(color);
      customMarkers.add(
        Marker(
          markerId: MarkerId(point.toString()),
          position: point,
          icon: icon,
        ),
      );
    }
    return customMarkers.toSet();
  }

  Future<BitmapDescriptor> _createColoredMarker(Color color) async {
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

  @override
  Widget build(BuildContext context) {
    final Color color = widget.area['color'];
    final droughtPrediction = widget.area['droughtPrediction'] as String?;
    final floodPrediction = widget.area['floodPrediction'] as String?;
    final firePrediction = widget.area['firePrediction'] as String?;
    final selectedCrop = widget.area['selectedCrop'] as String?;
    final cropProbability = widget.area['cropProbability'] as String?;
print("cultivo: $selectedCrop");
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.area['name']),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mapa no interactivo
            Expanded(
              flex: 2,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.area['centroid']['latitude'],
                      widget.area['centroid']['longitude']),
                  zoom: 15,
                ),
                markers: _markers,
                polygons: _polygons,
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                scrollGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                zoomGesturesEnabled: false,
              ),
            ),
            const SizedBox(height: 20),

            // Información textual
            Row(
              children: [
                const Text(
                  'Color:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            const SizedBox(height: 20),

            // Predicción de sequía
            const Text(
              'Predicción de Sequía:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              droughtPrediction != null
                  ? getDroughtRecommendation(droughtPrediction)
                  : 'No hay datos de predicción de sequía.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // Predicción de inundación
            const Text(
              'Predicción de Inundación:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              floodPrediction != null
                  ? getFloodRecommendation(floodPrediction)
                  : 'No hay datos de predicción de inundación.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // Predicción de incendios
            const Text(
              'Predicción de Incendios:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              firePrediction != null
                  ? getFireRecommendation(firePrediction)
                  : 'No hay datos de predicción de incendios.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // Detalle del cultivo seleccionado
            if (selectedCrop != null && selectedCrop.isNotEmpty) ...[
              const Text(
                'Cultivo Seleccionado:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                selectedCrop,
                style: const TextStyle(fontSize: 16),
              ),
              if (cropProbability != null)
                Text(
                  'Probabilidad: $cropProbability%',
                  style: const TextStyle(fontSize: 16),
                ),
            ] else
              const Text(
                'No hay datos de cultivo seleccionado.',
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 20),

            // Botón de abrir chat
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(contextData: widget.area),
                  ),
                );
              },
              child: const Text("Abrir Chat Asistente"),
            ),
          ],
        ),
      ),
    );
  }
}
