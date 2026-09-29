import 'package:flutter/material.dart';

import '../../errors.dart';
import '../../generated/community/v1/community.pb.dart';
import '../../grpc/clients.dart';
import '../channels/channels_screen.dart';

/// Paso 1: elegir con qué usuario entrar (no hay login real) o crear uno.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.clients});

  final ChatClients clients;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<List<User>> _users = _load();

  Future<List<User>> _load() async {
    final response = await widget.clients.community.listUsers(ListUsersRequest());
    final users = response.users.toList()..sort((a, b) => a.username.compareTo(b.username));
    return users;
  }

  void _reload() => setState(() => _users = _load());

  Future<void> _createUser() async {
    final username = TextEditingController();
    final email = TextEditingController();
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo usuario'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: username, decoration: const InputDecoration(labelText: 'Nombre de usuario')),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Correo')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear')),
        ],
      ),
    );
    if (create != true || !mounted) return;
    try {
      await widget.clients.community.createUser(CreateUserRequest()
        ..username = username.text.trim()
        ..email = email.text.trim());
      _reload();
    } catch (error) {
      debugPrint('[chat] createUser: $error');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('¿Quién eres?')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createUser,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo usuario'),
      ),
      body: FutureBuilder<List<User>>(
        future: _users,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(message: friendlyError(snapshot.error!), onRetry: _reload);
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final users = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(user.username.substring(0, 1).toUpperCase())),
                  title: Text(user.username),
                  subtitle: Text(user.email),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChannelsScreen(clients: widget.clients, user: user)),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
      ]),
    );
  }
}
