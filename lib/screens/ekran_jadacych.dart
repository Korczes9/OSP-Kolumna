import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Ekran wyświetlający listę jadących strażaków
class RespondersScreen extends StatelessWidget {
  const RespondersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kto jedzie'),
        backgroundColor: Colors.red,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('alarmy')
            .doc('aktywny')
            .collection('odpowiadajacy')
            .snapshots(),
        builder: (context, snapshot) {
          /// Ładowanie
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          /// Błąd
          if (snapshot.hasError) {
            return Center(
              child: Text('❌ Błąd: ${snapshot.error}'),
            );
          }

          /// Brak danych
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nikt jeszcze się nie zgłosił',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          /// Lista odpowiadających
          final odpowiadajacy = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: odpowiadajacy.length,
            itemBuilder: (context, indeks) {
              final doc = odpowiadajacy[indeks];
              final dane = doc.data() as Map<String, dynamic>;
              final name = dane['name'] ?? 'Unknown';
              final status = dane['status'] ?? 'Bez statusu';

              /// Kolor w zależności od statusu
              Color kolorStatusu = Colors.grey;
              if (status == 'JADĘ') kolorStatusu = Colors.green;
              if (status == 'Nie mogę') kolorStatusu = Colors.red;
              if (status == 'Na miejscu') kolorStatusu = Colors.blue;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.red),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kolorStatusu,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  subtitle: Text('ID: ${doc.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
