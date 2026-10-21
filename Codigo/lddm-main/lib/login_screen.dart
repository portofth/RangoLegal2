import 'package:flutter/material.dart';
import 'main.dart'; // Para navegar para HomePage
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meu_app/database_helper.dart';
import 'package:meu_app/models/user.dart';

const Color corAmareloPrincipal = Color(0xFFFBC02D);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _login() {
    if (_formKey.currentState!.validate()) {
      _tryLogin();
    }
  }

  Future<void> _tryLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final db = DatabaseHelper();
    final user = await db.getUser(email, password);
    if (user != null) {
      // Salva o id do usuário em SharedPreferences para manter sessão simples
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('userId', user.id ?? 0);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário ou senha incorretos'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _abrirCadastro() {
    _openCadastroAndPrefill();
  }

  Future<void> _openCadastroAndPrefill() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CadastroScreen()),
    );
    if (result != null && result is Map<String, String>) {
      // Prefill email and password returned from cadastro
      _emailController.text = result['email'] ?? '';
      _passwordController.text = result['password'] ?? '';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastro realizado! Faça login.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Login",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: "Email"),
                      validator: (v) => v == null || !v.contains("@")
                          ? "Digite um email válido"
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: "Senha"),
                      obscureText: true,
                      validator: (v) => v == null || v.length < 6
                          ? "Senha mínima de 6 caracteres"
                          : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: corAmareloPrincipal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Entrar",
                        style: TextStyle(fontSize: 18, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _abrirCadastro,
                      child: const Text(
                        "Não tem uma conta? Cadastre-se",
                        style: TextStyle(
                          color: Colors.grey,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// ================== CadastroScreen ==================
// =====================================================

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _cadastrar() {
    if (_formKey.currentState!.validate()) {
      _performRegister();
    }
  }

  Future<void> _performRegister() async {
    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Tenta dividir nome em primeiro e último
    final parts = nome.split(' ');
    final firstName = parts.isNotEmpty ? parts.first : nome;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final user = User(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );

    final db = DatabaseHelper();
    final id = await db.insertUser(user);
    if (id > 0) {
      // Retorna as credenciais para a tela de login para preenchimento automático
      if (!mounted) return;
      Navigator.pop(context, {'email': email, 'password': password});
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erro ao cadastrar usuário."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text("Cadastro"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Cadastro",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(labelText: "Nome"),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Digite seu nome" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: "Email"),
                      validator: (v) => v == null || !v.contains("@")
                          ? "Digite um email válido"
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: "Senha"),
                      obscureText: true,
                      validator: (v) => v == null || v.length < 6
                          ? "Senha mínima de 6 caracteres"
                          : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _cadastrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: corAmareloPrincipal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Cadastrar",
                        style: TextStyle(fontSize: 18, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
