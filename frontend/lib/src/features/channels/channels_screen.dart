import 'package:flutter/material.dart';

import '../../errors.dart';
import '../../generated/community/v1/community.pb.dart';
import '../../grpc/clients.dart';
import '../chat/chat_screen.dart';

/// Paso 2: mis canales, los demás canales (para unirse) y crear uno nuevo.
class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key, required this.clients, required this.user});

  final ChatClients clients;
  final User user;

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  late Future<(List<Channel>, List<Channel>)> _channels = _load();

  Future<(List<Channel>, List<Channel>)> _load() async {
    final community = widget.clients.community;
    final results = await Future.wait([
      community.listMyChannels(ListMyChannelsRequest()..userId = widget.user.userId),
      community.listChannels(ListChannelsRequest()),
    ]);
    final mine = (results[0] as ListMyChannelsResponse).channels.toList();
    final mineIds = mine.map((c) => c.channelId).toSet();
    final others = (results[1] as ListChannelsResponse).channels.where((c) => !mineIds.contains(c.channelId)).toList();
    mine.sort((a, b) => a.name.compareTo(b.name));
    others.sort((a, b) => a.name.compareTo(b.name));
    return (mine, others);
  }

  void _reload() => setState(() => _channels = _load());

  void _showError(Object error) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(error))));
  }

  Future<void> _join(Channel channel) async {
    try {
      await widget.clients.community.joinChannel(JoinChannelRequest()
        ..userId = widget.user.userId
        ..channelId = channel.channelId);
      _reload();
    } catch (error) {
      debugPrint('[chat] joinChannel: $error');
      _showError(error);
    }
  }

  Future<void> _createChannel() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo canal'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: description, decoration: const InputDecoration(labelText: 'Descripción')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear')),
        ],
      ),
    );
    if (create != true || !mounted) return;
    try {
      final channel = await widget.clients.community.createChannel(CreateChannelRequest()
        ..name = name.text.trim()
        ..description = description.text.trim()
        ..createdBy = widget.user.userId);
      await _join(channel); // quien crea el canal queda como miembro
    } catch (error) {
      debugPrint('[chat] createChannel: $error');
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Canales de ${widget.user.username}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createChannel,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo canal'),
      ),
      body: FutureBuilder<(List<Channel>, List<Channel>)>(
        future: _channels,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(friendlyError(snapshot.error!)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _reload, child: const Text('Reintentar')),
              ]),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final (mine, others) = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(children: [
              const _Header('Mis canales'),
              if (mine.isEmpty) const ListTile(title: Text('Todavía no estás en ningún canal')),
              for (final channel in mine)
                ListTile(
                  leading: const Icon(Icons.tag),
                  title: Text(channel.name),
                  subtitle: Text(channel.description),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatScreen(clients: widget.clients, user: widget.user, channel: channel)),
                  ),
                ),
              const _Header('Otros canales'),
              for (final channel in others)
                ListTile(
                  leading: const Icon(Icons.tag_outlined),
                  title: Text(channel.name),
                  subtitle: Text(channel.description),
                  trailing: OutlinedButton(onPressed: () => _join(channel), child: const Text('Unirse')),
                  // Se puede abrir sin ser miembro: la lectura es abierta, pero enviar dará PERMISSION_DENIED.
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatScreen(clients: widget.clients, user: widget.user, channel: channel)),
                  ),
                ),
              const SizedBox(height: 88),
            ]),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
