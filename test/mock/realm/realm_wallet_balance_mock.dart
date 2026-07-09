import 'package:hotconut_wallet/repository/realm/model/hotconut_wallet_model.dart';

class RealmWalletBalanceMock {
  static RealmWalletBalance getMock({
    int id = 1,
    int walletId = 1,
    int total = 1500,
    int confirmed = 1000,
    int unconfirmed = 500,
  }) {
    return RealmWalletBalance(id, walletId, total, confirmed, unconfirmed);
  }
}
