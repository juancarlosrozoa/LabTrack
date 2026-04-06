import 'package:equatable/equatable.dart';

enum LabRole { admin, manager, analyst, viewer }

extension LabRoleX on LabRole {
  String get label => switch (this) {
        LabRole.admin   => 'Admin',
        LabRole.manager => 'Manager',
        LabRole.analyst => 'Analyst',
        LabRole.viewer  => 'Viewer',
      };

  bool get canWrite     => this != LabRole.viewer;
  bool get canManage    => this == LabRole.admin || this == LabRole.manager;
  bool get isAdmin      => this == LabRole.admin;

  static LabRole fromString(String value) =>
      LabRole.values.firstWhere((r) => r.name == value, orElse: () => LabRole.viewer);
}

class LabMembership extends Equatable {
  final String labId;
  final String labName;
  final String labSlug;
  final LabRole role;

  const LabMembership({
    required this.labId,
    required this.labName,
    required this.labSlug,
    required this.role,
  });

  factory LabMembership.fromMap(Map<String, dynamic> map) => LabMembership(
        labId:   map['lab_id'] as String,
        labName: (map['laboratories'] as Map<String, dynamic>)['name'] as String,
        labSlug: (map['laboratories'] as Map<String, dynamic>)['slug'] as String,
        role:    LabRoleX.fromString(map['role'] as String),
      );

  @override
  List<Object?> get props => [labId];
}
