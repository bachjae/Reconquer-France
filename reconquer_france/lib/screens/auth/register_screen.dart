import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _step = 0; // 0=credentials, 1=username, 2=avatar
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  String _selectedEmoji = '🌽';

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _usernameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _authService.registerWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        displayName: _nameCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        avatarEmoji: _selectedEmoji,
      );
      if (mounted) context.go('/trip-setup');
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      setState(() => _step = 1); // Go back to username step if it fails
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _step > 0
              ? () => setState(() => _step--)
              : () => context.go('/auth/login'),
        ),
        title: Text(
          ['Create Account', 'Choose Username', 'Pick Your Avatar'][_step],
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: [
            _Step1(
              key: const ValueKey('step1'),
              formKey: _formKey,
              emailCtrl: _emailCtrl,
              passwordCtrl: _passwordCtrl,
              nameCtrl: _nameCtrl,
              obscurePassword: _obscurePassword,
              onTogglePassword: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              onNext: () {
                if (_formKey.currentState!.validate()) {
                  setState(() => _step = 1);
                }
              },
            ),
            _Step2(
              key: const ValueKey('step2'),
              usernameCtrl: _usernameCtrl,
              error: _step == 1 ? _error : null,
              onNext: () {
                if (_usernameCtrl.text.trim().length >= 3) {
                  setState(() => _step = 2);
                }
              },
            ),
            _Step3(
              key: const ValueKey('step3'),
              selectedEmoji: _selectedEmoji,
              onEmojiSelected: (e) => setState(() => _selectedEmoji = e),
              loading: _loading,
              onComplete: _complete,
            ),
          ][_step],
        ),
      ),
    );
  }
}

class _Step1 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController nameCtrl;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onNext;

  const _Step1({
    super.key,
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.nameCtrl,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              'Begin your conquest 🏰',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: const Color(kColorAccent),
                  ),
            ).animate().fadeIn(),
            const SizedBox(height: 32),
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v?.isEmpty ?? true) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) =>
                  (v?.contains('@') ?? false) ? null : 'Enter a valid email',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordCtrl,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: onTogglePassword,
                ),
              ),
              validator: (v) => (v?.length ?? 0) >= 6
                  ? null
                  : 'Password must be at least 6 characters',
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onNext,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step2 extends StatelessWidget {
  final TextEditingController usernameCtrl;
  final String? error;
  final VoidCallback onNext;

  const _Step2({
    super.key,
    required this.usernameCtrl,
    this.error,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'Pick your username',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: const Color(kColorAccent),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Friends will find you by this name.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: usernameCtrl,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.alternate_email),
              helperText: 'Minimum 3 characters, letters and numbers only',
            ),
            onChanged: (_) {},
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFFF6B6B),
                  ),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: usernameCtrl.text.length >= 3 ? onNext : null,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _Step3 extends StatelessWidget {
  final String selectedEmoji;
  final ValueChanged<String> onEmojiSelected;
  final bool loading;
  final VoidCallback onComplete;

  const _Step3({
    super.key,
    required this.selectedEmoji,
    required this.onEmojiSelected,
    required this.loading,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'Choose your avatar',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: const Color(kColorAccent),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'This will represent you on the map.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          // Selected emoji display
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(kColorAccent), width: 3),
              ),
              child: Center(
                child: Text(selectedEmoji,
                    style: const TextStyle(fontSize: 48)),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Emoji grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: kAvatarEmojis.map((emoji) {
              final isSelected = emoji == selectedEmoji;
              return GestureDetector(
                onTap: () => onEmojiSelected(emoji),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(kColorAccent).withValues(alpha: 0.2)
                        : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(kColorAccent)
                          : const Color(0xFF2A2A4E),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 28)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: loading ? null : onComplete,
            child: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Start Conquering! 🚀"),
          ),
        ],
      ),
    );
  }
}
