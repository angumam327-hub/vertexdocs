class ChatMessageModel {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isDemo;
  final String? attachedPdfName;
  final String language; // 'en' or 'ta'
  final List<String>? suggestedActions;

  const ChatMessageModel({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isDemo = true,
    this.attachedPdfName,
    this.language = 'en',
    this.suggestedActions,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isDemo': isDemo,
      'attachedPdfName': attachedPdfName,
      'language': language,
      'suggestedActions': suggestedActions,
    };
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isDemo: json['isDemo'] as bool? ?? true,
      attachedPdfName: json['attachedPdfName'] as String?,
      language: json['language'] as String? ?? 'en',
      suggestedActions: (json['suggestedActions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  ChatMessageModel copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    bool? isDemo,
    String? attachedPdfName,
    String? language,
    List<String>? suggestedActions,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isDemo: isDemo ?? this.isDemo,
      attachedPdfName: attachedPdfName ?? this.attachedPdfName,
      language: language ?? this.language,
      suggestedActions: suggestedActions ?? this.suggestedActions,
    );
  }
}
