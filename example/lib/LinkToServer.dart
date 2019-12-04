// This class links a Nuki lock to Agnes WS

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:nuki_lock/nuki_lock.dart';

import 'AppDialogs.dart';

// Host address of Agnes WS
const AGNES_WS_ADDR = 'https://agnescontrol.pythonanywhere.com';

class LinkToServer extends StatefulWidget {
  final SmartLock lock;
  final LockConfig config;
  final SmartLockState lockState;

  LinkToServer(this.lock, this.config, this.lockState, {Key key}) : super(key: key);

  @override
  LinkToServerState createState() => LinkToServerState(lock, config,lockState);

}

class LinkToServerState extends State<LinkToServer> {

  final SmartLock lock;
  final LockConfig config;
  final SmartLockState lockState;
  final TextEditingController _oldPinCntrl = TextEditingController(text: '1234');
  final TextEditingController _newPinCntrl = TextEditingController(text: '1234');

  bool _isLinking = false;
  bool _isLinked = false;

  LinkToServerState(this.lock, this.config, this.lockState) : super();

  /// Sets the lock's Security Pin
  void setPin() async {
    // get pin code from textfield
    String oldPin = _oldPinCntrl.text;
    if (oldPin == null || oldPin == '') {
      await AppDialogs.showAlertDialog(context,'Pin Error','Enter old pin');
      return;
    }

     String newPin = _newPinCntrl.text;
    if (newPin == null || newPin == '') {
      await AppDialogs.showAlertDialog(context,'Pin Error','Enter new pin');
      return;
    }

    setState(() {
      _isLinking = true; 
    });

    SmartLockConnection connection = SmartLockConnection();

    connection.setSecurityPin(lock,int.parse(oldPin),int.parse(newPin))
      .listen((bool success) async {

        if(success) {
          //linkToServer(int.parse(newPin));
        }
        else {
          await AppDialogs.showAlertDialog(context,'Lock Error','Failed to set pin');
          setState(() {
            _isLinking = false;
          });
        }
    }, onError: (error) async {
      await AppDialogs.showAlertDialog(context,'Lock Error',
          'Request error: $error');
          setState(() {
            _isLinking = false;
          });
    });
  }

  

  @override
  Widget build(BuildContext context) {
    final TextStyle headerTxt = TextStyle(fontWeight: FontWeight.bold,fontSize: 16);
    final TextStyle bodyTxt = TextStyle(fontSize: 20);

    Widget getLinkButton() {
      return RaisedButton(
        child: Text('Link to server',style: headerTxt,),
        padding: EdgeInsets.all(20),
        textColor: Colors.white,
        color: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).primaryColor,),
          borderRadius: BorderRadius.all((Radius.circular(8)))
        ),
        onPressed: (){
          setPin();
        },
      );
    }

    Widget getStatusMsg(Widget icon, String message) {
      return Column(
        children: <Widget>[
          icon,
          Text(message, style:TextStyle(fontSize: 16, color: Colors.grey, fontStyle: FontStyle.italic))
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Link lock to server'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        //alignment: Alignment.center,
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
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child:Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Old Pin', style: headerTxt,),
                        TextField(
                          controller: _oldPinCntrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          decoration:InputDecoration (
                            border: OutlineInputBorder()
                          )
                        ),
                      ],
                    )
                  ),
                  SizedBox(width: 20,),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('New Pin', style: headerTxt,),
                        TextField(
                          controller: _newPinCntrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          decoration:InputDecoration (
                            border: OutlineInputBorder()
                          )
                        ),
                      ],
                    )
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _isLinking
                ? getStatusMsg(CircularProgressIndicator(), 'Linking lock to server')
                : _isLinked
                  ? getStatusMsg(Icon(Icons.check_circle, size: 64, color: Colors.green,), 'Successfully linked lock to server')
                  : getLinkButton()
              ],
            )
            
          ],
        ),
      ),
    );
      
  }

   @override 
  dispose() {
    _oldPinCntrl.dispose();
    _newPinCntrl.dispose();
    super.dispose();
  }
}