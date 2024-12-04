import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

class AddPlantPage extends StatefulWidget {
  const AddPlantPage({Key? key}) : super(key: key);

  @override
  _AddPlantPageState createState() => _AddPlantPageState();
}

class _AddPlantPageState extends State<AddPlantPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  File? _imageFile;
  bool isLoading = false;
  String? predictedLabel;

  List<String> classLabels = [
    "Manzana costra del manzano",
    "Manzana pudrición negra",
    "Manzana roya del manzano de los cedros",
    "Manzana saludable",
    "Arándano saludable",
    "Cereza (incluyendo ácida) oídio",
    "Cereza (incluyendo ácida) saludable",
    "Maíz (mazorca) mancha foliar de Cercospora y mancha gris de la hoja",
    "Maíz (mazorca) roya común",
    "Maíz (mazorca) tizón foliar del norte",
    "Maíz (mazorca) saludable",
    "Uva pudrición negra",
    "Uva Esca (manchas negras)",
    "Uva tizón foliar (mancha foliar de Isariopsis)",
    "Uva saludable",
    "Naranja Huanglongbing (enverdecimiento de los cítricos)",
    "Durazno mancha bacteriana",
    "Durazno saludable",
    "Pimiento morrón mancha bacteriana",
    "Pimiento morrón saludable",
    "Papa tizón temprano",
    "Papa tizón tardío",
    "Papa saludable",
    "Frambuesa saludable",
    "Soya saludable",
    "Calabaza oídio",
    "Fresa quemadura de las hojas",
    "Fresa saludable",
    "Tomate mancha bacteriana",
    "Tomate tizón temprano",
    "Tomate tizón tardío",
    "Tomate moho de las hojas",
    "Tomate mancha foliar de Septoria",
    "Tomate ácaros araña (araña roja de dos manchas)",
    "Tomate mancha objetivo",
    "Tomate virus del enrollamiento amarillo de la hoja",
    "Tomate virus del mosaico del tomate",
    "Tomate saludable"
  ];

  Future<void> selectImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        isLoading = true; // Mostrar indicador de carga mientras se predice
      });

      try {
        final prediction = await predictDisease(_imageFile!);
        setState(() {
          predictedLabel = prediction;
          isLoading = false;
        });
      } catch (e) {
        setState(() {
          predictedLabel = 'Error al predecir';
          isLoading = false;
        });
        print('Error durante la predicción: $e');
      }
    }
  }

  Float32List preprocessImage(File imageFile, int inputHeight, int inputWidth) {
    final rawImage = img.decodeImage(imageFile.readAsBytesSync());

    if (rawImage == null) {
      throw Exception("No se pudo decodificar la imagen.");
    }

    final resizedImage =
        img.copyResize(rawImage, height: inputHeight, width: inputWidth);

    final Float32List normalizedImage =
        Float32List(resizedImage.width * resizedImage.height * 3);
    int pixelIndex = 0;

    for (int y = 0; y < resizedImage.height; y++) {
      for (int x = 0; x < resizedImage.width; x++) {
        final int pixel = resizedImage.getPixel(x, y);
        final int r = (pixel >> 16) & 0xFF;
        final int g = (pixel >> 8) & 0xFF;
        final int b = pixel & 0xFF;

        normalizedImage[pixelIndex++] = r / 255.0;
        normalizedImage[pixelIndex++] = g / 255.0;
        normalizedImage[pixelIndex++] = b / 255.0;
      }
    }

    return normalizedImage;
  }

  Future<String> predictDisease(File imageFile) async {
    try {
      final interpreter =
          await Interpreter.fromAsset('assets/models/plant_disease.tflite');

      interpreter.allocateTensors();

      final inputDetails = interpreter.getInputTensor(0);
      final outputDetails = interpreter.getOutputTensor(0);

      final inputHeight = inputDetails.shape[1];
      final inputWidth = inputDetails.shape[2];

      final inputImage = preprocessImage(imageFile, inputHeight, inputWidth);

      final reshapedInput = inputImage.buffer
          .asFloat32List()
          .reshape([1, inputHeight, inputWidth, 3]);

      final outputBuffer =
          List.generate(1, (_) => List.filled(outputDetails.shape[1], 0.0));

      interpreter.run(reshapedInput, outputBuffer);

      interpreter.close();

      final predictedClassIndex = outputBuffer[0]
          .indexOf(outputBuffer[0].reduce((a, b) => a > b ? a : b));

      return classLabels[predictedClassIndex];
    } catch (e) {
      print('Error durante la predicción: $e');
      return 'Error al predecir';
    }
  }

  Future<String> uploadToImgBB(File imageFile) async {
    const apiKey = "2c68fb0d7ff2f04835d1da3cf672e0a3";
    final url = "https://api.imgbb.com/1/upload?key=$apiKey";
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

  Future<void> addPlant() async {
    if (_nameController.text.isEmpty || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Usuario no autenticado';

      final imageUrl = await uploadToImgBB(_imageFile!);
      final prediction = await predictDisease(_imageFile!);

      await _firestore.collection('plants').add({
        'uid': user.uid,
        'name': _nameController.text,
        'imageUrl': imageUrl,
        'prediction': prediction,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Planta agregada exitosamente')),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error al agregar planta: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Planta'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration:
                  const InputDecoration(labelText: 'Nombre de la planta'),
            ),
            const SizedBox(height: 16.0),
            _imageFile == null
                ? const Text('No se ha seleccionado ninguna imagen')
                : Column(
                    children: [
                      Image.file(_imageFile!, height: 150),
                      const SizedBox(height: 16.0),
                      if (predictedLabel != null)
                        Text(
                          'Predicción: $predictedLabel',
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: selectImage,
              child: const Text('Seleccionar Imagen'),
            ),
            const SizedBox(height: 16.0),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: addPlant,
                    child: const Text('Agregar Planta'),
                  ),
          ],
        ),
      ),
    );
  }
}
