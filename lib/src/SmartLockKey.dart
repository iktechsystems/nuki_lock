// Copyright 2020, Ikechukwu Ukaegbu.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'Authorization.dart';
/// The class encapsulate the settings required to connect and make
/// request to the smart lock
class SmartLockKey {
  final String bluetoothId; // bluetooth mac address
  final Authorization authorization;
  
  SmartLockKey(this.bluetoothId, this.authorization);

}