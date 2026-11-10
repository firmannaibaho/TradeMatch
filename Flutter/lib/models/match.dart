import 'package:trade_match/models/item.dart';
import 'package:trade_match/models/user.dart';

class Match {
  final int id;
  final String status;
  final Item itemA;
  final Item itemB;
  final User userA;
  final User userB;
  final DateTime createdAt;

  Match({
    required this.id,
    required this.status,
    required this.itemA,
    required this.itemB,
    required this.userA,
    required this.userB,
    required this.createdAt,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'],
      status: json['status'],
      itemA: Item.fromJson(json['itemA']),
      itemB: Item.fromJson(json['itemB']),
      userA: User.fromJson(json['userA']),
      userB: User.fromJson(json['userB']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
