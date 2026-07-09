import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:hotconut_wallet/utils/mnemonic_generate_util.dart';
import 'package:hotconut_wallet/utils/mnemonic_scan_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SingleSignatureVault.random mnemonic length', () {
    test('generates 12-word mnemonic when mnemonicLength is 12', () {
      final vault = SingleSignatureVault.random(mnemonicLength: 12);
      final mnemonic = utf8.decode(vault.keyStore.seed.mnemonic);

      expect(mnemonic.split(' '), hasLength(12));
    });

    test('generates 24-word mnemonic when mnemonicLength is 24', () {
      final vault = SingleSignatureVault.random(mnemonicLength: 24);
      final mnemonic = utf8.decode(vault.keyStore.seed.mnemonic);

      expect(mnemonic.split(' '), hasLength(24));
    });
  });

  group('generateRandomMnemonic', () {
    test('generates 12-word mnemonic off the main isolate', () async {
      final mnemonic = await generateRandomMnemonic(mnemonicLength: 12);

      expect(mnemonic.split(' '), hasLength(12));
    });

    test('generates 24-word mnemonic off the main isolate', () async {
      final mnemonic = await generateRandomMnemonic(mnemonicLength: 24);

      expect(mnemonic.split(' '), hasLength(24));
    });

    test('builds vault from mnemonic off the main isolate', () async {
      NetworkType.setNetworkType(NetworkType.regtest);
      final mnemonic = await generateRandomMnemonic(mnemonicLength: 12, networkType: NetworkType.regtest);
      final vault = await vaultFromMnemonic(mnemonic, networkType: NetworkType.regtest);

      expect(vault.descriptor, isNotEmpty);
      NetworkType.setNetworkType(NetworkType.regtest);
      expect(() => SingleSignatureWallet.fromDescriptor(vault.descriptor), returnsNormally);
    });

    test('vault descriptor matches requested network type off the main isolate', () async {
      NetworkType.setNetworkType(NetworkType.mainnet);
      final mnemonic = await generateRandomMnemonic(mnemonicLength: 12, networkType: NetworkType.mainnet);
      final vault = await vaultFromMnemonic(mnemonic, networkType: NetworkType.mainnet);

      NetworkType.setNetworkType(NetworkType.mainnet);
      expect(() => SingleSignatureWallet.fromDescriptor(vault.descriptor), returnsNormally);
      expect(vault.descriptor.toLowerCase(), contains('zpub'));

      NetworkType.setNetworkType(NetworkType.regtest);
      expect(() => SingleSignatureWallet.fromDescriptor(vault.descriptor), throwsA(isA<Exception>()));
    });
  });

  group('normalizeMnemonicText', () {
    test('trims and collapses whitespace', () {
      expect(normalizeMnemonicText('  word1   word2\nword3  '), 'word1 word2 word3');
    });
  });
}
