import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import 'package:coldguard/tools.dart';
import 'device_config.dart';
import 'settings_screen.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  const ChatMessage({required this.text, required this.isUser});
}

class ChatScreen extends StatefulWidget {
  final LiteLmEngine engine;
  const ChatScreen({super.key, required this.engine});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _streamingText; // non-null while tokens are arriving
  bool _showRestartBanner = false;
  LiteLmConversation? _conversation;

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  // Builds the Qwen tool-calling system prompt. Persona comes from DeviceConfig
  // so users can customise it in Settings without touching code.
  String _buildSystemInstruction(List<Map<String, dynamic>> tools) {
    final toolsJson = tools.map((t) => jsonEncode(t)).join('\n');
    final c = DeviceConfig.instance;
    return '''${c.customPrompt}
DEVICE PINS: red_led=${c.redLedPin}, green_led=${c.greenLedPin}, buzzer=${c.buzzerPin}, fan=${c.fanPin}
# Tools
<tools>
$toolsJson
</tools>

For each function call return a json object within <tool_call></tool_call> tags. For multiple actions, output multiple separate <tool_call> blocks:
<tool_call>
{"name": "function-name", "arguments": {"arg": "value"}}
</tool_call>''';
  }

  // Extracts all top-level JSON objects from a string, even if concatenated.
  List<Map<String, dynamic>> _extractJsonObjects(String text) {
    final results = <Map<String, dynamic>>[];
    int depth = 0;
    int start = -1;
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0 && start != -1) {
          try {
            final obj = jsonDecode(text.substring(start, i + 1));
            if (obj is Map<String, dynamic>) results.add(obj);
          } catch (_) {}
          start = -1;
        }
      }
    }
    return results;
  }

  // Parses all <tool_call> blocks. Handles both separate blocks and multiple
  // JSON objects concatenated inside a single block.
  List<Map<String, dynamic>> _parseAllToolCalls(String text) {
    final matches = RegExp(
      r'<tool_call>(.*?)</tool_call>',
      dotAll: true,
    ).allMatches(text);
    return matches
        .expand((m) => _extractJsonObjects(m.group(1)!.trim()))
        .toList();
  }

  Future<void> _initConversation() async {
    final tools = getColdChainTools().map((t) => t.toMap()).toList();
    final conversation = await widget.engine.createConversation(
      LiteLmConversationConfig(
        systemInstruction: _buildSystemInstruction(tools),
      ),
    );
    setState(() => _conversation = conversation);
  }

  void _resetConversation() {
    _conversation?.dispose();
    setState(() {
      _messages.clear();
      _streamingText = null;
      _isLoading = false;
      _showRestartBanner = false;
      _conversation = null;
    });
    _initConversation();
  }

  Future<void> _openSettings() async {
    final promptChanged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (promptChanged == true && mounted) {
      setState(() => _showRestartBanner = true);
    }
  }

  String _clean(String text) => text
      .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
      .replaceAll(RegExp(r'<tool_call>.*?</tool_call>', dotAll: true), '')
      .replaceAll(RegExp(r'<tool_call>.*', dotAll: true), '')
      .trim();

  // Strips think blocks AND any partial/complete tool_call blocks so they
  // never appear in the live streaming bubble.
  String _cleanForDisplay(String text) => text
      .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
      .replaceAll(RegExp(r'<tool_call>.*', dotAll: true), '')
      .trim();

  void _scrollToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading || _conversation == null) return;

    HapticFeedback.lightImpact();
    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
      _streamingText = ''; // empty string = waiting for first token
    });
    _scrollToNewest();

    try {
      // Stream tokens and accumulate into buffer.
      final buffer = StringBuffer();
      await for (final delta in _conversation!.sendMessageStream(text)) {
        buffer.write(delta.text);
        setState(() {
          _streamingText = _cleanForDisplay(buffer.toString());
        });
      }

      final fullResponse = buffer.toString();
      final toolCalls = _parseAllToolCalls(fullResponse);

      if (toolCalls.isNotEmpty) {
        // Hide streaming bubble while executing tools.
        setState(() => _streamingText = null);

        LiteLmMessage? finalReply;
        for (final call in toolCalls) {
          final name = call['name'] as String;
          final arguments = Map<String, dynamic>.from(call['arguments'] as Map);
          final handler = toolHandlers[name];
          final result = await handler!(arguments);
          finalReply = await _conversation!.sendMessage(
            '<tool_response>\n$result\n</tool_response>',
          );
        }
        setState(() {
          _messages.add(
            ChatMessage(text: _clean(finalReply!.text), isUser: false),
          );
        });
      } else {
        setState(() {
          _messages.add(ChatMessage(text: _clean(fullResponse), isUser: false));
          _streamingText = null;
        });
      }
      _scrollToNewest();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
        _streamingText = null;
      });
      _scrollToNewest();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _conversation?.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_showRestartBanner)
            Container(
              color: const Color(0xFF2979FF).withValues(alpha: 0.08),
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFF2979FF)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Settings updated — restart conversation to apply.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF2979FF)),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetConversation,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2979FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoading && index == 0) {
                        final s = _streamingText;
                        if (s != null && s.isNotEmpty) {
                          // Live streaming bubble — same key keeps it stable
                          // across token updates so the animation only plays once.
                          return _MessageBubble(
                            key: const ValueKey('__stream__'),
                            message: ChatMessage(text: s, isUser: false),
                          );
                        }
                        return const _TypingIndicator();
                      }
                      final msgIndex = _messages.length -
                          1 -
                          (_isLoading ? index - 1 : index);
                      return _MessageBubble(
                        key: ValueKey(msgIndex),
                        message: _messages[msgIndex],
                      );
                    },
                  ),
          ),
          _buildInputArea(context),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: Column(
        children: [
          const Text(
            'ColdGuard',
            style: TextStyle(
              color: Color(0xFF0D1B2A),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _conversation != null
                      ? const Color(0xFF4CAF50)
                      : Colors.orange,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _conversation != null ? 'Ready' : 'Connecting…',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B8AAD),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_rounded, size: 20),
          color: const Color(0xFF6B8AAD),
          onPressed: _openSettings,
          tooltip: 'Settings',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE0E8F4)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.vaccines_rounded,
            size: 36,
            color: const Color(0xFF2979FF).withValues(alpha: 0.22),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ask ColdGuard anything',
            style: TextStyle(
              color: Color(0xFF6B8AAD),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE0E8F4), width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  color: Color(0xFF0D1B2A),
                  fontSize: 15,
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  hintText: 'Message ColdGuard…',
                  hintStyle: TextStyle(
                    color: Color(0xFF6B8AAD),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isLoading
                    ? const Color(0xFF2979FF).withValues(alpha: 0.35)
                    : const Color(0xFF2979FF),
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.arrow_upward_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated message bubble ──────────────────────────────────────────────────

class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  const _MessageBubble({super.key, required this.message});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.74,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? const Color(0xFF2979FF)
                  : const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 5),
                bottomRight: Radius.circular(isUser ? 5 : 20),
              ),
              border: isUser
                  ? null
                  : Border.all(color: const Color(0xFFD0DEEF), width: 1),
            ),
            child: Text(
              widget.message.text,
              style: TextStyle(
                color: isUser ? Colors.white : const Color(0xFF0D1B2A),
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Typing indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _dots;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _dots = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 480),
      );
      Future.delayed(Duration(milliseconds: i * 140), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
    _anims = _dots
        .map(
          (c) => Tween<double>(begin: 0, end: -5).animate(
            CurvedAnimation(parent: c, curve: Curves.easeInOut),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final c in _dots) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF4FF),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: const Color(0xFFD0DEEF), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _anims[i],
              builder: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Transform.translate(
                  offset: Offset(0, _anims[i].value),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2979FF).withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
