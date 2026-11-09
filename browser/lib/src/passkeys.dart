import 'package:sixora_core/sixora_core.dart';

/// A passkey with its place in the vault.
class StoredPasskey {
  StoredPasskey(this.id, this.vaultId, this.revision, this.passkey);
  final String id;
  final String vaultId;
  final int revision;
  final PasskeyEntry passkey;
}
