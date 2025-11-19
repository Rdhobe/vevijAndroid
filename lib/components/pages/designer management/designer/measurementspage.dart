import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'editmeasurement.dart';

class Measurementspage extends StatefulWidget {
  const Measurementspage({super.key});

  @override
  State<Measurementspage> createState() => _MeasurementspageState();
}

class _MeasurementspageState extends State<Measurementspage>
    with TickerProviderStateMixin {
  String? selectedLocation;
  String? selectedBatchId;
  final List<String> locations = [
    "Main Door",
    "Common Bedroom",
    "Common Toilet",
    "Master Bedroom",
    "Master Toilet",
    "Kids Bedroom",
    "Kids Toilet",
    "Guest Bedroom",
    "Guest Toilet",
  ];
  
  final TextEditingController newBatchController = TextEditingController();
  final TextEditingController flatNoController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController wallThicknessController = TextEditingController();
  final TextEditingController widthController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController beamController = TextEditingController();
  
  // Focus nodes for navigation
  final FocusNode flatNoFocusNode = FocusNode();
  final FocusNode wallThicknessFocusNode = FocusNode();
  final FocusNode widthFocusNode = FocusNode();
  final FocusNode heightFocusNode = FocusNode();
  final FocusNode beamFocusNode = FocusNode();
  
  List<Map<String, dynamic>> _allProjects = [];
  List<Map<String, dynamic>> _filteredProjects = [];
  Map<String, dynamic>? _selectedProject;
  List<Map<String, dynamic>> batches = [];
  bool isLoadingBatches = false;
  bool showCreateBatchField = false;
  bool _isSaving = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _searchController.addListener(_filterProjects);
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    flatNoFocusNode.dispose();
    wallThicknessFocusNode.dispose();
    widthFocusNode.dispose();
    heightFocusNode.dispose();
    beamFocusNode.dispose();
    newBatchController.dispose();
    flatNoController.dispose();
    wallThicknessController.dispose();
    widthController.dispose();
    heightController.dispose();
    beamController.dispose();
    super.dispose();
  }

  Future<void> _loadBatches(String projectId) async {
    if (projectId.isEmpty) {
      setState(() {
        batches = [];
        isLoadingBatches = false;
      });
      return;
    }

    setState(() => isLoadingBatches = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('batch')
          .orderBy('createdAt', descending: true)
          .get();

      final loadedBatches = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          "id": doc.id,
          "name": data['name'] ?? "Unnamed",
          "startDate": data['startDate'],
          "endDate": data['endDate'],
        };
      }).toList();

      setState(() {
        batches = loadedBatches;
        isLoadingBatches = false;
        selectedBatchId = null;
        showCreateBatchField = false;
      });
    } catch (e) {
      setState(() {
        isLoadingBatches = false;
        batches = [];
      });
      _showErrorSnackBar("Failed to load batches: ${e.toString()}");
      debugPrint("Error loading batches: $e");
    }
  }

  Future<void> _loadProjects() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .orderBy('createdAt', descending: true)
          .get();

      final projects = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          "id": doc.id,
          "name": data['name'] ?? "Unnamed Project",
          "customerName": data['customerName'] ?? "N/A",
          "projectAddress": data['projectAddress'] ?? "N/A",
        };
      }).toList();
      
      setState(() {
        _allProjects = projects;
        _filteredProjects = projects;
      });
    } catch (e) {
      _showErrorSnackBar("Failed to load projects: ${e.toString()}");
      debugPrint("Error loading projects: $e");
    }
  }

  void _filterProjects() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProjects = _allProjects.where((proj) {
        final name = proj['name'].toString().toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  // Check if measurement already exists
  Future<bool> _checkDuplicateMeasurement({
    required String projectId,
    required String batchId,
    required String location,
    required String flatNo,
  }) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('measurements')
          .where('batch', isEqualTo: batchId)
          .where('location', isEqualTo: location)
          .where('flatNo', isEqualTo: flatNo)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint("Error checking duplicate measurement: $e");
      // In case of error, return false to allow the operation
      return false;
    }
  }

  Widget _buildModernCard({
    required Widget child,
    EdgeInsets? padding,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _buildMeasurementField({
    required String label,
    required TextEditingController controller,
    String? suffix,
    IconData? icon,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    VoidCallback? onFieldSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textInputAction: nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        onSubmitted: (value) {
          if (nextFocusNode != null) {
            FocusScope.of(context).requestFocus(nextFocusNode);
          } else if (onFieldSubmitted != null) {
            onFieldSubmitted();
          } else {
            FocusScope.of(context).unfocus();
          }
        },
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          prefixIcon: icon != null 
            ? Icon(icon, color: Colors.deepPurple[300]) 
            : null,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: "Search projects...",
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.deepPurple[300],
            size: 24,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildProjectDropdown() {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business_center_rounded,
                  color: Colors.deepPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Select Project",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: DropdownButtonFormField<Map<String, dynamic>>(
              isExpanded: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                hintText: "Choose a project",
              ),
              items: _filteredProjects.map((proj) {
                return DropdownMenuItem(
                  value: proj,
                  child: Text(
                    "${proj['name']} - ${proj['customerName']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProject = value;
                  selectedBatchId = null;
                  batches = [];
                  showCreateBatchField = false;
                });
                
                if (value != null) {
                  _loadBatches(value['id']);
                }
              },
              value: _selectedProject,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedProjectCard() {
    if (_selectedProject == null) return const SizedBox.shrink();
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      child: _buildModernCard(
        color: Colors.deepPurple[50],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedProject!['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Selected Project",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple[300],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    Icons.person_outline_rounded,
                    "Customer",
                    _selectedProject!['customerName'],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    "Address",
                    _selectedProject!['projectAddress'],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBatchSection() {
    if (_selectedProject == null) return const SizedBox.shrink();

    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.orange[700],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Batch Configuration",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      hintText: "Select Batch",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    value: selectedBatchId,
                    items: isLoadingBatches
                        ? [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text("Loading batches..."),
                                ],
                              ),
                            ),
                          ]
                        : batches.isEmpty
                            ? [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text(
                                    "No batches found",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ]
                            : batches.map((batch) {
                                return DropdownMenuItem<String>(
                                  value: batch['id'],
                                  child: Text(
                                    batch['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              }).toList(),
                    onChanged: isLoadingBatches
                        ? null
                        : (value) {
                            setState(() {
                              selectedBatchId = value;
                            });
                          },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: isLoadingBatches
                        ? null
                        : () {
                            setState(() {
                              showCreateBatchField = !showCreateBatchField;
                              if (showCreateBatchField) {
                                selectedBatchId = null;
                              }
                            });
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        showCreateBatchField ? Icons.close : Icons.add,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (showCreateBatchField) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: TextField(
                      controller: newBatchController,
                      decoration: InputDecoration(
                        hintText: "Enter new batch name",
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        prefixIcon: Icon(
                          Icons.new_label_outlined,
                          color: Colors.orange[600],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.orange[600],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _createBatch,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeasurementsSection() {
    if (_selectedProject == null || selectedBatchId == null) {
      return const SizedBox.shrink();
    }

    final isWeb = MediaQuery.of(context).size.width > 600;
    final crossAxisCount = isWeb ? 5 : 2;
    
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.straighten_rounded,
                  color: Colors.green[700],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Measurements",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                hintText: "Select Location",
                prefixIcon: Icon(
                  Icons.room_outlined,
                  color: Colors.green[600],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              value: selectedLocation,
              items: locations.map((loc) {
                return DropdownMenuItem(value: loc, child: Text(loc));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedLocation = value;
                });
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: isWeb ? 4 : 3.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildMeasurementField(
                label: "Flat No",
                controller: flatNoController,
                icon: Icons.home_outlined,
                focusNode: flatNoFocusNode,
                nextFocusNode: wallThicknessFocusNode,
              ),
              _buildMeasurementField(
                label: "Wall Thickness",
                controller: wallThicknessController,
                suffix: "mm",
                icon: Icons.width_normal_outlined,
                focusNode: wallThicknessFocusNode,
                nextFocusNode: widthFocusNode,
              ),
              _buildMeasurementField(
                label: "Width",
                controller: widthController,
                suffix: "cm",
                icon: Icons.swap_horiz_rounded,
                focusNode: widthFocusNode,
                nextFocusNode: heightFocusNode,
              ),
              _buildMeasurementField(
                label: "Height",
                controller: heightController,
                suffix: "cm",
                icon: Icons.swap_vert_rounded,
                focusNode: heightFocusNode,
                nextFocusNode: beamFocusNode,
              ),
              _buildMeasurementField(
                label: "Beam",
                controller: beamController,
                suffix: "cm",
                icon: Icons.architecture_outlined,
                focusNode: beamFocusNode,
                onFieldSubmitted: _saveMeasurement,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    if (_selectedProject == null || selectedBatchId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.deepPurple[300]!],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveMeasurement,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save_rounded, color: Colors.white),
        label: Text(
          _isSaving ? "Saving..." : "Save Measurement",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _createBatch() async {
    final batchName = newBatchController.text.trim();
    
    if (batchName.isEmpty) {
      _showErrorSnackBar("Please enter batch name");
      return;
    }

    if (_selectedProject == null) {
      _showErrorSnackBar("No project selected");
      return;
    }

    try {
      final batch = {
        'name': batchName,
        'createdAt': Timestamp.now(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        'startDate': Timestamp.now(),
        'endDate': Timestamp.now(),
      };

      String projectId = _selectedProject!['id'];
      final docRef = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('batch')
          .add(batch);

      setState(() {
        batches.insert(0, {
          "id": docRef.id,
          "name": batch['name'],
          "startDate": batch['startDate'],
          "endDate": batch['endDate'],
        });
        selectedBatchId = docRef.id;
        showCreateBatchField = false;
      });

      newBatchController.clear();
      _showSuccessSnackBar("Batch created successfully!");
    } catch (e) {
      _showErrorSnackBar("Failed to create batch: ${e.toString()}");
      debugPrint("Error creating batch: $e");
    }
  }

  Future<void> _saveMeasurement() async {
    // Prevent multiple saves
    if (_isSaving) return;

    // Validate required fields
    if (_selectedProject == null) {
      _showErrorSnackBar("Please select a project first");
      return;
    }
    
    if (selectedBatchId == null) {
      _showErrorSnackBar("Please select a batch first");
      return;
    }
    
    if (selectedLocation == null) {
      _showErrorSnackBar("Please select a location");
      return;
    }
    
    final flatNo = flatNoController.text.trim();
    final wallThickness = wallThicknessController.text.trim();
    final width = widthController.text.trim();
    final height = heightController.text.trim();
    
    if (flatNo.isEmpty) {
      _showErrorSnackBar("Please enter flat number");
      FocusScope.of(context).requestFocus(flatNoFocusNode);
      return;
    }
    
    if (wallThickness.isEmpty) {
      _showErrorSnackBar("Please enter wall thickness");
      FocusScope.of(context).requestFocus(wallThicknessFocusNode);
      return;
    }
    
    if (width.isEmpty) {
      _showErrorSnackBar("Please enter width");
      FocusScope.of(context).requestFocus(widthFocusNode);
      return;
    }
    
    if (height.isEmpty) {
      _showErrorSnackBar("Please enter height");
      FocusScope.of(context).requestFocus(heightFocusNode);
      return;
    }

    setState(() => _isSaving = true);

    try {
      String projectId = _selectedProject!['id'];

      // Check for duplicate measurement
      final isDuplicate = await _checkDuplicateMeasurement(
        projectId: projectId,
        batchId: selectedBatchId!,
        location: selectedLocation!,
        flatNo: flatNo,
      );

      if (isDuplicate) {
        setState(() => _isSaving = false);
        _showErrorSnackBar(
          "Measurement already exists for this batch, location, and flat number!"
        );
        return;
      }

      // Save measurement data to Firestore
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _isSaving = false);
        _showErrorSnackBar("User not authenticated");
        return;
      }

      final measurementData = {
        'batch': selectedBatchId,
        'location': selectedLocation,
        'flatNo': flatNo,
        'wallThickness': wallThickness,
        'width': width,
        'height': height,
        'beam': beamController.text.trim(),
        'createdAt': Timestamp.now(),
        'createdBy': currentUser.uid,
      };

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('measurements')
          .add(measurementData);

      setState(() => _isSaving = false);
      _showSuccessSnackBar("Measurement saved successfully!");
      
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnackBar("Failed to save measurement: ${e.toString()}");
      debugPrint("Error saving measurement: $e");
    }
  }
  
  void _showSuccessSnackBar([String? message]) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message ?? "Operation completed successfully!"),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    
    // Clear measurement fields after successful save
    if (message == null || message.contains("Measurement")) {
      _clearMeasurementFields();
    }
  }
  
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
  
  void _clearMeasurementFields() {
    flatNoController.clear();
    wallThicknessController.clear();
    widthController.clear();
    heightController.clear();
    beamController.clear();
    
    // Reset focus to first field
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(flatNoFocusNode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Measurements",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditMeasurementsPage(),
                ),
              );
            },
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: "Edit Measurements",
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(maxWidth: isWeb ? 2000 : double.infinity),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchField(),
                  const SizedBox(height: 24),
          
                  _buildProjectDropdown(),
                  const SizedBox(height: 24),
          
                  _buildSelectedProjectCard(),
                  if (_selectedProject != null) const SizedBox(height: 24),
          
                  _buildBatchSection(),
                  if (_selectedProject != null) const SizedBox(height: 24),
          
                  _buildMeasurementsSection(),
                  if (_selectedProject != null && selectedBatchId != null) const SizedBox(height: 32),
          
                  _buildSaveButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}