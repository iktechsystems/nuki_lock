// This class searches for nearby Nuki locks and connect to 
// the selected lock to create a master authorisation and 
// retrieves the lock's information

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:nuki_lock/nuki_lock.dart';

import 'AppDialogs.dart';
import 'LockDetails.dart';

class FindSmartLock extends StatefulWidget {
  FindSmartLock({Key key, this.title}) : super(key: key);

  final String title;

  @override
  FindSmartLockState createState() => new FindSmartLockState();
  
}

class FindSmartLockState extends State<FindSmartLock> {

  Set<BluetoothDevice> devices = new LinkedHashSet();
  Duration scanTime = Duration(seconds: 5);
  String statusMsg = 'Click the search button to search for nearby Nuki locks';
  String defaultProgressMsg = 'Please wait';

  StreamController<String> progMsg = StreamController<String>.broadcast();

  /// Search for nearby Nuki locks
  /// 
  /// Stores found locks in [devices]
  void findDevices(BuildContext context) async {

    SmartLockConnection connection = new SmartLockConnection();

    // check if bluetooth is on
    if(!await connection.isBluetoothOn()) {
      await AppDialogs.showAlertDialog(context,'Bluetooth Error', 'Switch on bluetooth to search for Nuki locks');
      return;
    }
    
    devices.clear();
    
    StreamSubscription<BluetoothDevice> scanSubscription;
    scanSubscription = connection.findSmartLockDevices(scanTime).listen((device){
      progMsg.add('Found ${device.name}');
      setState(() {
       devices.add(device); 
      });
    }, onDone:(){
      scanSubscription?.cancel();
      scanSubscription = null;
      Navigator.pop(context);
      if(devices.isEmpty)
        setState(() {
          statusMsg = 'No Nuki locks found. Click search button to search again'; 
        });
    }); 

    defaultProgressMsg = 'Searching for Nuki locks';
    showProgressDialog(context);
  }

  ///Connects to the selected Nuki lock to create a master authorisation and 
  /// retrieves the lock's ID, name and status
  void connectToLock(BuildContext context, BluetoothDevice device) async {

     SmartLockConnection connection = new SmartLockConnection();

    // check if bluetooth is on
    if(!await connection.isBluetoothOn()) {
      await AppDialogs.showAlertDialog(context,'Bluetooth Error', 'Switch on bluetooth to connect to lock');
      return;
    }

    SmartLockKey lock;
    Config config;
    connection.authorizeApp(device,IdType.APP,12345,'MyApp').listen((SmartLockKey sl){
      progMsg.add('Successfully connected to ${device.name}');
      lock = sl;
    },onDone: (){
      if(lock == null) 
        return;
      progMsg.add('Retrieving information from ${device.name}');
      connection.getLockConfig(lock).listen((Config lc){
        config = lc;
      }, onDone: (){
        connection.getLockState(lock).listen((SmartLockState sls){
          Navigator.pop(context);
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(
              builder: (context)=>LockDetail(lock,config,sls)
            )
          );
        }, onError: (error) async{
            await AppDialogs.showAlertDialog(context,'Lock Error',
              'Request error: $error');
            Navigator.pop(context);
        });

      }, onError: (error) async{
          await AppDialogs.showAlertDialog(context,'Lock Error',
            'Request error: $error');
          Navigator.pop(context);
      });

    },onError: (error) async{
      if (error == RequestError.P_ERROR_NOT_PAIRING)
        await AppDialogs.showAlertDialog(context,'Lock Error',
          'Lock not in pairing mode');
      else
         await AppDialogs.showAlertDialog(context,'Lock Error',
          'Request error: $error');
      Navigator.pop(context);
    });
  
    defaultProgressMsg = 'Connecting to ${device.name}';
    showProgressDialog(context);
  }

  Future showProgressDialog(BuildContext context) {

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Container(
          child: Row(
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(width: 5,),
              Expanded(
                child: StreamBuilder(
                  stream: progMsg.stream,
                  builder: (BuildContext context, AsyncSnapshot<String> snapshot){
                    if(snapshot.data != null)
                      return Text(
                        snapshot.data,
                        softWrap: true,
                        textAlign: TextAlign.center,
                      );
                    else
                      return Text(
                        defaultProgressMsg,
                        softWrap: true,
                        textAlign: TextAlign.center,
                      );
                  },
                )
              )          
            ],
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(7))
          ),
        ),
      
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
   
    Widget getBody() {
      return ListView.builder(
          itemCount: devices.length,
          itemBuilder: (context, index){
            return ListTile(
              title: Row(
                children: <Widget>[
                  Icon(Icons.bluetooth),
                  SizedBox(width: 5,),
                  Text(devices.elementAt(index).name),
                ],
              ),
              subtitle: Text('Put lock in pairing mode and tap to authorize'),
              onTap: (){
                connectToLock(context, devices.elementAt(index));
              },
            );
          },
        );
    }

    Widget getStatusWidget() {
      return Container(
        alignment: Alignment.center,
        child: Text(
          statusMsg, 
          textAlign: TextAlign.center,
          style: TextStyle(
            fontStyle: FontStyle.italic, 
            color: Colors.grey, 
            fontSize: 18
          ),
        )
      );
    }
  
    return Scaffold(
      appBar: AppBar(
        title: Text('Nearby Nuki locks'),
      ),
      body: devices.isEmpty ? getStatusWidget() : getBody(),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.search),
        onPressed: (){
          findDevices(context);
        },
      ),
    );
  }

  @override
  void dispose() {
    progMsg.close();
    super.dispose();
  }
}
