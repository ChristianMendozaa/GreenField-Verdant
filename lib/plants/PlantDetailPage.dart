import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PlantDetailPage extends StatefulWidget {
  final Map<String, dynamic> plant;

  const PlantDetailPage({Key? key, required this.plant}) : super(key: key);

  @override
  _PlantDetailPageState createState() => _PlantDetailPageState();
}

class _PlantDetailPageState extends State<PlantDetailPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final String _apiKey = "8cd6995d-a404-4f2c-bbb0-0eec439d82d3";
  final String _apiUrl = "https://api.sambanova.ai/v1/chat/completions";

  String _generateContextPrompt(Map<String, dynamic> plant) {
    return """
Eres un asistente especializado en el cuidado de plantas. Esta es la información de la planta:
- Nombre: ${plant['name']}
- Estado de salud: ${plant['prediction']}
- Notas adicionales: ${plant['notes'] ?? "No hay notas adicionales."}

Usa esta información para ayudar al usuario con preguntas sobre cómo cuidar esta planta o entender su estado.
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
              "content": _generateContextPrompt(widget.plant),
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
    final plant = widget.plant;

    return Scaffold(
      appBar: AppBar(
        title: Text(plant['name']),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(plant['imageUrl'], height: 200, fit: BoxFit.cover),
                const SizedBox(height: 10),
                Text(
                  "Nombre: ${plant['name']}",
                  style: const TextStyle(fontSize: 18),
                ),
                Text(
                  "Estado: ${plant['prediction']}",
                  style: const TextStyle(fontSize: 16),
                ),
                if (plant['notes'] != null)
                  Text(
                    "Notas: ${plant['notes']}",
                    style: const TextStyle(fontSize: 16),
                  ),
              ],
            ),
          ),
          const Divider(),
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
