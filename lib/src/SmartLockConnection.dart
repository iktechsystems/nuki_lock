

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:tweetnacl/tweetnacl.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:convert/convert.dart';
import 'package:crclib/crclib.dart';
import 'package:crypto/crypto.dart';

import 'Authorization.dart';
import 'LockAction.dart';
import 'Config.dart';
import 'RequestError.dart';
import 'SmartLockState.dart';
import 'SmartLockKey.dart';


// Advertisement service UUID
//const String ADVERT_SERVICE_UUID = 'a92ee000-5501-11e4-916c-0800200c9a66';

// Pairing UUIDs
const String PAIRING_SERVICE_UUID = 'a92ee100-5501-11e4-916c-0800200c9a66'; 
const String PAIRING_GDIO_XTERISTIC_UUID = 'a92ee101-5501-11e4-916c-0800200c9a66'; 

// Keyturner UUIDs
const String KEYTURNER_SERVICE_UUID = 'a92ee200-5501-11e4-916c-0800200c9a66';
const String KEYTURNER_GDIO_XTERISTIC_UUID = 'a92ee201-5501-11e4-916c-0800200c9a66';
const String KEYTURNER_USDIO_XTERISTIC_UUID = 'a92ee202-5501-11e4-916c-0800200c9a66';

/// Maximum packet length per notification
const int MAX_PACKET_LENGTH = 20;

// Nuki Bluetooth API Commands
const int REQUEST_DATA_CMD = 0x01;  
const int PUBLIC_KEY_CMD = 0x03;
const int CHALLENGE_CMD = 0x04;
const int AUTHORIZATION_AUTHENTICATOR_CMD = 0x05;
const int AUTHORIZATION_DATA_CMD = 0x06;
const int AUTHORIZATION_ID_CMD = 0x07;
const int AUTHORIZATION_DATA_INVITE_CMD = 0x0B;
const int KEYTURNER_STATE_CMD = 0x0C;
const int LOCK_ACTION_CMD = 0x0D;
const int STATUS_CMD = 0x0E;
const int AUTHORIZATION_ID_CONFIRMATION_CMD = 0x1E;
const int AUTHORIZATION_ID_INVITE_CMD = 0x1F;
const int ERROR_REPORT_CMD = 0x12;
const int GET_CONFIG_CMD = 0x14;
const int CONFIG_CMD = 0x15;
const int SET_PIN_CMD = 0x19;

// Status codes
const int ACCEPTED_STATUS = 0x01;
const int COMPLETED_STATUS = 0x00;

// Default connection timeout
const Duration DEFAULT_CONNECTION_TIMEOUT = Duration(seconds: 30);

class SmartLockConnection {

  /// [FlutterBlue] library instance
  FlutterBlue _flutterBlue = FlutterBlue.instance;
  ///CRC calculator
  ParametricCrc _crcCalc = Crc16Ccitt(); 
  /// [Map] of [LockAction] codes
  final Map<LockAction, int> _lockActionCodes = {
    LockAction.UNLOCK:0x01,
    LockAction.LOCK:0x02,
    LockAction.UNLATCH:0x03,
    LockAction.LOCK_N_GO:0x04,
    LockAction.LOCK_N_GO_WITH_UNLATCH:0x05,
    LockAction.FULL_LOCK:0x06,
    LockAction.FOB_ACTION_1:0x81,
    LockAction.FOB_ACTION_2:0x82,
    LockAction.FOB_ACTION_3:0x83
  };
  /// [Map] of [RequestError]s 
  final Map<int, RequestError> _requestErrors = {
    // General error codes
    0xFD:RequestError.ERROR_BAD_CRC,
    0xFE:RequestError.ERROR_BAD_LENGTH,
    0xFF:RequestError.ERROR_UNKNOWN,
    //Pairing service error codes
    0x10:RequestError.P_ERROR_NOT_PAIRING,
    0x11:RequestError.P_ERROR_BAD_AUTHENTICATOR,
    0x12:RequestError.P_ERROR_BAD_PARAMETER,
    0x12:RequestError.P_ERROR_MAX_USERS_EXCEEDED,
    // Keyturner service error codes
    0x20:RequestError.K_ERROR_NOT_AUTHORIZED,
    0x21:RequestError.K_ERROR_BAD_PIN,
    0x22:RequestError.K_ERROR_BAD_NONCE,
    0x23:RequestError.K_ERROR_BAD_PARAMETER,
    0x24:RequestError.K_ERROR_INVALID_AUTH_ID,
    0x25:RequestError.K_ERROR_DISABLED,
    0x26:RequestError.K_ERROR_REMOTE_NOT_ALLOWED,
    0x27:RequestError.K_ERROR_TIME_NOT_ALLOWED,
    0x28:RequestError.K_ERROR_TOO_MANY_PIN_ATTEMPTS,
    0x29:RequestError.K_ERROR_TOO_MANY_ENTRIES,
    0x2A:RequestError.K_ERROR_CODE_ALREADY_EXISTS,
    0x2B:RequestError.K_ERROR_CODE_INVALID,
    0x2C:RequestError.K_ERROR_CODE_INVALID_TIMEOUT_1,
    0x2D:RequestError.K_ERROR_CODE_INVALID_TIMEOUT_2,
    0x2E:RequestError.K_ERROR_CODE_INVALID_TIMEOUT_3,
    0x40:RequestError.K_ERROR_AUTO_UNLOCK_TOO_RECENT,
    0x41:RequestError.K_ERROR_POSITION_UNKNOWN,
    0x42:RequestError.K_ERROR_MOTOR_BLOCKED,
    0x43:RequestError.K_ERROR_CLUTCH_FAILURE,
    0x44:RequestError.K_ERROR_MOTOR_TIMEOUT,
    0x45:RequestError.K_ERROR_BUSY,
    0x46:RequestError.K_ERROR_CANCELED,
    0x47:RequestError.K_ERROR_NOT_CALIBRATED,
    0x48:RequestError.K_ERROR_MOTOR_POSITION_LIMIT,
    0x49:RequestError.K_ERROR_MOTOR_LOW_VOLTAGE,
    0x4A:RequestError.K_ERROR_MOTOR_POWER_FAILURE,
    0x4B:RequestError.K_ERROR_CLUTCH_POWER_FAILURE,
    0x4C:RequestError.K_ERROR_VOLTAGE_TOO_LOW,
    0x4D:RequestError.K_ERROR_FIRMWARE_UPDATE_NEEDED
  };

