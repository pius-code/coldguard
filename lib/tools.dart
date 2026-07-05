import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import 'device_config.dart';
import 'raw_tools.dart';

List<LiteLmTool> getColdChainTools() {
  final c = DeviceConfig.instance;

  return [
    LiteLmTool(
      name: "publish_command",
      description:
          "ALWAYS use this for any simple, immediate, one-shot device command: "
          "turn on/off the buzzer, fan, red LED, or green LED right now. "
          "NEVER use send_lua_script for simple on/off commands — use this tool. "
          "Turn on fan → device='fan', value=1. "
          "Turn off fan → device='fan', value=0. "
          "Turn on red LED → device='red_led', value=1. "
          "Turn off red LED → device='red_led', value=0. "
          "Sound buzzer → device='buzzer', value=1. "
          "Stop buzzer → device='buzzer', value=0.",
      parameters: {
        'type': 'object',
        'properties': {
          'device': {
            'type': 'string',
            'description': 'The device to control.',
            'enum': ['buzzer', 'fan', 'red_led', 'green_led'],
          },
          'value': {
            'type': 'integer',
            'description': '1 to turn on, 0 to turn off.',
            'enum': [0, 1],
          },
        },
        'required': ['device', 'value'],
      },
    ),
    LiteLmTool(
      name: "get_sensor_reading",
      description:
          "ALWAYS call this tool when the user asks about temperature, humidity, or light. "
          "Never guess or make up sensor readings. "
          "Returns live readings from the cold storage unit.",
      parameters: {'type': 'object', 'properties': {}, 'required': []},
    ),
    LiteLmTool(
      name: "send_lua_script",
      description:
          "Sends a Lua script to the ESP32 to run autonomously in real-time. "
          "ONLY use this for conditional or continuous rules that depend on sensor readings — "
          "e.g. 'turn on the red light IF temperature goes above 25°C' or 'keep fan on WHILE temp is high'. "
          "NEVER use this for simple on/off commands — use publish_command instead. "
          "The script runs on the device even when the phone is not connected. "
          "ALWAYS use asha.sleep(100) inside every while loop or the device will crash. "
          "DEVICE PINS: red_led=${c.redLedPin}, green_led=${c.greenLedPin}, buzzer=${c.buzzerPin}, fan=${c.fanPin}. "
          "AVAILABLE FUNCTIONS (all under the asha module — ALWAYS use the asha. prefix): "
          "asha.getTemperature() — returns current temperature in Celsius. "
          "asha.getHumidity() — returns current humidity percentage. "
          "asha.command(jsonStr) — control a device. "
          "asha.sleep(ms) — MANDATORY in all while loops. "
          "NEVER call getTemperature() or getHumidity() without the asha. prefix — they will be nil. "
          "NOTE: red_led and green_led use digital action. buzzer uses pwm action. "
          "EXAMPLE — alert if temperature above 25: "
          "while true do "
          "  local temp = asha.getTemperature() "
          "  if temp > 25 then "
          "    asha.command('{\"pin\": ${c.redLedPin}, \"action\": \"digital\", \"value\": 1}') "
          "    asha.command('{\"pin\": ${c.buzzerPin}, \"action\": \"pwm\", \"channel\": ${c.buzzerChannel}, \"freq\": ${c.buzzerFreq}, \"duty\": ${c.buzzerDuty}}') "
          "  else "
          "    asha.command('{\"pin\": ${c.redLedPin}, \"action\": \"digital\", \"value\": 0}') "
          "    asha.command('{\"pin\": ${c.buzzerPin}, \"action\": \"pwm\", \"channel\": ${c.buzzerChannel}, \"freq\": ${c.buzzerFreq}, \"duty\": 0}') "
          "  end "
          "  asha.sleep(100) "
          "end "
          "NOTE: LEDs always use digital action. Only buzzer uses pwm action.",
      parameters: {
        'type': 'object',
        'properties': {
          'script': {
            'type': 'string',
            'description': 'The Lua script to run on the ESP32.',
          },
        },
        'required': ['script'],
      },
    ),
  ];
}

final Map<String, Future<String> Function(Map<String, dynamic>)> toolHandlers =
    {
      'publish_command': (args) => publishCommand(args),
      'get_sensor_reading': (args) => getSensorReading(),
      'send_lua_script': (args) => sendLuaScript(args['script'] as String),
    };
