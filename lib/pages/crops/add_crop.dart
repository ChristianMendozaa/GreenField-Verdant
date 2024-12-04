import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class AddImagesScreen extends StatefulWidget {
  @override
  _AddImagesScreenState createState() => _AddImagesScreenState();
}

class _AddImagesScreenState extends State<AddImagesScreen> {
  final List<File> _images = [];
  final List<Map<String, dynamic>> _predictions = [];
  final picker = ImagePicker();

  final List<String> _classDict = [
    'Yute',
    'Maíz',
    'Arroz',
    'Caña de azúcar',
    'Trigo'
  ];

  bool _isLoadingPredictions = false;
  bool _isSaving = false;

  Future<void> _pickImages() async {
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles != null) {
      setState(() {
        _images.addAll(pickedFiles.map((e) => File(e.path)));
      });
      await _predictImages();
    }
  }

  Future<void> _predictImages() async {
    setState(() {
      _isLoadingPredictions = true;
    });

    final interpreter =
        await Interpreter.fromAsset('assets/models/crop_clasification.tflite');

    for (var imageFile in _images) {
      final inputImage = await _processImage(imageFile);
      final output = List<double>.filled(5, 0).reshape([1, 5]);
      interpreter.run([inputImage], output);

      final maxConfidence =
          output[0].reduce((double a, double b) => a > b ? a : b);
      final maxIndex = output[0].indexOf(maxConfidence);

      final prediction = {
        'label': _classDict[maxIndex],
        'confidence': output[0][maxIndex],
      };

      setState(() {
        _predictions.add({'file': imageFile, 'prediction': prediction});
      });
    }

    interpreter.close();
    setState(() {
      _isLoadingPredictions = false;
    });
  }

  Future<List<List<List<double>>>> _processImage(File imageFile) async {
    final image = img.decodeImage(imageFile.readAsBytesSync())!;
    final resizedImage = img.copyResize(image, width: 299, height: 299);

    final imageBytes = resizedImage.data;
    return List.generate(299, (y) {
      return List.generate(299, (x) {
        final pixel = imageBytes[y * 299 + x];
        final r = img.getRed(pixel) / 255.0;
        final g = img.getGreen(pixel) / 255.0;
        final b = img.getBlue(pixel) / 255.0;
        return [r, g, b];
      });
    });
  }

  Future<String> _uploadToImgBB(File imageFile) async {
    final url =
        "https://api.imgbb.com/1/upload?key=2c68fb0d7ff2f04835d1da3cf672e0a3";
    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.files
        .add(await http.MultipartFile.fromPath('image', imageFile.path));
    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = json.decode(await response.stream.bytesToString());
      return responseData['data']['url'];
    } else {
      throw Exception("Error al subir la imagen a ImgBB");
    }
  }

  Future<void> _saveToDatabase() async {
    setState(() {
      _isSaving = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("No user in session")));
      setState(() {
        _isSaving = false;
      });
      return;
    }

    for (var item in _predictions) {
      final imageFile = item['file'];
      final prediction = item['prediction'];
      final cropName =
          prediction['label'];

      final imageUrl = await _uploadToImgBB(imageFile);

      final collection = FirebaseFirestore.instance.collection('crops');
      final query = await collection
          .where('uid', isEqualTo: user.uid)
          .where('name', isEqualTo: cropName)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final existingImages = List<String>.from(doc['images']);
        existingImages.add(imageUrl);

        await collection.doc(doc.id).update({'images': existingImages});
      } else {
        await collection.add({
          'uid': user.uid,
          'name': cropName,
          'images': [imageUrl],
        });
      }
    }

    setState(() {
      _isSaving = false;
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Agregar Imágenes"),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          if (_isLoadingPredictions)
            LinearProgressIndicator(),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(10),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                final item = _predictions[index];
                final prediction = item['prediction'];
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          item['file'],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        child: Text(
                          "${prediction['label']} (${(prediction['confidence'] * 100).toStringAsFixed(2)}%)",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _predictions.removeAt(index);
                            _images.removeAt(index);
                          });
                        },
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(10),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveToDatabase,
              icon: _isSaving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(Icons.cloud_upload),
              label: Text("Guardar Cultivos"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImages,
        backgroundColor: Colors.teal,
        child: Icon(Icons.add_photo_alternate),
      ),
    );
  }
}
