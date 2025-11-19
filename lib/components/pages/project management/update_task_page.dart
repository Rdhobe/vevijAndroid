import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class OptionalHandover {
  String id;
  String title;
  String toName;
  bool isCompleted;
  File? photo;
  String? photoUrl;

  OptionalHandover({
    required this.id,
    required this.title,
    required this.toName,
    this.isCompleted = false,
    this.photo,
    this.photoUrl,
  });
}


// UpdateTaskPage
class UpdateTaskPage extends StatefulWidget {
  final String projectId;
  final String taskId;
  final String buildingNo;
  final String flatNo;
  final String materialGroup;
  final String location;
  final int qty;
  final String remark;
  final bool doorFrameHardware;
  final bool architrave;
  final bool handover;

  const UpdateTaskPage({
    super.key,
    required this.projectId,
    required this.taskId,
    required this.buildingNo,
    required this.flatNo,
    required this.materialGroup,
    required this.location,
    required this.qty,
    required this.remark,
    required this.doorFrameHardware,
    required this.architrave,
    required this.handover,
  });

  @override
  State<UpdateTaskPage> createState() => _UpdateTaskPageState();
}

class _UpdateTaskPageState extends State<UpdateTaskPage> {
  late bool doorFrameHardware;
  late bool architrave;
  late bool handover;
  File? handoverImage;
  final ImagePicker _picker = ImagePicker();
  bool isLoading = false;

  // Contractor selection
  List<Map<String, dynamic>> availableContractors = [];
  String? selectedContractorId;
  bool isLoadingContractors = true;

  // Edit mode states for each step
  bool isDoorFrameEditable = false;
  bool isArchitectureEditable = false;
  bool isHandoverEditable = false;

  // Optional handovers list
  List<OptionalHandover> optionalHandovers = [];

  @override
  void initState() {
    super.initState();
    doorFrameHardware = widget.doorFrameHardware;
    architrave = widget.architrave;
    handover = widget.handover;

    // Initialize edit states - incomplete steps should be editable
    isDoorFrameEditable = !doorFrameHardware;
    isArchitectureEditable =
        !architrave && canEditArchitrave; // Enable if incomplete and unlocked
    isHandoverEditable =
        !handover && canEditHandover; // Enable if incomplete and unlocked

    _loadContractors();
    _loadExistingContractor();
  }

