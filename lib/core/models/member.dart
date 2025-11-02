import 'package:freezed_annotation/freezed_annotation.dart';

part 'member.freezed.dart';
part 'member.g.dart';

enum MemberRole {
  owner,
  partner,
}

@freezed
class Member with _$Member {
  const factory Member({
    required String uid,
    required String displayName,
    required MemberRole role,
    required double share, // Percentage as decimal (e.g., 0.7333 for 73.33%)
    @Default(0.0) double monthlySalary, // Salario mensual del miembro
    @Default(0.0) double contributedThisMonth,
    @Default([]) List<String> fcmTokens,
    @Default(null) String? email,
    @Default(null) String? photoUrl,
    @Default(null) DateTime? joinedAt,
  }) = _Member;

  factory Member.fromJson(Map<String, dynamic> json) => _$MemberFromJson(json);
}

extension MemberExtension on Member {
  double expectedContribution(double monthTarget) => monthTarget * share;
  
  double remainingContribution(double monthTarget) =>
      (expectedContribution(monthTarget) - contributedThisMonth)
          .clamp(0.0, double.infinity);
  
  double contributionProgress(double monthTarget) {
    final expected = expectedContribution(monthTarget);
    if (expected == 0) return 0.0;
    return (contributedThisMonth / expected).clamp(0.0, 1.0);
  }
  
  bool hasMetGoal(double monthTarget) =>
      contributedThisMonth >= expectedContribution(monthTarget);
}
