import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/config/salon_assets.dart';
import '../../core/config/salon_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/salon_image.dart';
import 'auth_controller.dart';
import 'auth_service.dart';

/// Staff login. The very first time, it asks to create the admin account.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _setup = false;
  bool _loading = true;
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final setup = await auth.needsSetup();
      if (mounted) setState(() => _setup = setup);
    } catch (_) {
      // handled below: service unavailable message
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_setup) {
        await auth.createFirstAdmin(_user.text, _pass.text);
      } else {
        final locked = auth.lockRemaining;
        if (locked != null) {
          setState(() => _error =
              'Too many attempts. Please wait ${locked.inSeconds + 1} seconds.');
        } else {
          final ok = await auth.login(_user.text, _pass.text);
          if (!ok) {
            final nowLocked = auth.lockRemaining;
            setState(() => _error = nowLocked != null
                ? 'Too many attempts. Please wait ${nowLocked.inSeconds + 1} seconds.'
                : 'Incorrect username or password.');
          }
        }
      }
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    }
    if (mounted) setState(() => _busy = false);
    // On success the router redirects automatically.
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : auth.service == null
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'The database is not available, so login cannot work. '
                        'Please restart the app.',
                        textAlign: TextAlign.center))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 90,
                              height: 90,
                              child: ClipOval(
                                  child: SalonImage(SalonAssets.logo,
                                      fit: BoxFit.contain)),
                            ),
                            const SizedBox(height: 16),
                            Text(_setup ? 'Create admin account' : 'Staff login',
                                style: t.headlineSmall),
                            const SizedBox(height: 6),
                            Text(
                              _setup
                                  ? 'Welcome! Set up the owner login for '
                                      '${SalonConfig.name}. Keep this password safe.'
                                  : SalonConfig.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.brown),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _user,
                              autofillHints: const [AutofillHints.username],
                              decoration:
                                  const InputDecoration(labelText: 'Username'),
                              validator: (v) => (v == null || v.trim().length < 3)
                                  ? 'Enter your username (3+ characters)'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _pass,
                              obscureText: _hide,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                suffixIcon: IconButton(
                                  icon: Icon(_hide
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() => _hide = !_hide),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter your password';
                                if (_setup &&
                                    v.length < AuthService.minPasswordLength) {
                                  return 'Use at least ${AuthService.minPasswordLength} characters';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _setup ? null : _submit(),
                            ),
                            if (_setup) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _confirm,
                                obscureText: _hide,
                                decoration: const InputDecoration(
                                    labelText: 'Confirm password'),
                                validator: (v) =>
                                    v != _pass.text ? 'Passwords do not match' : null,
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.error)),
                            ],
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : Text(_setup ? 'Create account' : 'Log in'),
                              ),
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
