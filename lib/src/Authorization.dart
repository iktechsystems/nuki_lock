
// Copyright 2020, Ikechukwu Ukaegbu.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

enum IdType {APP, BRIDGE, FOB, KEYPAD}

//TODO: Complete the list of Authorization properties
class Authorization {
 
  final String id;  // id is stored as hex string for convenience
  final String ssk; // Shared secret key
  final String name;
  final IdType idType;
  final DateTime allowedFromDate;
  final DateTime allowedUntilDate;
  final DateTime allowedFromTime;
  final DateTime allowedUntilTime;
  

  Authorization(this.id, this.ssk,{this.idType,this.name, this.allowedFromDate,
    this.allowedUntilDate,this.allowedFromTime,this.allowedUntilTime});
}