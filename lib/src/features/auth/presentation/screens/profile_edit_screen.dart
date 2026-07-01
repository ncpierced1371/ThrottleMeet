import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/auth_bootstrap_controller.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.authController});

  final AuthBootstrapController authController;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  static const _maximumDisplayNameLength = 40;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _avatarUrlController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.authController.profile;
    _displayNameController = TextEditingController(
      text: profile?.displayName ?? '',
    );
    _avatarUrlController = TextEditingController(
      text: profile?.avatarUrl ?? '',
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Your beta profile',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the name other beta testers will recognize. Event '
              'organizer names remain managed per event for now.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('profile-display-name-field'),
                    controller: _displayNameController,
                    enabled: !_isSaving,
                    maxLength: _maximumDisplayNameLength,
                    maxLengthEnforcement: MaxLengthEnforcement.none,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      hintText: 'How should people recognize you?',
                    ),
                    validator: _validateDisplayName,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile-avatar-url-field'),
                    controller: _avatarUrlController,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Avatar URL (optional)',
                      hintText: 'https://example.com/avatar.jpg',
                    ),
                    onFieldSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('save-profile-button'),
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Saving…' : 'Save profile'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateDisplayName(String? value) {
    final displayName = value?.trim() ?? '';
    if (displayName.isEmpty) {
      return 'Enter a display name.';
    }
    if (displayName.length > _maximumDisplayNameLength) {
      return 'Display name must be 40 characters or fewer.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);
    final avatarUrl = _avatarUrlController.text.trim();
    final succeeded = await widget.authController.updateProfile(
      displayName: _displayNameController.text.trim(),
      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? 'Profile saved.'
              : 'Unable to save profile. Check your connection and try again.',
        ),
      ),
    );
  }
}