  static final SmartLockConnection _connection = new SmartLockConnection._internal();

  factory SmartLockConnection() {
    return _connection;
  }

  SmartLockConnection._internal();

  // global methods
 
  /// Returns [true] if this device supports Bluetooth else returns [false]
  Future<bool> isBluetoothSupported() {
    return _flutterBlue.isAvailable;
  }

  /// Returns [true] if Bluetooth is on else returns [false]
  Future<bool> isBluetoothOn() {
    return _flutterBlue.isOn;
  }

  /// Find nearby Nuki smart lock devices
  /// 
  /// Returns a [Stream] which notifies listeners whenever a Nuki [BluetoothDevice] is found.
  /// If [withIdentifier] is set,  then only smart locks with the identifiers will be returned
  Stream<BluetoothDevice> findSmartLockDevices(Duration duration, {List<DeviceIdentifier> withIdentifier}) {
    String uuid = '';
    KEYTURNER_SERVICE_UUID.split('-').forEach((val){
      uuid = uuid+val;
    });

    StreamController<BluetoothDevice> streamController = new StreamController();
    var scanSubscription;
    /// Start scanning
    scanSubscription = _flutterBlue.scan(
      scanMode: ScanMode.lowLatency,
      timeout: duration

    ).listen((scanResult) {
     
        scanResult.advertisementData.manufacturerData.forEach((idx,vals){
          if(hex.encode(vals).contains(uuid)) {
            if(withIdentifier == null)
              streamController.add(scanResult.device);
            else if(withIdentifier.contains(scanResult.device.id))
              streamController.add(scanResult.device);
          }
        });
      
    },
    onDone: (){
      streamController?.close();
      streamController = null;
      scanSubscription?.cancel();
      scanSubscription = null;
    });

    return streamController.stream;
  }

  /// Get the current state of [lock]
  /// 
  /// Returns a [Stream] which sends [SmartLockState] of [lock] to listeners. The [Stream] closes
  /// if the request is not completed after [timeout].  
  Stream<SmartLockState> getLockState(SmartLockKey lock, {Duration timeout=DEFAULT_CONNECTION_TIMEOUT}) {

    List<int> buffer = [];
    StreamController<SmartLockState> streamController = new StreamController();
    BluetoothDevice device = BluetoothDevice(id:DeviceIdentifier(lock.bluetoothId), type: BluetoothDeviceType.le);
    StreamSubscription deviceCon; 
    StreamSubscription indListener;

    void disconnect() {
      streamController.close();
      streamController = null;
      indListener?.cancel();
      indListener = null;
      deviceCon?.cancel();
      deviceCon = null;
    }
    
    deviceCon = _flutterBlue.connect(device, autoConnect: false, timeout: timeout).listen((s) async {
   
      if(s == BluetoothDeviceState.connected) {
        BluetoothCharacteristic xter = await _findCharacteristics(device, KEYTURNER_SERVICE_UUID, KEYTURNER_USDIO_XTERISTIC_UUID);
        await device.setNotifyValue(xter, true);
        indListener = device.onValueChanged(xter).listen((values) async {
          buffer.addAll(values);

          if(values.length < MAX_PACKET_LENGTH) {
            
            List<int> msg = _decrypt(buffer, hex.decode(lock.authorization.ssk));
            
            if(_isCrcOk(msg)) {
              if(lock.authorization.id == hex.encode(msg.sublist(0,4))) {
                int command = msg[4]; // get command in the response 
                
                switch(command) {
                  case KEYTURNER_STATE_CMD: 
                    streamController.add(SmartLockState.fromBytes(msg));
                    break;
                  case ERROR_REPORT_CMD: 
                    streamController.addError(_requestErrors[msg[6]]);
                    break;
                  default: 
                    streamController.addError(RequestError.API_UNKNOWN_ERROR);
                }

              } else   
                  streamController.addError(RequestError.API_AUTHID_AUTHENTICATION_FAILED);
            } else
                streamController.addError(RequestError.API_CRC_AUTHENTICATION_FAILED);

            disconnect();
          }
        });
        
        // create request payload
        List<int> payload = _createLockStateRequest(lock.authorization.id, lock.authorization.ssk);
        //write payload
        device.writeCharacteristic(xter, payload,type: CharacteristicWriteType.withResponse);
      } else if (s == BluetoothDeviceState.disconnected){
        // send error if the connection is closed before the request completes
        debugPrint('disconnect in get lock state');
        if(streamController != null) {
          streamController.addError(RequestError.API_CONNECTION_CLOSED);
          disconnect();
        }
        
      }
    });

    return streamController.stream;
  }

