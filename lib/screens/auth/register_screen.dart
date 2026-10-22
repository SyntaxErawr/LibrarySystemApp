import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/auth_validation.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{
    for (final key in [
      'name',
      'studentId',
      'email',
      'otherProgram',
      'password',
      'confirmPassword',
    ])
      key: TextEditingController(),
  };
  String? _course, _year;
  bool _hidePassword = true, _hideConfirm = true;
  final Set<String> _edited = {};

  Map<String, String> get _values => {
    for (final entry in _controllers.entries) entry.key: entry.value.text,
    'course': _course ?? '',
    'yearLevel': _year ?? '',
  };

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    _edited.clear();
    final ok = await auth.register(_values);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {});
      _form.currentState!.validate();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String key,
    String label, {
    bool password = false,
    bool confirm = false,
  }) {
    final auth = context.read<AuthProvider>();
    final hidden = confirm ? _hideConfirm : _hidePassword;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _controllers[key],
        enabled: !auth.busy,
        obscureText: password && hidden,
        autocorrect: false,
        enableSuggestions: !password,
        keyboardType: key == 'email'
            ? TextInputType.emailAddress
            : TextInputType.text,
        textInputAction: confirm ? TextInputAction.done : TextInputAction.next,
        autofillHints: password ? const [AutofillHints.newPassword] : null,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: password
              ? IconButton(
                  tooltip: hidden ? 'Show password' : 'Hide password',
                  icon: Icon(
                    hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() {
                    if (confirm) {
                      _hideConfirm = !_hideConfirm;
                    } else {
                      _hidePassword = !_hidePassword;
                    }
                  }),
                )
              : null,
        ),
        onChanged: (_) => setState(() => _edited.add(key)),
        validator: (_) =>
            AuthValidation.registration(_values)[key] ??
            (_edited.contains(key) ? null : auth.fieldErrors[key]),
        onFieldSubmitted: confirm
            ? (_) {
                if (!auth.busy) _submit();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return PopScope(
      canPop: !auth.busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Create student account')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Join your library',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF243D30),
                          ),
                        ),
                        const Text('Use the same account on web and mobile.'),
                        const SizedBox(height: 24),
                        if (auth.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
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
                        _field('name', 'Full name'),
                        _field('studentId', 'School ID'),
                        _field('email', 'Email'),
                        DropdownButtonFormField<String>(
                          initialValue: _course,
                          decoration: const InputDecoration(
                            labelText: 'Course / program',
                          ),
                          items: AuthValidation.programs
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                          onChanged: auth.busy
                              ? null
                              : (v) => setState(() {
                                  _course = v;
                                  _edited.add('course');
                                }),
                          validator: (_) =>
                              AuthValidation.registration(_values)['course'] ??
                              (_edited.contains('course')
                                  ? null
                                  : auth.fieldErrors['course']),
                        ),
                        const SizedBox(height: 16),
                        if (_course == 'Other')
                          _field('otherProgram', 'Your course / program'),
                        DropdownButtonFormField<String>(
                          initialValue: _year,
                          decoration: const InputDecoration(
                            labelText: 'Year level',
                          ),
                          items: AuthValidation.years
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                          onChanged: auth.busy
                              ? null
                              : (v) => setState(() {
                                  _year = v;
                                  _edited.add('yearLevel');
                                }),
                          validator: (_) =>
                              AuthValidation.registration(
                                _values,
                              )['yearLevel'] ??
                              (_edited.contains('yearLevel')
                                  ? null
                                  : auth.fieldErrors['yearLevel']),
                        ),
                        const SizedBox(height: 16),
                        _field('password', 'Password', password: true),
                        ...AuthValidation.passwordChecks(
                              _controllers['password']!.text,
                            ).entries
                            .where(
                              (entry) => entry.key != 'At most 72 UTF-8 bytes',
                            )
                            .map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      entry.value
                                          ? Icons.check_circle_outline
                                          : Icons.circle_outlined,
                                      size: 16,
                                      color: const Color(0xFF286444),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        const SizedBox(height: 16),
                        _field(
                          'confirmPassword',
                          'Confirm password',
                          password: true,
                          confirm: true,
                        ),
                        FilledButton(
                          onPressed: auth.busy ? null : _submit,
                          child: auth.busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Create account'),
                        ),
                        TextButton(
                          onPressed: auth.busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Already registered? Log in'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
