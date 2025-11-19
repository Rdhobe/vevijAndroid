import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Update Inventory Dialog Widget - Fixed Responsive Version
class UpdateInventoryDialog extends StatefulWidget {
  final String projectId;

  const UpdateInventoryDialog({super.key, required this.projectId});

  @override
  UpdateInventoryDialogState createState() => UpdateInventoryDialogState();
}

class UpdateInventoryDialogState extends State<UpdateInventoryDialog> {
  String selectedAction = 'entry_on_site'; // Default action
  List<Map<String, dynamic>> inventoryItems = [];
  List<Map<String, dynamic>> selectedItems = [];
  Map<String, TextEditingController> qtyControllers = {};
  TextEditingController contractorNameController = TextEditingController();
  TextEditingController challanNumberController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInventoryItems();
  }

  Future<void> _loadInventoryItems() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .get();

      setState(() {
        inventoryItems = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'materialName': data['materialName'] ?? '',
            'requiredQty': data['requiredQty'] ?? 0,
            'receivedQty': data['receivedQty'] ?? 0,
            'totalReceivedQty': data['totalReceivedQty'] ?? 0,
            'usedQty': data['usedQty'] ?? 0,
            'totalIssuedQty': data['totalIssuedQty'] ?? 0,
            'balanceQty': data['balanceQty'] ?? 0,
            'balIssueQty': data['balIssueQty'] ?? 0,
            'receivedEntries': data['receivedEntries'] ?? [],
            'issuedEntries': data['issuedEntries'] ?? [],
          };
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inventory: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1024;
    final isDesktop = screenSize.width >= 1024;
    
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : (isTablet ? 24 : 48),
        vertical: isSmallScreen ? 16 : 24,
      ),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: isSmallScreen ? double.infinity : (isTablet ? 720 : 980),
          maxHeight: screenSize.height * (isSmallScreen ? 0.95 : 0.9),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed Header
            _buildHeader(isSmallScreen),
            
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 12 : (isTablet ? 16 : 20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action Selection
                    _buildActionSelection(isSmallScreen, isTablet),
                    SizedBox(height: isSmallScreen ? 12 : 16),

                    // Contractor Name (only for issue to contractor)
                    if (selectedAction == 'issue_to_contractor') ...[
                      _buildContractorField(isSmallScreen),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                    ],

                    // Challan Number
                    _buildChallanNumber(isSmallScreen),
                    SizedBox(height: isSmallScreen ? 12 : 16),

                    // Material Selection
                    _buildMaterialSelection(isSmallScreen, isTablet, isDesktop),
                  ],
                ),
              ),
            ),

            // Fixed Footer with Action Buttons
            _buildFooter(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Update Inventory',
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSelection(bool isSmallScreen, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: flutter.Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Action:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: isSmallScreen ? 13 : 14,
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          DropdownButtonFormField<String>(
            value: selectedAction,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            style: TextStyle(fontSize: isSmallScreen ? 13 : 14, color: Colors.black),
            items: const [
              DropdownMenuItem(
                value: 'entry_on_site',
                child: Text('Entry on Site (Material Received)'),
              ),
              DropdownMenuItem(
                value: 'issue_to_contractor',
                child: Text('Issue to Contractor'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                selectedAction = value!;
                selectedItems.clear();
                qtyControllers.clear();
                contractorNameController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContractorField(bool isSmallScreen) {
    return TextFormField(
      controller: contractorNameController,
      decoration: InputDecoration(
        labelText: 'Contractor Name',
        labelStyle: TextStyle(fontSize: isSmallScreen ? 13 : 14),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        prefixIcon: const Icon(Icons.person, size: 20),
        isDense: true,
      ),
      style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
    );
  }

  Widget _buildChallanNumber(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Challan Number:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 13 : 14,
          ),
        ),
        SizedBox(height: isSmallScreen ? 6 : 8),
        TextFormField(
          controller: challanNumberController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            isDense: true,
          ),
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialSelection(bool isSmallScreen, bool isTablet, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Materials:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 13 : 14,
          ),
        ),
        SizedBox(height: isSmallScreen ? 6 : 8),
        
        Container(
          height: isSmallScreen ? 280 : (isTablet ? 350 : 400),
          decoration: BoxDecoration(
            border: flutter.Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Header
              _buildMaterialHeader(isSmallScreen, isTablet),
              
              // Material List
              Expanded(
                child: inventoryItems.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : ListView.separated(
                        itemCount: inventoryItems.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey[200],
                        ),
                        itemBuilder: (context, index) {
                          final item = inventoryItems[index];
                          final isSelected = selectedItems.any(
                            (selected) => selected['id'] == item['id'],
                          );

                          return Container(
                            color: isSelected ? Colors.blue[50] : Colors.white,
                            child: Padding(
                              padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                              child: isSmallScreen
                                  ? _buildMobileMaterialItem(item, isSelected)
                                  : _buildDesktopMaterialItem(item, isSelected, isTablet),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialHeader(bool isSmallScreen, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: isSmallScreen
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Materials Selection',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallScreen ? 12 : 13,
                  ),
                ),
                Text(
                  'Tap to select materials and enter quantities',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const SizedBox(width: 32),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Material',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isTablet ? 12 : 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Available',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isTablet ? 12 : 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Quantity',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isTablet ? 12 : 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMobileMaterialItem(Map<String, dynamic> item, bool isSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (value) => _toggleItemSelection(item, value),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['materialName'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (selectedAction == 'entry_on_site' &&
                      item['receivedEntries'].isNotEmpty)
                    Text(
                      'Last received: ${item['receivedEntries'].last['qty']} on ${item['receivedEntries'].last['date']}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        if (isSelected) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Available: ${selectedAction == 'entry_on_site' ? (item['receivedQty'] ?? item['totalReceivedQty']) : item['balIssueQty']}',
                  style: TextStyle(
                    color: selectedAction == 'entry_on_site'
                        ? Colors.green
                        : (item['balIssueQty'] > 0 ? Colors.green : Colors.red),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: qtyControllers[item['id']],
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopMaterialItem(
      Map<String, dynamic> item, bool isSelected, bool isTablet) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox
        Checkbox(
          value: isSelected,
          onChanged: (value) => _toggleItemSelection(item, value),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        
        // Material Name
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['materialName'],
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: isTablet ? 12 : 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (selectedAction == 'entry_on_site' &&
                  item['receivedEntries'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Last received: ${item['receivedEntries'].last['qty']} on ${item['receivedEntries'].last['date']}',
                    style: TextStyle(
                      fontSize: isTablet ? 9 : 10,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        
        // Available Quantity
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              selectedAction == 'entry_on_site'
                  ? '${item['receivedQty'] ?? item['totalReceivedQty']}'
                  : '${item['balIssueQty']}',
              style: TextStyle(
                color: selectedAction == 'entry_on_site'
                    ? Colors.green
                    : (item['balIssueQty'] > 0 ? Colors.green : Colors.red),
                fontWeight: FontWeight.w600,
                fontSize: isTablet ? 12 : 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        
        // Quantity Input
        Expanded(
          flex: 2,
          child: isSelected
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextFormField(
                    controller: qtyControllers[item['id']],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: isTablet ? 11 : 12),
                    textAlign: TextAlign.center,
                  ),
                )
              : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 10 : 12),
          Expanded(
            child: ElevatedButton(
              onPressed: selectedItems.isNotEmpty && !isLoading
                  ? _updateInventory
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: isLoading
                  ? SizedBox(
                      width: isSmallScreen ? 12 : 14,
                      height: isSmallScreen ? 12 : 14,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        selectedAction == 'entry_on_site'
                            ? 'Update Received'
                            : 'Issue Materials',
                        style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleItemSelection(Map<String, dynamic> item, bool? value) {
    setState(() {
      if (value == true) {
        selectedItems.add(item);
        qtyControllers[item['id']] = TextEditingController();
      } else {
        selectedItems.removeWhere((selected) => selected['id'] == item['id']);
        qtyControllers.remove(item['id']);
      }
    });
  }

  Future<void> _updateInventory() async {
    // Validation
    if (selectedAction == 'issue_to_contractor' &&
        contractorNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter contractor name')),
      );
      return;
    }

    // Check if quantities are valid
    for (var item in selectedItems) {
      final qtyText = qtyControllers[item['id']]?.text ?? '';
      final qty = int.tryParse(qtyText);

      if (qty == null || qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter valid quantity for ${item['materialName']}',
            ),
          ),
        );
        return;
      }

      // Prevent over-issuing
      if (selectedAction == 'issue_to_contractor' &&
          qty > item['balIssueQty']) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot issue more than available quantity (${item['balIssueQty']})\n'
              'Received: ${item['receivedQty'] ?? item['totalReceivedQty']}, '
              'Used: ${item['usedQty'] ?? item['totalIssuedQty']}, '
              'Already Issued: ${item['totalIssuedQty'] ?? item['usedQty']}',
            ),
          ),
        );
        return;
      }

      // Prevent over-receiving
      if (selectedAction == 'entry_on_site' &&
          ((item['receivedQty'] ?? item['totalReceivedQty']) + qty) > item['requiredQty']) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot exceed required quantity (${item['requiredQty']})\n'
              'Current total would be: ${(item['receivedQty'] ?? item['totalReceivedQty']) + qty}',
            ),
          ),
        );
        return;
      }
    }

    setState(() => isLoading = true);
    
    // Perform batch update
    try {
      final batch = FirebaseFirestore.instance.batch();
      final date = DateFormat('dd.MM.yyyy').format(DateTime.now());

      for (var item in selectedItems) {
        final qty = int.parse(qtyControllers[item['id']]!.text);
        final docRef = FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('inventory')
            .doc(item['id']);

        if (selectedAction == 'entry_on_site') {
          // Add to received entries
          final newReceivedEntry = {
            'challanNo': challanNumberController.text.trim(),
            'date': date,
            'qty': qty,
          };

          final updatedReceivedEntries = List<Map<String, dynamic>>.from(
            item['receivedEntries'],
          )..add(newReceivedEntry);

          // Calculate updated values
          final currentReceivedQty = item['receivedQty'] ?? item['totalReceivedQty'] ?? 0;
          final currentUsedQty = item['usedQty'] ?? item['totalIssuedQty'] ?? 0;
          
          final newReceivedQty = currentReceivedQty + qty;
          final newTotalReceivedQty = newReceivedQty; // Keep both fields in sync
          final newBalanceQty = item['requiredQty'] - newReceivedQty;
          final newBalIssueQty = newReceivedQty - currentUsedQty;

          batch.update(docRef, {
            'receivedEntries': updatedReceivedEntries,
            'receivedQty': newReceivedQty,
            'totalReceivedQty': newTotalReceivedQty,
            'balanceQty': newBalanceQty,
            'balIssueQty': newBalIssueQty,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (selectedAction == 'issue_to_contractor') {
          // Add to issued entries
          final newIssuedEntry = {
            'challanNo': challanNumberController.text.trim(),
            'date': date,
            'qty': qty,
            'contractorName': contractorNameController.text.trim(),
          };

          final updatedIssuedEntries = List<Map<String, dynamic>>.from(
            item['issuedEntries'],
          )..add(newIssuedEntry);

          // Calculate updated values
          final currentUsedQty = item['usedQty'] ?? item['totalIssuedQty'] ?? 0;
          final currentReceivedQty = item['receivedQty'] ?? item['totalReceivedQty'] ?? 0;
          
          final newUsedQty = currentUsedQty + qty;
          final newTotalIssuedQty = newUsedQty; // Keep both fields in sync
          final newBalIssueQty = currentReceivedQty - newUsedQty;

          batch.update(docRef, {
            'issuedEntries': updatedIssuedEntries,
            'usedQty': newUsedQty,
            'totalIssuedQty': newTotalIssuedQty,
            'balIssueQty': newBalIssueQty,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selectedAction == 'entry_on_site'
                  ? 'Materials received successfully'
                  : 'Materials issued successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating inventory: $e'),
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

  @override
  void dispose() {
    for (var controller in qtyControllers.values) {
      controller.dispose();
    }
    contractorNameController.dispose();
    super.dispose();
  }
}
// Add the detail view classes from the previous artifact
