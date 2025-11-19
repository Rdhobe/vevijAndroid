import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Edit Inventory Page Class
class EditInventoryPage extends StatefulWidget {
  final String projectId;
  final String itemId;
  final String materialName;

  const EditInventoryPage({
    super.key,
    required this.projectId,
    required this.itemId,
    required this.materialName,
  });

  @override
  State<EditInventoryPage> createState() => _EditInventoryPageState();
}

class _EditInventoryPageState extends State<EditInventoryPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _materialNameController = TextEditingController();
  final _requiredQtyController = TextEditingController();
  final _reasonController = TextEditingController();
  final _receivedQtyController = TextEditingController();
  final _balIssueQtyController = TextEditingController();
  final _usedQtyController = TextEditingController();
  
  // Tab controller
  late TabController _tabController;
  
  String _selectedUom = 'PCS';
  bool _isLoading = true;
  bool _isSaving = false;
  
  Map<String, dynamic> _originalData = {};
  List<Map<String, dynamic>> _receivedEntries = [];
  List<Map<String, dynamic>> _issuedEntries = [];

  final List<String> _uomOptions = [
    'PCS', 'KG', 'MT', 'L', 'M', 'M2', 'M3', 'BOX', 'BAG', 'TON'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInventoryItem();
  }

  @override
  void dispose() {
    _materialNameController.dispose();
    _requiredQtyController.dispose();
    _receivedQtyController.dispose();
    _reasonController.dispose();
    _balIssueQtyController.dispose();
    _usedQtyController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInventoryItem() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .doc(widget.itemId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _originalData = Map<String, dynamic>.from(data);
        _receivedEntries = List<Map<String, dynamic>>.from(data['receivedEntries'] ?? []);
        _issuedEntries = List<Map<String, dynamic>>.from(data['issuedEntries'] ?? []);

        setState(() {
          _materialNameController.text = data['materialName'] ?? '';
          _requiredQtyController.text = (data['requiredQty'] ?? 0).toString();
          _receivedQtyController.text = (data['totalReceivedQty'] ?? 0).toString();
          _balIssueQtyController.text = (data['balIssueQty'] ?? 0).toString();
          _usedQtyController.text = (data['usedQty'] ?? 0).toString();
          _selectedUom = data['uom'] ?? 'PCS';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error loading inventory item: $e', Colors.red);
    }
  }

  List<String> _getChanges() {
    List<String> changes = [];

    if (_originalData['materialName'] != _materialNameController.text.trim()) {
      changes.add('Material name: "${_originalData['materialName']}" → "${_materialNameController.text.trim()}"');
    }

    final newRequiredQty = int.tryParse(_requiredQtyController.text) ?? 0;
    if (_originalData['requiredQty'] != newRequiredQty) {
      changes.add('Required qty: ${_originalData['requiredQty']} → $newRequiredQty');
    }

    final newReceivedQty = int.tryParse(_receivedQtyController.text) ?? 0;
    if (_originalData['totalReceivedQty'] != newReceivedQty) {
      changes.add('Received qty: ${_originalData['totalReceivedQty']} → $newReceivedQty');
    }

    final newBalIssueQty = int.tryParse(_balIssueQtyController.text) ?? 0;
    if (_originalData['balIssueQty'] != newBalIssueQty) {
      changes.add('Balance issue qty: ${_originalData['balIssueQty']} → $newBalIssueQty');
    }

    final newUsedQty = int.tryParse(_usedQtyController.text) ?? 0;
    if (_originalData['usedQty'] != newUsedQty) {
      changes.add('Used qty: ${_originalData['usedQty']} → $newUsedQty');
    }

    if (_originalData['uom'] != _selectedUom) {
      changes.add('UOM: "${_originalData['uom']}" → "$_selectedUom"');
    }

    // Check for received entries changes
    final originalReceived = List<Map<String, dynamic>>.from(_originalData['receivedEntries'] ?? []);
    if (originalReceived.length != _receivedEntries.length) {
      changes.add('Received entries count changed: ${originalReceived.length} → ${_receivedEntries.length}');
    }

    // Check for issued entries changes
    final originalIssued = List<Map<String, dynamic>>.from(_originalData['issuedEntries'] ?? []);
    if (originalIssued.length != _issuedEntries.length) {
      changes.add('Issued entries count changed: ${originalIssued.length} → ${_issuedEntries.length}');
    }

    return changes;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final changes = _getChanges();
    if (changes.isEmpty) {
      _showSnackBar('No changes detected', Colors.orange);
      return;
    }
    

    try {
      final requiredQty = int.tryParse(_requiredQtyController.text) ?? 0;
      final receivedQty = int.tryParse(_receivedQtyController.text) ?? 0;
      final usedQty = int.tryParse(_usedQtyController.text) ?? 0;
      final totalReceivedQty = _receivedEntries.fold<int>(0, (acc, entry) => acc + (entry['qty'] as int? ?? 0));
      final totalIssuedQty = _issuedEntries.fold<int>(0, (acc, entry) => acc + (entry['qty'] as int? ?? 0));
      final balanceQty = totalReceivedQty - totalIssuedQty - usedQty;
      if (requiredQty < totalReceivedQty) {
        _showSnackBar('Error: Received quantity exceeds required quantity', Colors.red);
        return;
      }
      if (totalReceivedQty < totalIssuedQty ) {
        _showSnackBar('Error: Issued quantity exceeds received quantity', Colors.red);
        return;
      }
      final updatedData = {
        'materialName': _materialNameController.text.trim(),
        'requiredQty': requiredQty,
        'totalReceivedQty': totalReceivedQty,
        'totalIssuedQty': totalIssuedQty,
        'balIssueQty': int.tryParse(_balIssueQtyController.text) ?? 0,
        'usedQty': usedQty,
        'balanceQty': balanceQty,
        'uom': _selectedUom,
        'receivedEntries': _receivedEntries,
        'issuedEntries': _issuedEntries,
        'updatedAt': Timestamp.now(),
      };

      final editEntry = {
        'editedBy': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        'editDate': '${DateTime.now().day}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}',
        'timestamp': Timestamp.now(),
        'changes': changes,
        'reason': _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      };

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .doc(widget.itemId)
          .update({
        ...updatedData,
        'editHistory': FieldValue.arrayUnion([editEntry]),
      });

      _showSnackBar('Inventory updated successfully', Colors.green);
      Navigator.of(context).pop(true);
    } catch (e) {
      _showSnackBar('Error updating inventory: $e', Colors.red);
      print(e);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _addReceivedEntry() {
    _showEntryDialog(
      title: 'Add Received Entry',
      isReceived: true,
      onSave: (challanNo, date, qty) {
        setState(() {
          _receivedEntries.add({
            'challanNo': challanNo,
            'date': date,
            'qty': qty,
          });
        });
      },
    );
  }

  void _editReceivedEntry(int index) {
    final entry = _receivedEntries[index];
    _showEntryDialog(
      title: 'Edit Received Entry',
      initialChallanNo: entry['challanNo'],
      initialDate: entry['date'],
      initialQty: entry['qty'],
      isReceived: true,
      editingIndex: index,
      onSave: (challanNo, date, qty) {
        setState(() {
          _receivedEntries[index] = {
            'challanNo': challanNo,
            'date': date,
            'qty': qty,
          };
        });
      },
    );
  }

  void _deleteReceivedEntry(int index) {
    // Show confirmation dialog before deleting
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Received Entry'),
        content: const Text('Are you sure you want to delete this received entry? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _receivedEntries.removeAt(index);
              });
              Navigator.of(context).pop();
              _showSnackBar('Received entry deleted', Colors.orange);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _addIssuedEntry() {
    _showEntryDialog(
      title: 'Add Issued Entry',
      isReceived: false,
      onSave: (challanNo, date, qty) {
        setState(() {
          _issuedEntries.add({
            'challanNo': challanNo,
            'date': date,
            'qty': qty,
          });
        });
      },
    );
  }

  void _editIssuedEntry(int index) {
    final entry = _issuedEntries[index];
    _showEntryDialog(
      title: 'Edit Issued Entry',
      initialChallanNo: entry['challanNo'],
      initialDate: entry['date'],
      initialQty: entry['qty'],
      isReceived: false,
      editingIndex: index,
      onSave: (challanNo, date, qty) {
        setState(() {
          _issuedEntries[index] = {
            'challanNo': challanNo,
            'date': date,
            'qty': qty,
          };
        });
      },
    );
  }

  void _deleteIssuedEntry(int index) {
    // Show confirmation dialog before deleting
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Issued Entry'),
        content: const Text('Are you sure you want to delete this issued entry? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _issuedEntries.removeAt(index);
              });
              Navigator.of(context).pop();
              _showSnackBar('Issued entry deleted', Colors.orange);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEntryDialog({
    required String title,
    String? initialChallanNo,
    String? initialDate,
    int? initialQty,
    required Function(String, String, int) onSave,
    bool isReceived = true,
    int? editingIndex,
  }) {
    final challanController = TextEditingController(text: initialChallanNo ?? '');
    final dateController = TextEditingController(text: initialDate ?? '');
    final qtyController = TextEditingController(text: initialQty?.toString() ?? '');
    
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: challanController,
                decoration: const InputDecoration(
                  labelText: 'Challan No',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (DD.MM.YYYY)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  border: const OutlineInputBorder(),
                  errorText: errorMessage,
                  helperText: _getQuantityHelperText(isReceived),
                  helperMaxLines: 2,
                ),
                onChanged: (value) {
                  setState(() {
                    errorMessage = _validateQuantity(value, isReceived, editingIndex);
                  });
                },
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                    border: flutter.Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[600], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: errorMessage != null ? null : () {
                final challanNo = challanController.text.trim();
                final date = dateController.text.trim();
                final qty = int.tryParse(qtyController.text) ?? 0;

                if (challanNo.isNotEmpty && date.isNotEmpty && qty > 0) {
                  onSave(challanNo, date, qty);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateQuantity(String value, bool isReceived, int? editingIndex) {
    final qty = int.tryParse(value);
    if (qty == null || qty <= 0) {
      return qty == null ? 'Please enter a valid number' : 'Quantity must be greater than 0';
    }

    final requiredQty = int.tryParse(_requiredQtyController.text) ?? _originalData['requiredQty'] ?? 0;
    
    if (isReceived) {
      // Calculate current total received (excluding the entry being edited)
      int currentTotalReceived = 0;
      for (int i = 0; i < _receivedEntries.length; i++) {
        if (editingIndex == null || i != editingIndex) {
          currentTotalReceived += _receivedEntries[i]['qty'] as int;
        }
      }
      
      final newTotalReceived = currentTotalReceived + qty;
      
      if (newTotalReceived > requiredQty) {
        return 'Cannot exceed required quantity ($requiredQty)\nCurrent total would be: $newTotalReceived';
      }
    } else {
      // For issued entries - validate against available quantity
      final currentTotalReceived = _receivedEntries.fold<int>(0, (acc, entry) => acc + (entry['qty'] as int));
      final currentUsedQty = int.tryParse(_usedQtyController.text) ?? _originalData['usedQty'] ?? 0;
      
      // Calculate current total issued (excluding the entry being edited)
      int currentTotalIssued = 0;
      for (int i = 0; i < _issuedEntries.length; i++) {
        if (editingIndex == null || i != editingIndex) {
          currentTotalIssued += _issuedEntries[i]['qty'] as int;
        }
      }
      
      final availableQty = currentTotalReceived - currentTotalIssued - currentUsedQty;
      
      if (qty > availableQty) {
        return 'Cannot issue more than available quantity ($availableQty)\nReceived: $currentTotalReceived, Used: $currentUsedQty, Already Issued: $currentTotalIssued';
      }
    }
    
    return null;
  }

  String _getQuantityHelperText(bool isReceived) {
    if (isReceived) {
      final requiredQty = int.tryParse(_requiredQtyController.text) ?? _originalData['requiredQty'] ?? 0;
      final currentTotalReceived = _receivedEntries.fold<int>(0, (acc, entry) => acc + (entry['qty'] as int));
      final remaining = requiredQty - currentTotalReceived;
      
      return 'Required: $requiredQty, Received: $currentTotalReceived, Remaining: $remaining';
    } else {
      final currentTotalReceived = _receivedEntries.fold<int>(0, (acc, entry) => acc + (entry['qty'] as int));
      final currentUsedQty = int.tryParse(_usedQtyController.text) ?? _originalData['usedQty'] ?? 0;
      final currentTotalIssued = _issuedEntries.fold<int>(0, (acc, entry) => acc + (entry['qty'] as int));
      final available = currentTotalReceived - currentTotalIssued - currentUsedQty;
      
      return 'Available to issue: $available (Received: $currentTotalReceived, Used: $currentUsedQty, Issued: $currentTotalIssued)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Edit Inventory'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(_isSaving ? 'Saving...' : 'Save'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[600],
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
        bottom: _isLoading ? null : TabBar(
          controller: _tabController,
          labelColor: Colors.blue[600],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue[600],
          tabs: const [
            Tab(
              icon: Icon(Icons.edit, size: 18),
              text: 'Basic Info',
            ),
            Tab(
              icon: Icon(Icons.input, size: 18),
              text: 'Received',
            ),
            Tab(
              icon: Icon(Icons.output, size: 18),
              text: 'Issued',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBasicInfoTab(isDesktop),
                _buildReceivedEntriesTab(),
                _buildIssuedEntriesTab(),
              ],
            ),
    );
  }

  Widget _buildBasicInfoTab(bool isDesktop) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 800 : double.infinity,
          ),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Main Form Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.blue[600],
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Material Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Material Name
                          _buildCompactTextField(
                            controller: _materialNameController,
                            label: 'Material Name',
                            icon: Icons.inventory_2_outlined,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Quantities Row
                          if (isDesktop) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactTextField(
                                    controller: _requiredQtyController,
                                    label: 'Required Qty',
                                    icon: Icons.directions_run,
                                    keyboardType: TextInputType.number,
                                    validator: _quantityValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildCompactTextField(
                                    controller: _receivedQtyController,
                                    label: 'Received Qty',
                                    icon: Icons.input,
                                    keyboardType: TextInputType.number,
                                    validator: _quantityValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: _buildCompactDropdown(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactTextField(
                                    controller: _balIssueQtyController,
                                    label: 'Balance Issue Qty',
                                    icon: Icons.balance,
                                    keyboardType: TextInputType.number,
                                    validator: _quantityValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildCompactTextField(
                                    controller: _usedQtyController,
                                    label: 'Used Qty',
                                    icon: Icons.done,
                                    keyboardType: TextInputType.number,
                                    validator: _quantityValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(flex: 1, child: SizedBox()),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildCompactTextField(
                                    controller: _requiredQtyController,
                                    label: 'Required Qty',
                                    icon: Icons.directions_run,
                                    keyboardType: TextInputType.number,
                                    validator: _quantityValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildCompactDropdown(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactTextField(
                                    controller: _receivedQtyController,
                                    label: 'Received Qty',
                                    icon: Icons.input,
                                    keyboardType: TextInputType.number,
                                    validator: _quantityValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildCompactTextField(
                                    controller: _balIssueQtyController,
                                    label: 'Balance Issue',
                                    icon: Icons.balance,
                                    keyboardType: TextInputType.number,
                                    validator: _quantityValidator,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildCompactTextField(
                              controller: _usedQtyController,
                              label: 'Used Quantity',
                              icon: Icons.done,
                              keyboardType: TextInputType.number,
                              validator: _quantityValidator,
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Reason field
                          _buildCompactTextField(
                            controller: _reasonController,
                            label: 'Reason for Changes (Optional)',
                            icon: Icons.note_alt_outlined,
                            maxLines: 2,
                            hint: 'Brief reason for the changes...',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Current Info Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, 
                                   color: Colors.blue[600], size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Current Values',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[800],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          if (isDesktop) ...[
                            Row(
                              children: [
                                Expanded(child: _buildInfoItem('Total Received', '${_originalData['totalReceivedQty'] ?? 0}')),
                                Expanded(child: _buildInfoItem('Balance Qty', '${_originalData['balanceQty'] ?? 0}')),
                                Expanded(child: _buildInfoItem('UOM', _originalData['uom'] ?? 'N/A')),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: _buildInfoItem('Total Received', '${_originalData['totalReceivedQty'] ?? 0}')),
                                Expanded(child: _buildInfoItem('Balance Qty', '${_originalData['balanceQty'] ?? 0}')),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildInfoItem('Unit of Measurement', _originalData['uom'] ?? 'N/A'),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceivedEntriesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.input, color: Colors.green[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Received Entries',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Total entries: ${_receivedEntries.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addReceivedEntry,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _receivedEntries.isEmpty
                ? const Center(
                    child: Text(
                      'No received entries yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _receivedEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _receivedEntries[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[100],
                            child: Icon(Icons.receipt, color: Colors.green[600]),
                          ),
                          title: Text('Challan: ${entry['challanNo']}'),
                          subtitle: Text('Date: ${entry['date']} • Qty: ${entry['qty']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _editReceivedEntry(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                color: Colors.red,
                                onPressed: () => _deleteReceivedEntry(index),
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
    );
  }

  Widget _buildIssuedEntriesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.output, color: Colors.orange[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Issued Entries',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Total entries: ${_issuedEntries.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addIssuedEntry,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _issuedEntries.isEmpty
                ? const Center(
                    child: Text(
                      'No issued entries yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _issuedEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _issuedEntries[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange[100],
                            child: Icon(Icons.receipt_long, color: Colors.orange[600]),
                          ),
                          title: Text('Challan: ${entry['challanNo']}'),
                          subtitle: Text('Date: ${entry['date']} • Qty: ${entry['qty']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _editIssuedEntry(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                color: Colors.red,
                                onPressed: () => _deleteIssuedEntry(index),
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
    );
  }

  String? _quantityValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    if (int.tryParse(value) == null) {
      return 'Invalid number';
    }
    return null;
  }

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey[600], size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        labelStyle: const TextStyle(fontSize: 13),
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }

  Widget _buildCompactDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedUom,
      isExpanded: true,
      style: const TextStyle(fontSize: 14, color: Colors.black),
      decoration: InputDecoration(
        labelText: 'UOM',
        prefixIcon: Icon(Icons.straighten, color: Colors.grey[600], size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        labelStyle: const TextStyle(fontSize: 13),
      ),
      items: _uomOptions.map((String uom) {
        return DropdownMenuItem<String>(
          value: uom,
          child: Text(uom, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedUom = newValue!;
        });
      },
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
