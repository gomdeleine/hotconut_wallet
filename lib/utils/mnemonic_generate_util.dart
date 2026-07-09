import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter/foundation.dart';

class _MnemonicGenerateParams {
  final int mnemonicLength;
  final NetworkType networkType;

  const _MnemonicGenerateParams(this.mnemonicLength, this.networkType);
}

class _VaultFromMnemonicParams {
  final String mnemonic;
  final String passphrase;
  final NetworkType networkType;

  const _VaultFromMnemonicParams(this.mnemonic, this.passphrase, this.networkType);
}

Future<String> generateRandomMnemonic({required int mnemonicLength, NetworkType? networkType}) {
  return compute(
    _generateRandomMnemonic,
    _MnemonicGenerateParams(mnemonicLength, networkType ?? NetworkType.currentNetworkType),
  );
}

Future<SingleSignatureVault> vaultFromMnemonic(String mnemonic, {String passphrase = '', NetworkType? networkType}) {
  return compute(
    _vaultFromMnemonic,
    _VaultFromMnemonicParams(mnemonic, passphrase, networkType ?? NetworkType.currentNetworkType),
  );
}

String _generateRandomMnemonic(_MnemonicGenerateParams params) {
  NetworkType.setNetworkType(params.networkType);
  final seed = Seed.random(mnemonicLength: params.mnemonicLength);
  return utf8.decode(seed.mnemonic);
}

SingleSignatureVault _vaultFromMnemonic(_VaultFromMnemonicParams params) {
  NetworkType.setNetworkType(params.networkType);
  final mnemonicBytes = Uint8List.fromList(utf8.encode(params.mnemonic));
  final passphraseBytes = params.passphrase.isEmpty ? null : Uint8List.fromList(utf8.encode(params.passphrase));
  return SingleSignatureVault.fromMnemonic(mnemonicBytes, passphrase: passphraseBytes);
}
