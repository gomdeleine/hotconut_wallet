import 'package:hotconut_wallet/model/node/script_status.dart';
import 'package:hotconut_wallet/repository/realm/model/hotconut_wallet_model.dart';

class UpdateAddressBalanceDto {
  final ScriptStatus scriptStatus;
  final int confirmed;
  final int unconfirmed;

  int get total => confirmed + unconfirmed;

  UpdateAddressBalanceDto({required this.scriptStatus, required this.confirmed, required this.unconfirmed});
}

class AddressBalanceCalculationResult {
  final RealmWalletAddress realmAddress;

  final int confirmedDiff;
  final int unconfirmedDiff;
  final int newConfirmed;
  final int newUnconfirmed;
  int get newTotal => newConfirmed + newUnconfirmed;

  AddressBalanceCalculationResult({
    required this.realmAddress,
    required this.confirmedDiff,
    required this.unconfirmedDiff,
    required this.newConfirmed,
    required this.newUnconfirmed,
  });
}
