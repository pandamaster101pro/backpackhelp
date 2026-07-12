import 'package:flutter/material.dart';
import 'package:ollama_dart/ollama_dart.dart';

class Ai extends StatefulWidget {
  const Ai({super.key});

  @override
  State<Ai> createState() => _AiState();
}

class _AiState extends State<Ai> {
  Future<void> Ollama() async {
    final client = OllamaClient(baseUrl: 'http://10.0.2.2:11434/api');

    try {
      final response = await client.chat.create(
        request: ChatRequest(
          model: 'gpt-oss',
          messages: [ChatMessage.user('Explain what Dart isolates do.')],
        ),
      );

      print(response.message?.content);
    } finally {
      client.close();
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
              onPressed: (){
                Ollama();
              },
              child: Text("Test ai"))

        ],
      ),
    );
  }
}
