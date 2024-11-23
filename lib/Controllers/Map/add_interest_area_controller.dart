import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AddInterestAreaController {
  final List<LatLng> polygonPoints = [];
  final List<Marker> markers = [];
  final List<Polygon> polygons = [];
  GoogleMapController? mapController;

  Future<BitmapDescriptor> createCustomMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 80;

    final Paint paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }

  void onMapTapped(LatLng position, Function updateState) async {
    final existingIndex = polygonPoints.indexWhere(
        (point) => point.latitude == position.latitude && point.longitude == position.longitude);

    if (existingIndex != -1) {
      // Si el punto ya existe, eliminarlo
      polygonPoints.removeAt(existingIndex);
      markers.removeAt(existingIndex);
    } else {
      // Si no existe, agregar un nuevo punto
      final customIcon = await createCustomMarker();
      polygonPoints.add(position);
      markers.add(
        Marker(
          markerId: MarkerId(position.toString()),
          position: position,
          icon: customIcon,
          onTap: () {
            onMapTapped(position, updateState);
          },
        ),
      );
      reorderPolygon(); // Reorganizar los puntos para evitar cruces
    }
    updatePolygon();
    updateState();
  }

  void reorderPolygon() {
    if (polygonPoints.length > 2) {
      polygonPoints.sort((a, b) {
        final center = calculateCentroid(polygonPoints);
        final angleA = calculateAngle(center, a);
        final angleB = calculateAngle(center, b);
        return angleA.compareTo(angleB);
      });
    }
  }

  double calculateAngle(LatLng center, LatLng point) {
    return atan2(point.longitude - center.longitude, point.latitude - center.latitude);
  }

  void updatePolygon() {
    if (polygonPoints.isNotEmpty) {
      final polygon = Polygon(
        polygonId: const PolygonId('polygon'),
        points: polygonPoints,
        strokeColor: Colors.black,
        strokeWidth: 3,
        fillColor: Colors.blue.withOpacity(0.3),
      );
      polygons.clear();
      polygons.add(polygon);
    }
  }

  LatLng calculateCentroid(List<LatLng> points) {
    double latSum = 0.0;
    double lngSum = 0.0;

    for (var point in points) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }

    return LatLng(latSum / points.length, lngSum / points.length);
  }
}
