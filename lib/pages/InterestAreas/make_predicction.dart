import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class PredictionService {
  double? latitude;
  double? longitude;

  late Interpreter fireModel;
  late Interpreter floodModel;

  // Inicializar modelos TFLite
  Future<void> initializeModels() async {
    try {
      // Verifica y carga el modelo de incendio
      var fireModelData = await rootBundle.load('assets/models/fire_area_model_optimized.tflite');
      debugPrint('El modelo de incendio se encontró correctamente, tamaño: ${fireModelData.lengthInBytes} bytes.');
      fireModel = Interpreter.fromBuffer(fireModelData.buffer.asUint8List());
      debugPrint('Modelo de incendio cargado correctamente.');

      // Verifica y carga el modelo de inundación
      var floodModelData = await rootBundle.load('assets/models/flood_prediction_model.tflite');
      debugPrint('El modelo de inundación se encontró correctamente, tamaño: ${floodModelData.lengthInBytes} bytes.');
      floodModel = Interpreter.fromBuffer(floodModelData.buffer.asUint8List());
      debugPrint('Modelo de inundación cargado correctamente.');
    } catch (e, stacktrace) {
      debugPrint('Error al cargar los modelos: $e');
      debugPrint('Stacktrace: $stacktrace');
      rethrow; // Opcional: Propaga el error si necesitas manejarlo en otro lugar
    }
  }

  // Fetch the current position of the device
  Future<void> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Los servicios de ubicación están deshabilitados.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Los permisos de ubicación están denegados');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Los permisos de ubicación están permanentemente denegados.');
    }

    Position position = await Geolocator.getCurrentPosition();
    latitude = position.latitude;
    longitude = position.longitude;
  }

  // Fetch data from NASA
  Future<Map<String, dynamic>> fetchNasaData(
      double latitude, double longitude) async {
    try {
      debugPrint('Solicitando datos a la API de NASA...');
      final currentDate =
          DateFormat('yyyyMMdd').format(DateTime.now()); // Fecha actual
      final parameters = "PRECTOTCORR,PS,QV2M,T2M,WS10M,WS50M";

      final nasaUrl = Uri.parse(
          'https://power.larc.nasa.gov/api/temporal/hourly/point'
          '?start=$currentDate&end=$currentDate&latitude=$latitude&longitude=$longitude'
          '&community=ag&parameters=$parameters&format=json&time-standard=lst');

      final response = await http.get(nasaUrl);

      if (response.statusCode == 200) {
        debugPrint('Datos recibidos correctamente de la API de NASA.');
        return json.decode(response.body);
      } else {
        throw Exception('Error al obtener datos de la API de la NASA: '
            'Código de estado ${response.statusCode}');
      }
    } catch (e, stacktrace) {
      debugPrint('Error al obtener datos de la NASA: $e');
      debugPrint('Stacktrace: $stacktrace');
      rethrow;
    }
  }
  // Fetch precipitation data for flood prediction
  Future<List<double>> fetchMonthlyPrecipitation(
      double latitude, double longitude) async {
    DateTime now = DateTime.now();
    List<double> monthlyAverages = [];

    for (int i = 0; i < 12; i++) {
      DateTime endDate = DateTime(now.year, now.month - i, 0);
      DateTime startDate = DateTime(endDate.year, endDate.month, 1);

      String startDateStr = DateFormat('yyyyMMdd').format(startDate);
      String endDateStr = DateFormat('yyyyMMdd').format(endDate);

      final nasaUrl = Uri.parse(
        'https://power.larc.nasa.gov/api/temporal/daily/point'
        '?parameters=PRECTOTCORR&community=RE&longitude=$longitude&latitude=$latitude'
        '&start=$startDateStr&end=$endDateStr&format=JSON',
      );

      final response = await http.get(nasaUrl);

      if (response.statusCode == 200) {
        Map<String, dynamic> precipitationData = json.decode(response.body);
        var precipitationValues =
            precipitationData['properties']['parameter']['PRECTOTCORR'] ?? {};

        double monthlyTotal = precipitationValues.isNotEmpty
            ? precipitationValues.values.reduce((a, b) => a + b)
            : 0.0;
        double monthlyAverage = precipitationValues.isNotEmpty
            ? monthlyTotal / precipitationValues.length
            : 0.0;

        monthlyAverages.insert(0, monthlyAverage);
      } else {
        throw Exception(
            'Error al obtener datos de precipitación de la API de la NASA');
      }
    }
    return monthlyAverages;
  }

  // Fire prediction using TFLite
  Future<String> fetchFirePrediction(double latitude, double longitude) async {
  try {
    // Obtener datos de la API de NASA
    Map<String, dynamic> nasaData = await fetchNasaData(latitude, longitude);

    // Extraer parámetros relevantes
    var parameterData = nasaData['properties']['parameter'];
    var temperatureData = parameterData['T2M'] ?? {};
    var humidityData = parameterData['QV2M'] ?? {};
    var wind10mData = parameterData['WS10M'] ?? {};
    var pressureData = parameterData['PS'] ?? {};
    var rainData = parameterData['PRECTOTCORR'] ?? {};

    // Calcular promedios
    double avgTemp = temperatureData.isNotEmpty
        ? temperatureData.values.reduce((a, b) => a + b) / temperatureData.length
        : 0.0;
    double avgHumidity = humidityData.isNotEmpty
        ? humidityData.values.reduce((a, b) => a + b) / humidityData.length
        : 0.0;
    double avgWind10m = wind10mData.isNotEmpty
        ? wind10mData.values.reduce((a, b) => a + b) / wind10mData.length
        : 0.0;
    double avgPressure = pressureData.isNotEmpty
        ? pressureData.values.reduce((a, b) => a + b) / pressureData.length
        : 0.0;
    double avgRain = rainData.isNotEmpty
        ? rainData.values.reduce((a, b) => a + b) / rainData.length
        : 0.0;

    // Preparar datos de entrada
    List<double> fireData = [
      avgTemp,
      avgHumidity,
      avgWind10m,
      avgPressure,
      avgTemp - ((100 - avgHumidity) / 5),
      avgTemp + (avgWind10m / 10),
      avgTemp - (avgPressure / 100),
      avgRain,
    ];

    print("Datos para el modelo de incendio: $fireData");

    // Validar si el modelo está cargado
    if (fireModel == null) {
      throw Exception("Error: Fire model no cargado.");
    }

    // Validar las dimensiones de entrada esperadas por el modelo
    final inputShape = fireModel.getInputTensor(0).shape;
    final outputShape = fireModel.getOutputTensor(0).shape;

    if (inputShape.length != 2 || inputShape[1] != fireData.length) {
      throw Exception(
          "Dimensiones de entrada incorrectas. Se esperaban ${inputShape}, pero se recibieron ${[1, fireData.length]}.");
    }

    // Ajustar el formato de los datos para el modelo
    final input = [fireData]; // [1, n_features]
    final output = List.generate(outputShape[0], (_) => List.filled(outputShape[1], 0.0)); // [1, 1]

    // Ejecutar el modelo
    fireModel.run(input, output);

    // Extraer el resultado de la predicción
    final result = output[0][0]; // Accede al primer valor
    print("Resultado de predicción de incendio: $result");

    return result > 0.5 ? "Alto riesgo de incendio" : "Bajo riesgo de incendio";
  } catch (e) {
    print("Error durante la predicción de incendio: $e");
    return "Error durante la predicción de incendio: $e";
  }
}


  // Flood prediction using TFLite
  Future<String> fetchFloodPrediction(double latitude, double longitude) async {
  try {
    // Obtener los promedios mensuales
    List<double> monthlyAverages = await fetchMonthlyPrecipitation(latitude, longitude);
    print("Datos mensuales: $monthlyAverages");

    if (floodModel == null) {
      throw Exception("Error: Flood model no cargado.");
    }

    // Validar las dimensiones de entrada esperadas por el modelo
    final inputShape = floodModel.getInputTensor(0).shape;
    final outputShape = floodModel.getOutputTensor(0).shape;

    // Validar si la forma esperada es correcta
    if (inputShape.length != 2 || inputShape[1] != 12) {
      throw Exception(
          "Dimensiones de entrada incorrectas. Se esperaban ${inputShape}, pero se recibieron ${[1, monthlyAverages.length]}.");
    }

    // Rellenar los datos con ceros si tienen menos de 12 elementos
    while (monthlyAverages.length < 12) {
      monthlyAverages.add(0.0);
    }

    // Formatear los datos para la entrada del modelo
    final input = [monthlyAverages]; // Debe ser [1, 12] para cumplir con el modelo
    final output = List.generate(outputShape[0], (_) => List.filled(outputShape[1], 0.0)); // [1, 1]

    // Ejecutar la predicción
    floodModel.run(input, output);

    // Extraer el resultado
    final result = output[0][0]; // Obtener el valor de salida
    print("Resultado de predicción de inundación: $result");

    return result > 0.5 ? "Alto riesgo de inundación" : "Bajo riesgo de inundación";
  } catch (e) {
    print("Error durante la predicción de inundación: $e");
    return "Error durante la predicción de inundación: $e";
  }
}

