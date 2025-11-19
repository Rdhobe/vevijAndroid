import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class DocumentVaultPage extends StatefulWidget {
  const DocumentVaultPage({super.key});

  @override
  State<DocumentVaultPage> createState() => _DocumentVaultPageState();
}

class _DocumentVaultPageState extends State<DocumentVaultPage> {
  final user = FirebaseAuth.instance.currentUser;

  // ✅ Allowed designations
  final allowedDesignations = ['Admin', 'superadmin', 'Designer'];

  String? userDesignation;
  bool isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _getUserDesignation();
  }

  Future<void> _getUserDesignation() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    setState(() {
      userDesignation = snapshot.data()?['designation'] ?? 'Employee';
      isLoading = false;
    });
  }

  Future<void> _uploadDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'xlsx', 'xls'],
        withData: false, // important: avoid bytes
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final fileName = path.basename(file.path);

      setState(() {
        _isUploading = true;
      });

      // ✅ Show simple loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );

      final storageRef = FirebaseStorage.instance.ref('documents/$fileName');
      final uploadTask = storageRef.putFile(file);

      // ✅ Wait for completion
      final snapshot = await uploadTask;
      final fileUrl = await snapshot.ref.getDownloadURL();

      // Save metadata
      await FirebaseFirestore.instance.collection('documents').add({
        'name': fileName,
        'url': fileUrl,
        'storagePath': 'documents/$fileName',
        'uploadedBy': user!.email,
        'designation': userDesignation,
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.of(context).pop(); // close dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$fileName uploaded successfully')),
      );
    } catch (e) {
      Navigator.of(context).pop(); // close dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _deleteDocument(String docId, String storagePath) async {
    try {
      // ✅ Delete from Firebase Storage
      await FirebaseStorage.instance.ref(storagePath).delete();

      // ✅ Delete from Firestore
      await FirebaseFirestore.instance
          .collection('documents')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  // ✅ Simple web download using url_launcher
  Future<void> _downloadForWeb(String url, String fileName) async {
    try {
      final Uri downloadUri = Uri.parse(url);

      // Use launchUrl with webOnlyWindowName to force download
      await launchUrl(
        downloadUri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fileName download started'),
          action: SnackBarAction(
            label: 'Info',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'If download didn\'t start, check your browser\'s download settings',
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  // ✅ Android download function
  Future<void> _downloadForAndroid(String url, String fileName) async {
    try {
      // Request storage permission
      if (await Permission.storage.request().isGranted ||
          await Permission.manageExternalStorage.request().isGranted) {
        // Get Downloads directory
        Directory? downloadsDir;
        if (Platform.isAndroid) {
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!downloadsDir.existsSync()) {
            downloadsDir = await getExternalStorageDirectory();
          }
        }

        if (downloadsDir == null) {
          throw Exception('Could not access downloads directory');
        }

        final filePath = '${downloadsDir.path}/$fileName';

        // Show download progress
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
            content: SizedBox(
              height: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Downloading...'),
                ],
              ),
            ),
          ),
        );

        // Download the file
        final response = await http.get(Uri.parse(url));
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        Navigator.of(context).pop(); // Close progress dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fileName downloaded to Downloads folder'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => OpenFile.open(filePath),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission denied')),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close progress dialog if open
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  // ✅ Platform-specific download handler
  Future<void> _downloadDocument(String url, String fileName) async {
      await _downloadForAndroid(url, fileName);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final canUploadDelete = allowedDesignations.contains(userDesignation);

    return Scaffold(
      appBar: AppBar(title: const Text("Document Vault")),
      floatingActionButton: canUploadDelete
          ? FloatingActionButton.extended(
              onPressed: _isUploading ? null : _uploadDocument,
              icon: const Icon(Icons.upload_file),
              label: _isUploading
                  ? const Text("Uploading...")
                  : const Text("Upload"),
              backgroundColor: const Color(0xFF2563EB),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('documents')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No documents uploaded yet."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              final name = data['name'] ?? "Unnamed";
              final url = data['url'] ?? "";
              final storagePath = data['storagePath'] ?? "";
              final uploadedBy = data['uploadedBy'] ?? "Unknown";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(
                    Icons.insert_drive_file,
                    color: Colors.blueAccent,
                  ),
                  title: Text(name),
                  subtitle: Text("Uploaded by: $uploadedBy"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.green),
                        onPressed: () => _downloadDocument(url, name),
                      ),
                      if (canUploadDelete)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteDocument(docId, storagePath),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
