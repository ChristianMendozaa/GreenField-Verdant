import 'package:alerta_punk/pages/plants/AddPlantPage.dart';
import 'package:alerta_punk/pages/plants/PlantDetailPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlantsPage extends StatefulWidget {
  const PlantsPage({Key? key}) : super(key: key);

  @override
  _PlantsPageState createState() => _PlantsPageState();
}

class _PlantsPageState extends State<PlantsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> plants = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchPlants();
  }

  Future<void> fetchPlants() async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final querySnapshot = await _firestore
            .collection('plants')
            .where('uid', isEqualTo: user.uid)
            .get();

        setState(() {
          plants = querySnapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        });
      }
    } catch (e) {
      print('Error al obtener las plantas: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Plantas'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : plants.isEmpty
              ? const Center(child: Text('No hay plantas registradas.'))
              : ListView.builder(
                  itemCount: plants.length,
                  itemBuilder: (context, index) {
                    final plant = plants[index];
                    return ListTile(
                      leading: Image.network(plant['imageUrl'],
                          width: 50, height: 50, fit: BoxFit.cover),
                      title: Text(plant['name']),
                      subtitle: Text('Predicción: ${plant['prediction']}'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlantDetailPage(plant: plant),
                          ),
                        );
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPlantPage()),
          ).then((_) => fetchPlants()); // Refresca la lista al volver
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
