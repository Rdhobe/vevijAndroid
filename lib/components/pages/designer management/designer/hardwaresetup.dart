import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HardwaresetupPage extends StatefulWidget {
  const HardwaresetupPage({super.key});

  @override
  State<HardwaresetupPage> createState() => _HardwaresetupPageState();
}

class _HardwaresetupPageState extends State<HardwaresetupPage> {
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _filteredProjects = [];
  final TextEditingController _searchController = TextEditingController();

  String? _selectedProjectId;
  String? _selectedProjectName;
  bool _isLoading = true;
  bool _isLoadingCategories = false;
  bool _isSaving = false;
  bool _isLoadingHardwareList = false;

  // Category-wise data
  Map<String, Map<String, dynamic>> _categoryData = {};
  Map<String, Map<String, TextEditingController>> _categoryControllers = {};

  // Combined totals
  Map<String, Map<String, dynamic>> _combinedTotals = {};
  Map<String, TextEditingController> _combinedControllers = {};

  // Hardware dropdown list
  List<String> _hardwareDropdownList = [];
  List<Map<String, dynamic>> _customHardwareItems = [];

  // Hardware items configuration (default)
  final List<Map<String, dynamic>> _defaultHardwareItems = [
    {'name': 'Fastener', 'key': 'fastener', 'unit': 'PCS', 'default': 8.0, 'isDecimal': false},
    {'name': 'Screw 10x75', 'key': 'screws', 'unit': 'PCS', 'default': 6.0, 'isDecimal': false},
    {'name': 'Dowel pin', 'key': 'dowel', 'unit': 'PCS', 'default': 2.0, 'isDecimal': false},
    {'name': 'PU Foam', 'key': 'foam', 'unit': 'L', 'default': 0.33, 'isDecimal': true},
    {'name': 'Fevicol', 'key': 'fevicol', 'unit': 'L', 'default': 0.33, 'isDecimal': true},
  ];

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _loadHardwareDropdownList();
    _searchController.addListener(_filterProjects);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _disposeControllers();
    _disposeCombinedControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (var categoryControllers in _categoryControllers.values) {
      for (var controller in categoryControllers.values) {
        controller.dispose();
      }
    }
    _categoryControllers.clear();
  }

  void _disposeCombinedControllers() {
    for (var controller in _combinedControllers.values) {
      controller.dispose();
    }
    _combinedControllers.clear();
  }

  double _getResponsiveWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1400) return 1200;
    if (width > 1000) return width * 0.9;
    if (width > 800) return width * 0.92;
    return width * 0.95;
  }

  bool _isDesktop(BuildContext context) => MediaQuery.of(context).size.width > 1000;
  bool _isTablet(BuildContext context) => MediaQuery.of(context).size.width > 600 && MediaQuery.of(context).size.width <= 1000;
  bool _isMobile(BuildContext context) => MediaQuery.of(context).size.width <= 600;
  // Future<void> _initializeHardwareDropdown() async {
  //   try {
  //     final defaultHardwareNames = [
  //       'Fastener',
  //       'Self Tapping Screw 25*10',
  //       'Doval pin',
  //       'PU Foam',
  //       'Fevicol',
  //       'Hinges',
  //       'Door Handles',
  //       'Door Locks',
  //       'Tower Bolts',
  //       'Aldrop',
  //       'Door Stopper',
  //       'Door Closer',
  //       'Magnetic Catch',
  //       'Door Viewer',
  //       'Number Plate',
  //       'Name Plate',
  //       'L Bracket',
  //       'Corner Bracket',
  //       'Angle Bracket',
  //       'Wood Screws',
  //       'Self Drilling Screws',
  //       'Expansion Bolts',
  //       'Rawl Plugs',
  //       'Chemical Anchors',
  //       'Silicon Sealant',
  //       'Acrylic Sealant',
  //       'Wood Glue',
  //       'Contact Adhesive',
  //       'Double Sided Tape',
  //       'Masking Tape',
  //       'Sandpaper',
  //       'Wood Filler',
  //       'Putty',
  //       'Primer',
  //       'Paint',
  //       'Varnish',
  //       'Wood Polish',
  //       'Thinner',
  //       'Brush',
  //       'Roller',
  //       'Tray',
  //       'Drop Sheet',
  //       'Safety Glasses',
  //       'Gloves',
  //       'Dust Mask',
  //     ];

  //     final batch = FirebaseFirestore.instance.batch();
  //     final collectionRef = FirebaseFirestore.instance.collection('hardwareDropdown');
      
  //     // Check if collection is empty
  //     final existingDocs = await collectionRef.limit(1).get();
      
  //     if (existingDocs.docs.isEmpty) {
  //       print('Initializing hardware dropdown collection...');
        
  //       for (var name in defaultHardwareNames) {
  //         final docRef = collectionRef.doc();
  //         batch.set(docRef, {
  //           'name': name,
  //           'createdAt': Timestamp.now(),
  //           'createdBy': 'System',
  //           'isDefault': true,
  //         });
  //       }
        
  //       await batch.commit();
  //       print('Successfully added ${defaultHardwareNames.length} hardware items to database');
        
  //       // Reload the list
  //       await _loadHardwareDropdownList();
        
  //       _showSnackBar('Hardware dropdown initialized with ${defaultHardwareNames.length} items', Colors.green);
  //     } else {
  //       print('Hardware dropdown collection already exists');
  //     }
  //   } catch (e) {
  //     print('Error initializing hardware dropdown: $e');
  //     _showSnackBar('Error initializing hardware dropdown: $e', Colors.red);
  //   }
  // }
  Future<void> _loadHardwareDropdownList() async {
    setState(() {
      _isLoadingHardwareList = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('hardwareDropdown')
          .orderBy('name')
          .get();
      
      setState(() {
        _hardwareDropdownList = snapshot.docs.map((doc) => doc['name'] as String).toList();
        _isLoadingHardwareList = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingHardwareList = false;
      });
      // If collection doesn't exist, initialize with defaults
      _hardwareDropdownList = _defaultHardwareItems.map((item) => item['name'] as String).toList();
    }
  }

  void _loadProjects() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .orderBy('createdAt', descending: true)
          .get();
      
      setState(() {
        _projects = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _filteredProjects = List.from(_projects);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error loading projects: $e', Colors.red);
    }
  }

  void _filterProjects() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProjects = _projects.where((project) {
        return project['name'].toLowerCase().contains(query);
      }).toList();
    });
  }

  void _onProjectSelected(String? projectName) async {
    if (projectName == null) return;
    
    final project = _projects.firstWhere((p) => p['name'] == projectName);
    
    setState(() {
      _selectedProjectName = projectName;
      _selectedProjectId = project['id'];
      _searchController.text = projectName;
      _isLoadingCategories = true;
      _categoryData.clear();
      _combinedTotals.clear();
      _customHardwareItems.clear();
      _disposeControllers();
      _disposeCombinedControllers();
    });

    await _loadCategoryWiseData();
  }

  Future<void> _loadCategoryWiseData() async {
    if (_selectedProjectId == null) return;

    try {
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(_selectedProjectId)
          .collection('tasks')
          .get();
      
      // Group tasks by materialGroup
      Map<String, int> categoryCount = {};
      for (var doc in tasksSnapshot.docs) {
        final data = doc.data();
        final materialGroup = data['materialGroup'] as String? ?? 'Unknown';
        final qty = (data['qty'] as num?)?.toInt() ?? 1;
        categoryCount[materialGroup] = (categoryCount[materialGroup] ?? 0) + qty;
      }

      // Initialize controllers and data for each category
      Map<String, Map<String, dynamic>> newCategoryData = {};
      Map<String, Map<String, TextEditingController>> newControllers = {};

      for (var entry in categoryCount.entries) {
        final category = entry.key;
        final count = entry.value;

        newCategoryData[category] = {
          'doorCount': count,
          'totals': {},
        };

        newControllers[category] = {};
        for (var item in _defaultHardwareItems) {
          final controller = TextEditingController(
            text: item['default'].toString(),
          );
          newControllers[category]![item['key']] = controller;
        }
      }

      setState(() {
        _categoryData = newCategoryData;
        _categoryControllers = newControllers;
        _isLoadingCategories = false;
      });

      // Auto-calculate for all categories
      _calculateAllTotals();
      _calculateCombinedTotals();
      
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
      _showSnackBar('Error loading categories: $e', Colors.orange);
    }
  }

  void _calculateAllTotals() {
    for (var category in _categoryData.keys) {
      _calculateCategoryTotal(category);
    }
  }

  void _calculateCategoryTotal(String category) {
    final doorCount = _categoryData[category]!['doorCount'];
    Map<String, double> totals = {};

    for (var item in _defaultHardwareItems) {
      final controller = _categoryControllers[category]![item['key']]!;
      final perDoorQty = double.tryParse(controller.text) ?? 0;
      totals[item['key']] = doorCount * perDoorQty;
    }

    setState(() {
      _categoryData[category]!['totals'] = totals;
    });
  }

  void _calculateCombinedTotals() {
    Map<String, Map<String, dynamic>> newCombinedTotals = {};
    
    // Calculate totals for default hardware items
    for (var item in _defaultHardwareItems) {
      double grandTotal = 0;
      Map<String, double> categoryBreakdown = {};
      
      for (var entry in _categoryData.entries) {
        final category = entry.key;
        final totals = entry.value['totals'] as Map<String, double>;
        final categoryTotal = totals[item['key']] ?? 0;
        grandTotal += categoryTotal;
        categoryBreakdown[category] = categoryTotal;
      }
      
      newCombinedTotals[item['key']] = {
        'name': item['name'],
        'total': grandTotal,
        'unit': item['unit'],
        'isDecimal': item['isDecimal'],
        'categoryBreakdown': categoryBreakdown,
      };
      
      // Create or update controller
      if (_combinedControllers.containsKey(item['key'])) {
        _combinedControllers[item['key']]!.text = item['isDecimal'] 
            ? grandTotal.toStringAsFixed(2) 
            : grandTotal.toInt().toString();
      } else {
        _combinedControllers[item['key']] = TextEditingController(
          text: item['isDecimal'] 
              ? grandTotal.toStringAsFixed(2) 
              : grandTotal.toInt().toString(),
        );
      }
    }

    // Add custom hardware items
    for (var customItem in _customHardwareItems) {
      final key = customItem['key'];
      newCombinedTotals[key] = {
        'name': customItem['name'],
        'total': double.tryParse(_combinedControllers[key]?.text ?? '0') ?? 0,
        'unit': customItem['unit'],
        'isDecimal': customItem['isDecimal'],
        'categoryBreakdown': {},
        'isCustom': true,
      };
    }

    setState(() {
      _combinedTotals = newCombinedTotals;
    });
  }

  void _showAddHardwareDialog() {
    String? selectedHardware;
    String? customHardwareName;
    String? selectedUnit = 'PCS';
    bool isDecimal = false;
    final qtyController = TextEditingController(text: '0');
    final customNameController = TextEditingController();
    final searchController = TextEditingController();
    List<String> filteredHardwareList = List.from(_hardwareDropdownList);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: _isDesktop(context) ? 600 : (_isTablet(context) ? 500 : MediaQuery.of(context).size.width * 0.9),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple[600]!, Colors.purple[800]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Hardware Item',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Select existing or create new',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Option 1: Select Existing
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.purple[600],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '1',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Select from Existing Hardware',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.purple[900],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Search field
                              TextField(
                                controller: searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search hardware...',
                                  prefixIcon: Icon(Icons.search, color: Colors.purple[600]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.purple[300]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.purple[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.purple[600]!, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onChanged: (value) {
                                  setDialogState(() {
                                    filteredHardwareList = _hardwareDropdownList
                                        .where((item) => item.toLowerCase().contains(value.toLowerCase()))
                                        .toList();
                                  });
                                },
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Hardware list
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.purple[200]!),
                                ),
                                child: _isLoadingHardwareList
                                    ? const Center(child: CircularProgressIndicator())
                                    : filteredHardwareList.isEmpty
                                        ? Center(
                                            child: Text(
                                              'No hardware found',
                                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                            ),
                                          )
                                        : ListView.builder(
                                            itemCount: filteredHardwareList.length,
                                            itemBuilder: (context, index) {
                                              final hardware = filteredHardwareList[index];
                                              final isSelected = selectedHardware == hardware;
                                              return InkWell(
                                                onTap: () {
                                                  setDialogState(() {
                                                    selectedHardware = hardware;
                                                    customHardwareName = null;
                                                    customNameController.clear();
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? Colors.purple[100] : Colors.transparent,
                                                    border: Border(
                                                      bottom: BorderSide(color: Colors.grey[200]!),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                                        color: isSelected ? Colors.purple[600] : Colors.grey[400],
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          hardware,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                            color: isSelected ? Colors.purple[900] : Colors.grey[800],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Divider with OR
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Option 2: Create New
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[600],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '2',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Create New Hardware',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: customNameController,
                                decoration: InputDecoration(
                                  hintText: 'Enter new hardware name',
                                  prefixIcon: Icon(Icons.create, color: Colors.blue[600]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.blue[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                onChanged: (value) {
                                  setDialogState(() {
                                    customHardwareName = value.trim().isEmpty ? null : value.trim();
                                    if (customHardwareName != null) selectedHardware = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Configuration Section
                        Text(
                          'Hardware Configuration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedUnit,
                                decoration: InputDecoration(
                                  labelText: 'Unit',
                                  prefixIcon: const Icon(Icons.straighten),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                items: ['PCS', 'L', 'KG', 'M', 'SQ.M', 'BOX', 'SET']
                                    .map((unit) => DropdownMenuItem(
                                          value: unit,
                                          child: Text(unit),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedUnit = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.grey[50],
                                ),
                                child: CheckboxListTile(
                                  title: const Text('Decimal', style: TextStyle(fontSize: 14)),
                                  value: isDecimal,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      isDecimal = value ?? false;
                                    });
                                  },
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        TextField(
                          controller: qtyController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Total Quantity',
                            hintText: '0',
                            suffixText: selectedUnit,
                            prefixIcon: const Icon(Icons.format_list_numbered),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Footer Actions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey[700], fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final hardwareName = customHardwareName ?? selectedHardware;
                          if (hardwareName == null || hardwareName.isEmpty) {
                            _showSnackBar('Please select or enter hardware name', Colors.orange);
                            return;
                          }

                          // If custom name, save to Firebase
                          if (customHardwareName != null && !_hardwareDropdownList.contains(customHardwareName)) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('hardwareDropdown')
                                  .add({
                                'name': customHardwareName,
                                'createdAt': Timestamp.now(),
                                'createdBy': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
                              });
                              
                              setState(() {
                                _hardwareDropdownList.add(customHardwareName!);
                                _hardwareDropdownList.sort();
                              });
                            } catch (e) {
                              _showSnackBar('Error saving hardware to list: $e', Colors.red);
                            }
                          }

                          // Add to custom hardware items
                          final key = hardwareName.toLowerCase().replaceAll(' ', '_');
                          final newItem = {
                            'name': hardwareName,
                            'key': key,
                            'unit': selectedUnit ?? 'PCS',
                            'isDecimal': isDecimal,
                          };

                          setState(() {
                            _customHardwareItems.add(newItem);
                            _combinedControllers[key] = TextEditingController(text: qtyController.text);
                          });

                          _calculateCombinedTotals();
                          Navigator.pop(context);
                          _showSnackBar('Hardware item added successfully', Colors.green);
                        },
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Add Hardware', style: TextStyle(fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _removeCustomHardware(String key) {
    setState(() {
      _customHardwareItems.removeWhere((item) => item['key'] == key);
      _combinedControllers[key]?.dispose();
      _combinedControllers.remove(key);
    });
    _calculateCombinedTotals();
    _showSnackBar('Hardware item removed', Colors.orange);
  }

  Future<void> _saveHardwareRequirements() async {
    if (_selectedProjectId == null || _combinedTotals.isEmpty) {
      _showSnackBar('No data to save', Colors.orange);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final inventoryRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(_selectedProjectId)
          .collection('inventory');

      final currentUser = FirebaseAuth.instance.currentUser;
      final timestamp = Timestamp.now();

      // Save each hardware item
      for (var entry in _combinedTotals.entries) {
        final itemData = entry.value;
        final isCustom = itemData['isCustom'] ?? false;
        final totalQty = double.tryParse(_combinedControllers[entry.key]?.text ?? '0') ?? itemData['total'];

        final existingQuery = await inventoryRef
            .where('materialName', isEqualTo: itemData['name'])
            .get();

        final inventoryData = {
          'materialName': itemData['name'],
          'requiredQty': itemData['isDecimal'] ? totalQty : totalQty.toInt(),
          'totalReceivedQty': 0,
          'totalIssuedQty': 0,
          'balIssueQty': 0,
          'usedQty': 0,
          'balanceQty': 0,
          'uom': itemData['unit'],
          'receivedEntries': [],
          'issuedEntries': [],
          'editHistory': [],
          'createdAt': timestamp,
          'updatedAt': timestamp,
          'createdBy': currentUser?.email ?? 'Unknown',
          'source': isCustom ? 'Hardware Setup Manual Entry' : 'Hardware Setup Auto-calculation',
          'projectId': _selectedProjectId,
          'categoryBreakdown': itemData['categoryBreakdown'],
          'isCustomHardware': isCustom,
        };

        if (existingQuery.docs.isNotEmpty) {
          final docRef = existingQuery.docs.first.reference;
          final existingData = existingQuery.docs.first.data();
          
          final editEntry = {
            'editedBy': currentUser?.email ?? 'Unknown',
            'editDate': '${DateTime.now().day}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}',
            'timestamp': timestamp,
            'changes': ['Required qty: ${existingData['requiredQty']} → ${inventoryData['requiredQty']}'],
            'reason': 'Hardware setup update',
          };

          batch.update(docRef, {
            'requiredQty': inventoryData['requiredQty'],
            'updatedAt': timestamp,
            'editHistory': FieldValue.arrayUnion([editEntry]),
            'categoryBreakdown': inventoryData['categoryBreakdown'],
          });
        } else {
          final docRef = inventoryRef.doc();
          batch.set(docRef, inventoryData);
        }
      }

      await batch.commit();
      
      _showSnackBar('Hardware requirements saved successfully! (${_combinedTotals.length} items)', Colors.green);
      
    } catch (e) {
      _showSnackBar('Error saving: $e', Colors.red);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.symmetric(
          horizontal: _isMobile(context) ? 16 : 32,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isMobile(context) ? 'Hardware Setup' : 'Hardware Requirements Setup',
          style: TextStyle(
            fontSize: _isMobile(context) ? 16 : 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: _isMobile(context),
        leading: _isMobile(context) 
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(_isMobile(context) ? 16 : 24),
                child: Center(
                  child: Container(
                    width: _getResponsiveWidth(context),
                    child: Column(
                      children: [
                        _buildProjectSelectionCard(),
                        if (_selectedProjectName != null) ...[
                          SizedBox(height: _isMobile(context) ? 16 : 24),
                          if (_isLoadingCategories)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (_categoryData.isEmpty)
                            _buildEmptyState()
                          else ...[
                            _buildCategoriesSection(),
                            SizedBox(height: _isMobile(context) ? 20 : 28),
                            _buildCombinedTotalsSection(),
                            SizedBox(height: _isMobile(context) ? 16 : 24),
                            _buildSaveButton(),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildProjectSelectionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(_isMobile(context) ? 20 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.blue[800]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.apartment, color: Colors.white, size: _isMobile(context) ? 20 : 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Select Project',
                    style: TextStyle(
                      fontSize: _isMobile(context) ? 18 : 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Project',
                labelStyle: TextStyle(color: Colors.grey[600]),
                hintText: 'Type to search...',
                prefixIcon: Icon(Icons.search, color: Colors.blue[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _selectedProjectName,
              hint: const Text('Select a project'),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Project',
                labelStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.folder_open, color: Colors.blue[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: _filteredProjects.map((project) {
                return DropdownMenuItem<String>(
                  value: project['name'],
                  child: Text(
                    project['name'],
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _onProjectSelected,
              menuMaxHeight: 300,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Door Categories Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This project has no tasks assigned yet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.category, color: Colors.orange[700], size: 24),
              const SizedBox(width: 12),
              Text(
                'Door Categories',
                style: TextStyle(
                  fontSize: _isMobile(context) ? 18 : 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_categoryData.length} Categories',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _isMobile(context) ? 12 : 16),
        ..._categoryData.keys.map((category) => Padding(
          padding: EdgeInsets.only(bottom: _isMobile(context) ? 12 : 16),
          child: _buildCategoryCard(category),
        )),
      ],
    );
  }

  Widget _buildCategoryCard(String category) {
    final doorCount = _categoryData[category]!['doorCount'];
    final totals = _categoryData[category]!['totals'] as Map<String, double>;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: EdgeInsets.all(_isMobile(context) ? 16 : 20),
        childrenPadding: EdgeInsets.all(_isMobile(context) ? 16 : 20),
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.door_front_door, color: Colors.orange[700], size: 24),
        ),
        title: Text(
          category,
          style: TextStyle(
            fontSize: _isMobile(context) ? 15 : 17,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '$doorCount Door${doorCount > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.edit, size: 18, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Per Door Requirements (Editable)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          if (_isDesktop(context))
            _buildDesktopHardwareGrid(category)
          else
            _buildMobileHardwareList(category),
          
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                _calculateCategoryTotal(category);
                _calculateCombinedTotals();
              },
              icon: const Icon(Icons.calculate, size: 20),
              label: const Text('Recalculate Totals'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
          
          if (totals.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[50]!, Colors.green[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Category Total Requirements',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._defaultHardwareItems.map((item) {
                    final total = totals[item['key']] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['name'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[700],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item['isDecimal'] ? total.toStringAsFixed(2) : total.toInt()} ${item['unit']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopHardwareGrid(String category) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 4,
      ),
      itemCount: _defaultHardwareItems.length,
      itemBuilder: (context, index) {
        final item = _defaultHardwareItems[index];
        return _buildHardwareField(
          controller: _categoryControllers[category]![item['key']]!,
          label: item['name'],
          unit: item['unit'],
          isDecimal: item['isDecimal'],
        );
      },
    );
  }

  Widget _buildMobileHardwareList(String category) {
    return Column(
      children: _defaultHardwareItems.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildHardwareField(
            controller: _categoryControllers[category]![item['key']]!,
            label: item['name'],
            unit: item['unit'],
            isDecimal: item['isDecimal'],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHardwareField({
    required TextEditingController controller,
    required String label,
    required String unit,
    required bool isDecimal,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey[700]),
        suffixText: unit,
        suffixStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
          fontSize: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildCombinedTotalsSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(_isMobile(context) ? 20 : 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple[50]!, Colors.purple[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple[600]!, Colors.purple[800]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.analytics, color: Colors.white, size: _isMobile(context) ? 22 : 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Combined Total Requirements',
                        style: TextStyle(
                          fontSize: _isMobile(context) ? 18 : 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.purple[900],
                        ),
                      ),
                      Text(
                        'All categories combined • Editable',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _showAddHardwareDialog,
                  icon: const Icon(Icons.add_circle),
                  color: Colors.purple[700],
                  iconSize: 32,
                  tooltip: 'Add Hardware Item',
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            if (_combinedTotals.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Calculate category totals first',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.purple[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ..._buildCombinedTotalsList(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCombinedTotalsList() {
    List<Widget> widgets = [];
    
    for (var entry in _combinedTotals.entries) {
      final itemData = entry.value;
      final isCustom = itemData['isCustom'] ?? false;
      
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isCustom ? Colors.purple[300]! : Colors.purple[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.purple[100]!.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isCustom)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'CUSTOM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.purple[700],
                        ),
                      ),
                    ),
                  if (isCustom) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      itemData['name'],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  if (isCustom)
                    IconButton(
                      onPressed: () => _removeCustomHardware(entry.key),
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red[400],
                      iconSize: 20,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _combinedControllers[entry.key],
                      keyboardType: TextInputType.numberWithOptions(decimal: itemData['isDecimal']),
                      decoration: InputDecoration(
                        labelText: 'Total Quantity',
                        labelStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        suffixText: itemData['unit'],
                        suffixStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.purple[700],
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.purple[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.purple[600]!, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.purple[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              
              if (!isCustom && (itemData['categoryBreakdown'] as Map).isNotEmpty) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    'Category Breakdown',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple[700],
                    ),
                  ),
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: (itemData['categoryBreakdown'] as Map).entries.map((catEntry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    catEntry.key,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[600],
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '${itemData['isDecimal'] ? (catEntry.value as double).toStringAsFixed(2) : (catEntry.value as double).toInt()} ${itemData['unit']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }
    
    return widgets;
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveHardwareRequirements,
        icon: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Icon(Icons.save, size: 24),
        label: Text(
          _isSaving ? 'Saving to Inventory...' : 'Save All to Inventory',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
          shadowColor: Colors.green.withOpacity(0.5),
        ),
      ),
    );
  }
}