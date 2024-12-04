import 'package:alerta_punk/pages/crops/add_crop.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class CropGallery extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Galería de Cultivos")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('crops').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final crops = snapshot.data?.docs ?? [];
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
            ),
            itemCount: crops.length,
            itemBuilder: (context, index) {
              final crop = crops[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AlbumViewScreen(
                        cropName: crop['name'],
                        images: List<String>.from(crop['images']),
                      ),
                    ),
                  );
                },
                child: Card(
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.network(
                          crop['images'].isNotEmpty
                              ? crop['images'][0]
                              : 'https://via.placeholder.com/150',
                          fit: BoxFit.cover,
                        ),
                      ),
                      Text(crop['name']),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddImagesScreen()),
        ),
        child: Icon(Icons.add),
      ),
    );
  }
}

class AlbumViewScreen extends StatelessWidget {
  final String cropName;
  final List<String> images;

  AlbumViewScreen({required this.cropName, required this.images});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(cropName)),
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageViewScreen(imageUrl: images[index]),
                ),
              );
            },
            child: Card(
              child: Image.network(
                images[index],
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }
}

class ImageViewScreen extends StatelessWidget {
  final String imageUrl;

  ImageViewScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Imagen"),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () async {
              try {
                // Descargar la imagen usando un paquete como `dio` o `http`.
                Clipboard.setData(ClipboardData(text: imageUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Enlace copiado al portapapeles")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error al descargar la imagen")),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Image.network(imageUrl),
      ),
    );
  }
}