  /// Performs the requested [action] on [lock] 
  /// 
  /// Returns a [Stream] which sends [SmartLockState] of [lock] to listeners. The [Stream] closes
  /// if the request is not completed after [timeout].
  Stream<SmartLockState> requestLockAction(SmartLockKey lock, LockAction action, {Duration timeout=DEFAULT_CONNECTION_TIMEOUT}) {
    List<int> buffer = [];
    StreamController<SmartLockState> streamController = new StreamController();
    BluetoothDevice device = BluetoothDevice(id:DeviceIdentifier(lock.bluetoothId), type: BluetoothDeviceType.le);
    StreamSubscription deviceCon; 
    StreamSubscription indListener;
    
    void disconnect() {
      streamController.close();
      streamController = null;
      indListener?.cancel();
      indListener = null;
      deviceCon?.cancel();
      deviceCon = null;
    }
    
    deviceCon = _flutterBlue.connect(device, autoConnect: false, timeout: timeout).listen((s) async {
      if(s == BluetoothDeviceState.connected) {
        BluetoothCharacteristic xter = await _findCharacteristics(device, KEYTURNER_SERVICE_UUID, KEYTURNER_USDIO_XTERISTIC_UUID);
        
        await device.setNotifyValue(xter, true);

        indListener = device.onValueChanged(xter).listen((values) async{

          buffer.addAll(values);

          if(values.length < MAX_PACKET_LENGTH) {
           
            List<int> msg = _decrypt(buffer, hex.decode(lock.authorization.ssk));

            //clear buffer to receive next response
            buffer.clear();

            if(_isCrcOk(msg)) { // check crc
              if(lock.authorization.id == hex.encode(msg.sublist(0,4))) { // check authorization id
                int command = msg[4]; // get command in the response 
                
                switch(command) {
                  case CHALLENGE_CMD: 
                    //create lock action request with the received challenge
                    List<int> payload = _createLockActionRequest(lock.authorization.id,
                    lock.authorization.ssk,action,msg.sublist(6,msg.length-2));
                    //write payload
                    device.writeCharacteristic(xter, payload,type: CharacteristicWriteType.withResponse);
                    break;
                  case KEYTURNER_STATE_CMD: 
                    streamController.add(SmartLockState.fromBytes(msg));
                    break;
                  case STATUS_CMD:
                    int status = msg[6]; // get the status 
                    if(status == ACCEPTED_STATUS) 
                      debugPrint('$action request accepted by smart lock');
                    else // COMPLETED_STATUS
                      disconnect();
                    break;
                  case ERROR_REPORT_CMD: 
                    streamController.addError(_requestErrors[msg[6]]);
                    // clean up
                    disconnect();
                    break;
                  default: 
                    streamController.addError(RequestError.API_UNKNOWN_ERROR);
                    // clean up
                    disconnect();
                }

              } else {   
                  streamController.addError(RequestError.API_AUTHID_AUTHENTICATION_FAILED);
                  disconnect();
              }
            } else {
                streamController.addError(RequestError.API_CRC_AUTHENTICATION_FAILED);
                disconnect();
            }
          }

        });
      
        // create challenge request payload
        List<int> payload = _createChallengeRequest(lock.authorization.id, lock.authorization.ssk);
        //write payload
        device.writeCharacteristic(xter, payload,type: CharacteristicWriteType.withResponse);

      }  else if (s == BluetoothDeviceState.disconnected){
        // send error if the connection is closed before the request completes
        if(streamController != null) {
          streamController.addError(RequestError.API_CONNECTION_CLOSED);
          disconnect();
        }
      }
    });

    return streamController.stream;
  }

  /// Create an [Authorization] using an existing [SmartLockKey]
  /// The [Stream] closes if the request is not completed after [timeout].
  Stream<Authorization> createAuthorization(SmartLockKey lock, int pin, IdType idType, String name, 
  DateTime allowedFromDate, DateTime allowedUntilDate, DateTime allowedFromTime, DateTime allowedUntilTime, 
  {Duration timeout=DEFAULT_CONNECTION_TIMEOUT}) {
    List<int> buffer = [];
    StreamController<Authorization> streamController = new StreamController();
    BluetoothDevice device = BluetoothDevice(id:DeviceIdentifier(lock.bluetoothId), type: BluetoothDeviceType.le);
    StreamSubscription deviceCon; 
    StreamSubscription indListener;
    
    void disconnect() {
      streamController.close();
      streamController = null;
      indListener?.cancel();
      indListener = null;
      deviceCon?.cancel();
      deviceCon = null;
    }

    deviceCon = _flutterBlue.connect(device, autoConnect: false, timeout: timeout).listen((s) async {
      if(s == BluetoothDeviceState.connected) {
        BluetoothCharacteristic xter = await _findCharacteristics(device, KEYTURNER_SERVICE_UUID, 
          KEYTURNER_USDIO_XTERISTIC_UUID);
        await device.setNotifyValue(xter, true);

        Uint8List authSsk = TweetNaclFast.randombytes(32); // generate ssk

        indListener = device.onValueChanged(xter).listen((values) async{
          buffer.addAll(values);
          if(values.length < MAX_PACKET_LENGTH) {
      
            List<int> msg = _decrypt(buffer, hex.decode(lock.authorization.ssk));
           

            //clear buffer to receive next response
            buffer.clear();

            if(_isCrcOk(msg)) { // check crc
              if(lock.authorization.id == hex.encode(msg.sublist(0,4))) { // check authorization id
                int command = msg[4]; // get command in the response 
                
                switch(command) {
                  case CHALLENGE_CMD: 
                    // create authorization request with the received challenge
                    List<int> payload = _createAuthorizationRequest(lock.authorization.id, 
                    lock.authorization.ssk, pin, idType, name, authSsk, allowedFromDate, allowedUntilDate, 
                    allowedFromTime, allowedUntilTime, xter, msg.sublist(6,msg.length-2));
                    //write payload
                    device.writeCharacteristic(xter, payload,type: CharacteristicWriteType.withResponse);
                    break;
                  case AUTHORIZATION_ID_INVITE_CMD:
                    //send created authorization to listeners as a smart lock object
                    streamController.add(Authorization(hex.encode(msg.sublist(6,10)), hex.encode(authSsk),
                    name:name, idType:idType,allowedFromDate: allowedFromDate,allowedUntilDate:allowedUntilDate, 
                    allowedFromTime:allowedFromTime,allowedUntilTime:allowedUntilTime));
                    // clean up
                    disconnect();
                    break;
                  case ERROR_REPORT_CMD: 
                    streamController.addError(_requestErrors[msg[6]]);
                    // clean up
                    disconnect();
                    break;
                  default: 
                    streamController.addError(RequestError.API_UNKNOWN_ERROR);
                    // clean up
                    disconnect();
                }

              } else {   
                  streamController.addError(RequestError.API_AUTHID_AUTHENTICATION_FAILED);
                  // clean up
                  disconnect();
              }
            } else {
                streamController.addError(RequestError.API_CRC_AUTHENTICATION_FAILED);
                // clean up
                disconnect();
            }
          }
          
        });
      
        // create request payload
        List<int> payload = _createChallengeRequest(lock.authorization.id, lock.authorization.ssk);
        //write payload
        device.writeCharacteristic(xter, payload,type: CharacteristicWriteType.withResponse);
      } else if (s == BluetoothDeviceState.disconnected){
        // send error if the connection is closed before the request completes
        if(streamController != null) {
          streamController.addError(RequestError.API_CONNECTION_CLOSED);
          disconnect();
        }
      }
    });

    return streamController.stream;
  }

