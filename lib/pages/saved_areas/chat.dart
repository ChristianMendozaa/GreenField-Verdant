import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> contextData;

  const ChatScreen({Key? key, required this.contextData}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final String _apiKey = "8cd6995d-a404-4f2c-bbb0-0eec439d82d3";
  final String _apiUrl = "https://api.sambanova.ai/v1/chat/completions";

  String _getColorName(Color color) {
    // Mapa con valores ARGB como claves
    const Map<int, String> colorNames = {
      0xFFFF0000: "Rojo",
      0xFF00FF00: "Verde",
      0xFF0000FF: "Azul",
      0xFFFFFF00: "Amarillo",
      0xFFFFA500: "Naranja",
      0xFF800080: "Morado",
      0xFF808080: "Gris",
      0xFFFFFFFF: "Blanco",
      0xFF000000: "Negro",
    };

    // Encuentra el color más cercano en la lista
    String closestColorName = "Desconocido";
    int closestDistance = 100000; // Un valor inicial grande
    colorNames.forEach((colorValue, name) {
      // Convierte el valor ARGB a un objeto Color para compararlo
      final Color knownColor = Color(colorValue);

      // Calcula la distancia RGB
      final int distance = (color.red - knownColor.red).abs() +
          (color.green - knownColor.green).abs() +
          (color.blue - knownColor.blue).abs();

      // Actualiza el color más cercano si la distancia es menor
      if (distance < closestDistance) {
        closestDistance = distance;
        closestColorName = name;
      }
    });

    return closestColorName;
  }

 String _generateContextPrompt(Map<String, dynamic> area) {
  final Color color = area['color'];
  final String colorName = _getColorName(color); // Usa el nombre del color.

  final floodPrediction = area['floodPrediction'] == "1"
      ? "Se espera inundación en esta área."
      : "No se espera inundación en esta área.";
  final droughtPrediction = area['droughtPrediction'];
  final droughtLevel = int.tryParse(droughtPrediction ?? "0") ?? 0;
  final droughtDescription = droughtLevel == 0
      ? "Sin sequía."
      : droughtLevel == 5
          ? "Sequía extrema."
          : "Nivel de sequía: $droughtLevel.";
  final firePrediction = area['firePrediction'] ?? "0";
  final fireArea = double.tryParse(firePrediction) ?? 0.0;
  final fireDescription = fireArea > 0
      ? "Área estimada afectada por incendios: ${fireArea.toStringAsFixed(2)} m²."
      : "No se espera afectación por incendios.";

  final selectedCrop = area['selectedCrop'] ?? "No seleccionado.";
  final cropProbability = area['cropProbability'] != null
      ? "${area['cropProbability']}%"
      : "Probabilidad no disponible.";

  return """
Eres un asistente que ayuda a los usuarios agricultores con información detallada sobre un área específica. Esta es la información del área:
- Nombre: ${area['name']}
- Color asociado: $colorName
- Predicción de inundaciones: $floodPrediction
- Predicción de sequías: $droughtDescription
- Predicción de incendios: $fireDescription
- Cultivo seleccionado: $selectedCrop
- Probabilidad de éxito del cultivo: $cropProbability

Usa esta información para responder preguntas del usuario sobre el área, sus posibles riesgos y la viabilidad del cultivo seleccionado.
""";
}

  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "content": message});
    });

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "Meta-Llama-3.1-8B-Instruct",
          "messages": [
            {
              "role": "system",
              "content": _generateContextPrompt(widget.contextData),
            },
            ..._messages,
          ],
          "temperature": 0.1,
          "top_p": 0.1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final assistantMessage = data['choices'][0]['message']['content'];

        setState(() {
          _messages.add({"role": "assistant", "content": assistantMessage});
        });
      } else {
        throw Exception("Error al obtener respuesta de la API");
      }
    } catch (e) {
      setState(() {
        _messages.add({"role": "assistant", "content": "Error: $e"});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat Asistente"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message["role"] == "user";
                return Container(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  margin:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(message["content"] ?? ""),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Escribe un mensaje...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    final message = _controller.text;
                    _controller.clear();
                    _sendMessage(message);
                  },
                  child: const Text("Enviar"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
