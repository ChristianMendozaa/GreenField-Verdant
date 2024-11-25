import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

class AddPlantPage extends StatefulWidget {
  const AddPlantPage({Key? key}) : super(key: key);

  @override
  _AddPlantPageState createState() => _AddPlantPageState();
}

class _AddPlantPageState extends State<AddPlantPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  File? _imageFile;
  bool isLoading = false;
  String? predictedLabel;

  List<String> classLabels = [
    "Apple Apple scab",
    "Apple Black rot",
    "Apple Cedar apple rust",
    "Apple healthy",
    "Bacterial leaf blight in rice leaf",
    "Blight in corn Leaf",
    "Blueberry healthy",
    "Brown spot in rice leaf",
    "Cercospora leaf spot",
    "Cherry (including sour) Powdery mildew",
    "Cherry (including sour) healthy",
    "Common Rust in corn Leaf",
    "Corn (maize) healthy",
    "Garlic",
    "Grape Black rot",
    "Grape Esca Black Measles",
    "Grape Leaf blight Isariopsis Leaf Spot",
    "Grape healthy",
    "Gray Leaf Spot in corn Leaf",
    "Leaf smut in rice leaf",
    "Orange Haunglongbing Citrus greening",
    "Peach healthy",
    "Pepper bell Bacterial spot",
    "Pepper bell healthy",
    "Potato Early blight",
    "Potato Late blight",
    "Potato healthy",
    "Raspberry healthy",
    "Soybean healthy",
    "Strawberry Leaf scorch",
    "Strawberry healthy",
    "Tomato Bacterial spot",
    "Tomato Early blight",
    "Tomato Late blight",
    "Tomato Leaf Mold",
    "Tomato Septoria leaf spot",
    "Tomato Spider mites Two spotted spider mite",
    "Tomato Target Spot",
    "Tomato Tomato mosaic virus",
    "Tomato healthy",
    "algal leaf in tea",
    "anthracnose in tea",
    "bird eye spot in tea",
    "brown blight in tea",
    "cabbage looper",
    "corn crop",
    "ginger",
    "healthy tea leaf",
    "lemon canker",
    "potato crop",
    "potato hollow heart",
    "red leaf spot in tea"
  ];

  Future<void> selectImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        isLoading = true; // Mostrar indicador de carga mientras se predice
      });

      // Realizar la predicción
      try {
        final prediction = await predictDisease(_imageFile!);
        setState(() {
          predictedLabel =
              prediction; // Actualizar el resultado de la predicción
          isLoading = false; // Ocultar el indicador de carga
        });
      } catch (e) {
        setState(() {
          predictedLabel = 'Error al predecir'; // Mostrar error si ocurre
          isLoading = false;
        });
        print('Error durante la predicción: $e');
      }
    }
  }

  Float32List preprocessImage(File imageFile, int inputHeight, int inputWidth) {
    final rawImage = img.decodeImage(imageFile.readAsBytesSync());

    if (rawImage == null) {
      throw Exception(
          "No se pudo decodificar la imagen. Asegúrate de que el archivo es válido.");
    }

    final resizedImage =
        img.copyResize(rawImage, height: inputHeight, width: inputWidth);

    // Crear el buffer para almacenar los datos normalizados
    final Float32List normalizedImage =
        Float32List(resizedImage.width * resizedImage.height * 3);
    int pixelIndex = 0;

    // Iterar sobre cada píxel para extraer los valores RGB
    for (int y = 0; y < resizedImage.height; y++) {
      for (int x = 0; x < resizedImage.width; x++) {
        final int pixel = resizedImage.getPixel(x, y);
        final int r = (pixel >> 16) & 0xFF; // Extraer el canal rojo
        final int g = (pixel >> 8) & 0xFF; // Extraer el canal verde
        final int b = pixel & 0xFF; // Extraer el canal azul

        // Normalizar los valores y almacenarlos en el buffer
        normalizedImage[pixelIndex++] = r / 255.0; // Normalizar el canal rojo
        normalizedImage[pixelIndex++] = g / 255.0; // Normalizar el canal verde
        normalizedImage[pixelIndex++] = b / 255.0; // Normalizar el canal azul
      }
    }

    return normalizedImage;
  }

  Future<String> predictDisease(File imageFile) async {
    try {
      // Cargar el intérprete
      final interpreter =
          await Interpreter.fromAsset('assets/models/plant_disease.tflite');

      // Asignar tensores
      interpreter.allocateTensors();

      // Obtener detalles de entrada y salida
      final inputDetails = interpreter.getInputTensor(0);
      final outputDetails = interpreter.getOutputTensor(0);

      // Dimensiones de entrada del modelo
      final inputHeight = inputDetails.shape[1];
      final inputWidth = inputDetails.shape[2];
      final inputChannels = inputDetails.shape[3];

      print("Dimensiones de entrada: ${inputDetails.shape}");
      print("Dimensiones de salida: ${outputDetails.shape}");

      // Preprocesar la imagen
      final inputImage = preprocessImage(imageFile, inputHeight, inputWidth);

      // Ajustar la dimensión del batch (Tensor NHWC: [1, height, width, channels])
      final reshapedInput = inputImage.buffer
          .asFloat32List()
          .reshape([1, inputHeight, inputWidth, 3]);

      // Crear un buffer para la salida con forma [1, 52]
      final outputBuffer =
          List.generate(1, (_) => List.filled(outputDetails.shape[1], 0.0));

      // Ejecutar el modelo
      interpreter.run(reshapedInput, outputBuffer);

      // Cerrar el intérprete para liberar recursos
      interpreter.close();

      // Obtener la clase con mayor probabilidad
      final predictedClassIndex = outputBuffer[0]
          .indexOf(outputBuffer[0].reduce((a, b) => a > b ? a : b));

      return classLabels[predictedClassIndex];
    } catch (e) {
      print('Error durante la predicción: $e');
      return 'Error al predecir';
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

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef =
          _storage.ref().child('plants').child(user.uid).child(fileName);
      await storageRef.putFile(_imageFile!);

      final imageUrl = await storageRef.getDownloadURL();
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