  /// Authorize app
  /// 
  /// Creates a [SmartLockKey] from the [device] returned by [findSmartLockDevices] method
  Stream<SmartLockKey> authorizeApp(BluetoothDevice device, IdType typeId, int appId, String authName) {
    
    StreamController<SmartLockKey> streamController = new StreamController();
    StreamSubscription deviceCon; 
    StreamSubscription indListener;

    void disconnect() {
      streamController.close();
      streamController = null;
      indListener?.cancel();
      indListener = null;
      deviceCon?.cancel();
      deviceCon = null;
    }
  
    deviceCon = _flutterBlue.connect(device,autoConnect:false).listen((s) async{
      if(s == BluetoothDeviceState.connected) {
        BluetoothCharacteristic xter = await _findCharacteristics(device, PAIRING_SERVICE_UUID, PAIRING_GDIO_XTERISTIC_UUID);
        await device.setNotifyValue(xter, true);

        List<int> buffer = [];
        List<int> response = [];
        Uint8List ssk = Uint8List(32);
        Uint8List authId;
        Hmac hasher;  
        List<int> smartLockPublicKey;
        int challengeCmdCnt = 0;
        //calculate keypair
        KeyPair keys = KeyPair(32,32);
        TweetNaclFast.crypto_box_keypair(keys.publicKey, keys.secretKey);

        indListener = device.onValueChanged(xter).listen((values) {
          buffer.addAll(values);

          if(values.length < MAX_PACKET_LENGTH) {

            response = buffer.sublist(0,buffer.length);// copy contents of buffer
            buffer.clear(); // empty buffer

            int command = response[0]; // get command in the response
            switch(command) {
              case PUBLIC_KEY_CMD:
                
                smartLockPublicKey = response.sublist(2,response.length-2);
                // calculate DH Key
                Uint8List dhk = Uint8List(32);
                TweetNaclFast.crypto_scalarmult(dhk,  keys.secretKey, Uint8List.fromList(smartLockPublicKey));
                
                // calculate shared key
                Uint8List _sigma = Uint8List.fromList([101, 120, 112, 97, 110, 100, 32, 51, 50, 45, 98, 121, 116, 101, 32, 107]);
                Uint8List _zero = Uint8List.fromList([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]);
                if(0 != TweetNaclFast.crypto_core_hsalsa20(ssk, _zero, dhk, _sigma)){
                  streamController.addError(RequestError.API_FAILED_TO_CALC_SSK);
                  disconnect();
                }
                // create request payload
                List<int> payload = _createClientPublicKeyRequest(keys.publicKey.toList());
                //write payload
                device.writeCharacteristic(xter, payload,type: CharacteristicWriteType.withResponse);
                break;
              case CHALLENGE_CMD:
                
                challengeCmdCnt++;
                if(challengeCmdCnt == 1) {
                  // HMAC-SHA256
                  hasher = new Hmac(sha256, ssk.toList()); 
                  // create request payload
                  List<int> payload = _createAuthenticatorRequest(hasher, smartLockPublicKey, 
                    keys.publicKey.toList(), response.sublist(2,response.length-2));
                  //write payload
                  device.writeCharacteristic(xter, payload,type: CharacteristicWriteType.withResponse);
                } else if(challengeCmdCnt == 2) {
                  // create request payload
                  List<int> payload = _createAuthorizationDataRequest(hasher, typeId, appId, authName, 
                    response.sublist(2,response.length-2));
                  //write payload
                  device.writeCharacteristic(xter, payload,type: CharacteristicWriteType.withResponse);
                }
                break;
              case AUTHORIZATION_ID_CMD:
                //hash = Uint8List.fromList(response.sublist(2,34)); 
                //TODO: need to authenticate response using above hash
                authId = Uint8List.fromList(response.sublist(34,38));
                //uuid = Uint8List.fromList(response.sublist(38,54));
                
                //send authorised lock to listeners
                streamController.add(
                  SmartLockKey(
                    device.id.id, 
                    Authorization(hex.encode(authId.toList()), 
                    hex.encode(ssk.toList()),name:authName)
                  )
                );

                // create request payload
                List<int> payload = _createAuthIDConfirmationRequest(hasher, authId,  
                  response.sublist(54,response.length-2));
                //write payload
                device.writeCharacteristic(xter, payload,type: CharacteristicWriteType.withResponse);
                break;
              case STATUS_CMD:
                int status = response[2]; // get the status 
                if(status == ACCEPTED_STATUS) 
                  debugPrint('Warning: Pairing requested accepted but status complete not received from smart lock');
                else // COMPLETED_STATUS
                  debugPrint('Pairing successful');
                disconnect();
                break;
              case ERROR_REPORT_CMD: 
                streamController.addError(_requestErrors[response[2]]);
                disconnect();
                break;
              default: 
                streamController.addError(RequestError.API_UNKNOWN_ERROR);
                disconnect();
              
            }
          }
        });

        // create request payload
        List<int> payload = _createPublicKeyRequest();
        //write payload
        device.writeCharacteristic(xter, payload,type: CharacteristicWriteType.withResponse);
      } 
    });

    return streamController.stream;
  }

