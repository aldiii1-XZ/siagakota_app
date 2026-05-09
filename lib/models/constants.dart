import 'package:flutter/material.dart';
import '../theme.dart';

enum ReportStatus { diterima, proses, selesai }

enum ExportFormat { csv, pdf, doc, print }

const List<String> kecamatanPalembang = [
  'SEMUA WILAYAH',
  'Alang-Alang Lebar',
  'Bukit Kecil',
  'Gandus',
  'Ilir Barat I',
  'Ilir Barat II',
  'Ilir Timur I',
  'Ilir Timur II',
  'Ilir Timur III',
  'Jakabaring',
  'Kalidoni',
  'Kemuning',
  'Kertapati',
  'Plaju',
  'Sako',
  'Seberang Ulu I',
  'Seberang Ulu II',
  'Sematang Borang',
  'Sukarami',
];

extension ReportStatusText on ReportStatus {
  String get label {
    switch (this) {
      case ReportStatus.diterima:
        return 'Diterima';
      case ReportStatus.proses:
        return 'Proses';
      case ReportStatus.selesai:
        return 'Selesai';
    }
  }

  Color get color {
    switch (this) {
      case ReportStatus.diterima:
        return AppTheme.warning;
      case ReportStatus.proses:
        return AppTheme.info;
      case ReportStatus.selesai:
        return AppTheme.success;
    }
  }
}
