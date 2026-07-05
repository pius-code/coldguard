import 'package:flutter/material.dart';
import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "chat_screen.dart";
import 'mqtt_services.dart';
import 'device_config.dart';

const _kModelPathKey = 'model_path';
const _kBrokerIpKey = 'broker_ip';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceConfig.instance.load();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2979FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const Scaffold(body: ModelLoader()),
    );
  }
}

class ModelLoader extends StatefulWidget {
  const ModelLoader({super.key});

  @override
  State<ModelLoader> createState() => _ModelLoaderState();
}

class _ModelLoaderState extends State<ModelLoader> {
  final TextEditingController _ipController = TextEditingController();
  String? _savedModelPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _restoreSaved();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  // Restore saved values into the UI — never auto-load.
  Future<void> _restoreSaved() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final savedIp = prefs.getString(_kBrokerIpKey);
      final savedModel = prefs.getString(_kModelPathKey);
      if (savedIp != null) _ipController.text = savedIp;
      if (savedModel != null) _savedModelPath = savedModel;
    });
  }

  Future<void> _onButtonPressed() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the broker IP address first')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // If a model is already saved, skip the picker and go straight to loading.
    if (_savedModelPath != null) {
      setState(() => _isLoading = true);
      await prefs.setString(_kBrokerIpKey, ip);
      await mqttService.connect(ip);
      await _loadFromPath(_savedModelPath!, prefs);
      return;
    }

    // No saved model — open file picker.
    final permission = await Permission.manageExternalStorage.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission denied')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || !mounted) return;

    final path = result.files.single.path!;
    setState(() {
      _savedModelPath = path;
      _isLoading = true;
    });

    await prefs.setString(_kBrokerIpKey, ip);
    await prefs.setString(_kModelPathKey, path);
    await mqttService.connect(ip);
    await _loadFromPath(path, prefs);
  }

  Future<void> _loadFromPath(String path, SharedPreferences prefs) async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final engine = await LiteLmEngine.create(
        LiteLmEngineConfig(modelPath: path, backend: LiteLmBackend.gpu),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(engine: engine)),
      );
    } catch (e) {
      await prefs.remove(_kModelPathKey);
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('Failed to load model: $e')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEF4FF), Color(0xFFF2F7FF), Color(0xFFF7FAFF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Icon + title
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2979FF).withValues(alpha: 0.08),
                  border: Border.all(
                    color: const Color(0xFF2979FF).withValues(alpha: 0.18),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.vaccines_rounded,
                  size: 52,
                  color: Color(0xFF2979FF),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'ColdGuard',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D1B2A),
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'On-device IoT agent',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B8AAD),
                  letterSpacing: 0.3,
                ),
              ),

              const Spacer(flex: 2),

              // ── Step 1: Broker IP ──
              _StepLabel(number: '1', label: 'Broker IP'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _ipController,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(
                    color: Color(0xFF0D1B2A),
                    fontSize: 15,
                  ),
                  decoration: const InputDecoration(
                    hintText: '192.168.x.x',
                    hintStyle: TextStyle(color: Color(0xFF6B8AAD)),
                    prefixIcon: Icon(
                      Icons.router_rounded,
                      color: Color(0xFF6B8AAD),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Step 2: Load model ──
              _StepLabel(number: '2', label: 'AI Model'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _onButtonPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2979FF),
                    disabledBackgroundColor:
                        const Color(0xFF2979FF).withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _savedModelPath != null
                              ? Icons.play_arrow_rounded
                              : Icons.folder_open_rounded,
                          size: 20,
                        ),
                  label: Text(
                    _isLoading
                        ? 'Loading…'
                        : _savedModelPath != null
                            ? 'Connect & Start'
                            : 'Load Model',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              const Text(
                'First load may take a minute depending on your device — keep the app open.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B8AAD),
                  height: 1.5,
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final String number;
  final String label;
  const _StepLabel({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF2979FF),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0D1B2A),
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
