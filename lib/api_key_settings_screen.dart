import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _openAiController = TextEditingController(text: 'sk-******');
  // final _groqController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApiKeys();
  }

  Future<void> _loadApiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _openAiController.text = prefs.getString('OPENAI_API_KEY') ?? '';
      // _groqController.text = prefs.getString('GROQ_API_KEY') ?? '';
    });
  }

  Future<void> _saveApiKeys() async {
    print('Saving API keys...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('OPENAI_API_KEY', _openAiController.text);
    // await prefs.setString('GROQ_API_KEY', _groqController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('API keys saved successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cloud Transcription API Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildApiKeyField('OpenAI API Key', _openAiController),
            // _buildApiKeyField('Groq API Key', _groqController),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveApiKeys,
              child: Text('Save API Keys'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Enter your API key (starts with sk-...)',
          border: OutlineInputBorder(),
        ),
        obscureText: true,
      ),
    );
  }

  @override
  void dispose() {
    _openAiController.dispose();
    // _groqController.dispose();
    super.dispose();
  }
}