String _parseDroughtResponse(Map<String, dynamic> response) {
  try {
    // Mapear las probabilidades
    var probabilities = response.map((key, value) => MapEntry(int.parse(key), value as double));

    // Encontrar la clave con el valor más alto
    var maxEntry = probabilities.entries.reduce((a, b) => a.value > b.value ? a : b);

    // Convertir el nivel de sequía al formato esperado por _getDroughtRecommendation
    String droughtLevel = "[${maxEntry.key}]";

    // Obtener la recomendación usando la función existente
    

    // Construir el mensaje final
    return droughtLevel;
  } catch (e) {
    print("Error al procesar la respuesta de sequía: $e");
    return "Error al interpretar la predicción de sequía";
  }
}
Future<Map<String, double>> fetchCropPrediction(double latitude, double longitude) async {
  try {
    // 1. Obtener datos de la API de la NASA
    Map<String, dynamic> nasaData = await fetchNasaData(latitude, longitude);

    // 2. Extraer los datos relevantes
    var temperatureData = nasaData['properties']['parameter']['T2M'] ?? {};
    var humidityData = nasaData['properties']['parameter']['QV2M'] ?? {};
    var precipitationData = nasaData['properties']['parameter']['PRECTOTCORR'] ?? {};

    // Calcular promedios
    double temperatureAvg = temperatureData.isNotEmpty
        ? temperatureData.values.reduce((a, b) => a + b) / temperatureData.length
        : 0.0;
    double humidityAvg = humidityData.isNotEmpty
        ? humidityData.values.reduce((a, b) => a + b) / humidityData.length
        : 0.0;
    double precipitationAvg = precipitationData.isNotEmpty
        ? precipitationData.values.reduce((a, b) => a + b) / precipitationData.length
        : 0.0;

    // 3. Preparar datos de entrada
    List<double> inputData = [
      100.0, // N
      90.0,  // P
      100.0, // K
      temperatureAvg, // Temperatura promedio
      7.0, // pH
      humidityAvg, // Humedad promedio
      precipitationAvg // Precipitación promedio
    ];

    debugPrint("Datos preparados para predicción de cultivos: $inputData");

    // 4. Enviar datos al servidor Flask
    final url = Uri.parse('https://web-production-25ec5.up.railway.app//predecirCrop');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode({'input': inputData}),
    );

    // 5. Procesar respuesta
    if (response.statusCode == 200) {
      Map<String, dynamic> result = json.decode(response.body);

      // Convertir las probabilidades a un mapa de String -> Double
      Map<String, double> cropPredictions = result.map((key, value) =>
          MapEntry(key, value is double ? value : double.parse(value.toString())));

      debugPrint("Predicciones de cultivos recibidas: $cropPredictions");

      return cropPredictions;
    } else {
      throw Exception("Error al obtener la predicción de cultivos: ${response.statusCode}");
    }
  } catch (e) {
    debugPrint("Error durante la predicción de cultivos: $e");
    return {};
  }
}

  // General prediction logic

