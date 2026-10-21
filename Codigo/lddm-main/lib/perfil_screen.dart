import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meu_app/database_helper.dart';
import 'package:meu_app/models/profile.dart';
import 'package:meu_app/notification_service.dart';

// Cores que definimos anteriormente para manter o padrão
const Color corAmareloPrincipal = Color(0xFFFBC02D);

class PerfilNutricionalScreen extends StatefulWidget {
  final Profile? profile;
  
  const PerfilNutricionalScreen({super.key, this.profile});

  @override
  State<PerfilNutricionalScreen> createState() => _PerfilNutricionalScreenState();
}

class _PerfilNutricionalScreenState extends State<PerfilNutricionalScreen> {
  // 1. Controladores para cada campo do formulário
  final _nomeController = TextEditingController();
  final _sexoController = TextEditingController();
  final _idadeController = TextEditingController();
  final _pesoController = TextEditingController();
  final _alturaController = TextEditingController();
  final _nivelAtividadeController = TextEditingController();
  final _objetivoController = TextEditingController();
  final _restricoesController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  Profile? _existingProfile;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    if (userId == null || userId == 0) return;

    final profile = widget.profile;
    if (profile == null) {
      // Novo perfil: não carregamos nenhum perfil já existente para evitar
      // sobrescrever outro registro.
      return;
    }

    if (!mounted) return;
    final p = profile;
    setState(() {
      _existingProfile = p;
      _nomeController.text = '${p.firstName} ${p.lastName}';
      _sexoController.text = p.sex;
      _idadeController.text = p.age.toString();
      _pesoController.text = p.weight.toString();
      _alturaController.text = p.height.toString();
      _nivelAtividadeController.text = p.activityLevel;
      _objetivoController.text = p.nutritionalGoal;
      _restricoesController.text = p.restrictions;
    });
  }

  Future<void> _salvarDados() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null || userId == 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro: usuário não autenticado.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Tenta dividir nome em primeiro/último
      final nomeCompleto = _nomeController.text.trim();
      final parts = nomeCompleto.split(' ');
      final firstName = parts.isNotEmpty ? parts.first : nomeCompleto;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      final profile = Profile(
        id: _existingProfile?.id,
        firstName: firstName,
        lastName: lastName,
        preferences: '',
        restrictions: _restricoesController.text.trim(),
        activityLevel: _nivelAtividadeController.text.trim(),
        nutritionalGoal: _objetivoController.text.trim(),
        weight: double.tryParse(_pesoController.text.replaceAll(',', '.')) ?? 0.0,
        height: double.tryParse(_alturaController.text.replaceAll(',', '.')) ?? 0.0,
        age: int.tryParse(_idadeController.text) ?? 0,
        sex: _sexoController.text.trim(),
        userId: userId,
      );

      final db = DatabaseHelper();
      if (_existingProfile == null) {
        await db.insertProfile(profile);
      } else {
        await db.updateProfile(profile);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil salvo com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      // Notifica outras telas que o perfil foi atualizado
      NotificationService.instance.notify('profile_updated');
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }
  
  @override
  void dispose() {
    _nomeController.dispose();
    _sexoController.dispose();
    _idadeController.dispose();
    _pesoController.dispose();
    _alturaController.dispose();
    _nivelAtividadeController.dispose();
    _objetivoController.dispose();
    _restricoesController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: corAmareloPrincipal),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor, preencha este campo';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro do Perfil Nutricional'),
        backgroundColor: corAmareloPrincipal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Formulário de Perfil Nutricional',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildTextField(controller: _nomeController, label: 'Nome', icon: Icons.person),
              const SizedBox(height: 16),
              _buildTextField(controller: _sexoController, label: 'Sexo', icon: Icons.wc),
              const SizedBox(height: 16),
              _buildTextField(controller: _idadeController, label: 'Idade', icon: Icons.cake, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField(controller: _pesoController, label: 'Peso (kg)', icon: Icons.monitor_weight, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField(controller: _alturaController, label: 'Altura (m)', icon: Icons.height, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField(controller: _nivelAtividadeController, label: 'Nível de atividade física', icon: Icons.fitness_center),
              const SizedBox(height: 16),
              _buildTextField(controller: _objetivoController, label: 'Objetivo', icon: Icons.flag),
              const SizedBox(height: 16),
              _buildTextField(controller: _restricoesController, label: 'Restrições alimentares', icon: Icons.no_food),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _salvarDados,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: corAmareloPrincipal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Salvar',
                        style: TextStyle(fontSize: 18, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}