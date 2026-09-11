import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../services/ai_extractor.dart';
import 'understanding_screen.dart';

class BurstScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const BurstScreen({super.key, required this.onSaved});

  @override
  State<BurstScreen> createState() => _BurstScreenState();
}

class _BurstScreenState extends State<BurstScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _statusText = '';
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.9,
      upperBound: 1.15,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _pulseController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _pulseController.forward();
        }
      });
  }

  @override
  void dispose() {
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _statusText = '';
      });
      _pulseController.stop();
    } else {
      bool available = false;
      try {
        available = await _speech.initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              setState(() {
                _isListening = false;
                _statusText = '';
              });
              _pulseController.stop();
            }
          },
          onError: (error) {
            setState(() {
              _isListening = false;
              _statusText = 'Speech error: ${error.errorMsg}';
            });
            _pulseController.stop();
          },
        );
      } catch (e) {
        available = false;
      }

      if (available) {
        setState(() {
          _isListening = true;
          _statusText = 'Listening… 🎙';
        });
        _pulseController.forward();
        _speech.listen(
          onResult: (result) {
            setState(() {
              _textController.text = result.recognizedWords;
            });
          },
        );
      } else {
        setState(() {
          _statusText = 'Speech recognition unavailable on this device.';
        });
      }
    }
  }

  Future<void> _handleBurst() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or speak a thought first!')),
      );
      return;
    }

    // 1. Save raw capture immediately
    final capture = await DatabaseHelper.instance.createCapture(text, source: _isListening ? 'voice' : 'text');

    // 2. AI Extraction
    final memories = AIExtractor.extractMemories(text, capture.id!);

    _textController.clear();
    setState(() => _statusText = '');

    if (!mounted) return;

    // 3. Navigate to Understanding Review Screen
    final bool? saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => UnderstandingScreen(
          capture: capture,
          initialMemories: memories,
        ),
      ),
    );

    if (saved == true) {
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'MINDBURST ✦',
                  style: TextStyle(
                    color: AppTheme.goldAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  "What's on your mind?",
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Input Card
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(fontSize: 16, height: 1.4, color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        hintText: 'Type or speak anything...\n\n• Tasks & reminders\n• Items to carry\n• Ideas & thoughts\n• Shopping lists\n\nSupports English & Tanglish!',
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Status indicator
              if (_statusText.isNotEmpty)
                Center(
                  child: Text(
                    _statusText,
                    style: const TextStyle(
                      color: AppTheme.goldAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Mic Button (Tap-to-Speak)
              Center(
                child: ScaleTransition(
                  scale: _isListening ? _pulseController : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? AppTheme.deleteRed.withOpacity(0.15) : AppTheme.goldAccentLight,
                      border: Border.all(
                        color: _isListening ? AppTheme.deleteRed : AppTheme.goldBorder,
                        width: 1.5,
                      ),
                    ),
                    child: IconButton(
                      iconSize: 32,
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? AppTheme.deleteRed : AppTheme.goldAccent,
                      ),
                      onPressed: _toggleListening,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Burst Action Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: _handleBurst,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '💥 Burst',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
