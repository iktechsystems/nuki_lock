
enum IdType {APP, BRIDGE, FOB, KEYPAD}

class Authorization {
  final String authId; // authorisation Id
  final String ssk; // Shared secret key
  final String authName;
  final IdType idType;
  final DateTime allowedFromDate;
  final DateTime allowedUntilDate;
  final DateTime allowedFromTime;
  final DateTime allowedUntilTime;
  

  Authorization(this.authId, this.ssk,{this.idType,this.authName, this.allowedFromDate,
    this.allowedUntilDate,this.allowedFromTime,this.allowedUntilTime});
}