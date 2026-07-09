import 'package:hotconut_wallet/model/node/script_status.dart';
import 'package:hotconut_wallet/repository/realm/model/hotconut_wallet_model.dart';

UnaddressedScriptStatus mapRealmToUnaddressedScriptStatus(RealmScriptStatus realmScriptStatus) {
  return UnaddressedScriptStatus(
    scriptPubKey: realmScriptStatus.scriptPubKey,
    status: realmScriptStatus.status,
    timestamp: realmScriptStatus.timestamp,
  );
}
