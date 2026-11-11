enum QueueMode {
  bothSingleQueue,
  homeOnly,
  lockOnly,
  separateQueues,
}

class AppSettings {
  final bool autoChangeEnabled;
  final int intervalMinutes;
  final QueueMode queueMode;
  final bool autoDownloadEnabled;
  final int queueMaxSize;
  final bool autoDeleteApplied;
  final int? lastRunAt;
  final String? lastStatusMessage;

  const AppSettings({
    this.autoChangeEnabled = false,
    this.intervalMinutes = 60,
    this.queueMode = QueueMode.bothSingleQueue,
    this.autoDownloadEnabled = true,
    this.queueMaxSize = 20,
    this.autoDeleteApplied = true,
    this.lastRunAt,
    this.lastStatusMessage,
  });

  AppSettings copyWith({
    bool? autoChangeEnabled,
    int? intervalMinutes,
    QueueMode? queueMode,
    bool? autoDownloadEnabled,
    int? queueMaxSize,
    bool? autoDeleteApplied,
    int? lastRunAt,
    String? lastStatusMessage,
  }) {
    return AppSettings(
      autoChangeEnabled: autoChangeEnabled ?? this.autoChangeEnabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      queueMode: queueMode ?? this.queueMode,
      autoDownloadEnabled: autoDownloadEnabled ?? this.autoDownloadEnabled,
      queueMaxSize: queueMaxSize ?? this.queueMaxSize,
      autoDeleteApplied: autoDeleteApplied ?? this.autoDeleteApplied,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      lastStatusMessage: lastStatusMessage ?? this.lastStatusMessage,
    );
  }
}

class QueueBoard {
  final int? id;
  final String queueType; // 'home' or 'lock'
  final String boardUrl;
  final String label;
  final int addedAt;

  const QueueBoard({
    this.id,
    required this.queueType,
    required this.boardUrl,
    required this.label,
    required this.addedAt,
  });

  factory QueueBoard.fromMap(Map<String, dynamic> map) {
    return QueueBoard(
      id: map['id'] as int?,
      queueType: map['queue_type'] as String,
      boardUrl: map['board_url'] as String,
      label: (map['label'] as String?) ?? map['board_url'] as String,
      addedAt: map['added_at'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'queue_type': queueType,
        'board_url': boardUrl,
        'label': label,
        'added_at': addedAt,
      };
}

class QueuedWallpaper {
  final int? id;
  final String queueType; // 'home' or 'lock'
  final String? pinId;
  final String imageUrl;
  final String localPath;
  final String? sourceBoard;
  final String? alt;
  final int? width;
  final int? height;
  final String status; // 'queued' or 'applied'
  final int createdAt;
  final int? appliedAt;

  const QueuedWallpaper({
    this.id,
    required this.queueType,
    this.pinId,
    required this.imageUrl,
    required this.localPath,
    this.sourceBoard,
    this.alt,
    this.width,
    this.height,
    this.status = 'queued',
    required this.createdAt,
    this.appliedAt,
  });

  bool get isApplied => status == 'applied';

  factory QueuedWallpaper.fromMap(Map<String, dynamic> map) {
    return QueuedWallpaper(
      id: map['id'] as int?,
      queueType: map['queue_type'] as String,
      pinId: map['pin_id'] as String?,
      imageUrl: map['image_url'] as String,
      localPath: map['local_path'] as String,
      sourceBoard: map['source_board'] as String?,
      alt: map['alt'] as String?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      status: map['status'] as String,
      createdAt: map['created_at'] as int,
      appliedAt: map['applied_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'queue_type': queueType,
        'pin_id': pinId,
        'image_url': imageUrl,
        'local_path': localPath,
        'source_board': sourceBoard,
        'alt': alt,
        'width': width,
        'height': height,
        'status': status,
        'created_at': createdAt,
        'applied_at': appliedAt,
      };
}

class ImportHistoryEntry {
  final String boardUrl;
  final String title;
  final int pinCount;
  final String? previewUrl;
  final int lastImportedAt;

  const ImportHistoryEntry({
    required this.boardUrl,
    required this.title,
    required this.pinCount,
    this.previewUrl,
    required this.lastImportedAt,
  });

  factory ImportHistoryEntry.fromMap(Map<String, dynamic> map) {
    return ImportHistoryEntry(
      boardUrl: map['board_url'] as String,
      title: map['title'] as String,
      pinCount: map['pin_count'] as int,
      previewUrl: map['preview_url'] as String?,
      lastImportedAt: map['last_imported_at'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
        'board_url': boardUrl,
        'title': title,
        'pin_count': pinCount,
        'preview_url': previewUrl,
        'last_imported_at': lastImportedAt,
      };
}

