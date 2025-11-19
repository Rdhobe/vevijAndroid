import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
class MultiUpdateTaskPage extends StatefulWidget {
  final String projectId;

  const MultiUpdateTaskPage({super.key, required this.projectId});

  @override
  State<MultiUpdateTaskPage> createState() => _MultiUpdateTaskPageState();
}

class _MultiUpdateTaskPageState extends State<MultiUpdateTaskPage> {
  String selectedUpdateMode = 'material'; // 'material' or 'flat'
  String? selectedMaterialGroup;
  int? selectedFlatNo;
  List<int> selectedFlats = [];
  List<String> selectedMaterials = [];
  List<QueryDocumentSnapshot> availableTasks = [];
  List<QueryDocumentSnapshot> filteredTasks = [];
  bool isLoading = true;

  // Progress updates
  bool updateDoorFrameHardware = false;
  bool updateArchitrave = false;
  bool updateHandover = false;

  // Photo handling for handover
  Map<String, File?> handoverPhotos = {};
  final ImagePicker _picker = ImagePicker();
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('tasks')
          .get();

      setState(() {
        availableTasks = snapshot.docs;
        _updateFilteredTasks();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading tasks: ${e.toString()}')),
      );
    }
  }

  void _updateFilteredTasks() {
    if (selectedUpdateMode == 'material' && selectedMaterialGroup != null) {
      filteredTasks = availableTasks.where((task) {
        final data = task.data() as Map<String, dynamic>;
        return data['materialGroup'] == selectedMaterialGroup;
      }).toList();
    } else if (selectedUpdateMode == 'flat' && selectedFlatNo != null) {
      filteredTasks = availableTasks.where((task) {
        final data = task.data() as Map<String, dynamic>;
        return data['flatNo'] == selectedFlatNo;
      }).toList();
    } else {
      filteredTasks = [];
    }
  }

  List<String> _getUniqueMaterialGroups() {
    return availableTasks
        .map(
          (task) =>
              (task.data() as Map<String, dynamic>)['materialGroup'] as String,
        )
        .toSet()
        .toList()
      ..sort();
  }

  List<int> _getUniqueFlats() {
    return availableTasks
        .map(
          (task) => (task.data() as Map<String, dynamic>)['flatNo'] as int,
        )
        .toSet()
        .toList()
      ..sort();
  }

  List<int> _getUniqueFlatsByMaterial(String materialGroup) {
    return availableTasks
        .where(
          (task) =>
              (task.data() as Map<String, dynamic>)['materialGroup'] ==
              materialGroup,
        )
        .map(
          (task) => (task.data() as Map<String, dynamic>)['flatNo'] as int, // flat no is in Int format
        )
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueMaterialsByFlat(int flatNo) {
    return availableTasks
        .where(
          (task) => (task.data() as Map<String, dynamic>)['flatNo'] == flatNo,
        )
        .map(
          (task) =>
              (task.data() as Map<String, dynamic>)['materialGroup'] as String,
        )
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6D28D9),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Multi Update Tasks',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Update multiple tasks at once',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Update Mode Selection
                            _buildUpdateModeSection(),
                            const SizedBox(height: 24),

                            // Selection Controls
                            _buildSelectionSection(),
                            const SizedBox(height: 24),

                            // Progress Update Options
                            if (filteredTasks.isNotEmpty) ...[
                              _buildProgressUpdateSection(),
                              const SizedBox(height: 24),
                            ],

                            // Task Preview
                            if (filteredTasks.isNotEmpty) ...[
                              _buildTaskPreviewSection(),
                              const SizedBox(height: 24),
                            ],

                            // Photo Section for Handover
                            if (updateHandover && filteredTasks.isNotEmpty) ...[
                              _buildPhotoSection(),
                              const SizedBox(height: 24),
                            ],

                            // Update Button
                            if (filteredTasks.isNotEmpty &&
                                (updateDoorFrameHardware ||
                                    updateArchitrave ||
                                    updateHandover))
                              _buildUpdateButton(),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Update Mode',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModeCard(
                'By Material Group',
                'Update all tasks of same material across different flats',
                Icons.category,
                'material',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModeCard(
                'By Flat Number',
                'Update all materials in specific flat',
                Icons.apartment,
                'flat',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeCard(
    String title,
    String description,
    IconData icon,
    String mode,
  ) {
    final isSelected = selectedUpdateMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedUpdateMode = mode;
          // Reset selections when mode changes
          selectedMaterialGroup = null;
          selectedFlatNo = null;
          selectedFlats.clear();
          selectedMaterials.clear();
          filteredTasks.clear();
          handoverPhotos.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: flutter.Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF3B82F6) : Colors.grey[600],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF3B82F6) : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionSection() {
    if (selectedUpdateMode == 'material') {
      return _buildMaterialModeSelection();
    } else {
      return _buildFlatModeSelection();
    }
  }

  Widget _buildMaterialModeSelection() {
    final materialGroups = _getUniqueMaterialGroups();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Material Group',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: selectedMaterialGroup,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          hint: const Text('Choose material group'),
          items: materialGroups.map((material) {
            return DropdownMenuItem(value: material, child: Text(material));
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedMaterialGroup = value;
              selectedFlats.clear();
              _updateFilteredTasks();
              handoverPhotos.clear();
            });
          },
        ),

        if (selectedMaterialGroup != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Select Flats to Update',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildFlatSelector(_getUniqueFlatsByMaterial(selectedMaterialGroup!)),
        ],
      ],
    );
  }

  Widget _buildFlatModeSelection() {
    final flats = _getUniqueFlats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Flat Number',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: selectedFlatNo,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          hint: const Text('Choose flat number'),
          items: flats.map((flat) {
            return DropdownMenuItem(value: flat, child: Text('Flat $flat'));
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedFlatNo = value;
              selectedMaterials.clear();
              _updateFilteredTasks();
              handoverPhotos.clear();
            });
          },
        ),

        if (selectedFlatNo != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Select Materials to Update',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildMaterialSelector(_getUniqueMaterialsByFlat(selectedFlatNo!)),
        ],
      ],
    );
  }

  Widget _buildFlatSelector(List<int> flats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: flutter.Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Flats (${selectedFlats.length}/${flats.length})',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedFlats = List.from(flats);
                        _updateFilteredTasks();
                      });
                    },
                    child: const Text('Select All'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedFlats.clear();
                        _updateFilteredTasks();
                      });
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: flats.map((flat) {
              final isSelected = selectedFlats.contains(flat);
              return FilterChip(
                label: Text('Flat $flat'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      selectedFlats.add(flat);
                    } else {
                      selectedFlats.remove(flat);
                    }
                    _updateFilteredTasks();
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialSelector(List<String> materials) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: flutter.Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Materials (${selectedMaterials.length}/${materials.length})',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedMaterials = List.from(materials);
                        _updateFilteredTasks();
                      });
                    },
                    child: const Text('Select All'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedMaterials.clear();
                        _updateFilteredTasks();
                      });
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: materials.map((material) {
              final isSelected = selectedMaterials.contains(material);
              return FilterChip(
                label: Text(material),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      selectedMaterials.add(material);
                    } else {
                      selectedMaterials.remove(material);
                    }
                    _updateFilteredTasks();
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressUpdateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Progress to Update',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        CheckboxListTile(
          title: const Text('Door + Frame + Hardware (60%)'),
          subtitle: const Text('Mark as completed'),
          value: updateDoorFrameHardware,
          onChanged: (value) =>
              setState(() => updateDoorFrameHardware = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),

        CheckboxListTile(
          title: const Text('Architrave (30%)'),
          subtitle: const Text('Mark as completed'),
          value: updateArchitrave,
          onChanged: (value) =>
              setState(() => updateArchitrave = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),

        CheckboxListTile(
          title: const Text('Handover (10%)'),
          subtitle: const Text('Mark as completed - Photos required'),
          value: updateHandover,
          onChanged: (value) {
            setState(() {
              updateHandover = value ?? false;
              if (!updateHandover) {
                handoverPhotos.clear();
              }
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget _buildTaskPreviewSection() {
    final tasksToUpdate = _getTasksToUpdate();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tasks to Update (${tasksToUpdate.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            itemCount: tasksToUpdate.length,
            itemBuilder: (context, index) {
              final task = tasksToUpdate[index];
              final data = task.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    'Building ${data['buildingNo']} - Flat ${data['flatNo']}',
                  ),
                  subtitle: Text(
                    '${data['materialGroup']} - ${data['location']}',
                  ),
                  trailing: Text('Qty: ${data['qty']}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    final tasksToUpdate = _getTasksToUpdate();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Handover Photos Required',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Text(
          'Please take photos for each task marked for handover (${tasksToUpdate.length} photos needed)',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),

        ...tasksToUpdate.map((task) {
          final data = task.data() as Map<String, dynamic>;
          final taskKey = task.id;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: flutter.Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Building ${data['buildingNo']} - Flat ${data['flatNo']?.toString()}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${data['materialGroup']} - ${data['location']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 12),

                if (handoverPhotos[taskKey] != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      handoverPhotos[taskKey]!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _pickPhoto(taskKey),
                        icon: const Icon(Icons.edit),
                        label: const Text('Change Photo'),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => handoverPhotos[taskKey] = null),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: () => _pickPhoto(taskKey),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildUpdateButton() {
    final tasksToUpdate = _getTasksToUpdate();
    final isValid = _validateUpdate();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isValid && !isUpdating ? _performMultiUpdate : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isUpdating
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Updating Tasks...'),
                ],
              )
            : Text(
                'Update ${tasksToUpdate.length} Tasks',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  List<QueryDocumentSnapshot> _getTasksToUpdate() {
    if (selectedUpdateMode == 'material') {
      return filteredTasks.where((task) {
        final data = task.data() as Map<String, dynamic>;
        return selectedFlats.contains(data['flatNo']);
      }).toList();
    } else {
      return filteredTasks.where((task) {
        final data = task.data() as Map<String, dynamic>;
        return selectedMaterials.contains(data['materialGroup']);
      }).toList();
    }
  }

  bool _validateUpdate() {
    final tasksToUpdate = _getTasksToUpdate();

    if (tasksToUpdate.isEmpty) return false;
    if (!updateDoorFrameHardware && !updateArchitrave && !updateHandover)
      return false;

    // If handover is selected, all tasks must have photos
    if (updateHandover) {
      for (final task in tasksToUpdate) {
        if (handoverPhotos[task.id] == null) return false;
      }
    }

    return true;
  }

  Future<void> _pickPhoto(String taskId) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          handoverPhotos[taskId] = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: ${e.toString()}')),
      );
    }
  }

  Future<String?> _uploadPhoto(String taskId, File photo) async {
    try {
      final fileName =
          'handover_${taskId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('projects')
          .child(widget.projectId)
          .child('tasks')
          .child(taskId)
          .child(fileName);

      final uploadTask = ref.putFile(photo);
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception(
        'Failed to upload photo for task $taskId: ${e.toString()}',
      );
    }
  }

  Future<void> _performMultiUpdate() async {
    setState(() => isUpdating = true);

    try {
      final tasksToUpdate = _getTasksToUpdate();
      final batch = FirebaseFirestore.instance.batch();

      for (final task in tasksToUpdate) {
        final data = task.data() as Map<String, dynamic>;

        // Check if task is already completed and needs confirmation
        final bool needsConfirmation =
            (updateDoorFrameHardware && data['doorFrameHardware'] == true) ||
            (updateArchitrave && data['architrave'] == true) ||
            (updateHandover && data['handover'] == true);

        if (needsConfirmation) {
          final shouldContinue = await _showEditConfirmation(task.id, data);
          if (!shouldContinue) continue;
        }

        Map<String, dynamic> updateData = {'updatedAt': Timestamp.now()};

        if (updateDoorFrameHardware) {
          updateData['doorFrameHardware'] = true;
        }
        if (updateArchitrave) {
          updateData['architrave'] = true;
        }
        if (updateHandover) {
          updateData['handover'] = true;

          // Upload photo if provided
          if (handoverPhotos[task.id] != null) {
            final photoUrl = await _uploadPhoto(
              task.id,
              handoverPhotos[task.id]!,
            );
            updateData['handoverPhotoUrl'] = photoUrl;
          }
        }

        batch.update(
          FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('tasks')
              .doc(task.id),
          updateData,
        );

        // Add to feed
        batch.set(
          FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('feed')
              .doc(),
          {
            'taskId': task.id,
            'title': 'Multi Task Update',
            'description':
                'Task for Building ${data['buildingNo']}, Flat ${data['flatNo']?.toString()} updated via multi-update.',
            'timestamp': Timestamp.now(),
            'type': 'multi_task_update',
          },
        );
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully updated ${tasksToUpdate.length} tasks!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating tasks: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isUpdating = false);
    }
  }

  Future<bool> _showEditConfirmation(
    String taskId,
    Map<String, dynamic> data,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Task Already Completed'),
            content: Text(
              'The task for Building ${data['buildingNo']}, Flat ${data['flatNo']?.toString()} has already been marked as completed for some of the selected progress items.\n\nDo you want to update it anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Skip'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
