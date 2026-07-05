import 'package:shared_preferences/shared_preferences.dart';

const String defaultCustomPrompt =
    'You are ColdGuard, an intelligent assistant for a medical cold storage unit. '
    'Your users are doctors, pharmacists, and healthcare workers — not engineers. '
    'NEVER mention Lua, scripts, ESP32, pins, MQTT, tool calls, or any technical internals in your replies. '
    'Always describe actions in plain human language. '
    'Say "I\'ve set up automatic monitoring for that" not "A Lua script has been sent to the ESP32". '
    'Say "The fan is now on" not "I\'ve published a command to pin 26". '
    'Keep responses short, warm, and confident. '
    'If asked to do something your tools don\'t support, say so honestly — '
    'e.g. "I can\'t do that one, sorry!" Never say "I can\'t assist with that."';

class DeviceConfig {
  DeviceConfig._();
  static final DeviceConfig instance = DeviceConfig._();

  // Pins
  int redLedPin = 18;
  int greenLedPin = 19;
  int buzzerPin = 21;
  int fanPin = 26;
  int dhtPin = 22;

  // Buzzer PWM
  int buzzerFreq = 440;
  int buzzerDuty = 32767;
  int buzzerChannel = 0;

  // MQTT topics
  String commandTopic = 'coldGuard/command';
  String responseTopic = 'coldGuard/response';

  // AI persona
  String customPrompt = defaultCustomPrompt;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    redLedPin = p.getInt('red_led_pin') ?? 18;
    greenLedPin = p.getInt('green_led_pin') ?? 19;
    buzzerPin = p.getInt('buzzer_pin') ?? 21;
    fanPin = p.getInt('fan_pin') ?? 26;
    dhtPin = p.getInt('dht_pin') ?? 22;
    buzzerFreq = p.getInt('buzzer_freq') ?? 440;
    buzzerDuty = p.getInt('buzzer_duty') ?? 32767;
    buzzerChannel = p.getInt('buzzer_channel') ?? 0;
    commandTopic = p.getString('command_topic') ?? 'coldGuard/command';
    responseTopic = p.getString('response_topic') ?? 'coldGuard/response';
    customPrompt = p.getString('custom_prompt') ?? defaultCustomPrompt;
  }

  // Returns true if any prompt-relevant field actually changed.
  Future<bool> save({
    required int redLedPin,
    required int greenLedPin,
    required int buzzerPin,
    required int fanPin,
    required int dhtPin,
    required int buzzerFreq,
    required int buzzerDuty,
    required int buzzerChannel,
    required String commandTopic,
    required String responseTopic,
    required String customPrompt,
  }) async {
    final promptChanged = redLedPin != this.redLedPin ||
        greenLedPin != this.greenLedPin ||
        buzzerPin != this.buzzerPin ||
        fanPin != this.fanPin ||
        dhtPin != this.dhtPin ||
        buzzerFreq != this.buzzerFreq ||
        buzzerDuty != this.buzzerDuty ||
        buzzerChannel != this.buzzerChannel ||
        customPrompt != this.customPrompt;

    this.redLedPin = redLedPin;
    this.greenLedPin = greenLedPin;
    this.buzzerPin = buzzerPin;
    this.fanPin = fanPin;
    this.dhtPin = dhtPin;
    this.buzzerFreq = buzzerFreq;
    this.buzzerDuty = buzzerDuty;
    this.buzzerChannel = buzzerChannel;
    this.commandTopic = commandTopic;
    this.responseTopic = responseTopic;
    this.customPrompt = customPrompt;

    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setInt('red_led_pin', redLedPin),
      p.setInt('green_led_pin', greenLedPin),
      p.setInt('buzzer_pin', buzzerPin),
      p.setInt('fan_pin', fanPin),
      p.setInt('dht_pin', dhtPin),
      p.setInt('buzzer_freq', buzzerFreq),
      p.setInt('buzzer_duty', buzzerDuty),
      p.setInt('buzzer_channel', buzzerChannel),
      p.setString('command_topic', commandTopic),
      p.setString('response_topic', responseTopic),
      p.setString('custom_prompt', customPrompt),
    ]);

    return promptChanged;
  }

  void resetToDefaults() {
    redLedPin = 18;
    greenLedPin = 19;
    buzzerPin = 21;
    fanPin = 26;
    dhtPin = 22;
    buzzerFreq = 440;
    buzzerDuty = 32767;
    buzzerChannel = 0;
    commandTopic = 'coldGuard/command';
    responseTopic = 'coldGuard/response';
    customPrompt = defaultCustomPrompt;
  }
}
