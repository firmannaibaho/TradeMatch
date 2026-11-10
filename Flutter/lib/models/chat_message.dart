import 'package:trade_match/models/user.dart';

class ChatMessage {
  final int id;
  final int userId;
  final String content;
  final String? type; // e.g., 'text', 'location_suggestion'
  final DateTime createdAt;
  final User? user;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.content,
    this.type,
    required this.createdAt,
    this.user,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      userId: json['user_id'],
      content: json['content'],
      type: json['type'],
      createdAt: DateTime.parse(json['created_at']),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}
