import 'base32.dart';
import 'otp.dart';

/// One account with its OTP secret. This is the plaintext that only ever
/// exists on the clients; the server stores it encrypted.
class OtpEntry {
  const OtpEntry({
    required this.issuer,
    required this.account,
    required this.secret,
    this.type = OtpType.totp,
    this.algorithm = OtpAlgorithm.sha1,
    this.digits = 6,
    this.period = 30,
    this.counter = 0,
    this.group = '',
    this.favorite = false,
    this.color,
    this.notes = '',
  });

  final String issuer;
  final String account;

  /// Normalized base32 secret.
  final String secret;
  final OtpType type;
  final OtpAlgorithm algorithm;
  final int digits;
  final int period;

  /// HOTP only: counter of the next code.
  final int counter;
  final String group;
  final bool favorite;

  /// ARGB colour of the avatar; null picks one from the issuer.
  final int? color;
  final String notes;

  String get displayName => issuer.isNotEmpty ? issuer : account;

  int get effectiveDigits => type == OtpType.steam ? 5 : digits;
  int get effectivePeriod => type == OtpType.steam ? 30 : period;

  String code([DateTime? time]) => Otp.generate(
    secret: secret,
    type: type,
    algorithm: algorithm,
    digits: digits,
    period: period,
    counter: counter,
    time: time,
  );

  /// Checks the parameters and throws [FormatException] with a German
  /// message when something cannot work.
  void validate() {
    if (issuer.trim().isEmpty && account.trim().isEmpty) {
      throw const FormatException('Dienst oder Konto angeben');
    }
    final key = Base32.decode(secret);
    if (key.length < 5) throw const FormatException('Schlüssel ist zu kurz');
    if (digits < 4 || digits > 10) {
      throw const FormatException('Stellen müssen zwischen 4 und 10 liegen');
    }
    if (period < 5 || period > 600) {
      throw const FormatException('Intervall muss zwischen 5 und 600 s liegen');
    }
    if (counter < 0) throw const FormatException('Zähler ist negativ');
  }

  OtpEntry copyWith({
    String? issuer,
    String? account,
    String? secret,
    OtpType? type,
    OtpAlgorithm? algorithm,
    int? digits,
    int? period,
    int? counter,
    String? group,
    bool? favorite,
    int? Function()? color,
    String? notes,
  }) => OtpEntry(
    issuer: issuer ?? this.issuer,
    account: account ?? this.account,
    secret: secret ?? this.secret,
    type: type ?? this.type,
    algorithm: algorithm ?? this.algorithm,
    digits: digits ?? this.digits,
    period: period ?? this.period,
    counter: counter ?? this.counter,
    group: group ?? this.group,
    favorite: favorite ?? this.favorite,
    color: color != null ? color() : this.color,
    notes: notes ?? this.notes,
  );

  Map<String, Object?> toJson() => {
    'v': 1,
    'issuer': issuer,
    'account': account,
    'secret': secret,
    'type': type.name,
    'algorithm': algorithm.name,
    'digits': digits,
    'period': period,
    if (type == OtpType.hotp) 'counter': counter,
    if (group.isNotEmpty) 'group': group,
    if (favorite) 'favorite': true,
    'color': ?color,
    if (notes.isNotEmpty) 'notes': notes,
  };

  factory OtpEntry.fromJson(Map<String, Object?> json) => OtpEntry(
    issuer: json['issuer'] as String? ?? '',
    account: json['account'] as String? ?? '',
    secret: Base32.normalize(json['secret'] as String? ?? ''),
    type: OtpType.parse(json['type'] as String?),
    algorithm: OtpAlgorithm.parse(json['algorithm'] as String?),
    digits: (json['digits'] as num?)?.toInt() ?? 6,
    period: (json['period'] as num?)?.toInt() ?? 30,
    counter: (json['counter'] as num?)?.toInt() ?? 0,
    group: json['group'] as String? ?? '',
    favorite: json['favorite'] as bool? ?? false,
    color: (json['color'] as num?)?.toInt(),
    notes: json['notes'] as String? ?? '',
  );

  /// True when both describe the same secret for the same account; used to
  /// skip duplicates on import.
  bool sameKeyAs(OtpEntry other) =>
      secret == other.secret &&
      type == other.type &&
      issuer.toLowerCase() == other.issuer.toLowerCase() &&
      account.toLowerCase() == other.account.toLowerCase();
}
