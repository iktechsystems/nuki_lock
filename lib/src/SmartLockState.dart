import 'package:convert/convert.dart';

enum NukiState {UNINITIALIZED, PAIRING_MODE, DOOR_MODE, MAINTENANCE_MODE, UNDEFINED}
enum LockState {UNCALIBRATED, LOCKED, UNLOCKING, UNLOCKED, LOCKING, UNLATCHED, UNLOCKED_LOCK_N_GO_ACTIVE, UNLATCHING, CALIBRATION, BOOT_RUN, MOTOR_BLOCKED, UNDEFINED}
enum Triger {SYSTEM, MANUAL, BUTTON, AUTOMATIC, AUTO_LOCK, UNDEFINED}
enum BatteryState {OK, CRITICAL, UNDEFINED}

//TODO: Complete the list of smart lock state properties
class SmartLockState {
  final NukiState nukiState;
  final LockState lockState;
  final Triger triger;
  final BatteryState batteryState;
  final DateTime currentTime;
  final int timeZoneOffset;


  SmartLockState({this.batteryState,this.currentTime, this.lockState, this.nukiState, this.timeZoneOffset, this.triger});

  ///Deserialize smart lock state from byte stream 
  ///
  ///Convinience method to deserialize [SmartLockState] properties from the decrypted 
  ///[response] returned by the get lock state request
  factory SmartLockState.fromBytes(List<int> response) {
    //sample response: de5c3400 0c00 02 03 00 e307 07 19 0e 28 1b 0000 00 02 00 00 00 00 01 7fcf                    
    
    // the year is reflected, e.g., it is 07e3 instead of e307
    String hexYr = hex.encode([response[10],response[9]]);
    int yr = int.parse(hexYr, radix:16);
    
    return SmartLockState(
            nukiState: _bit2NukiState(response[6]),
            lockState: _bit2LockState(response[7]),
            triger: _bit2Trigger(response[8]),
            currentTime: DateTime(yr,response[11],response[12],response[13],response[14],response[15]),
            timeZoneOffset: response[17]>0?-response[16]:response[16],
            batteryState: _bit2BatteryState(response[18])
          );
    
  }

  static NukiState _bit2NukiState(int bit) {
    if(bit == 0x00)
      return NukiState.UNINITIALIZED;
    else if(bit == 0x01)
      return NukiState.PAIRING_MODE;
    else if(bit == 0x02)
      return NukiState.DOOR_MODE;
    else if(bit == 0x04)
      return NukiState.MAINTENANCE_MODE;
    else
      return NukiState.UNDEFINED;
  }

  static LockState _bit2LockState(int bit) {
    if(bit == 0x00)
      return LockState.UNCALIBRATED;
    else if(bit == 0x01)
      return LockState.LOCKED;
    else if(bit == 0x02)
      return LockState.UNLOCKING;
    else if(bit == 0x03)
      return LockState.UNLOCKED;
    else if(bit == 0x04)
      return LockState.LOCKING;
    else if(bit == 0x05)
      return LockState.UNLATCHED;
    else if(bit == 0x06)
      return LockState.UNLOCKED_LOCK_N_GO_ACTIVE;
    else if(bit == 0x07)
      return LockState.UNLATCHING;
    else if(bit == 0xFC)
      return LockState.CALIBRATION;
    else if(bit == 0xFD)
      return LockState.BOOT_RUN;
    else if(bit == 0xFE)
      return LockState.MOTOR_BLOCKED;
    else
      return LockState.UNDEFINED;
  }

  static Triger _bit2Trigger(int bit) {
    if(bit == 0x00)
      return Triger.SYSTEM;
    else if(bit == 0x01)
      return Triger.MANUAL;
    else if(bit == 0x02)
      return Triger.BUTTON;
    else if(bit == 0x03)
      return Triger.AUTOMATIC;
    else if(bit == 0x04)
      return Triger.AUTO_LOCK;
    else
      return Triger.UNDEFINED;
  }

  static BatteryState _bit2BatteryState(int bit) {
    if(bit == 0x00)
      return BatteryState.OK;
    else if (bit == 0x01)
      return BatteryState.CRITICAL;
    else
      return BatteryState.UNDEFINED;
  }
}