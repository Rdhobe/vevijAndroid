class Notice {
  final String id;
  final String title;
  final String description;
  final String category; // General, Urgent, Policy, Event
  final String postedBy;
  final DateTime createdAt;
  final String? additionalInfo;
  final bool isRead;

  Notice({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.postedBy,
    required this.createdAt,
    this.additionalInfo,
    this.isRead = false,
  });

  Notice copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? postedBy,
    DateTime? createdAt,
    String? additionalInfo,
    bool? isRead,
  }) {
    return Notice(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      postedBy: postedBy ?? this.postedBy,
      createdAt: createdAt ?? this.createdAt,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'postedBy': postedBy,
      'createdAt': createdAt.toIso8601String(),
      'additionalInfo': additionalInfo,
      'isRead': isRead,
    };
  }

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      postedBy: json['postedBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      additionalInfo: json['additionalInfo'] as String?,
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'Notice(id: $id, title: $title, category: $category, postedBy: $postedBy, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Notice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}