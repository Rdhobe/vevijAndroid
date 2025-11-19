import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'framepreview.dart';
class WorkingListPage extends StatefulWidget {
  const WorkingListPage({super.key});

  @override
  State<WorkingListPage> createState() => _WorkingListPageState();
}

class _WorkingListPageState extends State<WorkingListPage>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minGapController = TextEditingController(text: '5');
  final TextEditingController _maxGapController = TextEditingController(text: '25');

  List<Map<String, dynamic>> _allProjects = [];
  List<Map<String, dynamic>> _filteredProjects = [];
  Map<String, dynamic>? _selectedProject;
  List<Map<String, dynamic>> batches = [];
  String? selectedBatchId;
  List<Map<String, dynamic>> measurements = [];
  bool isLoadingBatches = false;
  bool isLoadingMeasurements = false;
  bool showPreview = false;
  bool showGapForm = false;
  bool showFramePreview = false;

  Map<String, List<Map<String, dynamic>>> generatedFrames = {};

  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _searchController.addListener(_filterProjects);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _cardAnimationController, curve: Curves.bounceOut),
    );

    _animationController.forward();
    _cardAnimationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minGapController.dispose();
    _maxGapController.dispose();
    _animationController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .orderBy('createdAt', descending: true)
          .get();

      if (!mounted) return;

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
      if (!mounted) return;
      _showErrorSnackBar("Failed to load projects: $e");
    }
  }

  Future<void> _loadBatches(String projectId) async {
    if (!mounted) return;
    setState(() => isLoadingBatches = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('batch')
          .orderBy('createdAt', descending: true)
          .get();

      if (!mounted) return;

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
        showPreview = false;
        showGapForm = false;
        showFramePreview = false;
        measurements = [];
        generatedFrames = {};
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingBatches = false;
        batches = [];
      });
      _showErrorSnackBar("Failed to load batches: $e");
    }
  }

  Future<void> _loadMeasurements(String projectId, String batchId) async {
    if (!mounted) return;
    setState(() => isLoadingMeasurements = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('measurements')
          .where('batch', isEqualTo: batchId)
          .orderBy('createdAt')
          .get();

      if (!mounted) return;

      final loadedMeasurements = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          "id": doc.id,
          "location": data['location'] ?? "N/A",
          "flatNo": data['flatNo'] ?? "N/A",
          "wallThickness": double.tryParse(data['wallThickness'].toString()) ?? 0.0,
          "width": double.tryParse(data['width'].toString()) ?? 0.0,
          "height": double.tryParse(data['height'].toString()) ?? 0.0,
          "beam": double.tryParse(data['beam'].toString()) ?? 0.0,
          "createdAt": data['createdAt'],
        };
      }).toList();

      setState(() {
        measurements = loadedMeasurements;
        isLoadingMeasurements = false;
        showPreview = true;
        showGapForm = false;
        showFramePreview = false;
        generatedFrames = {};
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingMeasurements = false;
        measurements = [];
        showPreview = false;
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

  List<Map<String, dynamic>> _getPreviewData() {
    if (measurements.length <= 6) {
      return measurements;
    }

    List<Map<String, dynamic>> preview = [];
    preview.addAll(measurements.take(3));
    preview.addAll(measurements.skip(measurements.length - 3));
    return preview;
  }

  Map<String, List<Map<String, dynamic>>> _generateFrames(double minGap, double maxGap) {
    if (measurements.isEmpty) return {'frames': []};
    return {'frames': _generateCompleteFrames(minGap, maxGap)};
  }

  List<Map<String, dynamic>> _generateCompleteFrames(double minGap, double maxGap) {
    List<Map<String, dynamic>> frames = [];
    List<Map<String, dynamic>> remaining = List.from(measurements);

    while (remaining.isNotEmpty) {
      Map<String, dynamic> bestFrame = _findOptimalFrame(remaining, minGap, maxGap);
      frames.add(bestFrame);

      List<String> usedIds = (bestFrame['measurements'] as List<Map<String, dynamic>>)
          .map((m) => m['id'] as String)
          .toList();
      remaining.removeWhere((m) => usedIds.contains(m['id']));
    }

    return frames;
  }

  Map<String, dynamic> _findOptimalFrame(
    List<Map<String, dynamic>> candidates,
    double minGap,
    double maxGap,
  ) {
    for (int groupSize = candidates.length; groupSize >= 1; groupSize--) {
      for (int start = 0; start <= candidates.length - groupSize; start++) {
        List<Map<String, dynamic>> testGroup = candidates.sublist(start, start + groupSize);
        Map<String, dynamic>? frame = _calculateFrameForGroup(testGroup, minGap, maxGap);

        if (frame != null) {
          return frame;
        }
      }
    }
    return _calculateFrameForGroup([candidates.first], minGap, maxGap)!;
  }

  Map<String, dynamic>? _calculateFrameForGroup(
    List<Map<String, dynamic>> group,
    double minGap,
    double maxGap,
  ) {
    List<double> walls = group.map((m) => m['wallThickness'] as double).toList();
    List<double> widths = group.map((m) => m['width'] as double).toList();
    List<double> heights = group.map((m) => m['height'] as double).toList();

    double frameWall = walls.reduce((a, b) => a < b ? a : b) + maxGap;
    double frameWidth = widths.reduce((a, b) => a > b ? a : b) - minGap;
    double frameHeight = heights.reduce((a, b) => a > b ? a : b) - minGap;

    List<Map<String, dynamic>> validatedMeasurements = [];

    for (var measurement in group) {
      double wallGap = frameWall - (measurement['wallThickness'] as double);
      double widthGap = (measurement['width'] as double) - frameWidth;
      double heightGap = (measurement['height'] as double) - frameHeight;

      if (wallGap >= minGap &&
          wallGap <= maxGap &&
          widthGap >= minGap &&
          widthGap <= maxGap &&
          heightGap >= minGap &&
          heightGap <= maxGap) {
        validatedMeasurements.add({
          ...measurement,
          'gaps': {'wall': wallGap, 'width': widthGap, 'height': heightGap},
        });
      } else {
        return null;
      }
    }

    return {
      'frameWall': frameWall,
      'frameWidth': frameWidth,
      'frameHeight': frameHeight,
      'measurements': validatedMeasurements,
      'measurementCount': validatedMeasurements.length,
      'minGaps': {
        'wall': validatedMeasurements
            .map((m) => m['gaps']['wall'] as double)
            .reduce((a, b) => a < b ? a : b),
        'width': validatedMeasurements
            .map((m) => m['gaps']['width'] as double)
            .reduce((a, b) => a < b ? a : b),
        'height': validatedMeasurements
            .map((m) => m['gaps']['height'] as double)
            .reduce((a, b) => a < b ? a : b),
      },
      'maxGaps': {
        'wall': validatedMeasurements
            .map((m) => m['gaps']['wall'] as double)
            .reduce((a, b) => a > b ? a : b),
        'width': validatedMeasurements
            .map((m) => m['gaps']['width'] as double)
            .reduce((a, b) => a > b ? a : b),
        'height': validatedMeasurements
            .map((m) => m['gaps']['height'] as double)
            .reduce((a, b) => a > b ? a : b),
      },
    };
  }

  Widget _buildModernCard({
    required Widget child,
    EdgeInsets? padding,
    Color? color,
    bool isGlassmorphic = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isGlassmorphic ? Colors.white.withOpacity(0.85) : color ?? Colors.white,
        borderRadius: BorderRadius.circular(24),
        gradient: isGlassmorphic
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
        border: isGlassmorphic
            ? Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              )
            : null,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(24),
        child: child,
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withOpacity(0.1),
            Colors.purple.withOpacity(0.1),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: "Search projects...",
          hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w400),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.search_rounded, color: Colors.blue.shade600, size: 20),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int currentStep, int totalSteps) {
    return Row(
      children: List.generate(totalSteps, (index) {
        bool isActive = index <= currentStep;
        bool isCurrent = index == currentStep;

        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isCurrent ? 40 : 24,
              height: 24,
              decoration: BoxDecoration(
                color: isActive ? Colors.blue.shade600 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (index < totalSteps - 1)
              Container(
                width: 20,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: isActive ? Colors.blue.shade300 : Colors.grey.shade300,
              ),
          ],
        );
      }),
    );
  }

  Widget _buildIconContainer({
    required IconData icon,
    required Color color,
    Gradient? gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient ??
            LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.2)],
            ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildProjectDropdown() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: _buildModernCard(
        isGlassmorphic: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIconContainer(
                  icon: Icons.business_center_rounded,
                  color: Colors.blue,
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Select Project",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        "Choose a project to work with",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStepIndicator(0, 4),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade50, Colors.grey.shade100],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonFormField<Map<String, dynamic>>(
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                  hintText: "Choose a project",
                ),
                items: _filteredProjects.map((proj) {
                  return DropdownMenuItem(
                    value: proj,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                proj['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProject = value;
                    selectedBatchId = null;
                    batches = [];
                    measurements = [];
                    showPreview = false;
                    showGapForm = false;
                    showFramePreview = false;
                    generatedFrames = {};
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
      ),
    );
  }

  Widget _buildBatchSection() {
    if (_selectedProject == null) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      child: _buildModernCard(
        isGlassmorphic: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIconContainer(
                  icon: Icons.inventory_2_outlined,
                  color: Colors.orange.shade600,
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Select Batch",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        "Choose a batch from the project",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStepIndicator(1, 4),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade50, Colors.grey.shade100],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  hintText: "Select Batch",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                ),
                value: selectedBatchId,
                items: isLoadingBatches
                    ? [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text("Loading batches..."),
                            ],
                          ),
                        ),
                      ]
                    : batches.isEmpty
                        ? [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.grey[400], size: 16),
                                  const SizedBox(width: 12),
                                  const Text(
                                    "No batches found",
                                    style: TextStyle(color: Colors.grey, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        : batches.map((batch) {
                            return DropdownMenuItem<String>(
                              value: batch['id'],
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    batch['name'],
                                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                onChanged: isLoadingBatches
                    ? null
                    : (value) {
                        setState(() {
                          selectedBatchId = value;
                          showPreview = false;
                          showGapForm = false;
                          showFramePreview = false;
                          measurements = [];
                          generatedFrames = {};
                        });

                        if (value != null && _selectedProject != null) {
                          _loadMeasurements(_selectedProject!['id'], value);
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    bool isSecondary = false,
    Gradient? gradient,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: isSecondary
            ? null
            : gradient ?? LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade600]),
        borderRadius: BorderRadius.circular(16),
        border: isSecondary ? Border.all(color: Colors.grey.shade300) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: isSecondary ? Colors.grey[700] : Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSecondary ? Colors.grey[700] : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataPreview() {
    if (!showPreview || measurements.isEmpty) return const SizedBox.shrink();

    final previewData = _getPreviewData();
    final isPartialView = measurements.length > 6;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      child: _buildModernCard(
        isGlassmorphic: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIconContainer(
                  icon: Icons.preview_rounded,
                  color: Colors.green.shade600,
                  gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Data Preview",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text(
                        "${measurements.length} measurements found",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                _buildStepIndicator(2, 4),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatsCard(
                    "Total Measurements",
                    "${measurements.length}",
                    Icons.dataset,
                    Colors.blue.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatsCard(
                    "Locations",
                    "${measurements.map((m) => m['location']).toSet().length}",
                    Icons.location_on,
                    Colors.orange.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatsCard(
                    "Flats",
                    "${measurements.map((m) => m['flatNo']).toSet().length}",
                    Icons.home,
                    Colors.green.shade600,
                  ),
                ),
              ],
            ),
            if (isPartialView) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.blue.shade100]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.blue.shade700, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "Showing first 3 and last 3 rows",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateColor.resolveWith((states) => Colors.grey.shade50),
                  headingRowHeight: 50,
                  dataRowMaxHeight: 48,
                  columnSpacing: 20,
                  horizontalMargin: 16,
                  columns: [
                    DataColumn(
                      label: Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          const Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    DataColumn(
                      label: Row(
                        children: [
                          Icon(Icons.home, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          const Text('Flat No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    DataColumn(
                      label: Row(
                        children: [
                          Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          const Text('Width', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    DataColumn(
                      label: Row(
                        children: [
                          Icon(Icons.height, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          const Text('Height', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    DataColumn(
                      label: Row(
                        children: [
                          Icon(Icons.border_all, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          const Text('Wall', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    DataColumn(
                      label: Row(
                        children: [
                          Icon(Icons.view_column, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          const Text('Beam', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  rows: previewData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final measurement = entry.value;
                    final isGap = isPartialView && index == 3;

                    if (isGap) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.more_horiz, color: Colors.grey[400]),
                                  const SizedBox(width: 8),
                                  Text("...", style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                          ),
                          const DataCell(Text("...")),
                          const DataCell(Text("...")),
                          const DataCell(Text("...")),
                          const DataCell(Text("...")),
                          const DataCell(Text("...")),
                        ],
                      );
                    }

                    return DataRow(
                      color: WidgetStateProperty.resolveWith(
                          (states) => index.isEven ? Colors.grey.shade50 : Colors.white),
                      cells: [
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              measurement['location'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            measurement['flatNo'] ?? 'N/A',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(Text('${measurement['width']}mm', style: const TextStyle(fontSize: 12))),
                        DataCell(Text('${measurement['height']}mm', style: const TextStyle(fontSize: 12))),
                        DataCell(Text('${measurement['wallThickness']}mm', style: const TextStyle(fontSize: 12))),
                        DataCell(Text('${measurement['beam']}mm', style: const TextStyle(fontSize: 12))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    onPressed: () {
                      setState(() {
                        showPreview = false;
                        showGapForm = false;
                        showFramePreview = false;
                        selectedBatchId = null;
                        generatedFrames = {};
                      });
                    },
                    icon: Icons.arrow_back_rounded,
                    label: "Back",
                    isSecondary: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    onPressed: () {
                      setState(() {
                        showGapForm = true;
                      });
                    },
                    icon: Icons.check_circle_rounded,
                    label: "Confirm Data",
                    gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGapInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          suffixText: "mm",
          suffixStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          labelStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }

  Widget _buildGapForm() {
    if (!showGapForm) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      child: _buildModernCard(
        color: Colors.purple.shade50,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIconContainer(
                  icon: Icons.tune_rounded,
                  color: Colors.purple.shade600,
                  gradient: LinearGradient(colors: [Colors.purple.shade400, Colors.purple.shade600]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Gap Configuration",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text(
                        "Set minimum and maximum gap parameters",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                _buildStepIndicator(3, 4),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildGapInputField(
                    controller: _minGapController,
                    label: "Minimum Gap",
                    icon: Icons.remove_circle_outline,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildGapInputField(
                    controller: _maxGapController,
                    label: "Maximum Gap",
                    icon: Icons.add_circle_outline,
                    color: Colors.green.shade400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        "Frame Generation Logic",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "• Generates complete door frame specifications (Wall × Width × Height)\n• Uses optimal grouping algorithm to minimize frame variations\n• Ensures all measurements fit within specified gap ranges",
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade600, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    onPressed: () {
                      setState(() {
                        showGapForm = false;
                      });
                    },
                    icon: Icons.arrow_back_rounded,
                    label: "Back",
                    isSecondary: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    onPressed: _generateFramesPreview,
                    icon: Icons.auto_fix_high_rounded,
                    label: "Generate Frames",
                    gradient: LinearGradient(colors: [Colors.purple.shade400, Colors.purple.shade600]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildFramePreview() {
    if (!showFramePreview || generatedFrames.isEmpty) return const SizedBox.shrink();

    final frames = generatedFrames['frames'] as List<Map<String, dynamic>>;

    return _buildModernCard(
      color: Colors.indigo.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIconContainer(
                icon: Icons.architecture_rounded,
                color: Colors.indigo.shade600,
                gradient: LinearGradient(colors: [Colors.indigo.shade400, Colors.indigo.shade600]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Generated Frames",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      "${frames.length} frame${frames.length > 1 ? 's' : ''} optimized",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              _buildStepIndicator(4, 4),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatsCard("Total Frames", "${frames.length}", Icons.widgets, Colors.indigo.shade600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatsCard(
                  "Efficiency",
                  "${(measurements.length / frames.length).toStringAsFixed(1)}:1",
                  Icons.trending_up,
                  Colors.green.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatsCard("Coverage", "100%", Icons.done_all, Colors.blue.shade600),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  onPressed: () {
                    setState(() {
                      showFramePreview = false;
                    });
                  },
                  icon: Icons.arrow_back_rounded,
                  label: "Modify Settings",
                  isSecondary: true,
                ),
              ),
              Expanded(
  child: _buildActionButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FramePreviewPage(
            generatedFrames: generatedFrames,
            minGap: double.parse(_minGapController.text),
            maxGap: double.parse(_maxGapController.text),
          ),
        ),
      );
    },
    icon: Icons.auto_fix_high_rounded,
    label: "Preview Frames",
    isSecondary: true,
  ),
),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  onPressed: _saveFinalConfiguration,
                  icon: Icons.save_rounded,
                  label: "Save Configuration",
                  gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _generateFramesPreview() {
    final minGap = double.tryParse(_minGapController.text);
    final maxGap = double.tryParse(_maxGapController.text);

    if (minGap == null || maxGap == null) {
      _showErrorSnackBar("Please enter valid gap values");
      return;
    }

    if (minGap < 0 || maxGap < 0) {
      _showErrorSnackBar("Gap values must be positive");
      return;
    }

    if (minGap >= maxGap) {
      _showErrorSnackBar("Min gap must be less than max gap");
      return;
    }

    if (maxGap - minGap < 1) {
      _showErrorSnackBar("Gap range should be at least 1mm");
      return;
    }

    setState(() {
      showFramePreview = false;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      final frames = _generateFrames(minGap, maxGap);

      if (mounted) {
        setState(() {
          generatedFrames = frames;
          showFramePreview = true;
        });

        _showSuccessSnackBar("Frames generated successfully!");
      }
    });
  }

  Future<void> _saveFinalConfiguration() async {
    try {
      final minGap = double.parse(_minGapController.text);
      final maxGap = double.parse(_maxGapController.text);

      final configData = {
        'projectId': _selectedProject!['id'],
        'batchId': selectedBatchId,
        'minGap': minGap,
        'maxGap': maxGap,
        'generatedFrames': _convertFramesForStorage(generatedFrames),
        'totalMeasurements': measurements.length,
        'createdAt': Timestamp.now(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
      };

      await FirebaseFirestore.instance.collection('workingConfigurations').add(configData);

      if (!mounted) return;

      _showSuccessSnackBar("Configuration saved successfully!");

      setState(() {
        showFramePreview = false;
        showGapForm = false;
        showPreview = false;
        selectedBatchId = null;
        _selectedProject = null;
        batches = [];
        measurements = [];
        generatedFrames = {};
        _minGapController.text = '5';
        _maxGapController.text = '25';
      });

      _cardAnimationController.reset();
      _cardAnimationController.forward();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar("Failed to save configuration: $e");
    }
  }

  Map<String, dynamic> _convertFramesForStorage(Map<String, List<Map<String, dynamic>>> frames) {
    final frameList = frames['frames'] as List<Map<String, dynamic>>;

    return {
      'totalFrames': frameList.length,
      'frames': frameList.map((frame) {
        return {
          'frameSpecification': {
            'wallThickness': frame['frameWall'],
            'width': frame['frameWidth'],
            'height': frame['frameHeight'],
          },
          'gapRanges': {
            'wall': {'min': frame['minGaps']['wall'], 'max': frame['maxGaps']['wall']},
            'width': {'min': frame['minGaps']['width'], 'max': frame['maxGaps']['width']},
            'height': {'min': frame['minGaps']['height'], 'max': frame['maxGaps']['height']},
          },
          'applicableMeasurements': (frame['measurements'] as List<Map<String, dynamic>>)
              .map((m) => {
                    'id': m['id'],
                    'location': m['location'],
                    'flatNo': m['flatNo'],
                    'originalSizes': {
                      'wall': m['wallThickness'],
                      'width': m['width'],
                      'height': m['height'],
                    },
                    'gaps': m['gaps'],
                  })
              .toList(),
          'measurementCount': frame['measurementCount'],
        };
      }).toList(),
    };
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Working List",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade600, Colors.blue.shade700],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              _loadProjects();
              _showSuccessSnackBar("Data refreshed");
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50.withOpacity(0.3), Colors.white.withOpacity(0.8)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(maxWidth: isWeb ? 1400 : double.infinity),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchField(),
                    const SizedBox(height: 28),
                    _buildProjectDropdown(),
                    const SizedBox(height: 28),
                    _buildBatchSection(),
                    if (_selectedProject != null) const SizedBox(height: 28),
                    if (isLoadingMeasurements)
                      _buildModernCard(
                        isGlassmorphic: true,
                        child: Container(
                          padding: const EdgeInsets.all(60),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                "Loading measurements...",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      _buildDataPreview(),
                    if (showPreview) const SizedBox(height: 28),
                    _buildGapForm(),
                    if (showGapForm) const SizedBox(height: 28),
                    _buildFramePreview(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}