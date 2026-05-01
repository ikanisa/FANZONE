class PrivacySettingsModel {
  const PrivacySettingsModel({
    this.showNameInPoolActivity = false,
    this.allowFanDiscovery = false,
  });

  final bool showNameInPoolActivity;
  final bool allowFanDiscovery;

  static const defaults = PrivacySettingsModel();

  PrivacySettingsModel copyWith({
    bool? showNameInPoolActivity,
    bool? allowFanDiscovery,
  }) {
    return PrivacySettingsModel(
      showNameInPoolActivity:
          showNameInPoolActivity ?? this.showNameInPoolActivity,
      allowFanDiscovery: allowFanDiscovery ?? this.allowFanDiscovery,
    );
  }
}
