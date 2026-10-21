import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meu_app/database_helper.dart';
import 'package:meu_app/models/profile.dart';
import 'package:meu_app/notification_service.dart';
import 'perfil_screen.dart';

class PerfilListScreen extends StatefulWidget {
  const PerfilListScreen({super.key});

  @override
  State<PerfilListScreen> createState() => _PerfilListScreenState();
}

class _PerfilListScreenState extends State<PerfilListScreen> {
  late int _userId;
  List<Profile> _profiles = [];
  bool _isLoading = true;
  StreamSubscription<String>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _notificationSubscription = NotificationService.instance.stream.listen((event) {
      if (event == 'profile_updated') {
        _loadProfiles();
      }
    });
  }

  Future<void> _loadProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt('userId') ?? 0;

      if (_userId == 0) {
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      final profiles = await DatabaseHelper().getProfilesByUserId(_userId);
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao carregar perfis: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteProfile(Profile profile) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Deletar Perfil'),
          content: Text(
            'Tem certeza que deseja deletar o perfil de ${profile.firstName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await DatabaseHelper().deleteProfile(profile.id!);
                await _loadProfiles();
              },
              child: const Text('Deletar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color corAmareloPrincipal = Color(0xFFFBC02D);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meus Perfis Nutricionais')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Perfis Nutricionais'),
        backgroundColor: corAmareloPrincipal,
      ),
      body: _profiles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhum perfil criado ainda',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Toque no botão + abaixo para criar um novo perfil nutricional.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _profiles.length,
              itemBuilder: (context, index) {
                final profile = _profiles[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: corAmareloPrincipal,
                      child: Text(
                        profile.firstName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      '${profile.firstName} ${profile.lastName}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Objetivo: ${profile.nutritionalGoal} | Idade: ${profile.age}',
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem(
                          child: const Text('Editar'),
                          onTap: () async {
                            // Implementar edição
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PerfilNutricionalScreen(profile: profile),
                              ),
                            );
                            if (result == true) {
                              await _loadProfiles();
                            }
                          },
                        ),
                        PopupMenuItem(
                          child: const Text('Deletar'),
                          onTap: () => _deleteProfile(profile),
                        ),
                      ],
                    ),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PerfilNutricionalScreen(profile: profile),
                        ),
                      );
                      if (result == true) {
                        await _loadProfiles();
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
