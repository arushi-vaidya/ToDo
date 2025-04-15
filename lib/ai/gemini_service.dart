import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final String apiKey = 'AIzaSyD3XQz_NDWiNT00hXA0S4QMW6oOBZxR938'; // Replace with your actual API key

  Future<String> generateInsights(String prompt) async {
    try {
      final model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: apiKey);
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text ?? 'No insights generated.';
    } catch (e) {
      return 'Error generating insights: $e';
    }
  }
}