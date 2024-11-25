import 'dart:convert';
import 'dart:ui' as ui;
import 'package:alerta_punk/pages/InterestAreas/CropPredictionPage.dart';
import 'package:alerta_punk/pages/InterestAreas/make_predicction.dart';
import 'package:alerta_punk/pages/home_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class SaveAreaPage extends StatefulWidget {
  final List<LatLng> points;
  final LatLng centroid;

  const SaveAreaPage({Key? key, required this.points, required this.centroid})
      : super(key: key);

  @override
  _SaveAreaPageState createState() => _SaveAreaPageState();
}

class _SaveAreaPageState extends State<SaveAreaPage> {
  Color _selectedColor = Colors.blue;
  String _areaName = '';
  Set<Polygon> _polygons = {};
  Set<Marker> _markers = {};
  String? _userId;
  bool _isLoading = true;
  String _statusMessage = 'Obteniendo datos satelitales de la NASA...';
  String? _droughtPrediction;
  String? _floodPrediction;
  String? _firePrediction;
String? _selectedCrop;
  Map<String, double>? _cropPredictions; // Almacenar las predicciones de cultivos

  @override
  void initState() {
    super.initState();
    _initializePolygonAndMarkers();
    _getUserId();
    _getPredictions(); // Obtener predicciones automáticamente al cargar
  }

  Future<void> _getUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
    }
  }

  void _initializePolygonAndMarkers() {
    _polygons = {
      Polygon(
        polygonId: const PolygonId('area'),
        points: widget.points,
        strokeColor: Colors.black,
        strokeWidth: 3,
        fillColor: _selectedColor.withOpacity(0.3),
      ),
    };

    _createCustomMarkers().then((markers) {
      setState(() {
        _markers = markers;
      });
    });
  }

  Future<Set<Marker>> _createCustomMarkers() async {
    final List<Marker> customMarkers = [];
    for (var point in widget.points) {
      final icon = await _createColoredMarker(_selectedColor);
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

  Future<void> _getPredictions() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Obteniendo datos satelitales de la NASA...';
    });

    try {
      final latitude = widget.centroid.latitude;
      final longitude = widget.centroid.longitude;

      // Instancia del servicio de predicción
      final predictionService = PredictionService();
      await predictionService.determinePosition();
      final predictions =
          await predictionService.makePredictions(latitude, longitude);

      setState(() {
        _droughtPrediction = predictions['drought'];
        _floodPrediction = predictions['flood'];
        _firePrediction = predictions['fire'];
                _cropPredictions = _parseCropPredictions(predictions['crop']);

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al obtener predicciones: $e';
        _isLoading = false;
      });
    }
  }
Map<String, double> _parseCropPredictions(String? cropPrediction) {
    try {
      return cropPrediction != null
          ? Map<String, double>.from(json.decode(cropPrediction))
          : {};
    } catch (e) {
      return {};
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guardar Área de Interés')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.centroid,
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
            TextField(
              decoration: const InputDecoration(
                labelText: 'Nombre del Área',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _areaName = value;
                });
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Color del Área: ', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    _showColorPicker(context);
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (_isLoading)
              Text(
                _statusMessage,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            if (!_isLoading &&
                _droughtPrediction != null &&
                _floodPrediction != null &&
                _firePrediction != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resultados:',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // Detalle de sequía
                  Text(
                    'Sequía: Nivel $_droughtPrediction',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    _getDroughtRecommendation(_droughtPrediction!),
                    style: const TextStyle(
                        fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 10),

                  // Detalle de inundación
                  Text(
                    'Inundación: ${_floodPrediction == "1" ? "Alto riesgo de inundación" : "Sin riesgo de inundación"}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    _getFloodRecommendation(_floodPrediction!),
                    style: const TextStyle(
                        fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 10),

                  // Detalle de incendios
                  Text(
                    'Incendios: ${_firePrediction == "1" ? "Alto riesgo de incendio" : "Bajo riesgo de incendio"}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    _getFireRecommendation(_firePrediction!),
                    style: const TextStyle(
                        fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const Spacer(),
            ElevatedButton(
              onPressed: !_isLoading && _cropPredictions != null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CropPredictionPage(
                            cropPredictions: _cropPredictions!,
                            selectedCrop: _selectedCrop,
                            onCropSelected: (selected) {
                              setState(() {
                                _selectedCrop = selected;
                              });
                            },
                          ),
                        ),
                      );
                    }
                  : null,
              child: const Text('Seleccionar Cultivo'),
            ),
            if (_selectedCrop != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  'Cultivo seleccionado: $_selectedCrop',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: !_isLoading &&
                      _droughtPrediction != null &&
                      _floodPrediction != null
                  ? _saveToDatabase
                  : null,
              child: const Text('Guardar Área'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToDatabase() async {
    if (_areaName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa el nombre del área.')),
      );
      return;
    }

    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario no autenticado.')),
      );
      return;
    }

    final areaData = {
      'userId': _userId,
      'name': _areaName,
      'color': _selectedColor.value.toRadixString(16),
      'centroid': {
        'latitude': widget.centroid.latitude,
        'longitude': widget.centroid.longitude,
      },
      'points': widget.points
          .map((point) =>
              {'latitude': point.latitude, 'longitude': point.longitude})
          .toList(),
      'droughtPrediction': _droughtPrediction,
      'floodPrediction': _floodPrediction,
      'firePrediction': _firePrediction,
      'createdAt': Timestamp.now(),
    };

    try {
      await FirebaseFirestore.instance.collection('areas').add(areaData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Área guardada exitosamente.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el área: $e')),
      );
    }
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Seleccionar Color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: _selectedColor,
              onColorChanged: (color) {
                setState(() {
                  _selectedColor = color;
                  _updatePolygonAndMarkers();
                });
              },
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

  void _updatePolygonAndMarkers() {
    setState(() {
      _polygons = {
        Polygon(
          polygonId: const PolygonId('area'),
          points: widget.points,
          strokeColor: Colors.black,
          strokeWidth: 3,
          fillColor: _selectedColor.withOpacity(0.3),
        ),
      };

      _createCustomMarkers().then((markers) {
        setState(() {
          _markers = markers;
        });
      });
    });
  }

  String _getDroughtRecommendation(String droughtLevel) {
    switch (droughtLevel) {
      case "[0]":
        return "No hay sequía. Mantén las prácticas normales de riego.";
      case "[1]":
        return "Sequía leve. Incrementa la monitorización de la humedad del suelo.";
      case "[2]":
        return "Sequía moderada. Optimiza el riego y reduce el uso innecesario de agua.";
      case "[3]":
        return "Sequía severa. Prioriza los cultivos más importantes.";
      case "[4]":
        return "Sequía extrema. Implementa estrategias de conservación de agua.";
      case "[5]":
        return "Sequía severa. Considera medidas de emergencia para proteger cultivos.";
      default:
        return "Nivel de sequía desconocido.";
    }
  }

  String _getFloodRecommendation(String floodRisk) {
    if (floodRisk == "1") {
      return "Alto riesgo de inundación. Asegúrate de proteger los cultivos y verifica sistemas de drenaje.";
    } else {
      return "No hay riesgo de inundación. Mantén prácticas regulares.";
    }
  }
}

String _getFireRecommendation(String fireRisk) {
  if (fireRisk == "1") {
    return "Alto riesgo de incendio. Asegúrate de mantener despejadas las áreas circundantes y evita actividades que puedan generar chispas.";
  } else {
    return "Bajo riesgo de incendio. Continúa monitoreando las condiciones ambientales.";
  }
}
