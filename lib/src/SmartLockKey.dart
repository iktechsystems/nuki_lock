
import 'Authorization.dart';
/// The class encapsulate the settings required to connect and make
/// request to the smart lock
class SmartLockKey {
  final String bluetoothId; // bluetooth mac address
  final Authorization authorization;
  
  SmartLockKey(this.bluetoothId, this.authorization);

}