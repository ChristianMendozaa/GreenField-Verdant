import 'package:alerta_punk/pages/saved_areas/area_detailed_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  late Future<List<Map<String, dynamic>>> _areasFuture;

  @override
  void initState() {
    super.initState();
    _areasFuture = _fetchUserAreas();
  }

  Future<List<Map<String, dynamic>>> _fetchUserAreas() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Usuario no autenticado.');
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('areas')
          .where('userId', isEqualTo: user.uid)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'color': Color(int.parse('0xff${data['color']}')),
          'centroid': data['centroid'],
          'points': data['points'],
          'droughtPrediction':
              data['droughtPrediction'], // Incluye la predicción de sequía
          'floodPrediction':
              data['floodPrediction'], // Incluye la predicción de inundación
          'selectedCrop': data['selectedCrop'],
          'cropProbability': data['cropProbability'],
        };
      }).toList();
    } catch (e) {
      throw Exception('Error al recuperar las áreas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Áreas Guardadas'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _areasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(fontSize: 18),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No tienes lugares guardados aún.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final areas = snapshot.data!;

          return ListView.builder(
            itemCount: areas.length,
            itemBuilder: (context, index) {
              final area = areas[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: area['color'],
                ),
                title: Text(area['name']),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AreaDetailPage(area: area),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
