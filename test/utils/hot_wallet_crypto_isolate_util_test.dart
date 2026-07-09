import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_encryption.dart';
import 'package:hotconut_wallet/utils/hot_wallet_crypto_isolate_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hot_wallet_crypto_isolate_util', () {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const pin = '123456';
    const passphrase = 'test';

    late String encryptedSeedJson;
    late String wrappedDeviceKeyJson;
    late String pepperBase64;
    late String expectedDescriptor;

    setUpAll(() {
      NetworkType.setNetworkType(NetworkType.regtest);
    });

    setUp(() async {
      final deviceKey = HotWalletEncryption.generateDeviceKey();
      final pepper = HotWalletEncryption.generatePepper();
      final encrypted = await HotWalletEncryption.encryptSeed(
        const HotWalletSeedPayload(mnemonic: mnemonic),
        deviceKey,
      );
      final wrapped = await HotWalletEncryption.wrapDeviceKey(
        deviceKey: deviceKey,
        secret: pin,
        pepper: pepper,
        kdfParams: HotWalletKdfParams.fast,
      );
      encryptedSeedJson = encrypted.serialize();
      wrappedDeviceKeyJson = wrapped.serialize();
      pepperBase64 = base64Encode(pepper);
      expectedDescriptor = SingleSignatureVault.fromMnemonic(
        Uint8List.fromList(utf8.encode(mnemonic)),
        passphrase: Uint8List.fromList(utf8.encode(passphrase)),
      ).descriptor;
    });

    HotWalletUnlockParams unlockParams({String inputSecret = pin}) {
      return HotWalletUnlockParams(
        secret: inputSecret,
        encryptedSeedJson: encryptedSeedJson,
        wrappedDeviceKeyJson: wrappedDeviceKeyJson,
        pepperBase64: pepperBase64,
        networkType: NetworkType.regtest,
      );
    }

    test('unlockSeedOffMainIsolate decrypts mnemonic only payload', () async {
      final payload = await unlockSeedOffMainIsolate(unlockParams());

      expect(payload.mnemonic, mnemonic);
    });

    test('unlockSeedOffMainIsolate matches main-isolate decryption', () async {
      final deviceKey = await HotWalletEncryption.unwrapDeviceKey(
        wrapped: HotWalletWrappedDeviceKey.deserialize(wrappedDeviceKeyJson),
        secret: pin,
        pepper: base64Decode(pepperBase64),
      );
      final expected = await HotWalletEncryption.decryptSeed(
        HotWalletEncryptedPayload.deserialize(encryptedSeedJson),
        deviceKey,
      );

      final actual = await unlockSeedOffMainIsolate(unlockParams());

      expect(actual.mnemonic, expected.mnemonic);
    });

    test('unlockSeedOffMainIsolate fails for wrong secret', () async {
      await expectLater(
        unlockSeedOffMainIsolate(unlockParams(inputSecret: '999999')),
        throwsA(isA<HotWalletDecryptionException>()),
      );
    });

    test('deviceKeyOverride skips key derivation', () async {
      final deviceKey = await HotWalletEncryption.unwrapDeviceKey(
        wrapped: HotWalletWrappedDeviceKey.deserialize(wrappedDeviceKeyJson),
        secret: pin,
        pepper: base64Decode(pepperBase64),
      );
      final payload = await unlockSeedOffMainIsolate(
        HotWalletUnlockParams(
          secret: '',
          encryptedSeedJson: encryptedSeedJson,
          wrappedDeviceKeyJson: wrappedDeviceKeyJson,
          pepperBase64: '',
          networkType: NetworkType.regtest,
          deviceKeyOverride: deviceKey,
        ),
      );
      expect(payload.mnemonic, mnemonic);
    });

    test('vaultFromPayloadOffMainIsolate matches sync vault creation', () async {
      final expected = SingleSignatureVault.fromMnemonic(
        Uint8List.fromList(utf8.encode(mnemonic)),
        passphrase: Uint8List.fromList(utf8.encode(passphrase)),
      );
      final actual = await vaultFromPayloadOffMainIsolate(
        HotWalletVaultFromPayloadParams(mnemonic: mnemonic, passphrase: passphrase, networkType: NetworkType.regtest),
      );

      expect(actual.descriptor, expected.descriptor);
    });

    test('signPsbtOffMainIsolate rejects wrong passphrase via descriptor check', () async {
      await expectLater(
        signPsbtOffMainIsolate(
          HotWalletSignPsbtParams(
            secret: pin,
            encryptedSeedJson: encryptedSeedJson,
            wrappedDeviceKeyJson: wrappedDeviceKeyJson,
            pepperBase64: pepperBase64,
            networkType: NetworkType.regtest,
            unsignedPsbtBase64: 'cHNidP8=',
            passphrase: 'wrong',
            expectedDescriptor: expectedDescriptor,
          ),
        ),
        throwsA(isA<HotWalletPassphraseMismatchException>()),
      );
    });

    test('signPsbtOffMainIsolate fails for invalid psbt', () async {
      await expectLater(
        signPsbtOffMainIsolate(
          HotWalletSignPsbtParams(
            secret: pin,
            encryptedSeedJson: encryptedSeedJson,
            wrappedDeviceKeyJson: wrappedDeviceKeyJson,
            pepperBase64: pepperBase64,
            networkType: NetworkType.regtest,
            unsignedPsbtBase64: 'cHNidP8=',
            passphrase: passphrase,
            expectedDescriptor: expectedDescriptor,
          ),
        ),
        throwsA(anything),
      );
    });
  });
}
