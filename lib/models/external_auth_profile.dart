class ExternalAuthProfile {
  final String provider;
  final String displayName;
  final String email;

  const ExternalAuthProfile({
    required this.provider,
    required this.displayName,
    required this.email,
  });
}
