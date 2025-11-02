import 'package:freezed_annotation/freezed_annotation.dart';

part 'contribution.freezed.dart';
part 'contribution.g.dart';

@freezed
class Contribution with _$Contribution {
  const factory Contribution({
    required String id,
    required String by, // User UID
    required double amount,
    required DateTime date,
    @Default('') String note,
    @Default(null) String? byDisplayName,
    @Default(null) DateTime? createdAt,
  }) = _Contribution;

  factory Contribution.fromJson(Map<String, dynamic> json) =>
      _$ContributionFromJson(json);
}
