import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../errors.dart';
import '../../generated/community/v1/community.pb.dart';
import '../../generated/messaging/v1/messaging.pbgrpc.dart';
import '../../grpc/clients.dart';

/// Paso 3: el caso de uso principal.
/// Carga el historial del día (GetHistory), se suscribe en vivo (Subscribe,
/// server streaming, ADR-04) y envía con SendMessage (unary).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.clients, required this.user, required this.channel});

  final ChatClients clients;
  final User user;
  final Channel channel;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <Message>[];
  final _seen = <String>{}; // el mensaje propio llega por la respuesta y por el stream
  final _input = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<Message>? _subscription;
  Timer? _reconnectTimer;
  int _attempt = 0;
  bool _reconnecting = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _subscribe();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Devuelve true si el historial se pudo leer.
  Future<bool> _loadHistory() async {
    try {
      final response = await widget.clients.messaging.getHistory(GetHistoryRequest()
        ..channelId = widget.channel.channelId
        ..userId = widget.user.userId
        ..limit = 50);
      if (!mounted) return true;
      setState(() {
        for (final message in response.messages) {
          _add(message);
        }
      });
      _scrollToEnd();
      return true;
    } catch (error) {
      debugPrint('[chat] getHistory: $error');
      _showError(error);
      return false;
    }
  }

  /// Botón "recargar": GetHistory solo depende de message-service, así que
  /// funciona aunque community-service esté caído (acto 2 de la demo).
  Future<void> _refreshHistory() async {
    final ok = await _loadHistory();
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Historial actualizado: ${_messages.length} mensajes')),
      );
    }
  }

  void _subscribe() {
    debugPrint('[chat] suscribiendo a ${widget.channel.name}');
    final stream = widget.clients.messaging.subscribe(SubscribeRequest()
      ..channelId = widget.channel.channelId
      ..userId = widget.user.userId);
    _subscription = stream.listen(
      (message) {
        _attempt = 0;
        if (!mounted) return;
        setState(() {
          _reconnecting = false;
          _add(message);
        });
        _scrollToEnd();
      },
      onError: (Object error) {
        debugPrint('[chat] stream interrumpido: $error');
        _scheduleReconnect();
      },
      onDone: _scheduleReconnect,
      cancelOnError: true,
    );
  }

  /// Reconexión con backoff: 1 s, 2 s, 4 s, 8 s, 15 s.
  void _scheduleReconnect() {
    if (!mounted) return;
    _subscription?.cancel();
    final delay = Duration(seconds: min(15, 1 << _attempt));
    _attempt = min(_attempt + 1, 4);
    setState(() => _reconnecting = true);
    debugPrint('[chat] reconectando en ${delay.inSeconds} s');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!mounted) return;
      _loadHistory(); // recupera lo que llegó mientras no había stream
      _subscribe();
    });
  }

  void _add(Message message) {
    if (_seen.add(message.messageId)) _messages.add(message);
  }

  Future<void> _send() async {
    final text = _input.text;
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final message = await widget.clients.messaging.sendMessage(SendMessageRequest()
        ..channelId = widget.channel.channelId
        ..userId = widget.user.userId
        ..content = text);
      _input.clear();
      if (!mounted) return;
      setState(() => _add(message));
      _scrollToEnd();
    } catch (error) {
      debugPrint('[chat] sendMessage: $error');
      _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(Object error) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(error))));
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  String _time(Message message) {
    final t = DateTime.fromMillisecondsSinceEpoch(message.createdAtUnixMs.toInt()).toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('# ${widget.channel.name}'),
        actions: [
          IconButton(tooltip: 'Recargar historial', onPressed: _refreshHistory, icon: const Icon(Icons.refresh)),
        ],
        bottom: _reconnecting
            ? const PreferredSize(
                preferredSize: Size.fromHeight(24),
                child: Padding(padding: EdgeInsets.only(bottom: 6), child: Text('reconectando…')),
              )
            : null,
      ),
      body: Column(children: [
        Expanded(
          child: _messages.isEmpty
              ? const Center(child: Text('Sin mensajes hoy'))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final mine = message.userId == widget.user.userId;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoxDecoration(
                          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${message.username} · ${_time(message)}', style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 2),
                          Text(message.content),
                        ]),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'Escribe un mensaje', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}
