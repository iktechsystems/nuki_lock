
import 'Authorization.dart';

class SmartLock {
  final String bluetoothId; // bluetooth mac address
  final Authorization authorization;
  
  SmartLock(this.bluetoothId, this.authorization);

}