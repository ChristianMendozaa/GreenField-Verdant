import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

class PredictionService {
  double? latitude;
  double? longitude;

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
    final currentDate =
        DateFormat('yyyyMMdd').format(DateTime.now()); // Fecha actual
    final parameters = "PRECTOTCORR,PS,QV2M,T2M,WS10M,WS50M";

    final nasaUrl = Uri.parse(
        'https://power.larc.nasa.gov/api/temporal/hourly/point'
        '?start=$currentDate&end=$currentDate&latitude=$latitude&longitude=$longitude'
        '&community=ag&parameters=$parameters&format=json&time-standard=lst');

    final response = await http.get(nasaUrl);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener datos de la API de la NASA');
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

  // Predicción de incendios
  Future<String> fetchFirePrediction(double latitude, double longitude) async {
    // Paso 1: Obtener los datos relevantes de la API de la NASA
    Map<String, dynamic> nasaData = await fetchNasaData(latitude, longitude);

    var parameterData = nasaData['properties']['parameter'];
    var temperatureData = parameterData['T2M'] ?? {};
    var humidityData = parameterData['QV2M'] ?? {};
    var wind10mData = parameterData['WS10M'] ?? {};
    var pressureData = parameterData['PS'] ?? {};
    var rainData =
        parameterData['PRECTOTCORR'] ?? {}; // Precipitación total corregida

    // Paso 2: Calcular promedios necesarios
    double avgTemp = temperatureData.isNotEmpty
        ? temperatureData.values.reduce((a, b) => a + b) /
            temperatureData.length
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
        : 0.0; // Calcular promedio de lluvia

    // Paso 3: Crear los datos de entrada para el modelo
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

    print(fireData);
    // Paso 4: Enviar los datos al servidor Flask
    final fireResponse = await http.post(
      Uri.parse(
          'http://192.168.104.220:5000/predecirFire'), // Ruta del modelo en Flask
      headers: {"Content-Type": "application/json"},
      body: json.encode({'input': fireData}),
    );

    // Paso 5: Manejar la respuesta del servidor
    if (fireResponse.statusCode == 200) {
      return json.decode(fireResponse.body)['prediction'].toString();
    } else {
      throw Exception('Error al predecir incendios: ${fireResponse.body}');
    }
  }

  // General prediction logic
  Future<Map<String, String>> makePredictions(
      double latitude, double longitude) async {
    // Fetch NASA data for drought prediction
    Map<String, dynamic> nasaData = await fetchNasaData(latitude, longitude);

    // Drought prediction logic
    var parameterData = nasaData['properties']['parameter'];
    var precipitationData = parameterData['PRECTOTCORR'] ?? {};
    var temperatureData = parameterData['T2M'] ?? {};
    var humidityData = parameterData['QV2M'] ?? {};
    var pressureData = parameterData['PS'] ?? {};
    var wind10mData = parameterData['WS10M'] ?? {};
    var wind50mData = parameterData['WS50M'] ?? {};

    double avgPrecipitation = precipitationData.isNotEmpty
        ? precipitationData.values.reduce((a, b) => a + b) /
            precipitationData.length
        : 0.0;
    double avgTemp = temperatureData.isNotEmpty
        ? temperatureData.values.reduce((a, b) => a + b) /
            temperatureData.length
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

    final droughtResponse = await http.post(
      Uri.parse('http://192.168.104.220:5000/predecirDrought'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({'input': droughtData}),
    );

    // Flood prediction logic
    List<double> monthlyAverages =
        await fetchMonthlyPrecipitation(latitude, longitude);

    final floodResponse = await http.post(
      Uri.parse('http://192.168.104.220:5000/predecirFlood'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({'input': monthlyAverages}),
    );

    // Fire prediction logic
    String firePrediction = 'Error al predecir incendios';
    try {
      firePrediction = await fetchFirePrediction(latitude, longitude);
    } catch (e) {
      print('Error en predicción de incendios: $e');
    }

    String droughtPrediction = droughtResponse.statusCode == 200
        ? json.decode(droughtResponse.body)['prediction'].toString()
        : 'Error al predecir sequía';

    String floodPrediction = floodResponse.statusCode == 200
        ? json.decode(floodResponse.body)['prediction'].toString()
        : 'Error al predecir inundación';

    return {
      'drought': droughtPrediction,
      'flood': floodPrediction,
      'fire': firePrediction,
    };
  }
}
