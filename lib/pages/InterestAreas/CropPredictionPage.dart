import 'package:flutter/material.dart';
class CropPredictionPage extends StatelessWidget {
  final Map<String, double> cropPredictions;
  final Function(String) onCropSelected;
  final String? selectedCrop;

  const CropPredictionPage({
    Key? key,
    required this.cropPredictions,
    required this.onCropSelected,
    this.selectedCrop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar Cultivo')),
      body: cropPredictions.isEmpty
          ? Center(child: Text('No hay predicciones disponibles.'))
          : ListView(
              children: cropPredictions.entries.map((entry) {
                final probability = entry.value * 100;
                return ListTile(
                  title: Text(entry.key),
                  subtitle: Text('Probabilidad: ${probability.toStringAsFixed(2)}%'),
                  trailing: selectedCrop == entry.key
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    onCropSelected(entry.key);
                    Navigator.pop(context); // Volver a la página principal
                  },
                );
              }).toList(),
            ),
    );
  }
}
