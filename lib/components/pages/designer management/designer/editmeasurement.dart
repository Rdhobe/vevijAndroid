import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class EditMeasurementsPage extends StatefulWidget {
  const EditMeasurementsPage({super.key});

  @override
  State<EditMeasurementsPage> createState() => _EditMeasurementsPageState();
}

class _EditMeasurementsPageState extends State<EditMeasurementsPage> {
  String? selectedBatchId;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _measurementSearchController = TextEditingController();
  String _selectedSearchFilter = "All"; // Default filter
  
  List<Map<String, dynamic>> _allProjects = [];
  List<Map<String, dynamic>> _filteredProjects = [];
  Map<String, dynamic>? _selectedProject;
  List<Map<String, dynamic>> batches = [];
  List<Map<String, dynamic>> measurements = [];
  List<Map<String, dynamic>> _filteredMeasurements = [];
  bool isLoadingBatches = false;
  bool isLoadingMeasurements = false;

  final List<String> _searchFilters = [
    "All",
    "Location",
    "Flat No",
    "Date",
    "Wall Thickness",
    "Width",
    "Height",
  ];

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _searchController.addListener(_filterProjects);
    _measurementSearchController.addListener(_filterMeasurements);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _measurementSearchController.dispose();
    super.dispose();
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
      _showErrorSnackBar("Failed to load projects: $e");
    }
  }

  Future<void> _loadBatches(String projectId) async {
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
        measurements = [];
      });
    } catch (e) {
      setState(() {
        isLoadingBatches = false;
        batches = [];
      });
      _showErrorSnackBar("Failed to load batches: $e");
    }
  }

  Future<void> _loadMeasurements(String projectId, String batchId) async {
    setState(() => isLoadingMeasurements = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('measurements')
          .where('batch', isEqualTo: batchId)
          .orderBy('createdAt', descending: true)
          .get();

      final loadedMeasurements = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          "id": doc.id,
          "batch": data['batch'] ?? "",
          "location": data['location'] ?? "",
          "flatNo": data['flatNo'] ?? "",
          "wallThickness": data['wallThickness'] ?? "",
          "width": data['width'] ?? "",
          "height": data['height'] ?? "",
          "beam": data['beam'] ?? "",
          "createdAt": data['createdAt'],
          "createdBy": data['createdBy'] ?? "",
          "updatedAt": data['updatedAt'],
          "updatedBy": data['updatedBy'],
        };
      }).toList();

      setState(() {
        measurements = loadedMeasurements;
        _filteredMeasurements = loadedMeasurements;
        isLoadingMeasurements = false;
      });
    } catch (e) {
      setState(() {
        isLoadingMeasurements = false;
        measurements = [];
        _filteredMeasurements = [];
      });
      _showErrorSnackBar("Failed to load measurements: $e");
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

  void _filterMeasurements() {
    final query = _measurementSearchController.text.toLowerCase();
    
    setState(() {
      _filteredMeasurements = measurements.where((measurement) {
        if (query.isEmpty) return true;
        
        switch (_selectedSearchFilter) {
          case "Location":
            final location = measurement['location'].toString().toLowerCase();
            return location.contains(query);
            
          case "Flat No":
            final flatNo = measurement['flatNo'].toString().toLowerCase();
            return flatNo.contains(query);
            
          case "Date":
            final createdAt = measurement['createdAt'] as Timestamp?;
            final updatedAt = measurement['updatedAt'] as Timestamp?;
            final dateToShow = updatedAt ?? createdAt;
            if (dateToShow != null) {
              final dateStr = DateFormat('MMM dd, yyyy').format(dateToShow.toDate()).toLowerCase();
              return dateStr.contains(query);
            }
            return false;
            
          case "Wall Thickness":
            final wallThickness = measurement['wallThickness'].toString().toLowerCase();
            return wallThickness.contains(query);
            
          case "Width":
            final width = measurement['width'].toString().toLowerCase();
            return width.contains(query);
            
          case "Height":
            final height = measurement['height'].toString().toLowerCase();
            return height.contains(query);
            
          case "All":
          default:
            final location = measurement['location'].toString().toLowerCase();
            final flatNo = measurement['flatNo'].toString().toLowerCase();
            final wallThickness = measurement['wallThickness'].toString().toLowerCase();
            final width = measurement['width'].toString().toLowerCase();
            final height = measurement['height'].toString().toLowerCase();
            
            // Check date
            bool dateMatch = false;
            final createdAt = measurement['createdAt'] as Timestamp?;
            final updatedAt = measurement['updatedAt'] as Timestamp?;
            final dateToShow = updatedAt ?? createdAt;
            if (dateToShow != null) {
              final dateStr = DateFormat('MMM dd, yyyy').format(dateToShow.toDate()).toLowerCase();
              dateMatch = dateStr.contains(query);
            }
            
            return location.contains(query) || 
                   flatNo.contains(query) || 
                   wallThickness.contains(query) ||
                   width.contains(query) ||
                   height.contains(query) ||
                   dateMatch;
        }
      }).toList();
    });
  }

  Future<void> _deleteMeasurement(String measurementId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text("Delete Measurement"),
          ],
        ),
        content: const Text(
          "Are you sure you want to delete this measurement? This action cannot be undone.",
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(_selectedProject!['id'])
            .collection('measurements')
            .doc(measurementId)
            .delete();

        _showSuccessSnackBar("Measurement deleted successfully!");
        _loadMeasurements(_selectedProject!['id'], selectedBatchId!);
      } catch (e) {
        _showErrorSnackBar("Failed to delete measurement: $e");
      }
    }
  }

  void _editMeasurement(Map<String, dynamic> measurement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditMeasurementSheet(
        measurement: measurement,
        projectId: _selectedProject!['id'],
        onSaved: () {
          _loadMeasurements(_selectedProject!['id'], selectedBatchId!);
        },
      ),
    );
  }

  Widget _buildMeasurementSearchField() {
    return Column(
      children: [
        // Filter Dropdown
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedSearchFilter,
            decoration: InputDecoration(
              labelText: "Search Filter",
              labelStyle: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.filter_list_rounded,
                color: Colors.green[600],
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
            ),
            items: _searchFilters.map((filter) {
              return DropdownMenuItem(
                value: filter,
                child: Text(
                  filter,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedSearchFilter = value!;
                _filterMeasurements(); // Re-filter with new filter
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        
        // Search Field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: _measurementSearchController,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: _getSearchHintText(),
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.green[400],
                size: 22,
              ),
              suffixIcon: _measurementSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
                      onPressed: () {
                        _measurementSearchController.clear();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getSearchHintText() {
    switch (_selectedSearchFilter) {
      case "Location":
        return "Search by location (e.g., Master Bedroom)...";
      case "Flat No":
        return "Search by flat number (e.g., 203)...";
      case "Date":
        return "Search by date (e.g., Sep 27, 2025)...";
      case "Wall Thickness":
        return "Search by wall thickness (e.g., 70)...";
      case "Width":
        return "Search by width (e.g., 710)...";
      case "Height":
        return "Search by height (e.g., 2170)...";
      case "All":
      default:
        return "Search by location, flat no, date, or measurements...";
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
                  measurements = [];
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

  Widget _buildBatchDropdown() {
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
                "Select Batch",
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
                      if (value != null) {
                        _loadMeasurements(_selectedProject!['id'], value);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementsList() {
    if (selectedBatchId == null) return const SizedBox.shrink();

    if (isLoadingMeasurements) {
      return _buildModernCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (measurements.isEmpty) {
      return _buildModernCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  "No measurements found",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Search bar for measurements
        _buildMeasurementSearchField(),
        const SizedBox(height: 16),
        
        // Measurements list
        _buildModernCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
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
                    Text(
                      "Measurements (${_filteredMeasurements.length})",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (_measurementSearchController.text.isNotEmpty || _selectedSearchFilter != "All") ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_alt,
                              size: 12,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedSearchFilter,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _filteredMeasurements.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "No measurements match your search",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredMeasurements.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final measurement = _filteredMeasurements[index];
                        return _buildMeasurementCard(measurement);
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementCard(Map<String, dynamic> measurement) {
    final createdAt = measurement['createdAt'] as Timestamp?;
    final updatedAt = measurement['updatedAt'] as Timestamp?;
    final dateToShow = updatedAt ?? createdAt;
    final dateStr = dateToShow != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(dateToShow.toDate())
        : "Unknown date";
    
    final isUpdated = updatedAt != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.room_outlined,
                            size: 18,
                            color: Colors.deepPurple[400],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            measurement['location'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Flat ${measurement['flatNo']}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.deepPurple[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isUpdated ? Icons.edit_calendar : Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (isUpdated) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Updated",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _editMeasurement(measurement),
                      icon: const Icon(Icons.edit_outlined),
                      color: Colors.blue[600],
                      tooltip: "Edit",
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _deleteMeasurement(measurement['id']),
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red[600],
                      tooltip: "Delete",
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildMeasurementChip(
                  "Wall",
                  "${measurement['wallThickness']} mm",
                  Icons.width_normal_outlined,
                ),
                _buildMeasurementChip(
                  "Width",
                  "${measurement['width']} cm",
                  Icons.swap_horiz_rounded,
                ),
                _buildMeasurementChip(
                  "Height",
                  "${measurement['height']} cm",
                  Icons.swap_vert_rounded,
                ),
                if (measurement['beam'].isNotEmpty)
                  _buildMeasurementChip(
                    "Beam",
                    "${measurement['beam']} cm",
                    Icons.architecture_outlined,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Edit Measurements",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchField(),
            const SizedBox(height: 24),
            _buildProjectDropdown(),
            const SizedBox(height: 24),
            _buildBatchDropdown(),
            const SizedBox(height: 24),
            _buildMeasurementsList(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Edit Measurement Bottom Sheet
class EditMeasurementSheet extends StatefulWidget {
  final Map<String, dynamic> measurement;
  final String projectId;
  final VoidCallback onSaved;

  const EditMeasurementSheet({
    super.key,
    required this.measurement,
    required this.projectId,
    required this.onSaved,
  });

  @override
  State<EditMeasurementSheet> createState() => _EditMeasurementSheetState();
}

class _EditMeasurementSheetState extends State<EditMeasurementSheet> {
  late TextEditingController flatNoController;
  late TextEditingController wallThicknessController;
  late TextEditingController widthController;
  late TextEditingController heightController;
  late TextEditingController beamController;
  String? selectedLocation;

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

  @override
  void initState() {
    super.initState();
    flatNoController = TextEditingController(text: widget.measurement['flatNo']);
    wallThicknessController = TextEditingController(text: widget.measurement['wallThickness']);
    widthController = TextEditingController(text: widget.measurement['width']);
    heightController = TextEditingController(text: widget.measurement['height']);
    beamController = TextEditingController(text: widget.measurement['beam']);
    selectedLocation = widget.measurement['location'];
  }

  @override
  void dispose() {
    flatNoController.dispose();
    wallThicknessController.dispose();
    widthController.dispose();
    heightController.dispose();
    beamController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (selectedLocation == null || flatNoController.text.isEmpty ||
        wallThicknessController.text.isEmpty || widthController.text.isEmpty ||
        heightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('measurements')
          .doc(widget.measurement['id'])
          .update({
        'location': selectedLocation,
        'flatNo': flatNoController.text,
        'wallThickness': wallThicknessController.text,
        'width': widthController.text,
        'height': heightController.text,
        'beam': beamController.text,
        'updatedAt': Timestamp.now(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text("Measurement updated successfully!"),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? suffix,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Edit Measurement",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Location Dropdown
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Location",
                  prefixIcon: Icon(Icons.room_outlined, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
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
            const SizedBox(height: 16),
            
            _buildTextField(
              label: "Flat No",
              controller: flatNoController,
              icon: Icons.home_outlined,
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              label: "Wall Thickness",
              controller: wallThicknessController,
              suffix: "mm",
              icon: Icons.width_normal_outlined,
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              label: "Width",
              controller: widthController,
              suffix: "cm",
              icon: Icons.swap_horiz_rounded,
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              label: "Height",
              controller: heightController,
              suffix: "cm",
              icon: Icons.swap_vert_rounded,
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              label: "Beam",
              controller: beamController,
              suffix: "cm",
              icon: Icons.architecture_outlined,
            ),
            const SizedBox(height: 24),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.save_rounded),
                label: const Text(
                  "Save Changes",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}