import "mqtt_services.dart";
import 'device_config.dart';
import 'dart:convert';
import 'dart:math';

Map<String, int> get _devicePins => {
  'buzzer': DeviceConfig.instance.buzzerPin,
  'red_led': DeviceConfig.instance.redLedPin,
  'green_led': DeviceConfig.instance.greenLedPin,
  'fan': DeviceConfig.instance.fanPin,
};

// @tool
Future<String> publishCommand(Map<String, dynamic> args) async {
  final device = args["device"] as String;
  final value = args["value"] as int;
  final pin = _devicePins[device];
  final cfg = DeviceConfig.instance;

  late Map<String, dynamic> payload;
  if (device == "buzzer") {
    payload = {
      "pin": pin,
      'action': "pwm",
      'duty': value == 1 ? cfg.buzzerDuty : 0,
      'channel': cfg.buzzerChannel,
      'freq': cfg.buzzerFreq,
    };
  } else {
    payload = {'pin': pin, 'action': 'digital', 'value': value};
  }

  mqttService.publish(cfg.commandTopic, jsonEncode(payload));
  return '{"status": "success" }';
}

String generateCorrId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random();
  return List.generate(8, (i) => chars[rand.nextInt(chars.length)]).join();
}

// @tool
Future<String> getSensorReading() async {
  final cfg = DeviceConfig.instance;
  final corrId = generateCorrId();

  mqttService.subscribe(cfg.responseTopic);
  mqttService.publish(
    cfg.commandTopic,
    jsonEncode({'pin': cfg.dhtPin, 'action': 'DHT', 'correlation_id': corrId}),
  );

  final response = await mqttService.messages
      .where(
        (data) =>
            data['topic'] == cfg.responseTopic &&
            jsonDecode(data['payload']!)['correlation_id'] == corrId,
      )
      .first
      .timeout(
        const Duration(seconds: 5),
        onTimeout: () => {'payload': '{"error": "timeout"}'},
      );

  return response['payload']!;
}

// @tool
Future<String> sendLuaScript(String script) async {
  mqttService.publish(
    DeviceConfig.instance.commandTopic,
    jsonEncode({'action': 'lua', 'script': script}),
  );
  return '{"status": "success" }';
}
