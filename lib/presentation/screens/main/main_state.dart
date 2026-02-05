import 'package:flutter/foundation.dart';

@immutable
class MainState {
  final List<bool> permissionStates;
  final bool isCheckingPermissions;
  final bool showPermissionAlert;
  final bool allPermissionsGranted;
  final bool isRequestingPermission;
  final int currentPermissionIndex;

  const MainState({
    required this.permissionStates,
    required this.isCheckingPermissions,
    required this.showPermissionAlert,
    required this.allPermissionsGranted,
    required this.isRequestingPermission,
    required this.currentPermissionIndex,
  });

  MainState copyWith({
    List<bool>? permissionStates,
    bool? isCheckingPermissions,
    bool? showPermissionAlert,
    bool? allPermissionsGranted,
    bool? isRequestingPermission,
    int? currentPermissionIndex,
  }) {
    return MainState(
      permissionStates: permissionStates ?? this.permissionStates,
      isCheckingPermissions:
          isCheckingPermissions ?? this.isCheckingPermissions,
      showPermissionAlert: showPermissionAlert ?? this.showPermissionAlert,
      allPermissionsGranted:
          allPermissionsGranted ?? this.allPermissionsGranted,
      isRequestingPermission:
          isRequestingPermission ?? this.isRequestingPermission,
      currentPermissionIndex:
          currentPermissionIndex ?? this.currentPermissionIndex,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MainState &&
        listEquals(other.permissionStates, permissionStates) &&
        other.isCheckingPermissions == isCheckingPermissions &&
        other.showPermissionAlert == showPermissionAlert &&
        other.allPermissionsGranted == allPermissionsGranted &&
        other.isRequestingPermission == isRequestingPermission &&
        other.currentPermissionIndex == currentPermissionIndex;
  }

  @override
  int get hashCode {
    return Object.hash(
      permissionStates,
      isCheckingPermissions,
      showPermissionAlert,
      allPermissionsGranted,
      isRequestingPermission,
      currentPermissionIndex,
    );
  }
}
