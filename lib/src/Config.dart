// Copyright 2020, Ikechukwu Ukaegbu.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.


import 'dart:convert';

import 'package:convert/convert.dart';

//TODO: Complete the list of configuration properties
class Config {

  int nukiId;
  String name;

  Config({this.nukiId, this.name});

  ///Deserialize configuration from byte stream 
  ///
  ///Convinience method to deserialize [Config] properties from the 
  ///decrypted [response] returned by the get config request
   factory Config.fromBytes(List<int> response) {
     
     return Config(
       nukiId: int.parse(hex.encode(response.sublist(6,10).reversed.toList()),radix:16),
       name: utf8.decode(response.sublist(10,42)).replaceAll('\u0000', '')
     );
   }
}