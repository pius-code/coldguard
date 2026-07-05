import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  late MqttServerClient _client;
  String _brokerIp = '';

  bool get _isConnected =>
      _brokerIp.isNotEmpty &&
      (_client.connectionStatus?.state == MqttConnectionState.connected);

  Future<void> connect(String brokerIp) async {
    _brokerIp = brokerIp;
    _client = MqttServerClient.withPort(brokerIp, 'coldguard_app', 1883);
    _client.keepAlivePeriod = 60;
    _client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier('coldguard_app')
        .startClean();
    await _client.connect();
  }

  Future<void> publish(String topic, String payload) async {
    if (!_isConnected) return;
    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  Future<void> subscribe(String topic) async {
    _client.subscribe(topic, MqttQos.atMostOnce);
  }

  Stream<Map<String, String>> get messages {
    return _client.updates!.map((messages) {
      final message = messages[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        message.payload.message,
      );
      return {'topic': messages[0].topic, 'payload': payload};
    });
  }
}

final mqttService = MqttService();
