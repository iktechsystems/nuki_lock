# nuki_lock

A Flutter library for controlling [Nuki Smart locks](https://nuki.io/en/smart-lock/) using bluetooth. It implements the Nuki Smart Lock [protocol](https://developer.nuki.io/c/apis/bluetooth-api/18) using a [fork](https://github.com/bpillon/flutter_blue) of the FlutterBlue bluetooth library

## Getting Started
### Find nearby Nuki Smart Locks
```
// create connection object
SmartLockConnection connection = new SmartLockConnection();

// find Nuki Smart Locks
connection.findSmartLockDevices(scanTime).listen((BluetoothDevice device){
      
});
```

### Authorize an app
```
SmartLockKey lock;
    
connection.authorizeApp(device,IdType.APP,12345,'MyApp').listen((SmartLockKey sl){
      
 });
```
