import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/Login/login_controller.dart';
import 'package:flutter/scheduler.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final LoginController _controller = LoginController();

  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.init(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
      body: ResponsiveContent(
        child: SingleChildScrollView(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 40, right: 40, top: 100),
                  child: Image(
                    image: AssetImage('assets/img/logo_edi.png'),
                    width: 225,
                    height: 225,
                  ),
                ),
                _textFieldUser(),
                _textFieldPassword(),
                _buttonLogin(),
                _textForgotPassword(),
                _textDontHaveAccount(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textForgotPassword() {
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: GestureDetector(
        onTap: () {
          // Navega a la pantalla de recuperación
          Navigator.pushNamed(context, 'forgot_password');
        },
        child: const Text(
          '¿Olvidaste tu contraseña?',
          style: TextStyle(
            color: Color.fromRGBO(245, 188, 6, 1),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _textFieldUser() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color.fromRGBO(245, 188, 6, 1), width: 2),
        ),
      ),
      child: TextField(
        controller: _controller.emailCtrl,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Correo institucional',
          hintStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(15),
          prefixIcon: Icon(Icons.person, color: Colors.white),
        ),
      ),
    );
  }

  Widget _textFieldPassword() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color.fromRGBO(245, 188, 6, 1), width: 2),
        ),
      ),
      child: TextField(
        controller: _controller.passCtrl,
        obscureText: _obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Contraseña',
          hintStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(15),
          prefixIcon: const Icon(Icons.key, color: Colors.white),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
            icon: Icon(
              _obscure ? Icons.visibility : Icons.visibility_off,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buttonLogin() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ValueListenableBuilder<bool>(
        valueListenable: _controller.loading,
        builder: (_, loading, __) => ElevatedButton(
          onPressed: loading ? null : _controller.goToHomePage,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          child: loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Text(
                  'INGRESAR',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _textDontHaveAccount() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '¿No tienes cuenta?',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(width: 15, height: 25),
          GestureDetector(
            onTap: _controller.goToRegisterPage,
            child: const Text(
              'Registrate',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
