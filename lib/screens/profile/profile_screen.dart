import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final student = auth.student;
    if (student == null) return const SizedBox.shrink();
    String optional(String value) =>
        value.trim().isEmpty ? 'Not provided' : value;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: auth.refreshStudent,
        child: SingleChildScrollView(
          key: const PageStorageKey('profile'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 64,
                    color: AppTheme.forest,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    student.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deep,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: AppTheme.sand,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileField('Full Name', student.name),
                          _ProfileField('Email Address', student.email),
                          _ProfileField(
                            'School ID',
                            optional(student.studentId),
                          ),
                          _ProfileField(
                            'Course/Program',
                            optional(student.course),
                          ),
                          _ProfileField(
                            'Year Level',
                            optional(student.yearLevel),
                          ),
                          // The trusted Student parser accepts only active student accounts.
                          _ProfileField(
                            'Account Role',
                            student.role == 'student'
                                ? 'Student'
                                : student.role,
                          ),
                          _ProfileField(
                            'Account Status',
                            student.isActive ? 'Active' : 'Inactive',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (auth.busy)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Updating account',
                    ),
                  if (auth.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          auth.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: auth.busy ? null : auth.refreshStudent,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh profile'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: auth.busy ? null : auth.logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Log out'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Logging out also ends your existing web sessions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.forest),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(
            color: AppTheme.deep,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
