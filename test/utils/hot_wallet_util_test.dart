import 'package:hotconut_wallet/enums/wallet_enums.dart';
import 'package:hotconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:hotconut_wallet/providers/wallet_provider.dart';
import 'package:hotconut_wallet/utils/hot_wallet_util.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWalletListItem extends Fake implements WalletListItemBase {
  @override
  final int id;

  @override
  final WalletImportSource walletImportSource;

  _FakeWalletListItem({required this.id, required this.walletImportSource});
}

class _FakeWalletProvider extends Fake implements WalletProvider {
  _FakeWalletProvider(this._walletItems);

  final List<WalletListItemBase> _walletItems;

  @override
  List<WalletListItemBase> get walletItemList => _walletItems;
}

void main() {
  group('hasHotWallet', () {
    test('returns false when no wallets exist', () {
      final provider = _FakeWalletProvider([]);

      expect(hasHotWallet(provider), isFalse);
    });

    test('returns false when only non-hot wallets exist', () {
      final provider = _FakeWalletProvider([
        _FakeWalletListItem(id: 1, walletImportSource: WalletImportSource.coconutVault),
        _FakeWalletListItem(id: 2, walletImportSource: WalletImportSource.jade),
      ]);

      expect(hasHotWallet(provider), isFalse);
    });

    test('returns true when at least one hot wallet exists', () {
      final provider = _FakeWalletProvider([
        _FakeWalletListItem(id: 1, walletImportSource: WalletImportSource.coconutVault),
        _FakeWalletListItem(id: 2, walletImportSource: WalletImportSource.hotWallet),
      ]);

      expect(hasHotWallet(provider), isTrue);
    });
  });
}