  /// Get [Config] of [lock]
  Stream<Config> getLockConfig(SmartLockKey lock, {Duration timeout=DEFAULT_CONNECTION_TIMEOUT}) {
    List<int> buffer = [];
    StreamController<Config> streamController = new StreamController();
    BluetoothDevice device = BluetoothDevice(id:DeviceIdentifier(lock.bluetoothId), type: BluetoothDeviceType.le);
    StreamSubscription deviceCon; 
    StreamSubscription indListener;
    
    void disconnect() {
      streamController.close();
      streamController = null;
      indListener?.cancel();
      indListener = null;
      deviceCon?.cancel();
      deviceCon = null;
    }

    deviceCon = _flutterBlue.connect(device, autoConnect: false, timeout: timeout).listen((s) async {
      if(s == BluetoothDeviceState.connected) {
        BluetoothCharacteristic xter = await _findCharacteristics(device, KEYTURNER_SERVICE_UUID, KEYTURNER_USDIO_XTERISTIC_UUID);
        await device.setNotifyValue(xter, true);

        indListener = device.onValueChanged(xter).listen((values) async{
          buffer.addAll(values);
          if(values.length < MAX_PACKET_LENGTH) {
           
            List<int> msg = _decrypt(buffer, hex.decode(lock.authorization.ssk));

            //clear buffer to receive next response
            buffer.clear();

            if(_isCrcOk(msg)) { // check crc
              if(lock.authorization.id == hex.encode(msg.sublist(0,4))) { // check authorization id
                int command = msg[4]; // get command in the response 
                
                switch(command) {
                  case CHALLENGE_CMD: 
                    // request config with the received challenge
                    List<int> payload = _createConfigRequest(lock.authorization.id,lock.authorization.ssk, 
                      msg.sublist(6,msg.length-2));
                    //write payload
                    device.writeCharacteristic(xter, payload,type: CharacteristicWriteType.withResponse);
                    break;
                  case CONFIG_CMD:
                    //send created config to listeners as a smart lock object
                    streamController.add(Config.fromBytes(msg));
                    // clean up
                    disconnect();
                    break;
                  case ERROR_REPORT_CMD: 
                    streamController.addError(_requestErrors[msg[6]]);
                    // clean up
                    disconnect();
                    break;
                  default: 
                    streamController.addError(RequestError.API_UNKNOWN_ERROR);
                    // clean up
                    disconnect();
                }

              } else {   
                  streamController.addError(RequestError.API_AUTHID_AUTHENTICATION_FAILED);
                  // clean up
                  disconnect();
              }
            } else {
                streamController.addError(RequestError.API_CRC_AUTHENTICATION_FAILED);
                // clean up
                disconnect();
            }
          }
          
        });
      
        // create request payload
        List<int> payload = _createChallengeRequest(lock.authorization.id, lock.authorization.ssk);
        //write payload
        device.writeCharacteristic(xter, payload,type: CharacteristicWriteType.withResponse);
      } else if (s == BluetoothDeviceState.disconnected){
        // send error if the connection is closed before the request completes
        //if(streamController != null) {
        //  streamController.addError(RequestError.API_CONNECTION_CLOSED);
        //  disconnect();
        //}
      }
    });

    return streamController.stream;
  }

