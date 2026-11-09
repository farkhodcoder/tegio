/// `POST /staff/stamp` natijasi. Xato kodlari `apply_stamp` SQL funksiyasi bilan bir xil (B-25).
enum StampError {
  qrInvalid('qr_invalid'),
  qrExpired('qr_expired'),
  qrUsed('qr_used'),
  intervalLimit('interval_limit'),
  wrongBusiness('wrong_business'),
  cardNotFound('card_not_found'),
  programDisabled('program_disabled'),
  unknown('');

  const StampError(this.code);

  final String code;

  static StampError fromCode(String? code) =>
      StampError.values.firstWhere((error) => error.code == code, orElse: () => StampError.unknown);
}

class EarnedReward {
  const EarnedReward({required this.id, required this.title});

  factory EarnedReward.fromJson(Map<String, dynamic> json) =>
      EarnedReward(id: json['id'] as String, title: json['title'] as String);

  final String id;
  final String title;
}

sealed class StampOutcome {
  const StampOutcome();

  factory StampOutcome.fromJson(Map<String, dynamic> json) {
    if (json['ok'] != true) {
      return StampRejected(
        error: StampError.fromCode(json['error'] as String?),
        retryAt: DateTime.tryParse(json['retry_at'] as String? ?? ''),
      );
    }
    List<EarnedReward> rewards(String key) => (json[key] as List? ?? const [])
        .map((item) => EarnedReward.fromJson(item as Map<String, dynamic>))
        .toList();
    return StampApplied(
      stamps: json['stamps'] as int,
      duplicate: json['duplicate'] == true,
      newRewards: rewards('new_rewards'),
      availableRewards: rewards('available_rewards'),
    );
  }
}

class StampApplied extends StampOutcome {
  const StampApplied({
    required this.stamps,
    required this.duplicate,
    required this.newRewards,
    required this.availableRewards,
  });

  final int stamps;
  final bool duplicate;
  final List<EarnedReward> newRewards;
  final List<EarnedReward> availableRewards;
}

class StampRejected extends StampOutcome {
  const StampRejected({required this.error, this.retryAt});

  final StampError error;
  final DateTime? retryAt;
}
