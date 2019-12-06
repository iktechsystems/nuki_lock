
enum IdType {APP, BRIDGE, FOB, KEYPAD}

//TODO: Complete the list of Authorization properties
class Authorization {
  /// [id] is stored as hex string for convenience
  final String id; 
  // Shared secret key
  final String ssk; 
  final String name;
  final IdType idType;
  final DateTime allowedFromDate;
  final DateTime allowedUntilDate;
  final DateTime allowedFromTime;
  final DateTime allowedUntilTime;
  

  Authorization(this.id, this.ssk,{this.idType,this.name, this.allowedFromDate,
    this.allowedUntilDate,this.allowedFromTime,this.allowedUntilTime});
}