/// Exported for use in PromptBuilder only.
/// The real IntentModel lives in models/models.dart.
/// This file contains only the static role-scope helper used by prompt_builder.dart.
class BasePromptHelper {
  BasePromptHelper._();

  static String roleScopeInstruction(String role, String? deptCode) {
    switch (role) {
      case 'hod':
        return 'User is HOD of $deptCode. '
            'Default department = "$deptCode" when none is mentioned. '
            'Never return data for other departments unless explicitly requested.';
      case 'faculty':
        return 'User is Faculty in $deptCode. '
            'Scope all queries to department "$deptCode" by default.';
      case 'vc':
      case 'admin':
        return 'User has university-wide access. '
            'Do NOT auto-scope to any department unless named.';
      case 'student':
        return 'User is a student. Scope to their own records only.';
      default:
        return 'Standard access. Scope as specified in query.';
    }
  }
}