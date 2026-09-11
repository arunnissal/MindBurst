import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../models/memory_model.dart';
import '../database/db_helper.dart';
import '../services/grounded_qa.dart';
import '../services/llm_service.dart';
import 'memory_detail_screen.dart';

class QAMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Memory>? sourceMemories;

  QAMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.sourceMemories,
  });
}

class AskScreen extends StatefulWidget {
  const AskScreen({super.key});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<QAMessage> _messages = [];
  bool _isSearching = false;

  late stt.SpeechToText _speech;
  bool _isListening = false;

  final List<String> _suggestions = [
    'Where do I need to go?',
    'What should I carry?',
    'What tasks are scheduled?',
    'What do I need to buy?',
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      bool available = false;
      try {
        available = await _speech.initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              if (mounted) setState(() => _isListening = false);
            }
          },
          onError: (_) {
            if (mounted) setState(() => _isListening = false);
          },
        );
      } catch (_) {}

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _queryController.text = result.recognizedWords;
            });
            if (result.finalResult) {
              setState(() => _isListening = false);
              _handleSend();
            }
          },
        );
      }
    }
  }

  Future<void> _handleSend([String? presetQuery]) async {
    final query = presetQuery ?? _queryController.text.trim();
    if (query.isEmpty) return;

    _queryController.clear();
    setState(() {
      _messages.add(QAMessage(
        text: query,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isSearching = true;
    });

    _scrollToBottom();

    // Fetch all active memories
    final allMemories = await DatabaseHelper.instance.getActiveMemories();

    // Also check for direct search query matches
    final queryMatches = await DatabaseHelper.instance.getActiveMemories(query: query);

    // Combine memories for GroundedQA
    final combinedMemories = <int, Memory>{};
    for (final m in queryMatches) {
      if (m.id != null) combinedMemories[m.id!] = m;
    }
    for (final m in allMemories) {
      if (m.id != null && !combinedMemories.containsKey(m.id)) {
        combinedMemories[m.id!] = m;
      }
    }

    final memoriesList = combinedMemories.values.toList();
    String answer = '';
    final llmAns = await LLMService.instance.askLLM(query, memoriesList);
    if (llmAns != null && llmAns.trim().isNotEmpty) {
      answer = llmAns.trim();
    } else {
      answer = GroundedQA.answerQuestion(query, memoriesList);
    }

    // Filter relevant memories cited
    List<Memory> sources = [];
    final qLower = query.toLowerCase();
    for (final m in memoriesList) {
      if (qLower.contains('carry') && (m.type == 'Carry' || m.category == 'Carry' || m.items.isNotEmpty)) {
        sources.add(m);
      } else if (qLower.contains('rahul') && (m.people.any((p) => p.toLowerCase().contains('rahul')) || m.title.toLowerCase().contains('rahul'))) {
        sources.add(m);
      } else if (qLower.contains('project') && (m.projects.isNotEmpty || m.category == 'Projects')) {
        sources.add(m);
      } else if (queryMatches.any((qm) => qm.id == m.id)) {
        sources.add(m);
      }
    }

    if (!mounted) return;

    setState(() {
      _isSearching = false;
      _messages.add(QAMessage(
        text: answer,
        isUser: false,
        timestamp: DateTime.now(),
        sourceMemories: sources.take(4).toList(),
      ));
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ASK YOUR MIND ✦'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.goldAccent),
              tooltip: 'Clear Chat',
              onPressed: () {
                setState(() => _messages.clear());
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Subtitle bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.goldAccentLight,
            child: const Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: AppTheme.goldAccent),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '100% Offline & Grounded — Answers strictly from saved memories.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.goldAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Message history or empty state
          Expanded(
            child: _messages.isEmpty
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: AppTheme.goldAccentLight,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.goldBorder, width: 1.5),
                          ),
                          child: const Icon(Icons.psychology_outlined, size: 36, color: AppTheme.goldAccent),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ask Anything',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'MindBurst searches all your personal notes, tasks, items to carry, and people without hallucinating.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'TRY ASKING:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _suggestions.map((s) {
                            return ActionChip(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: AppTheme.goldBorder),
                              label: Text(s, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                              onPressed: () => _handleSend(s),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isSearching ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isSearching && index == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.goldAccent),
                            ),
                          ),
                        );
                      }

                      final msg = _messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),

          // Bottom Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: AppTheme.cardBg,
              border: Border(top: BorderSide(color: AppTheme.goldBorder, width: 0.8)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Mic button
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? AppTheme.deleteRed : AppTheme.goldAccent,
                    ),
                    onPressed: _toggleListening,
                  ),

                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      decoration: const InputDecoration(
                        hintText: 'Ask your memories...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send button
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.goldAccent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: () => _handleSend(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(QAMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.goldAccent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // AI Response bubble
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 30),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppTheme.goldBorder, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.goldAccentLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.bubble_chart, size: 14, color: AppTheme.goldAccent),
                ),
                const SizedBox(width: 8),
                const Text(
                  'MindBurst Intelligence',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.goldAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              msg.text,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),

            // Sourced memories chips
            if (msg.sourceMemories != null && msg.sourceMemories!.isNotEmpty) ...[
              const Divider(color: AppTheme.goldBorder, height: 18),
              const Text(
                'SOURCED MEMORIES:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              ...msg.sourceMemories!.map((sm) => InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MemoryDetailScreen(memory: sm)),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.goldAccentLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_right, size: 14, color: AppTheme.goldAccent),
                          Expanded(
                            child: Text(
                              sm.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            sm.category,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.goldAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