  Future<void> _loadContractors() async {
    try {
      // Get project data to fetch assignedContractorIds
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();

      if (!projectDoc.exists) {
        setState(() => isLoadingContractors = false);
        return;
      }

      final projectData = projectDoc.data() as Map<String, dynamic>;
      final List<dynamic> contractorIds =
          projectData['assignedContractorIds'] ?? [];

      // Fetch contractor details from users collection
      List<Map<String, dynamic>> contractors = [];
      for (String contractorId in contractorIds) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(contractorId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          contractors.add({
            'id': contractorId,
            'name': userData['empName'] ?? 'Unknown',
            'email': userData['email'] ?? '',
          });
        }
      }

      setState(() {
        availableContractors = contractors;
        isLoadingContractors = false;
      });
    } catch (e) {
      setState(() => isLoadingContractors = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contractors: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadExistingContractor() async {
    try {
      // Load existing contractor from task if available
      final taskDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('tasks')
          .doc(widget.taskId)
          .get();

      if (taskDoc.exists) {
        final taskData = taskDoc.data() as Map<String, dynamic>;
        if (taskData.containsKey('contractorId')) {
          setState(() {
            selectedContractorId = taskData['contractorId'];
          });
        }
      }
    } catch (e) {
      // Silently fail - contractor selection is optional for viewing
    }
  }

  // Check if architrave can be edited (door+frame+hardware must be completed)
  bool get canEditArchitrave => doorFrameHardware;

  // Check if handover can be edited (both door+frame+hardware and architrave must be completed)
  bool get canEditHandover => doorFrameHardware && architrave;

  void _addOptionalHandover() {
    setState(() {
      final handoverNumber = optionalHandovers.length + 1;
      optionalHandovers.add(
        OptionalHandover(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Handover $handoverNumber',
          toName: handoverNumber == 1 ? 'Designer' : 'Client',
        ),
      );
    });
  }

  void _removeOptionalHandover(String id) {
    setState(() {
      optionalHandovers.removeWhere((handover) => handover.id == id);
      // Renumber the remaining handovers
      for (int i = 0; i < optionalHandovers.length; i++) {
        optionalHandovers[i].title = 'Handover ${i + 1}';
        optionalHandovers[i].toName = i == 0 ? 'Designer' : 'Client';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress
    double progress = 0.0;
    if (doorFrameHardware) progress += 60.0;
    if (architrave) progress += 30.0;
    if (handover) progress += 10.0;

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Update Task',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Building ${widget.buildingNo} - Flat ${widget.flatNo}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress Bar
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: flutter.Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Overall Progress',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${progress.toInt()}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: progress == 100
                                        ? Colors.green
                                        : progress >= 60
                                        ? Colors.orange
                                        : Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress / 100,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation(
                                progress == 100
                                    ? Colors.green
                                    : progress >= 60
                                    ? Colors.orange
                                    : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Task Details
                      const Text(
                        'Task Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: flutter.Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              'Material Group',
                              widget.materialGroup,
                            ),
                            _buildDetailRow('Location', widget.location),
                            _buildDetailRow('Quantity', widget.qty.toString()),
                            if (widget.remark.isNotEmpty)
                              _buildDetailRow('Remark', widget.remark),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Contractor Selection
                      _buildContractorSelection(),
                      
                      const SizedBox(height: 24),

                      // Update Progress
                      const Text(
                        'Update Progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Progress Steps
                      // Door + Frame + Hardware step
                      _buildUpdateStep(
                        'Door + Frame + Hardware',
                        'Complete installation and hardware fitting',
                        '60%',
                        doorFrameHardware,
                        Colors.blue,
                        isDoorFrameEditable
                            ? (value) {
                                setState(() {
                                  doorFrameHardware = value ?? false;
                                  // If door+frame+hardware is completed, enable architrave editing if it's not completed
                                  if (doorFrameHardware && !architrave) {
                                    isArchitectureEditable = true;
                                  }
                                });
                              }
                            : null,
                        isEditable: isDoorFrameEditable,
                        onEditPressed: doorFrameHardware
                            ? () => _showEditConfirmation(
                                'Door + Frame + Hardware',
                                () {
                                  setState(() => isDoorFrameEditable = true);
                                },
                              )
                            : null,
                      ),

                      // Architrave step
                      _buildUpdateStep(
                        'Architrave',
                        'Install architrave around door frame',
                        '30%',
                        architrave,
                        Colors.orange,
                        (isArchitectureEditable && canEditArchitrave)
                            ? (value) {
                                setState(() {
                                  architrave = value ?? false;
                                  // If architrave is completed, enable handover editing if it's not completed
                                  if (architrave && !handover) {
                                    isHandoverEditable = true;
                                  }
                                });
                              }
                            : null,
                        isEditable: isArchitectureEditable && canEditArchitrave,
                        canEdit: canEditArchitrave,
                        onEditPressed: (architrave && canEditArchitrave)
                            ? () => _showEditConfirmation('Architrave', () {
                                setState(() => isArchitectureEditable = true);
                              })
                            : null,
                        isDisabled: !canEditArchitrave,
                        disabledReason: !doorFrameHardware
                            ? 'Complete Door + Frame + Hardware first'
                            : null,
                      ),

                      // Handover step
                      _buildUpdateStep(
                        'Handover',
                        'Final inspection and handover with photo',
                        '10%',
                        handover,
                        Colors.green,
                        (isHandoverEditable && canEditHandover)
                            ? (value) =>
                                  setState(() => handover = value ?? false)
                            : null,
                        requiresPhoto: true,
                        isEditable: isHandoverEditable && canEditHandover,
                        canEdit: canEditHandover,
                        onEditPressed: (handover && canEditHandover)
                            ? () => _showEditConfirmation('Handover', () {
                                setState(() => isHandoverEditable = true);
                              })
                            : null,
                        isDisabled: !canEditHandover,
                        disabledReason: !canEditHandover
                            ? (!doorFrameHardware
                                  ? 'Complete Door + Frame + Hardware first'
                                  : !architrave
                                  ? 'Complete Architrave first'
                                  : null)
                            : null,
                      ),

                      // Photo Upload for Handover
                      if (handover &&
                          (isHandoverEditable || handoverImage != null)) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: flutter.Border.all(
                              color: Colors.green[200]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Handover Photo Required',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (handoverImage != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    handoverImage!,
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (isHandoverEditable) ...[
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        onPressed: _pickHandoverPhoto,
                                        icon: const Icon(Icons.edit),
                                        label: const Text('Change Photo'),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => setState(
                                          () => handoverImage = null,
                                        ),
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        label: const Text(
                                          'Remove',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ] else if (isHandoverEditable) ...[
                                ElevatedButton.icon(
                                  onPressed: _pickHandoverPhoto,
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Upload Handover Photo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Optional Handovers Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Handover (Optional)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: _addOptionalHandover,
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.purple[100],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Color(0xFF6D28D9),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Optional Handovers List
                      if (optionalHandovers.isNotEmpty) ...[
                        ...optionalHandovers.map((optionalHandover) =>
                            _buildOptionalHandoverCard(optionalHandover)),
                        const SizedBox(height: 16),
                      ],

                      // Update Button - only show if any step is editable and has changes
                      if (_hasEditableChanges()) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _updateTaskProgress,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Updating...'),
                                    ],
                                  )
                                : const Text(
                                    'Update Task Progress',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
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

  Widget _buildContractorSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assigned Contractor',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        if (isLoadingContractors)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: flutter.Border.all(color: Colors.grey[200]!),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Loading contractors...'),
              ],
            ),
          )
        else if (availableContractors.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: flutter.Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No contractors assigned to this project',
                    style: TextStyle(color: Colors.orange[900]),
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            value: selectedContractorId,
            decoration: InputDecoration(
              isCollapsed: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              prefixIcon: const Icon(Icons.person),
            ),
            hint: const Text('Select contractor'),
            items: availableContractors.map((contractor) {
              return DropdownMenuItem<String>(
                value: contractor['id'],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      contractor['name'] ?? 'unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: _hasEditableChanges()
                ? (value) {
                    setState(() {
                      selectedContractorId = value;
                    });
                  }
                : null,
          ),
        
        if (selectedContractorId == null && _hasEditableChanges())
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please select a contractor before updating',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOptionalHandoverCard(OptionalHandover optionalHandover) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: flutter.Border.all(color: Colors.purple[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                optionalHandover.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6D28D9),
                ),
              ),
              IconButton(
                onPressed: () => _removeOptionalHandover(optionalHandover.id),
                icon: const Icon(
                  Icons.delete,
                  color: Colors.red,
                  size: 20,
                ),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'To: ${optionalHandover.toName}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text(
              'Mark as completed',
              style: TextStyle(fontSize: 14),
            ),
            value: optionalHandover.isCompleted,
            onChanged: (value) {
              setState(() {
                optionalHandover.isCompleted = value ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: const Color(0xFF6D28D9),
          ),
          if (optionalHandover.isCompleted) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasEditableChanges() {
    return (isDoorFrameEditable) ||
        (canEditArchitrave && isArchitectureEditable) ||
        (canEditHandover && isHandoverEditable) ||
        optionalHandovers.isNotEmpty;
  }

  Future<void> _showEditConfirmation(
    String stepName,
    VoidCallback onConfirm,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Confirmation'),
          content: Text(
            'Do you want to edit the "$stepName" step? This will allow you to modify the completion status.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
              child: const Text('Enable Editing'),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateStep(
    String title,
    String description,
    String percentage,
    bool isCompleted,
    Color color,
    ValueChanged<bool?>? onChanged, {
    bool requiresPhoto = false,
    bool isEditable = false,
    bool canEdit = true,
    VoidCallback? onEditPressed,
    bool isDisabled = false,
    String? disabledReason,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDisabled
            ? Colors.grey[100]
            : isCompleted
            ? color.withOpacity(0.1)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: flutter.Border.all(
          color: isDisabled
              ? Colors.grey[300]!
              : isCompleted
              ? color.withOpacity(0.3)
              : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDisabled
                      ? Colors.grey[400]
                      : isCompleted
                      ? color
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : isDisabled
                    ? const Icon(Icons.lock, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDisabled
                            ? Colors.grey[500]
                            : isCompleted
                            ? color
                            : Colors.grey[700],
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDisabled ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    if (isDisabled && disabledReason != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        disabledReason,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDisabled ? Colors.grey[200] : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  percentage,
                  style: TextStyle(
                    color: isDisabled ? Colors.grey[600] : color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Show edit button if step is completed and can be edited
          if (isCompleted && onEditPressed != null && !isEditable) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEditPressed,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ]
          // Show checkbox if step is editable and not disabled OR if step is not completed and not disabled
          else if (!isDisabled && (isEditable || !isCompleted)) ...[
            CheckboxListTile(
              title: Text(
                'Mark as completed${requiresPhoto ? ' (Photo required)' : ''}',
                style: const TextStyle(fontSize: 14),
              ),
              value: isCompleted,
              onChanged: onChanged,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: color,
            ),
          ]
          // Show completed status if completed but not editable
          else if (isCompleted && !isEditable) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: color, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Completed',
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ]
          // Show disabled state
          else if (isDisabled) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Locked - Complete previous steps first',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickHandoverPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        // Compress the image before setting it
        final compressedImage = await _compressImage(File(image.path));
        setState(() {
          handoverImage = compressedImage;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: ${e.toString()}')),
        );
      }
    }
  }

  Future<File> _compressImage(File imageFile) async {
    try {
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        quality: 70,
        minWidth: 800,
        minHeight: 600,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes != null) {
        final compressedFile = File('${imageFile.path}_compressed.jpg');
        await compressedFile.writeAsBytes(compressedBytes);
        return compressedFile;
      }
      return imageFile;
    } catch (e) {
      print('Error compressing image: $e');
      return imageFile;
    }
  }

  Future<String?> _uploadHandoverPhoto() async {
    if (handoverImage == null) return null;

    try {
      final fileName =
          'handover_${widget.taskId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('projects')
          .child(widget.projectId)
          .child('tasks')
          .child(widget.taskId)
          .child(fileName);

      final uploadTask = ref.putFile(handoverImage!);
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload photo: ${e.toString()}');
    }
  }

  Future<void> _updateTaskProgress() async {
    // Validate contractor selection
    if (selectedContractorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a contractor before updating'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate handover photo requirement
    if (handover && handoverImage == null && isHandoverEditable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo is required for handover completion'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      String? photoUrl;

      // Upload photo if handover is completed
      if (handover && handoverImage != null) {
        photoUrl = await _uploadHandoverPhoto();
      }

      // Prepare update data
      Map<String, dynamic> updateData = {
        'doorFrameHardware': doorFrameHardware,
        'architrave': architrave,
        'handover': handover,
        'updatedAt': Timestamp.now(),
        'contractorId': selectedContractorId, // Add contractor ID
      };

      // Add photo URL if uploaded
      if (photoUrl != null) {
        updateData['handoverPhotoUrl'] = photoUrl;
      }

      // Add optional handovers data
      if (optionalHandovers.isNotEmpty) {
        updateData['optionalHandovers'] = optionalHandovers.map((handover) => {
          'id': handover.id,
          'title': handover.title,
          'toName': handover.toName,
          'isCompleted': handover.isCompleted,
          'photoUrl': handover.photoUrl,
        }).toList();
      }

      // Update task in Firestore
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('tasks')
          .doc(widget.taskId)
          .update(updateData);
      
      // also update the feed
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('feed')
          .add({
            'taskId': widget.taskId,
            'title': 'Task Updated',
            'description':
                'Task for Building ${widget.buildingNo}, Flat ${widget.flatNo} has been updated.',
            'timestamp': Timestamp.now(),
            'type': 'task_update',
            'contractorId': selectedContractorId,
          });

      // Reset edit states after successful update
      setState(() {
        isDoorFrameEditable = false;
        isArchitectureEditable = false;
        isHandoverEditable = false;
      });

      // Show success message and go back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating task: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
}
