import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> _userAreas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserAreas();
  }

  Future<void> _fetchUserAreas() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('areas')
            .where('userId', isEqualTo: user.uid)
            .get();

        setState(() {
          _userAreas = querySnapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
          _isLoading = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final averageDrought = _calculateAverageDrought();
    final floodRiskPercentage = _calculateFloodRiskPercentage();
    final totalFireArea = _calculateTotalFireArea();
    final totalAreas = _userAreas.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard de Usuario')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userAreas.isEmpty
              ? const Center(child: Text('No hay datos para mostrar.'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      _buildKpiCards(
                        averageDrought: averageDrought,
                        floodRiskPercentage: floodRiskPercentage,
                        totalFireArea: totalFireArea,
                        totalAreas: totalAreas,
                      ),
                      const SizedBox(height: 20),
                      _buildTitle('Comparación de Predicciones de Sequía'),
                      _buildDroughtBarChart(),
                      const SizedBox(height: 20),
                      _buildTitle('Riesgos de Inundación'),
                      _buildFloodChart(),
                      const SizedBox(height: 20),
                      _buildTitle('Áreas posibles a quemarse en caso de incendio'),
                      _buildFireMap(),
                      const SizedBox(height: 20),
                      _buildTitle('Inundaciones vs Sequias'),
                      _buildPieChart(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildKpiCards({
    required double averageDrought,
    required double floodRiskPercentage,
    required double totalFireArea,
    required int totalAreas,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildKpiCard(
          title: 'Promedio Sequía',
          value: averageDrought.toStringAsFixed(2),
          color: Colors.orange,
        ),
        _buildKpiCard(
          title: '% Inundación',
          value: '${floodRiskPercentage.toStringAsFixed(1)}%',
          color: Colors.blue,
        ),
        _buildKpiCard(
          title: 'Área Fuego',
          value: '${totalFireArea.toStringAsFixed(1)} m',
          color: Colors.red,
        ),
        _buildKpiCard(
          title: 'Áreas Totales',
          value: totalAreas.toString(),
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 80,
        height: 100,
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                  fontSize: 16, color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // Gráfico de Promedio de Sequías (0-5)
  Widget _buildDroughtBarChart() {
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          barGroups: _userAreas.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, dynamic> area = entry.value;

            return BarChartGroupData(x: index, barRods: [
              BarChartRodData(
                toY: parsePrediction(area['droughtPrediction']),
                width: 15,
                color:
                    Color(int.parse(area['color'], radix: 16)).withOpacity(1),
              ),
            ]);
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: const Text('Nivel de Sequía (0-5)'),
              sideTitles: SideTitles(showTitles: true),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: const Text('Áreas'),
              sideTitles: SideTitles(showTitles: true),
            ),
          ),
        ),
      ),
    );
  }

  // Gráfico de Inundaciones (0-1)
  Widget _buildFloodChart() {
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          barGroups: _userAreas.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, dynamic> area = entry.value;

            return BarChartGroupData(x: index, barRods: [
              BarChartRodData(
                toY: parseFloodPrediction(area['floodPrediction']),
                width: 15,
                color:
                    Color(int.parse(area['color'], radix: 16)).withOpacity(1),
              ),
            ]);
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: const Text('Riesgo de Inundación (0-1)'),
              sideTitles: SideTitles(showTitles: true),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: const Text('Áreas'),
              sideTitles: SideTitles(showTitles: true),
            ),
          ),
        ),
      ),
    );
  }

  // Mapa para mostrar las áreas afectadas por incendios
  Widget _buildFireMap() {
    return SizedBox(
      height: 300,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _userAreas.isNotEmpty
              ? LatLng(
                  _userAreas.first['centroid']['latitude'],
                  _userAreas.first['centroid']['longitude'],
                )
              : const LatLng(0, 0),
          zoom: 15,
        ),
        markers: _userAreas.map((area) {
          final points = area['points'] as List;
          final centroidLat = area['centroid']['latitude'];
          final centroidLng = area['centroid']['longitude'];
          final fireArea = parseFireArea(area['firePrediction']);

          return Marker(
            markerId: MarkerId(area['name']),
            position: LatLng(centroidLat, centroidLng),
            infoWindow: InfoWindow(
              title: area['name'],
              snippet: 'Área posible a quemarse: ${fireArea.toStringAsFixed(1)} ha',
            ),
          );
        }).toSet(),
        polygons: _userAreas.map((area) {
          final points = area['points'] as List;
          final polygonPoints = points
              .map((point) => LatLng(
                  point['latitude'] as double, point['longitude'] as double))
              .toList();

          return Polygon(
            polygonId: PolygonId(area['name']),
            points: polygonPoints,
            strokeColor:
                Color(int.parse(area['color'], radix: 16)).withOpacity(1),
            fillColor:
                Color(int.parse(area['color'], radix: 16)).withOpacity(0.4),
          );
        }).toSet(),
        zoomControlsEnabled: true, // Controles de zoom
        scrollGesturesEnabled: true, // Permitir desplazamiento
        zoomGesturesEnabled: true, // Permitir zoom
        rotateGesturesEnabled: true, // Permitir rotación
        tiltGesturesEnabled: true, // Permitir inclinación
      ),
    );
  }

  Widget _buildPieChart() {
    final droughtCount = _userAreas
        .where((area) => parsePrediction(area['droughtPrediction']) > 0)
        .length;
    final floodCount = _userAreas
        .where((area) => parsePrediction(area['floodPrediction']) == 1)
        .length;

    return SizedBox(
      height: 300,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              value: droughtCount.toDouble(),
              color: Colors.orange,
              title: 'Sequías',
            ),
            PieChartSectionData(
              value: floodCount.toDouble(),
              color: Colors.blue,
              title: 'Inundaciones',
            ),
          ],
        ),
      ),
    );
  }

  // Función para convertir las predicciones de sequía (0-5)
  double parsePrediction(String? value) {
    if (value == null || value.isEmpty) return 0.0;
    final cleanValue = value.replaceAll(RegExp(r'\[|\]'), '');
    return double.tryParse(cleanValue) ?? 0.0;
  }

  // Función para convertir las predicciones de inundación (0-1)
  double parseFloodPrediction(String? value) {
    if (value == null || value.isEmpty) return 0.0;
    final cleanValue = value.replaceAll(RegExp(r'\[|\]'), '');
    return double.tryParse(cleanValue) ?? 0.0;
  }

  // Función para calcular el área quemada en caso de incendio
  double parseFireArea(String? value) {
    if (value == null || value.isEmpty) return 0.0;
    final cleanValue = value.replaceAll(RegExp(r'\[|\]'), '');
    return double.tryParse(cleanValue) ?? 0.0;
  }

  // Cálculos de KPIs
  double _calculateAverageDrought() {
    if (_userAreas.isEmpty) return 0.0;
    final total = _userAreas.fold<double>(
        0.0, (sum, area) => sum + parsePrediction(area['droughtPrediction']));
    return total / _userAreas.length;
  }

  double _calculateFloodRiskPercentage() {
    if (_userAreas.isEmpty) return 0.0;
    final floodCount = _userAreas
        .where((area) => parseFloodPrediction(area['floodPrediction']) == 1)
        .length;
    return (floodCount / _userAreas.length) * 100;
  }

  double _calculateTotalFireArea() {
    if (_userAreas.isEmpty) return 0.0;
    return _userAreas.fold<double>(
        0.0, (sum, area) => sum + parseFireArea(area['firePrediction']));
  }
}
