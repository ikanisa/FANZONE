class PrivacySettingsModel {
  const PrivacySettingsModel({
    this.showNameOnLeaderboards = false,
    this.allowFanDiscovery = false,
  });

  final bool showNameOnLeaderboards;
  final bool allowFanDiscovery;

  static const defaults = PrivacySettingsModel();

  PrivacySettingsModel copyWith({
    bool? showNameOnLeaderboards,
    bool? allowFanDiscovery,
  }) {
    return PrivacySettingsModel(
      showNameOnLeaderboards:
          showNameOnLeaderboards ?? this.showNameOnLeaderboards,
      allowFanDiscovery: allowFanDiscovery ?? this.allowFanDiscovery,
    );
  }
}
