import 'package:flutter/material.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/theme/app_theme.dart';
import 'package:streamtunes/views/admin_moderation_view.dart';

class AccountView extends StatefulWidget {
  const AccountView({super.key});

  @override
  State<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<AccountView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isRegistering = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionVM = SessionScope.of(context);
    final user = sessionVM.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Cuenta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: user == null || user.isAnonymous
            ? _buildAuthForm(sessionVM)
            : _buildProfileView(sessionVM, user),
      ),
    );
  }

  Widget _buildAuthForm(dynamic sessionVM) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isRegistering ? 'Crear Cuenta en StreamTunes' : 'Iniciar Sesión',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Música independiente sin intermediarios corporativos.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),

              if (sessionVM.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sessionVM.errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (_isRegistering) ...[
                TextField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre o Apodo',
                    hintText: 'Ej. Juan Rock',
                  ),
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  hintText: 'usuario@correo.com',
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: sessionVM.isLoading
                      ? null
                      : () async {
                          final email = _emailController.text.trim();
                          final password = _passwordController.text.trim();
                          if (email.isNotEmpty && password.isNotEmpty) {
                            if (_isRegistering) {
                              await sessionVM.signUpWithEmail(
                                email,
                                password,
                                _displayNameController.text.trim(),
                              );
                            } else {
                              await sessionVM.signInWithEmail(email, password);
                            }
                          }
                        },
                  child: sessionVM.isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text(_isRegistering ? 'Registrarse' : 'Ingresar'),
                ),
              ),
              const SizedBox(height: 8),

              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isRegistering = !_isRegistering),
                  child: Text(
                    _isRegistering
                        ? '¿Ya tienes cuenta? Inicia sesión aquí'
                        : '¿Nuevo en el colectivo? Regístrate aquí',
                    style: const TextStyle(color: AppTheme.primary, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Acceso rápido de prueba para la Cátedra y Defensa Oral
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ACCESOS RÁPIDOS DE PRUEBA (DEFENSA ORAL):',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Admin Colectivo'),
                    onPressed: () {
                      _emailController.text = 'admin@streamtunes.org';
                      _passwordController.text = 'admin123';
                    },
                  ),
                  ActionChip(
                    label: const Text('Músico con Banda'),
                    onPressed: () {
                      _emailController.text = 'artist@losfuzzers.com';
                      _passwordController.text = 'fuzz123';
                    },
                  ),
                  ActionChip(
                    label: const Text('Oyente / Fan'),
                    onPressed: () {
                      _emailController.text = 'fan@correo.com';
                      _passwordController.text = 'fan123';
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileView(dynamic sessionVM, dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tarjeta de Perfil
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.surfaceLight,
                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null
                    ? const Icon(Icons.person, size: 32, color: AppTheme.textSecondary)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.isAdmin
                          ? 'Moderador del Colectivo'
                          : (user.hasAnyBand ? 'Músico Independiente' : 'Oyente de la Comunidad'),
                      style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Ley de Privacidad y Consentimiento Expreso (Opt-in)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.privacy_tip_outlined, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text('PRIVACIDAD Y TOP FANS (OPT-IN)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'De acuerdo a las normativas de privacidad, tu nombre y foto en los rankings públicos de oyentes están ocultos por defecto. Si activas esta opción, aparecerás públicamente en el Top 10 de tus bandas favoritas.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mostrar mi perfil en rankings públicos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                value: user.isPublicProfile,
                activeThumbColor: AppTheme.primary,
                onChanged: (val) => sessionVM.togglePrivacyOptIn(val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Panel de Moderación para Admins
        if (user.isAdmin) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withAlpha(120)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, color: AppTheme.primary, size: 28),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Panel de Moderación del Colectivo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Aprobar bandas nuevas, revisar reportes y spend cap.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const AdminModerationView()),
                    );
                  },
                  child: const Text('Entrar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Selector de Banda si pertenece a más de una
        if (user.hasAnyBand && user.bandRoles.length > 1) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CAMBIAR DE BANDA ACTIVA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 10),
                ...user.bandRoles.keys.map((bandId) {
                  final isCurrent = sessionVM.activeBand?.id == bandId;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Banda: $bandId', style: const TextStyle(fontSize: 13)),
                    subtitle: Text('Rol: ${user.bandRoles[bandId]}'),
                    trailing: isCurrent ? const Icon(Icons.check, color: AppTheme.primary) : null,
                    onTap: () => sessionVM.switchActiveBand(bandId),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Botón Cerrar Sesión
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => sessionVM.signOut(),
            icon: const Icon(Icons.logout, color: AppTheme.errorRed, size: 18),
            label: const Text('Cerrar Sesión', style: TextStyle(color: AppTheme.errorRed)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.errorRed)),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
