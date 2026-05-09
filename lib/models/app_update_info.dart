class AppUpdateInfo {
  final String latestVersion;
  final String note;
  final bool force;
  final String apkUrl;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.note,
    required this.force,
    required this.apkUrl,
  });
}
