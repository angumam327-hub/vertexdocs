import 'dart:io';
import '../utils/file_utils.dart';

class PdfFileModel {
  final String id;
  final String name;
  final String path;
  final int size;
  final int? pageCount;
  final DateTime lastModified;
  final String operationType;
  final bool isEncrypted;

  const PdfFileModel({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    this.pageCount,
    required this.lastModified,
    this.operationType = 'Processed',
    this.isEncrypted = false,
  });

  String get formattedSize => FileUtils.formatBytes(size);

  String get formattedDate => FileUtils.formatDate(lastModified);

  String get formattedDateTime => FileUtils.formatDateTime(lastModified);

  bool get existsOnDisk => File(path).existsSync();

  PdfFileModel copyWith({
    String? id,
    String? name,
    String? path,
    int? size,
    int? pageCount,
    DateTime? lastModified,
    String? operationType,
    bool? isEncrypted,
  }) {
    return PdfFileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      pageCount: pageCount ?? this.pageCount,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      isEncrypted: isEncrypted ?? this.isEncrypted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'size': size,
      'pageCount': pageCount,
      'lastModified': lastModified.toIso8601String(),
      'operationType': operationType,
      'isEncrypted': isEncrypted,
    };
  }

  factory PdfFileModel.fromJson(Map<String, dynamic> json) {
    return PdfFileModel(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Untitled.pdf',
      path: json['path'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      pageCount: (json['pageCount'] as num?)?.toInt(),
      lastModified: json['lastModified'] != null
          ? DateTime.tryParse(json['lastModified'] as String) ?? DateTime.now()
          : DateTime.now(),
      operationType: json['operationType'] as String? ?? 'Processed',
      isEncrypted: json['isEncrypted'] as bool? ?? false,
    );
  }

  factory PdfFileModel.fromFile(
    File file, {
    int? pageCount,
    String operationType = 'Processed',
    bool isEncrypted = false,
  }) {
    final name = file.path.split(Platform.pathSeparator).last;
    final stat = file.existsSync() ? file.statSync() : null;
    return PdfFileModel(
      id: '${file.path}_${stat?.modified.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}',
      name: name,
      path: file.path,
      size: stat?.size ?? 0,
      pageCount: pageCount,
      lastModified: stat?.modified ?? DateTime.now(),
      operationType: operationType,
      isEncrypted: isEncrypted,
    );
  }
}
