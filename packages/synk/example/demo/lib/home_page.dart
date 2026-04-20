import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:synk/synk.dart';

enum SyncStatus { online, offline }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SynkDoc _docA;
  late final SynkDoc _docB;
  late final SynkList _listA;
  late final SynkList _listB;

  SyncStatus _syncStatus = SyncStatus.online;

  // Internal streams to simulate network latency/channels
  final _channelAtoB = StreamController<Uint8List>.broadcast();
  final _channelBtoA = StreamController<Uint8List>.broadcast();

  @override
  void initState() {
    super.initState();
    _docA = SynkDoc(clientId: 1);
    _docB = SynkDoc(clientId: 2);

    _listA = SynkList(_docA, 'todos');
    _listB = SynkList(_docB, 'todos');

    // Setup synchronization logic
    _setupSync();
  }

  void _setupSync() {
    // Peer A listens for local changes and broadcasts them
    _docA.addTransactionListener((_) {
      if (_syncStatus == SyncStatus.online) {
        final update = SynkProtocol.encodeStateAsUpdate(_docA);
        _channelAtoB.add(update);
      }
    });

    // Peer B listens for local changes and broadcasts them
    _docB.addTransactionListener((_) {
      if (_syncStatus == SyncStatus.online) {
        final update = SynkProtocol.encodeStateAsUpdate(_docB);
        _channelBtoA.add(update);
      }
    });

    // Peer B receives updates from A
    _channelAtoB.stream.listen((update) {
      if (_syncStatus == SyncStatus.online) {
        SynkProtocol.applyUpdate(_docB, update);
      }
    });

    // Peer A receives updates from B
    _channelBtoA.stream.listen((update) {
      if (_syncStatus == SyncStatus.online) {
        SynkProtocol.applyUpdate(_docA, update);
      }
    });
  }

  void _toggleSync(SyncStatus status) {
    setState(() {
      _syncStatus = status;
    });

    if (status == SyncStatus.online) {
      // Perform a full sync when coming back online
      _performFullSync();
    }
  }

  void _performFullSync() {
    // Alice -> Bob
    final bobSv = SynkProtocol.encodeStateVector(_docB);
    final aliceUpdate = SynkProtocol.encodeStateAsUpdate(_docA, bobSv);
    SynkProtocol.applyUpdate(_docB, aliceUpdate);

    // Bob -> Alice
    final aliceSv = SynkProtocol.encodeStateVector(_docA);
    final bobUpdate = SynkProtocol.encodeStateAsUpdate(_docB, aliceSv);
    SynkProtocol.applyUpdate(_docA, bobUpdate);
  }

  @override
  void dispose() {
    unawaited(_channelAtoB.close());
    unawaited(_channelBtoA.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Synk Demo'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _toggleSync(
            _syncStatus == SyncStatus.online
                ? SyncStatus.offline
                : SyncStatus.online,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _syncStatus == SyncStatus.online
                    ? CupertinoIcons.wifi
                    : CupertinoIcons.wifi_slash,
                size: 18,
                color: _syncStatus == SyncStatus.online
                    ? CupertinoColors.activeGreen
                    : CupertinoColors.systemRed,
              ),
              const SizedBox(width: 4),
              Text(
                _syncStatus == SyncStatus.online ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 14,
                  color: _syncStatus == SyncStatus.online
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.systemRed,
                ),
              ),
            ],
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Text(
                  'Conflict-free Todo List Simulation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: PeerScreen(
                        name: 'Peer A (Alice)',
                        doc: _docA,
                        list: _listA,
                        color: CupertinoColors.activeBlue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: PeerScreen(
                        name: 'Peer B (Bob)',
                        doc: _docB,
                        list: _listB,
                        color: CupertinoColors.systemPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PeerScreen extends StatefulWidget {
  const PeerScreen({
    required this.name,
    required this.doc,
    required this.list,
    required this.color,
    super.key,
  });

  final String name;
  final SynkDoc doc;
  final SynkList list;
  final Color color;

  @override
  State<PeerScreen> createState() => _PeerScreenState();
}

class _PeerScreenState extends State<PeerScreen> {
  final _textController = TextEditingController();
  late final void Function(Transaction) _listener;

  @override
  void initState() {
    super.initState();
    // Rebuild when the document receives an update
    _listener = (_) {
      if (mounted) setState(() {});
    };
    widget.doc.addTransactionListener(_listener);
  }

  @override
  void dispose() {
    widget.doc.removeTransactionListener(_listener);
    _textController.dispose();
    super.dispose();
  }

  void _addTodo() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.list.append(text);
      _textController.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final todos = widget.list.toList();

    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.color.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Text(
              widget.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: widget.color,
              ),
            ),
          ),
          Expanded(
            child: todos.isEmpty
                ? Center(
                    child: Text(
                      'No tasks yet',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: todos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return TodoItemWidget(
                        text: todos[index].toString(),
                        onDelete: () {
                          widget.list.delete(index);
                          setState(() {});
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: CupertinoTextField(
              controller: _textController,
              placeholder: 'Add task...',
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onSubmitted: (_) => _addTodo(),
              suffix: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _addTodo,
                child: const Icon(CupertinoIcons.add_circled_solid),
              ),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TodoItemWidget extends StatelessWidget {
  const TodoItemWidget({required this.text, required this.onDelete, super.key});

  final String text;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onDelete,
            child: const Icon(
              CupertinoIcons.delete,
              size: 18,
              color: CupertinoColors.systemRed,
            ),
          ),
        ],
      ),
    );
  }
}
