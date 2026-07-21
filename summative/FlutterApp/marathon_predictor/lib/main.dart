import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MarathonPredictorApp());
}

class MarathonPredictorApp extends StatelessWidget {
  const MarathonPredictorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marathon Finish Predictor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2A9D8F)),
        useMaterial3: true,
      ),
      home: const PredictionPage(),
    );
  }
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  static const String apiUrl =
      'https://linear-regression-model-tru9.onrender.com/predict';

  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _k5Controller = TextEditingController();
  final _k10Controller = TextEditingController();
  final _k15Controller = TextEditingController();
  final _k20Controller = TextEditingController();
  final _halfController = TextEditingController();

  String _result = '';
  bool _isError = false;
  bool _loading = false;

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _result = '';
      _isError = false;
    });

    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'age': int.parse(_ageController.text),
              'gender': _genderController.text.trim().toUpperCase(),
              'k5': double.parse(_k5Controller.text),
              'k10': double.parse(_k10Controller.text),
              'k15': double.parse(_k15Controller.text),
              'k20': double.parse(_k20Controller.text),
              'half': double.parse(_halfController.text),
            }),
          )
          .timeout(const Duration(seconds: 90));

      final body = jsonDecode(response.body);

      setState(() {
        if (response.statusCode == 200) {
          _result =
              'Predicted finish time: ${body['predicted_finish_formatted']} '
              '(${body['predicted_finish_minutes']} minutes)';
          _isError = false;
        } else if (response.statusCode == 422) {
          final detail = body['detail'];
          final message = detail is List
              ? detail.map((e) => e['msg']).join('\n')
              : detail.toString();
          _result = 'Invalid input:\n$message';
          _isError = true;
        } else {
          _result = 'Server error (${response.statusCode}). Please try again.';
          _isError = true;
        }
      });
    } catch (e) {
      setState(() {
        _result = 'Could not reach the API. Check your internet connection.\n'
            'Note: the free server may take up to a minute to wake up — '
            'please try again.';
        _isError = true;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _numberField(TextEditingController controller, String label,
      {bool isInt = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Required';
          }
          final parsed =
              isInt ? int.tryParse(value.trim()) : double.tryParse(value.trim());
          if (parsed == null) {
            return 'Enter a valid number';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marathon Finish Predictor'),
        backgroundColor: const Color(0xFF2A9D8F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter the runner\'s profile and first-half split times '
                '(in minutes) to predict their marathon finish time.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              _numberField(_ageController, 'Age (years)', isInt: true),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _genderController,
                  decoration: const InputDecoration(
                    labelText: 'Gender (M or F)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final v = value?.trim().toUpperCase() ?? '';
                    if (v.isEmpty) return 'Required';
                    if (v != 'M' && v != 'F') return 'Enter M or F';
                    return null;
                  },
                ),
              ),
              _numberField(_k5Controller, '5K split (minutes)'),
              _numberField(_k10Controller, '10K split (minutes)'),
              _numberField(_k15Controller, '15K split (minutes)'),
              _numberField(_k20Controller, '20K split (minutes)'),
              _numberField(_halfController, 'Half-marathon split (minutes)'),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _loading ? null : _predict,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2A9D8F),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Predict', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
              if (_result.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isError
                        ? Colors.red.withOpacity(0.08)
                        : const Color(0xFF2A9D8F).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isError ? Colors.red : const Color(0xFF2A9D8F),
                    ),
                  ),
                  child: Text(
                    _result,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isError
                          ? Colors.red.shade800
                          : const Color(0xFF1D6E64),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}