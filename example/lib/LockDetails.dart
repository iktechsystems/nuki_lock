// This class links a Nuki lock to Agnes WS

import 'package:flutter/material.dart';
import 'package:nuki_lock/nuki_lock.dart';

import 'AppDialogs.dart';


class LockDetail extends StatefulWidget {
  final SmartLockKey lock;
  final Config config;
  final SmartLockState lockState;

  LockDetail(this.lock, this.config, this.lockState, {Key key}) : super(key: key);

  @override
  LockDetailState createState() => LockDetailState(lock, config,lockState);

}

class LockDetailState extends State<LockDetail> {

  final SmartLockKey lock;
  final Config config;
  SmartLockState lockState;


  LockDetailState(this.lock, this.config, this.lockState) : super();

  /// Sets the lock's Security Pin
  void changeLockState(LockAction action, BuildContext context,) async{
    SmartLockConnection connection =  SmartLockConnection();

    // check if bluetooth is on
    if(!await connection.isBluetoothOn()) {
      await AppDialogs.showAlertDialog(context,'Bluetooth Error', 'Switch on bluetooth to connect to lock');
      return;
    }
    
    connection.requestLockAction(lock, action).listen((SmartLockState state){
      setState(() {
        lockState = state; 
      });
    },
    onError: (error) async{
      if(error == RequestError.K_ERROR_MOTOR_LOW_VOLTAGE) {
        await AppDialogs.showAlertDialog(context,'Lock Error',
        'Weak batteries');
      } 
      else if (error == RequestError.K_ERROR_TIME_NOT_ALLOWED)
        await AppDialogs.showAlertDialog(context,'Lock Error',
        'Your access period has expired');
      else if (error == RequestError.API_CONNECTION_CLOSED)
        await AppDialogs.showAlertDialog(context,'Lock Error',
        'Failed to connect to lock. Ensure the lock is powered and that you are within Bluetooth range');
      else
        await AppDialogs.showAlertDialog(context,'Lock Error',
          'Request error: $error');
    });
  }

  
  @override
  Widget build(BuildContext context) {
    final TextStyle headerTxt = TextStyle(fontWeight: FontWeight.bold,fontSize: 16);
    final TextStyle bodyTxt = TextStyle(fontSize: 20);

    Widget createButton(LockAction action, String title) {
      return RaisedButton(
        child: Text(title,style: headerTxt,),
        padding: EdgeInsets.all(20),
        textColor: Colors.white,
        color: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).primaryColor,),
          borderRadius: BorderRadius.all((Radius.circular(8)))
        ),
        onPressed: (){
         changeLockState(action, context);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Lock details'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.only(right: 20, left: 20),
        child: ListView(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 30, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Lock Name', style: headerTxt,),
                  Text(config.name, style: bodyTxt,)
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Nuki ID', style: headerTxt,),
                  Text(config.nukiId.toString(), style: bodyTxt,)
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Status', style: headerTxt,),
                  Text(lockState.lockState==LockState.LOCKED?'Locked':'Unlocked', style: bodyTxt,)
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                lockState?.lockState==LockState.LOCKED
                  ? createButton(LockAction.UNLOCK, 'Unlock')
                  : createButton(LockAction.LOCK, 'Lock'),
              ]
            )
            
          ],
        ),
      ),
    );
      
  }

}