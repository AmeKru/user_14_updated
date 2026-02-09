// placeholder file for conditional imports...
// if somehow a platform for app is used that is neither, throw error
class MqttClientDef {
  MqttClientDef(String server, String clientId) {
    throw UnsupportedError('MQTT not supported on this platform');
  }
}