  /// Change the security pain of [lock] from [oldPin] to [newPin]
  /// 
  //TODO: check whether pin is within 16 bit integer range
  Stream<bool> setSecurityPin(SmartLockKey lock, int oldPin, int newPin,{Duration timeout=DEFAULT_CONNECTION_TIMEOUT}) {
    
    List<int> buffer = [];
    StreamController<bool> streamController = new StreamController();
    BluetoothDevice device = BluetoothDevice(id:DeviceIdentifier(lock.bluetoothId), type: BluetoothDeviceType.le);
    StreamSubscription deviceCon; 
    StreamSubscription indListener;
    
    void disconnect() {
      streamController.close();
      streamController = null;
      indListener?.cancel();
      indListener = null;
      deviceCon?.cancel();
      deviceCon = null;
    }

    deviceCon = _flutterBlue.connect(device, autoConnect: false, timeout: timeout).listen((s) async {
      if(s == BluetoothDeviceState.connected) {
        BluetoothCharacteristic xter = await _findCharacteristics(device, KEYTURNER_SERVICE_UUID, KEYTURNER_USDIO_XTERISTIC_UUID);
        await device.setNotifyValue(xter, true);

        indListener = device.onValueChanged(xter).listen((values) async{
          buffer.addAll(values);
          if(values.length < MAX_PACKET_LENGTH) {
            
            List<int> msg = _decrypt(buffer, hex.decode(lock.authorization.ssk));
           
            //clear buffer to receive next response
            buffer.clear();

            if(_isCrcOk(msg)) { // check crc
              if(lock.authorization.id == hex.encode(msg.sublist(0,4))) { // check authorization id
                int command = msg[4]; // get command in the response 
                
                switch(command) {
                  case CHALLENGE_CMD: 
                    // request config with the received challenge
                    List<int> payload = _createSetPinRequest(lock.authorization.id,lock.authorization.ssk, 
                    oldPin, newPin, msg.sublist(6,msg.length-2));
                    //write payload
                    device.writeCharacteristic(xter, payload,type: CharacteristicWriteType.withResponse);
                    break;
                  case STATUS_CMD:
                    int status = msg[6]; // get the status 
                    if(status == ACCEPTED_STATUS) 
                      debugPrint('Warning: change pin request accepted but complete status not received');
                    
                    //send created authorization to listeners as a smart lock object
                    streamController.add(true);
                    //clean up
                    disconnect();
                    break;
                  case ERROR_REPORT_CMD: 
                    streamController.addError(_requestErrors[msg[6]]);
                    // clean up
                    disconnect();
                    break;
                  default: 
                    streamController.addError(RequestError.API_UNKNOWN_ERROR);
                    // clean up
                    disconnect();
                }

              } else {   
                  streamController.addError(RequestError.API_AUTHID_AUTHENTICATION_FAILED);
                  // clean up
                  disconnect();
              }
            } else {
                streamController.addError(RequestError.API_CRC_AUTHENTICATION_FAILED);
                // clean up
                disconnect();
            }
          }
          
        });
      
        // create request payload
        List<int> payload = _createChallengeRequest(lock.authorization.id, lock.authorization.ssk);
        //write payload
        device.writeCharacteristic(xter, payload,type: CharacteristicWriteType.withResponse);
      } else if (s == BluetoothDeviceState.disconnected){
        // send error if the connection is closed before the request completes
        if(streamController != null) {
          streamController.addError(RequestError.API_CONNECTION_CLOSED);
          disconnect();
        }
      }
    });

    return streamController.stream;
  }


  ///internal methods
  
  List<int> _createPublicKeyRequest() {

    List<int> payload = [];
    payload.addAll([REQUEST_DATA_CMD,0]); // add request data command
    payload.addAll([PUBLIC_KEY_CMD,0]); // add public key command 
    payload.addAll(Crc16Ccitt.reverseCrc(_crcCalc.convert(payload))); // calc and add CRC to payload

    return payload;
  }
  
  List<int> _createClientPublicKeyRequest(List<int> clientPublicKey) {
    List<int> payload = [];
    payload.addAll([PUBLIC_KEY_CMD,0]); // add public key command
    payload.addAll(clientPublicKey); // add client public key
    payload.addAll(Crc16Ccitt.reverseCrc(_crcCalc.convert(payload))); // calc and add CRC to payload

    return payload;

  }

  List<int> _createAuthenticatorRequest(Hmac hasher, List<int> smartLockPublicKey, List<int> clientPublicKey, List<int> challenge) {
     //calculate authenticator
    List<int> msg = [];
    msg.addAll(clientPublicKey); // add client public key
    msg.addAll(smartLockPublicKey); // add sl public key
    msg.addAll(challenge); // add challenge

    List<int> auth =  hasher.convert(msg.toList()).bytes; // authenticator

    //send authenticator to smart lock
    List<int> payload = [];
    payload.addAll([AUTHORIZATION_AUTHENTICATOR_CMD,0]); // add command id to payload
    payload.addAll(auth.toList()); // add authenticator to payload
    payload.addAll(Crc16Ccitt.reverseCrc(_crcCalc.convert(payload))); // calc and add CRC to payload

    return payload;
  }

  List<int> _createAuthorizationDataRequest(Hmac hasher, IdType typeId, int appId, String authName, List<int> challenge) {
    //generate authorization data
    List<int> msg = [];
    List<int> tid = hex.decode(typeId.index.toRadixString(16).padRight(2,'0')); // ID type 0 for App
    msg.addAll(tid); 
    List<int> aid = hex.decode(appId.toRadixString(16).padRight(8,'0')); // App ID
    msg.addAll(aid); // App ID
    var name = hex.encode(utf8.encode(authName)).padRight(64,'0'); // name text to List<int> to hex string and pad
    msg.addAll(hex.decode(name));
    List<int> nonce = TweetNaclFast.randombytes(32).toList(); // generate nonce
    msg.addAll(nonce);
    msg.addAll(challenge); // add sl challenge

    List<int> hashMsg =  hasher.convert(msg.toList()).bytes; // authenticator

    //send authenticator to smart lock
    List<int> payload = [];
    payload.addAll([AUTHORIZATION_DATA_CMD,0]); // add command id to payload
    payload.addAll(hashMsg); // add authenticator to payload
    payload.addAll(tid); // add type Id
    payload.addAll(aid); // app id
    payload.addAll(hex.decode(name)); // add name
    payload.addAll(nonce); // add  nonce
    payload.addAll(Crc16Ccitt.reverseCrc(_crcCalc.convert(payload))); // calc and add CRC to payload

    return payload;
  
  }

