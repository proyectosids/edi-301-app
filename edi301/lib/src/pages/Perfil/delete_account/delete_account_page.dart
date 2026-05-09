import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'delete_account_controller.dart';

/// Pantalla para que el usuario elimine (desactive) su propia cuenta.
///
/// Apple guideline 5.1.1(v): la app debe ofrecer un mecanismo accesible
/// para que la persona pueda solicitar la eliminación de su cuenta.
///
/// Flujo:
///   • Paso 0: explicación + botón para enviar OTP al correo del usuario.
///   • Paso 1: captura del código OTP de 4 dígitos.
///
/// Si todo va bien la cuenta se desactiva, se limpia la sesión local
/// y se redirige al login.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  static const _primary = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final DeleteAccountController c = DeleteAccountController();
  final List<TextEditingController> _otpCtrls =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(4, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    c.loadEmail();
  }

  @override
  void dispose() {
    for (final ctrl in _otpCtrls) {
      ctrl.dispose();
    }
    for (final node in _otpFocus) {
      node.dispose();
    }
    c.dispose();
    super.dispose();
  }

  String _maskedEmail(String email) {
    if (email.isEmpty || !email.contains('@')) return email;
    final parts = email.split('@');
    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 2) return '${local[0]}***@$domain';
    return '${local.substring(0, 2)}***${local.substring(local.length - 1)}@$domain';
  }

  Future<void> _onConfirm() async {
    // Recoger los 4 dígitos
    c.otpCtrl.text = _otpCtrls.map((e) => e.text.trim()).join();
    final ok = await c.verifyAndDelete(context);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tu cuenta ha sido eliminada.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primary,
      appBar: AppBar(
        title: const Text('Eliminar mi cuenta'),
        backgroundColor: _primary,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ValueListenableBuilder<int>(
            valueListenable: c.step,
            builder: (_, step, __) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: step == 0 ? _stepIntro() : _stepOtp(),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Paso 0: explicación ──────────────────────────────────────────────────
  Widget _stepIntro() {
    return Column(
      key: const ValueKey('intro'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 56),
        const SizedBox(height: 12),
        const Text(
          '¿Estás seguro de eliminar tu cuenta?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BulletText(
                icon: Icons.lock_outline_rounded,
                text:
                    'No podrás iniciar sesión con esta cuenta una vez eliminada.',
              ),
              SizedBox(height: 10),
              _BulletText(
                icon: Icons.history_edu_outlined,
                text:
                    'Tu información asociada (familia, mensajes y publicaciones) '
                    'se conservará por motivos de integridad.',
              ),
              SizedBox(height: 10),
              _BulletText(
                icon: Icons.refresh_rounded,
                text:
                    'Si más adelante deseas volver a usar la app, podrás '
                    'registrarte de nuevo con el mismo correo.',
              ),
              SizedBox(height: 10),
              _BulletText(
                icon: Icons.shield_outlined,
                text:
                    'Para confirmar te enviaremos un código de verificación a '
                    'tu correo.',
              ),
            ],
          ),
        ),
        const Spacer(),
        ValueListenableBuilder<bool>(
          valueListenable: c.loading,
          builder: (_, loading, __) {
            return Column(
              children: [
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      loading ? 'Enviando código...' : 'Enviar código al correo',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: loading ? null : () => c.sendOtp(context),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        loading ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Paso 1: OTP ──────────────────────────────────────────────────────────
  Widget _stepOtp() {
    final masked = _maskedEmail(c.email);

    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Icon(Icons.mark_email_read_outlined,
            color: Colors.white, size: 56),
        const SizedBox(height: 12),
        const Text(
          'Ingresa el código',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Te enviamos un código de 4 dígitos a $masked',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13.5),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) => _otpBox(i)),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: () => c.sendOtp(context),
            child: const Text(
              'Reenviar código',
              style: TextStyle(
                color: _gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const Spacer(),
        ValueListenableBuilder<bool>(
          valueListenable: c.loading,
          builder: (_, loading, __) {
            return Column(
              children: [
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete_forever_rounded),
                    label: Text(
                      loading ? 'Eliminando...' : 'Confirmar y eliminar',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: loading ? null : _onConfirm,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        loading ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _otpBox(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 56,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _otpCtrls[index],
        focusNode: _otpFocus[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: _primary,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 3) {
            _otpFocus[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _otpFocus[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color.fromRGBO(19, 67, 107, 1)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13.5, height: 1.4),
          ),
        ),
      ],
    );
  }
}
