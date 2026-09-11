import 'dart:convert';
import 'dart:io';
import '../models/memory_model.dart';
import 'ai_extractor.dart';

class LLMService {
  static final LLMService instance = LLMService._init();
  LLMService._init();

  // Configuration
  String endpointUrl = 'http://127.0.0.1:11434'; // Default Ollama port
  String modelName = 'llama3.2';
  bool isEnabled = false; // By default off, user can enable if they have local LLM

  /// Tests whether a local LLM server is reachable within 1.5 seconds
  Future<bool> checkConnection([String? customUrl]) async {
    final url = customUrl ?? endpointUrl;
    try {
      final uri = Uri.parse(url.endsWith('/') ? '${url}api/tags' : '$url/api/tags');
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1500);
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(milliseconds: 1500));
      return response.statusCode == 200;
    } catch (_) {
      // Also try llama.cpp health endpoint
      try {
        final uri = Uri.parse(url.endsWith('/') ? '${url}health' : '$url/health');
        final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1500);
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(const Duration(milliseconds: 1500));
        return response.statusCode == 200;
      } catch (_) {
        return false;
      }
    }
  }

  /// Extracts memories using the offline LLM if available, otherwise falls back to AIExtractor
  Future<List<Memory>> extractMemories(String text, int captureId) async {
    if (!isEnabled) {
      return AIExtractor.extractMemories(text, captureId);
    }

    try {
      final prompt = '''
You are MindBurst, a personal thought structuring AI.
Extract distinct tasks, carry items, shopping items, events, or notes from this input:
"$text"

Respond ONLY with a JSON array of objects with these exact keys:
[
  {
    "type": "Task" | "Carry" | "Shopping" | "Event" | "Note",
    "category": "Tasks" | "Carry" | "Shopping" | "Events" | "Reminders" | "Projects" | "Notes",
    "title": "Concise actionable title",
    "details": "Original details",
    "date": "YYYY-MM-DD or null",
    "time": "HH:MM or null",
    "retention": "Temporary" | "Permanent",
    "people": ["name"],
    "places": ["place"],
    "items": ["item"],
    "projects": ["project"]
  }
]
No other text, only valid JSON array.
''';

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(endpointUrl.endsWith('/') ? '${endpointUrl}api/generate' : '$endpointUrl/api/generate');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;

      final body = jsonEncode({
        'model': modelName,
        'prompt': prompt,
        'stream': false,
        'format': 'json',
      });
      request.write(body);

      final response = await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final respStr = await response.transform(utf8.decoder).join();
        final jsonResp = jsonDecode(respStr);
        final content = jsonResp['response'] ?? '';
        final List parsed = jsonDecode(content);

        List<Memory> result = [];
        for (final item in parsed) {
          result.add(Memory(
            captureId: captureId,
            type: item['type'] ?? 'Task',
            category: item['category'] ?? 'Tasks',
            title: item['title'] ?? text,
            details: item['details'] ?? text,
            date: item['date'] != null ? AIExtractor.resolveDate(item['date']) : null,
            time: item['time'],
            retention: item['retention'] ?? 'Temporary',
            people: List<String>.from(item['people'] ?? []),
            places: List<String>.from(item['places'] ?? []),
            items: List<String>.from(item['items'] ?? []),
            projects: List<String>.from(item['projects'] ?? []),
            originalText: text,
          ));
        }
        if (result.isNotEmpty) return result;
      }
    } catch (_) {
      // Fallback seamlessly to local rule-based extractor
    }

    return AIExtractor.extractMemories(text, captureId);
  }

  /// Answers a question using offline LLM with memories as context, or falls back to GroundedQA
  Future<String?> askLLM(String question, List<Memory> memories) async {
    if (!isEnabled) return null;

    try {
      final contextNotes = memories.map((m) => '- [${m.category}] ${m.title} (Date: ${m.date ?? "None"}, People: ${m.people.join(", ")}, Items: ${m.items.join(", ")})').join('\n');

      final prompt = '''
You are MindBurst, a strictly grounded offline assistant.
Answer the user's question using ONLY the facts in the user memories below.
If the answer cannot be found in the memories, say "I couldn't find anything relevant in your memories."
Do NOT invent or hallucinate any facts.

User Memories:
$contextNotes

User Question:
$question

Answer:
''';

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(endpointUrl.endsWith('/') ? '${endpointUrl}api/generate' : '$endpointUrl/api/generate');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;

      final body = jsonEncode({
        'model': modelName,
        'prompt': prompt,
        'stream': false,
      });
      request.write(body);

      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final respStr = await response.transform(utf8.decoder).join();
        final jsonResp = jsonDecode(respStr);
        return jsonResp['response']?.toString().trim();
      }
    } catch (_) {}

    return null;
  }
}