  List<int> _createAuthIDConfirmationRequest(Hmac hasher, List<int> authId, List<int> nonce) {
    //calculate authenticator
    List<int> msg = [];
    msg.addAll(authId); // add auth id
    msg.addAll(nonce); // add sl nonce
    
    List<int> hashMsg =  hasher.convert(msg.toList()).bytes; // authenticator
    //send authenticator to smart lock
    List<int> payload = [];
    payload.addAll([AUTHORIZATION_ID_CONFIRMATION_CMD,0]); // add command id to payload
    payload.addAll(hashMsg); // add request to payload
    payload.addAll(authId); // add type Id
    payload.addAll(Crc16Ccitt.reverseCrc(_crcCalc.convert(payload))); // calc and add CRC to payload

    return payload;
  }
  
  List<int> _createLockStateRequest(String authId, String ssk)  {
    List<int> msg = [];
    msg.addAll(hex.decode(authId)); // add authorisation id
    msg.addAll([REQUEST_DATA_CMD,0]); // add request data command
    msg.addAll([KEYTURNER_STATE_CMD,0]); // add keyturner state command
    msg.addAll(Crc16Ccitt.reverseCrc(_crcCalc.convert(msg))); // calc and add CRC to payload

    // generate nonce
    List<int> nonce = TweetNaclFast.randombytes(24).toList();
    //encrypt msg
    List<int> enmsg = _encrypt(msg, nonce, hex.decode(ssk));
    
    List<int> payload = [];
    payload.addAll(nonce); // add cnonce
    payload.addAll(hex.decode(authId)); // add authId
    payload.addAll(hex.decode(enmsg.length.toRadixString(16).padRight(4,'0'))); // add length
    payload.addAll(enmsg); // add encrypted msg

    return payload;
  }

  List<int> _createChallengeRequest(String authId, String ssk)  {
    List<int> msg = [];
    msg.addAll(hex.decode(authId)); // add authorisation id
    msg.addAll([REQUEST_DATA_CMD,0]); // add request data command
    msg.addAll([CHALLENGE_CMD,0]); // add challenge command
    msg.addAll(Crc16Ccitt.reverseCrc(_crcCalc.convert(msg))); // calc and add CRC to msg

    // generate nonce
    List<int> nonce = TweetNaclFast.randombytes(24).toList();
    //encrypt msg
    List<int> enmsg = _encrypt(msg, nonce, hex.decode(ssk));

    List<int> payload = [];
    payload.addAll(nonce); // add cnonce
    payload.addAll(hex.decode(authId)); // add authId
    payload.addAll(hex.decode(enmsg.length.toRadixString(16).padRight(4,'0'))); // add length
    payload.addAll(enmsg); // add encrypted msg

    return payload;
  }
  
  List<int> _createLockActionRequest(String authId, String ssk, 
  LockAction action, List<int> challenge)  {
    List<int> msg = [];
    msg.addAll(hex.decode(authId)); // add authorisation id
    msg.addAll([LOCK_ACTION_CMD,0]); // add Lock Action command
    msg.addAll([_lockActionCodes[action],0]); // add id of requested lock action
    msg.addAll(hex.decode('00000000')); // flag bitmasks. see developer doc under lock action command
    msg.addAll(challenge); // add challenge
    msg.addAll(Crc16Ccitt.reverseCrc(_crcCalc.convert(msg))); // calc and add CRC to msg
 
    // generate nonce
    List<int> nonce = TweetNaclFast.randombytes(24).toList();
    //encrypt msg
    List<int> enmsg = _encrypt(msg, nonce, hex.decode(ssk));

    List<int> payload = [];
    payload.addAll(nonce); // add nonce
    payload.addAll(hex.decode(authId)); // add authId
    payload.addAll(hex.decode(enmsg.length.toRadixString(16).padRight(4,'0'))); // add length
    payload.addAll(enmsg); // add encrypted msg

    return payload;
  }

  List<int> _createAuthorizationRequest(String authId, String ssk, int pin, IdType idType, 
  String authName, List<int> authSsk, DateTime startDate, DateTime endDate, DateTime startTime, 
  DateTime endTime, BluetoothCharacteristic xter, List<int> challenge) {
      //generate authorization data
   
    List<int> msg = [];
    msg.addAll(hex.decode(authId)); // add authorisation id
    msg.addAll([AUTHORIZATION_DATA_INVITE_CMD,0]); // add request data command
    var n = hex.encode(utf8.encode(authName)).padRight(64,'0'); // name text to List<int> to hex string and pad
    msg.addAll(hex.decode(n));
    List<int> tid = hex.decode(idType.index.toRadixString(16).padRight(2,'0')); // ID type 0 for App
    msg.addAll(tid); 
    
    msg.addAll(authSsk); // add authorization ssk
    msg.add(0); // remote allowed flag
    msg.add(1); // time limited flag
    msg.addAll(dateToIntArray(startDate)); // allowed from date
    msg.addAll(dateToIntArray(endDate)); // allowed until date
    msg.addAll(hex.decode('00')); // allowed weekdays
    msg.addAll([startTime.hour,startTime.minute]); // allowed from time
    msg.addAll([endTime.hour,endTime.minute]); // allowed until time
    msg.addAll(challenge); // add sl challenge

    List<int> p = hex.decode(pin.toRadixString(16).padLeft(4,'0'));

    msg.addAll([p[1],p[0]]); // add pin
    msg.addAll(Crc16Ccitt.reverseCrc(_crcCalc.convert(msg))); // calc and add CRC to msg
 
    // generate nonce
    List<int> nonce = TweetNaclFast.randombytes(24).toList();
    //encrypt msg
    List<int> enmsg = _encrypt(msg, nonce, hex.decode(ssk));
 
    List<int> payload = [];
    payload.addAll(nonce); // add nonce
    payload.addAll(hex.decode(authId)); // add authId
    payload.addAll(hex.decode(enmsg.length.toRadixString(16).padRight(4,'0'))); // add length
    payload.addAll(enmsg); // add encrypted msg

    return payload;
  }
  
