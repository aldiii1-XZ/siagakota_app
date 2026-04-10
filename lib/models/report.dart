import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

enum ReportStatus { pending, inProgress, resolved }

class Report {
  final String id;
  final String title;
  final String description;
  final String type;
  final double latitude;
  final double longitude;
  final double severity;
  final String district;
  final String? photoPath;
  final Uint8List? photoBytes;
  final DateTime createdAt;
  final String reporter;
  ReportStatus status;
  int votes;

  Report({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.district,
    this.photoPath,
    this.photoBytes,
    required this.createdAt,
    required this.reporter,
    this.status = ReportStatus.pending,
    this.votes = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type,
    'latitude': latitude,
    'longitude': longitude,
    'severity': severity,
    'district': district,
    'photoPath': photoPath,
    'photoBytes': photoBytes != null ? base64Encode(photoBytes!) : null,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'votes': votes,
    'reporter': reporter,
  };

  factory Report.fromJson(Map<String, dynamic> json) => Report(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    type: json['type'] as String? ?? 'Flood',
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    severity: (json['severity'] as num).toDouble(),
    district: json['district'] as String? ?? 'Ilir Barat I',
    photoPath: json['photoPath'] as String?,
    photoBytes: json['photoBytes'] != null 
        ? base64Decode(json['photoBytes'] as String) 
        : null,
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: ReportStatus.values.firstWhere(
      (e) => e.name == (json['status'] as String?),
      orElse: () => ReportStatus.pending,
    ),
    votes: json['votes'] as int? ?? 0,
    reporter: json['reporter'] as String? ?? '',
  );

  String get statusLabel {
    switch (status) {
      case ReportStatus.pending: return 'PENDING';
      case ReportStatus.inProgress: return 'PROSES';
      case ReportStatus.resolved: return 'SELESAI';
    }
  }

  Color get statusColor {
    switch (status) {
      case ReportStatus.pending: return Colors.orange;
      case ReportStatus.inProgress: return Colors.blue;
      case ReportStatus.resolved: return Colors.green;
    }
  }

  bool get isActive => status != ReportStatus.resolved;

  int get supportCount => votes;

  double priorityScore(DateTime now) {
    final Duration age = now.difference(createdAt);
    final double ageHours = age.inHours.toDouble();
    
    // Decay factor: older reports are weighted less (exponential decay)
    final double ageFactor = math.pow(2, (-ageHours / 12)).toDouble();
    
    // Severity (0-1 scale): 0 means low, 1 means high
    final double severityWeight = severity / 100;
    
    // Support factor: more votes increase score
    final double supportWeight = 1 + (votes / 10);
    
    // Status factor: active reports are weighted more
    final double statusFactor = isActive ? 1.5 : 0.5;
    
    return severityWeight * supportWeight * statusFactor * ageFactor;
  }

  String priorityLabel(DateTime now) {
    final double score = priorityScore(now);
    if (score >= 0.7) return 'SANGAT TINGGI';
    if (score >= 0.5) return 'TINGGI';
    if (score >= 0.3) return 'SEDANG';
    return 'RENDAH';
  }

  Color priorityColor(DateTime now) {
    final double score = priorityScore(now);
    if (score >= 0.7) return Colors.red;
    if (score >= 0.5) return Colors.orange;
    if (score >= 0.3) return Colors.yellow;
    return Colors.green;
  }

  Report copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    double? latitude,
    double? longitude,
    double? severity,
    String? district,
    String? photoPath,
    Uint8List? photoBytes,
    DateTime? createdAt,
    String? reporter,
    ReportStatus? status,
    int? votes,
  }) => Report(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    type: type ?? this.type,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    severity: severity ?? this.severity,
    district: district ?? this.district,
    photoPath: photoPath ?? this.photoPath,
    photoBytes: photoBytes ?? this.photoBytes,
    createdAt: createdAt ?? this.createdAt,
    reporter: reporter ?? this.reporter,
    status: status ?? this.status,
    votes: votes ?? this.votes,
  );
}

