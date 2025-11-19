import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GlobalFlatNoMigrationPage extends StatefulWidget {
  const GlobalFlatNoMigrationPage({super.key});

  @override
  State<GlobalFlatNoMigrationPage> createState() => _GlobalFlatNoMigrationPageState();
}

class _GlobalFlatNoMigrationPageState extends State<GlobalFlatNoMigrationPage> {
  bool isMigrating = false;
  String log = '';

  Future<void> migrateAllProjects() async {
    setState(() {
      isMigrating = true;
      log = '🚀 Starting migration for all projects...\n';
    });

    final projectsRef = FirebaseFirestore.instance.collection('projects');
    final projectsSnapshot = await projectsRef.get();

    int totalProjects = projectsSnapshot.docs.length;
    int totalUpdated = 0;

    for (final project in projectsSnapshot.docs) {
      final projectId = project.id;
      setState(() {
        log += '\n📁 Project: $projectId\n';
      });

      final tasksRef = projectsRef.doc(projectId).collection('tasks');
      final tasksSnapshot = await tasksRef.get();

      for (final taskDoc in tasksSnapshot.docs) {
        final data = taskDoc.data();
        final flatNo = data['flatNo'];

        if (flatNo is String) {
          final parsed = int.tryParse(flatNo);
          if (parsed != null) {
            await taskDoc.reference.update({'flatNo': parsed});
            totalUpdated++;
            setState(() {
              log += '✅ Updated task ${taskDoc.id} → flatNo: $parsed\n';
            });
          } else {
            setState(() {
              log += '⚠️ Skipped task ${taskDoc.id} (invalid flatNo: $flatNo)\n';
            });
          }
        }
      }
    }

    setState(() {
      isMigrating = false;
      log += '\n🎉 Migration completed.\n'
             '📊 Total projects: $totalProjects\n'
             '✅ Total flatNos updated: $totalUpdated';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Global FlatNo Migration')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: isMigrating ? null : migrateAllProjects,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run Migration for All Projects'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  log,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
