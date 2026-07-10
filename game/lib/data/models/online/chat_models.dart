import 'package:equatable/equatable.dart';

/// Chat message in a game room
class ChatMessage extends Equatable {
  final String roomId;
  final String userId;
  final String displayName;
  final String text;
  final int sentAt;

  const ChatMessage({
    required this.roomId,
    required this.userId,
    required this.displayName,
    required this.text,
    required this.sentAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      roomId: json['roomId'] as String,
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      text: json['text'] as String,
      sentAt: json['sentAt'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'userId': userId,
      'displayName': displayName,
      'text': text,
      'sentAt': sentAt,
    };
  }

  @override
  List<Object?> get props => [roomId, userId, displayName, text, sentAt];
}

/// Chat reaction/emoji
class ChatReaction extends Equatable {
  final String roomId;
  final String userId;
  final String emoji;

  const ChatReaction({
    required this.roomId,
    required this.userId,
    required this.emoji,
  });

  factory ChatReaction.fromJson(Map<String, dynamic> json) {
    return ChatReaction(
      roomId: json['roomId'] as String,
      userId: json['userId'] as String,
      emoji: json['emoji'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'userId': userId,
      'emoji': emoji,
    };
  }

  @override
  List<Object?> get props => [roomId, userId, emoji];
}

/// Allowed reaction emojis (matching backend)
class AllowedEmojis {
  static const thumbsUp = '👍';
  static const clap = '👏';
  static const surprised = '😮';
  static const laughing = '😂';
  static const sad = '😢';
  static const fire = '🔥';

  static const List<String> all = [
    thumbsUp,
    clap,
    surprised,
    laughing,
    sad,
    fire,
  ];

  static bool isAllowed(String emoji) => all.contains(emoji);
}
