import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../services/llm_service.dart';
import 'understanding_screen.dart';
import 'profile_screen.dart';

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
  bool _isProcessing = false;

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
          _statusText = 'Listening... Speak in English or Tanglish';
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
          _statusText = 'Microphone permission or speech recognition unavailable.';
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

    setState(() => _isProcessing = true);

    try {
      // 1. Save raw capture immediately
      final capture = await DatabaseHelper.instance.createCapture(text, source: _isListening ? 'voice' : 'text');

      // 2. AI Extraction (Calls LLM if enabled, otherwise built-in Edge NLP)
      final memories = await LLMService.instance.extractMemories(text, capture.id!);

      _textController.clear();
      setState(() {
        _statusText = '';
        _isProcessing = false;
      });

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

      if (saved == true && mounted) {
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showAISettings() {
    final urlController = TextEditingController(text: LLMService.instance.endpointUrl);
    final modelController = TextEditingController(text: LLMService.instance.modelName);
    bool enabled = LLMService.instance.isEnabled;
    String testStatus = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.psychology, color: AppTheme.goldAccent),
              SizedBox(width: 8),
              Text('AI Intelligence Engine', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MindBurst operates 100% offline. You can use the built-in Edge Engine or connect to your own offline LLM (Ollama, llama.cpp, PocketPal).',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.goldAccent,
                  title: const Text('Use Localhost Offline LLM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Connect to Ollama / llama.cpp / Termux', style: TextStyle(fontSize: 11)),
                  value: enabled,
                  onChanged: (val) {
                    setDlgState(() => enabled = val);
                  },
                ),
                if (enabled) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'LLM Endpoint URL',
                      hintText: 'http://127.0.0.1:11434',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: modelController,
                    decoration: const InputDecoration(
                      labelText: 'Model Name',
                      hintText: 'llama3.2 or gemma2',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.goldAccent,
                          side: const BorderSide(color: AppTheme.goldAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        icon: const Icon(Icons.cable, size: 16),
                        label: const Text('Test Connection', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          setDlgState(() => testStatus = 'Testing...');
                          final ok = await LLMService.instance.checkConnection(urlController.text.trim());
                          setDlgState(() {
                            testStatus = ok
                                ? '✅ Connected successfully!'
                                : '❌ Unreachable. Check if Ollama is running.';
                          });
                        },
                      ),
                    ],
                  ),
                  if (testStatus.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      testStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: testStatus.startsWith('✅') ? Colors.green : AppTheme.deleteRed,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.goldAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                LLMService.instance.isEnabled = enabled;
                LLMService.instance.endpointUrl = urlController.text.trim();
                LLMService.instance.modelName = modelController.text.trim();
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLLM = LLMService.instance.isEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MINDBURST ✦'),
        actions: [
          IconButton(
            icon: Icon(
              isLLM ? Icons.psychology : Icons.tune_outlined,
              color: AppTheme.primary,
            ),
            tooltip: 'AI Engine Settings',
            onPressed: _showAISettings,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14.0, left: 4.0),
            child: InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      onProfileUpdated: () {
                        setState(() {});
                      },
                    ),
                  ),
                );
                setState(() {});
              },
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppTheme.primary,
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              const Center(
                child: Text(
                  "What's on your mind?",
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Multiline Thought Input Area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.cardBorder, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18.0),
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                      height: 1.45,
                    ),
                    decoration: const InputDecoration(
                      hintText: "Type or tap the microphone to speak your thoughts...",
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),

              if (_statusText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isListening ? AppTheme.primary : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Mic Button (Tap-to-Speak with animated pulse)
              Center(
                child: ScaleTransition(
                  scale: _isListening ? _pulseController : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isListening
                          ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)])
                          : const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)]),
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? AppTheme.deleteRed : AppTheme.primary).withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: IconButton(
                      iconSize: 32,
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.white : AppTheme.primary,
                      ),
                      onPressed: _toggleListening,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Burst Action Button with Animated Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isProcessing ? null : _handleBurst,
                  child: _isProcessing
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '💥 Burst Thoughts',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