  List<int> _createConfigRequest(String authId, String ssk, List<int> challenge)  {
    List<int> msg = [];
    msg.addAll(hex.decode(authId)); // add authorisation id
    msg.addAll([GET_CONFIG_CMD,0]); // add get config command
    msg.addAll(challenge); // add challenge
    msg.addAll(Crc16Ccitt.reverseCrc(_crcCalc.convert(msg))); // calc and add CRC to payload

    // generate nonce
    List<int> nonce = TweetNaclFast.randombytes(24).toList();
    //encrypt msg
    List<int> enmsg = _encrypt(msg, nonce, hex.decode(ssk));

    List<int> payload = [];
    payload.addAll(nonce); // add cnonce
    payload.addAll(hex.decode(authId)); // add authId
    payload.addAll(hex.decode(enmsg.length.toRadixString(16).padRight(4,'0'))); // add length
    payload.addAll(enmsg); // add encrypted msg

    return payload;
  }

  List<int> _createSetPinRequest(String authId, String ssk, int oldPin, int newPin, List<int> challenge)  {
    List<int> msg = [];
    msg.addAll(hex.decode(authId)); // add authorisation id
    msg.addAll([SET_PIN_CMD,0]); // add command
    // add new pin
    List<int> p = hex.decode(newPin.toRadixString(16).padLeft(4,'0'));
    msg.addAll([p[1],p[0]]); 

    msg.addAll(challenge); // add challenge

    // add old pin
    p = hex.decode(oldPin.toRadixString(16).padLeft(4,'0'));
    msg.addAll([p[1],p[0]]);

    msg.addAll(Crc16Ccitt.reverseCrc(_crcCalc.convert(msg))); // calc and add CRC to payload

    // generate nonce
    List<int> nonce = TweetNaclFast.randombytes(24).toList();
    //encrypt msg
    List<int> enmsg = _encrypt(msg, nonce, hex.decode(ssk));

    List<int> payload = [];
    payload.addAll(nonce); // add cnonce
    payload.addAll(hex.decode(authId)); // add authId
    payload.addAll(hex.decode(enmsg.length.toRadixString(16).padRight(4,'0'))); // add length
    payload.addAll(enmsg); // add encrypted msg

    return payload;
  }
  
  List<int> _decrypt(List<int> response,  List<int> key)  {

    Uint8List nonce = Uint8List.fromList(response.sublist(0,24));
    Uint8List encryptedMsg = Uint8List.fromList(response.sublist(30,response.length));
    
    SecretBox box = SecretBox(Uint8List.fromList(key));
    Uint8List decryptedMsg = box.open_nonce(encryptedMsg,nonce);

    //debugPrint('Encrypted response: ${hex.encode(response)}');
    //debugPrint('Decrypted response: ${hex.encode(decryptedMsg.toList())}');
    
    return decryptedMsg.toList();
  }
  
  List<int> _encrypt(List<int> plainMsg, List<int> nonce, List<int> key) {
    SecretBox box = SecretBox(Uint8List.fromList(key));
    return box.box_nonce(Uint8List.fromList(plainMsg),Uint8List.fromList(nonce)).toList();
  }

  bool _isCrcOk(List<int> payload) {
    int len = payload.length;
    List<int> crcCalc = Crc16Ccitt.reverseCrc(_crcCalc.convert(payload.sublist(0,len-2)));  //calculate crc of payload
    List<int> crcTrans = payload.sublist(len-2,len);  // crc transmitted with load

    for(int i=0; i<crcCalc.length; i++)
      if(crcCalc[i] != crcTrans[i])
        return false;

    return true;
  }
  
  Future<BluetoothCharacteristic> _findCharacteristics(device, String serviceUUID, 
    String xterUUID) async {
    List<BluetoothService> services = await device.discoverServices();
    for(int i=0; i<services.length; i++) {
      if(services[i].uuid.toString() == serviceUUID) {
        List<BluetoothCharacteristic> xters = services[i].characteristics;
        for(int j=0; j<xters.length; j++) {
          if(xters[j].uuid.toString() == xterUUID) 
            return xters[j];
        }
      }
    }

    return null;
  }

  List<int> dateToIntArray(DateTime dateTime) {
    List<int> out = [];

    String yrString = dateTime.year.toRadixString(16).padLeft(4,'0');
    List<int> yrInt = hex.decode(yrString);

    // note that year is reflected
    out.addAll([yrInt[1],yrInt[0],dateTime.month,dateTime.day,dateTime.hour,dateTime.minute,dateTime.second]); 

    return out;
  }
}

class Crc16Ccitt extends ParametricCrc {
  Crc16Ccitt(): super(16,0x1021,0xFFFF,0x0000,inputReflected:false, outputReflected:false);

  static List<int> reverseCrc(int crc) {
    return hex.decode(crc.toRadixString(16).padLeft(4,'0')).reversed.toList();
  }
}
