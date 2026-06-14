enum TimerStatus { running, ended, cancelled }

class ActiveTimer {
  final int childId;
  final String childName;
  final String childAvatar;
  final int ruleId;
  final String ruleName;
  final String ruleIcon;
  final int minutesChange;
  final DateTime startAt;
  final int durationSec; // 1..86400
  final TimerStatus status;

  const ActiveTimer({
    required this.childId,
    required this.childName,
    required this.childAvatar,
    required this.ruleId,
    required this.ruleName,
    required this.ruleIcon,
    required this.minutesChange,
    required this.startAt,
    required this.durationSec,
    this.status = TimerStatus.running,
  });

  DateTime get fireAt =>
      startAt.add(Duration(seconds: durationSec));

  int remainingSecondsAt(DateTime now) {
    final elapsed = now.difference(startAt).inSeconds;
    final remain = durationSec - elapsed;
    return remain < 0 ? 0 : remain;
  }

  ActiveTimer copyWith({TimerStatus? status}) => ActiveTimer(
        childId: childId,
        childName: childName,
        childAvatar: childAvatar,
        ruleId: ruleId,
        ruleName: ruleName,
        ruleIcon: ruleIcon,
        minutesChange: minutesChange,
        startAt: startAt,
        durationSec: durationSec,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'childId': childId,
        'childName': childName,
        'childAvatar': childAvatar,
        'ruleId': ruleId,
        'ruleName': ruleName,
        'ruleIcon': ruleIcon,
        'minutesChange': minutesChange,
        'startAt': startAt.toIso8601String(),
        'durationSec': durationSec,
        'status': status.name,
      };

  factory ActiveTimer.fromJson(Map<String, dynamic> json) => ActiveTimer(
        childId: json['childId'] as int,
        childName: json['childName'] as String,
        childAvatar: json['childAvatar'] as String,
        ruleId: json['ruleId'] as int,
        ruleName: json['ruleName'] as String,
        ruleIcon: json['ruleIcon'] as String,
        minutesChange: json['minutesChange'] as int,
        startAt: DateTime.parse(json['startAt'] as String),
        durationSec: json['durationSec'] as int,
        status: TimerStatus.values.byName(json['status'] as String),
      );
}
