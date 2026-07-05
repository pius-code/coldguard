import 'package:flutter/material.dart';
import 'device_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _cfg = DeviceConfig.instance;

  // Pin controllers
  late final TextEditingController _redLed;
  late final TextEditingController _greenLed;
  late final TextEditingController _buzzer;
  late final TextEditingController _fan;
  late final TextEditingController _dht;

  // Buzzer PWM controllers
  late final TextEditingController _buzzerFreq;
  late final TextEditingController _buzzerDuty;
  late final TextEditingController _buzzerChannel;

  // MQTT topic controllers
  late final TextEditingController _commandTopic;
  late final TextEditingController _responseTopic;

  // Prompt controller
  late final TextEditingController _prompt;

  @override
  void initState() {
    super.initState();
    _redLed = TextEditingController(text: _cfg.redLedPin.toString());
    _greenLed = TextEditingController(text: _cfg.greenLedPin.toString());
    _buzzer = TextEditingController(text: _cfg.buzzerPin.toString());
    _fan = TextEditingController(text: _cfg.fanPin.toString());
    _dht = TextEditingController(text: _cfg.dhtPin.toString());
    _buzzerFreq = TextEditingController(text: _cfg.buzzerFreq.toString());
    _buzzerDuty = TextEditingController(text: _cfg.buzzerDuty.toString());
    _buzzerChannel = TextEditingController(text: _cfg.buzzerChannel.toString());
    _commandTopic = TextEditingController(text: _cfg.commandTopic);
    _responseTopic = TextEditingController(text: _cfg.responseTopic);
    _prompt = TextEditingController(text: _cfg.customPrompt);
  }

  @override
  void dispose() {
    for (final c in [
      _redLed, _greenLed, _buzzer, _fan, _dht,
      _buzzerFreq, _buzzerDuty, _buzzerChannel,
      _commandTopic, _responseTopic, _prompt,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int _parseInt(TextEditingController c, int fallback) =>
      int.tryParse(c.text.trim()) ?? fallback;

  Future<void> _save() async {
    final promptChanged = await _cfg.save(
      redLedPin: _parseInt(_redLed, _cfg.redLedPin),
      greenLedPin: _parseInt(_greenLed, _cfg.greenLedPin),
      buzzerPin: _parseInt(_buzzer, _cfg.buzzerPin),
      fanPin: _parseInt(_fan, _cfg.fanPin),
      dhtPin: _parseInt(_dht, _cfg.dhtPin),
      buzzerFreq: _parseInt(_buzzerFreq, _cfg.buzzerFreq),
      buzzerDuty: _parseInt(_buzzerDuty, _cfg.buzzerDuty),
      buzzerChannel: _parseInt(_buzzerChannel, _cfg.buzzerChannel),
      commandTopic: _commandTopic.text.trim().isEmpty
          ? _cfg.commandTopic
          : _commandTopic.text.trim(),
      responseTopic: _responseTopic.text.trim().isEmpty
          ? _cfg.responseTopic
          : _responseTopic.text.trim(),
      customPrompt: _prompt.text.trim().isEmpty
          ? _cfg.customPrompt
          : _prompt.text.trim(),
    );

    if (mounted) Navigator.pop(context, promptChanged);
  }

  void _resetPrompt() {
    setState(() => _prompt.text = defaultCustomPrompt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: const Color(0xFF6B8AAD),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF0D1B2A),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFF2979FF),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE0E8F4)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        children: [
          // ── Persona prompt ───────────────────────────────────────────────
          _SectionHeader(label: 'AI PERSONA PROMPT'),
          const SizedBox(height: 10),
          _InputField(
            controller: _prompt,
            minLines: 5,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            hint: 'Describe how the AI should behave…',
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resetPrompt,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Reset to default',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B8AAD)),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Device pins ──────────────────────────────────────────────────
          _SectionHeader(label: 'DEVICE PINS'),
          const SizedBox(height: 10),
          _PinRow(label: 'Red LED', controller: _redLed),
          _PinRow(label: 'Green LED', controller: _greenLed),
          _PinRow(label: 'Buzzer', controller: _buzzer),
          _PinRow(label: 'Fan', controller: _fan),
          _PinRow(label: 'DHT Sensor', controller: _dht),

          const SizedBox(height: 28),

          // ── Buzzer PWM ───────────────────────────────────────────────────
          _SectionHeader(label: 'BUZZER PWM'),
          const SizedBox(height: 10),
          _PinRow(label: 'Frequency (Hz)', controller: _buzzerFreq),
          _PinRow(label: 'Duty (on)', controller: _buzzerDuty),
          _PinRow(label: 'Channel', controller: _buzzerChannel),

          const SizedBox(height: 28),

          // ── MQTT topics ──────────────────────────────────────────────────
          _SectionHeader(label: 'MQTT TOPICS'),
          const SizedBox(height: 10),
          _LabeledField(label: 'Command topic', controller: _commandTopic),
          const SizedBox(height: 10),
          _LabeledField(label: 'Response topic', controller: _responseTopic),
        ],
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF2979FF),
        letterSpacing: 1.2,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final TextInputType keyboardType;
  final String hint;

  const _InputField({
    required this.controller,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.hint = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Color(0xFF0D1B2A), fontSize: 14, height: 1.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF6B8AAD), fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _PinRow({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0D1B2A),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0D1B2A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _LabeledField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B8AAD)),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEEF4FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Color(0xFF0D1B2A), fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
