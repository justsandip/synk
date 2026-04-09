// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:flutter_synk/flutter_synk.dart';
import 'package:synk/synk.dart';

void main() {
  // Create a single SynkDoc to be shared between our "peers".
  final doc = SynkDoc();

  runApp(
    SynkProvider(
      doc: doc,
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MyHomePage(),
      ),
    ),
  );
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Synk Collaboration Demo'),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          spacing: 16,
          children: [
            // Peer A
            Expanded(
              child: PeerCard(name: 'Peer A', color: Colors.blueAccent),
            ),
            // Peer B
            Expanded(
              child: PeerCard(name: 'Peer B', color: Colors.orangeAccent),
            ),
          ],
        ),
      ),
    );
  }
}

class PeerCard extends StatelessWidget {
  const PeerCard({required this.name, required this.color, super.key});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Both peers access the SAME document from the provider.
    final doc = SynkProvider.docOf(context);

    // Both peers point to the SAME key 'counter'.
    final counter = SynkInt(doc, 'counter');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header with Peer Name
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            width: double.infinity,
            color: color.withValues(alpha: 0.1),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
          ),
          const Spacer(),
          // Collaborative Value Display
          const Text('Current Value:', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          SynkBuilder<int>(
            stream: counter.stream,
            initialData: counter.value,
            builder: (context, value) {
              return Text(
                '$value',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w300,
                ),
              );
            },
          ),
          const Spacer(),
          // Increment Button for this Peer
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: counter.increment,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Icon(Icons.add, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
