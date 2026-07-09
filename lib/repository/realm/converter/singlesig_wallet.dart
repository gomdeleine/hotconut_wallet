import 'package:hotconut_wallet/enums/wallet_enums.dart';
import 'package:hotconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:hotconut_wallet/repository/realm/model/hotconut_wallet_model.dart';

SinglesigWalletListItem mapRealmToSingleSigWalletItem(
  RealmWalletBase realmWalletBase,
  String? decryptedDescriptor,
  WalletImportSource? walletImportSource,
) {
  return SinglesigWalletListItem(
    id: realmWalletBase.id,
    name: realmWalletBase.name,
    colorIndex: realmWalletBase.colorIndex,
    iconIndex: realmWalletBase.iconIndex,
    descriptor: decryptedDescriptor ?? realmWalletBase.descriptor,
    receiveUsedIndex: realmWalletBase.usedReceiveIndex,
    changeUsedIndex: realmWalletBase.usedChangeIndex,
    walletImportSource: walletImportSource ?? WalletImportSource.coconutVault,
  );
}
