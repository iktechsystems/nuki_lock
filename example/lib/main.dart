// Copyright 2020, Ikechukwu Ukaegbu.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:nuki_lock/nuki_lock.dart';
import 'FindSmartLock.dart';

void main() => runApp(LockSetup());

class LockSetup extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    SmartLockConnection connection = SmartLockConnection();
    return MaterialApp(
      title: 'Agnes Lock Setup',
      theme: ThemeData(
      
        primarySwatch: Colors.blue,
      ),
   
      home: FutureBuilder(
        future: connection.isBluetoothSupported(),
        builder: (context, snapshot){
          if(snapshot.hasData){
            if(snapshot.data) // Bluetooth supported
              return FindSmartLock();
            else  // no bluetooth found on device
              return buildStatusView('Bluetooth not found. You need Bluetooth to run this app');
          }
          return buildStatusView('Checking for Bluetooth');
        },
      )
    );
  }

  Widget buildStatusView(String message) {

    return Scaffold(
      body: Center(
        child: Text(
          message, 
          textAlign: TextAlign.center,
          style: TextStyle(
            fontStyle: FontStyle.italic, 
            color: Colors.grey, 
            fontSize: 18
          ),
        ),
      ),
    );
  }
}