Future<Map<String, dynamic>> makePredictions(double latitude, double longitude) async {

  // Inicializa modelos
  await initializeModels();

  // Obtén datos de la NASA
  Map<String, dynamic> nasaData = await fetchNasaData(latitude, longitude);
  var parameterData = nasaData['properties']['parameter'];
  var precipitationData = parameterData['PRECTOTCORR'] ?? {};
  var temperatureData = parameterData['T2M'] ?? {};
  var humidityData = parameterData['QV2M'] ?? {};
  var pressureData = parameterData['PS'] ?? {};
  var wind10mData = parameterData['WS10M'] ?? {};
  var wind50mData = parameterData['WS50M'] ?? {};

  // Calcula promedios
  double avgPrecipitation = precipitationData.isNotEmpty
      ? precipitationData.values.reduce((a, b) => a + b) / precipitationData.length
      : 0.0;
  double avgTemp = temperatureData.isNotEmpty
      ? temperatureData.values.reduce((a, b) => a + b) / temperatureData.length
      : 0.0;
  double avgHumidity = humidityData.isNotEmpty
      ? humidityData.values.reduce((a, b) => a + b) / humidityData.length
      : 0.0;
  double avgPressure = pressureData.isNotEmpty
      ? pressureData.values.reduce((a, b) => a + b) / pressureData.length
      : 0.0;
  double avgWind10m = wind10mData.isNotEmpty
      ? wind10mData.values.reduce((a, b) => a + b) / wind10mData.length
      : 0.0;
  double avgWind50m = wind50mData.isNotEmpty
      ? wind50mData.values.reduce((a, b) => a + b) / wind50mData.length
      : 0.0;

  // Prepara datos para el modelo de sequía
  List<int> droughtData = [
    avgPrecipitation.round(),
    avgPressure.round(),
    avgHumidity.round(),
    avgTemp.round(),
    (avgTemp - ((100 - avgHumidity) / 5)).round(),
    (avgTemp - 2).round(),
    (avgTemp + 5).round(),
    (avgTemp - 5).round(),
    (avgTemp + 5 - (avgTemp - 5)).round(),
    avgTemp.round(),
    avgWind10m.round(),
    (avgWind10m + 2).round(),
    (avgWind10m - 2).round(),
    ((avgWind10m + 2) - (avgWind10m - 2)).round(),
    avgWind50m.round(),
    (avgWind50m + 3).round(),
    (avgWind50m - 3).round(),
    ((avgWind50m + 3) - (avgWind50m - 3)).round(),
  ];

  // Asegúrate de convertir los datos a tipos estándar
  List<dynamic> droughtDataStandard = droughtData.map((e) => e.toInt()).toList();

  debugPrint("Datos preparados para sequía: $droughtDataStandard");

  // Enviar datos al servidor de predicción de sequía
  final droughtResponse = await http.post(
    Uri.parse('https://web-production-25ec5.up.railway.app//predecirDrought'),
    headers: {"Content-Type": "application/json"},
    body: json.encode({'input': droughtDataStandard}),
  );

  debugPrint("Respuesta del servidor de sequía: ${droughtResponse.body}");

  String droughtPrediction = droughtResponse.statusCode == 200
    ? _parseDroughtResponse(json.decode(droughtResponse.body))
    : 'Error al predecir sequía';
  Map<String,double > cropPrediction = await fetchCropPrediction(latitude, longitude);

  String floodPrediction = await fetchFloodPrediction(latitude, longitude);

  // Predicciones de incendio e inundación
  String firePrediction = await fetchFirePrediction(latitude, longitude);

  debugPrint("Predicción de incendio: $firePrediction");
  debugPrint("Predicción de inundación: $floodPrediction");
  debugPrint("Predicción de sequía: $droughtPrediction");
  debugPrint("Predicción de crop: $cropPrediction");

  return {
    'drought': droughtPrediction,
    'flood': floodPrediction,
    'fire': firePrediction,
    'crop': cropPrediction, // Como JSON para representarlo como string

  };
}

}
