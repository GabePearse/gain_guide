import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/workout_provider.dart';
import '../services/notification_service.dart';
import 'log_exercises_page.dart';
import 'main_scaffold.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _handledPendingNotification = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();

    if (!provider.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.isSignedIn && !_handledPendingNotification) {
      _handledPendingNotification = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final workoutId = NotificationService.instance.consumePendingWorkoutId();
        if (workoutId == null) {
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LogExercisesPage(workoutId: workoutId),
          ),
        );
      });
    }

    return provider.isSignedIn ? const MainScaffold() : const AuthPage();
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Gabe');
  final _emailController = TextEditingController(text: 'gabe@example.com');
  final _passwordController = TextEditingController(text: 'password');
  bool _isCreatingAccount = true;
  bool _isSubmitting = false;
  String? _externalProviderLoading;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final provider = context.read<WorkoutProvider>();
      if (_isCreatingAccount) {
        await provider.createAccount(
          displayName: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        final signedIn = await provider.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );

        if (!signedIn && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email or password did not match.')),
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not continue: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _signInWithExternal(String provider) async {
    setState(() {
      _externalProviderLoading = provider;
    });

    try {
      final workoutProvider = context.read<WorkoutProvider>();
      if (provider == 'google') {
        await workoutProvider.signInWithGoogle();
      } else {
        await workoutProvider.signInWithApple();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not sign in with $provider: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _externalProviderLoading = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GainGuide', style: theme.textTheme.titleLarge),
                          Text(
                            'Training, cleanly kept.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _isCreatingAccount ? 'Create account' : 'Welcome back',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isCreatingAccount
                        ? 'Start with a private workout space you can grow into.'
                        : 'Pick up where your last session left off.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isCreatingAccount) ...[
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Display name',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter a display name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || !value.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return 'Use at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _isSubmitting ? null : _submit,
                              child: Text(
                                _isSubmitting
                                    ? 'Working...'
                                    : _isCreatingAccount
                                        ? 'Create Account'
                                        : 'Sign In',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'or',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _externalProviderLoading == null
                                  ? () => _signInWithExternal('google')
                                  : null,
                              icon: const Icon(Icons.g_mobiledata),
                              label: Text(
                                _externalProviderLoading == 'google'
                                    ? 'Connecting...'
                                    : 'Continue with Google',
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _externalProviderLoading == null
                                  ? () => _signInWithExternal('apple')
                                  : null,
                              icon: const Icon(Icons.apple),
                              label: Text(
                                _externalProviderLoading == 'apple'
                                    ? 'Connecting...'
                                    : 'Continue with Apple',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _isCreatingAccount = !_isCreatingAccount;
                            });
                          },
                    child: Text(
                      _isCreatingAccount
                          ? 'Already have an account? Sign in'
                          : 'Need an account? Create one',
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
