# nuki_lock

A Flutter library for controlling [Nuki Smart locks](https://nuki.io/en/smart-lock/) using bluetooth. It implements the Nuki Smart Lock [protocol](https://developer.nuki.io/c/apis/bluetooth-api/18) using a [fork](https://github.com/bpillon/flutter_blue) of the FlutterBlue bluetooth library

## Getting Started
### Find nearby Nuki Smart Locks
```
// create connection object
SmartLockConnection connection = new SmartLockConnection();

// find Nuki Smart Locks. 
Set<BluetoothDevice> devices = new LinkedHashSet();
connection.findSmartLockDevices(scanTime).listen((BluetoothDevice device){
  devices.add(device);    
});
```

### Authorize an app
```
SmartLockKey slKey;
connection.authorizeApp(devices[0],IdType.APP,12345,'MyApp').listen((SmartLockKey key){
   slKey =  key; 
 });
```

### Lock a Smart Lock
```
connection.requestLockAction(slKey, LockAction.LOCK).listen((SmartLockState state){

})
```

See the example app in the example directory for a detailed example of how to use the library

