import 'dart:convert';

import 'package:convert/convert.dart';


class LockConfig {

  int nukiId;
  String name;

  LockConfig({this.nukiId, this.name});

   factory LockConfig.fromDeviceResponse(List<int> response) {
     
     return LockConfig(
       nukiId: int.parse(hex.encode(response.sublist(6,10).reversed.toList()),radix:16),
       name: utf8.decode(response.sublist(10,42)).replaceAll('\u0000', '')
     );
   }
}