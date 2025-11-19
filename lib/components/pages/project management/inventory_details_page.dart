import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
class InventoryDetailsPage extends StatelessWidget {
  final String materialName;
  final int requiredQty;
  final int totalReceivedQty;
  final int totalIssueQty;
  final String uom;
  final List receivedEntries;
  final List issuedEntries;
  final List<Map<String, dynamic>> editHistory;

  const InventoryDetailsPage({
    super.key,
    required this.materialName,
    required this.requiredQty,
    required this.totalReceivedQty,
    required this.totalIssueQty,
    required this.uom,
    required this.receivedEntries,
    required this.issuedEntries,
    required this.editHistory,
  });

  @override
  Widget build(BuildContext context) {
    final balanceQty = requiredQty - totalReceivedQty;
    final balIssueQty = totalReceivedQty - totalIssueQty;
    final Color balanceColor = balanceQty <= 0 ? Colors.green : Colors.red;
    final Color issueBalanceColor = balIssueQty > 0 ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: Text(materialName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[50]!, Colors.blue[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    materialName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Required', '$requiredQty $uom', Colors.blue),
                      _buildSummaryItem('Received', '$totalReceivedQty $uom', Colors.green),
                      _buildSummaryItem('Issued', '$totalIssueQty $uom', Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Balance', '${balanceQty.abs()} $uom', balanceColor),
                      _buildSummaryItem('Available', '$balIssueQty $uom', issueBalanceColor),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Received History Section
            if (receivedEntries.isNotEmpty) ...[
              _buildSectionHeader('Received History', Icons.input, Colors.green),
              const SizedBox(height: 12),
              ...receivedEntries.map(
                (entry) => _buildDetailedHistoryEntry(
                  entry['challanNo'] ?? '',
                  entry['date'] ?? '',
                  entry['qty'] ?? 0,
                  uom,
                  Colors.green,
                  null,
                ),
              ).toList(),
              const SizedBox(height: 24),
            ],

            // Issue History Section
            if (issuedEntries.isNotEmpty) ...[
              _buildSectionHeader('Issue History', Icons.output, Colors.orange),
              const SizedBox(height: 12),
              ...issuedEntries.map(
                (entry) => _buildDetailedHistoryEntry(
                  entry['challanNo'] ?? '',
                  entry['date'] ?? '',
                  entry['qty'] ?? 0,
                  uom,
                  Colors.orange,
                  entry['contractorName'],
                ),
              ).toList(),
              const SizedBox(height: 24),
            ],

            // Edit History Section
            if (editHistory.isNotEmpty) ...[
              _buildSectionHeader('Edit History', Icons.history, Colors.purple),
              const SizedBox(height: 12),
              ...editHistory.map(
                (edit) => _buildEditHistoryEntry(edit),
              ).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedHistoryEntry(
    String challanNo,
    String date,
    int qty,
    String uom,
    Color color,
    String? contractorName,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: flutter.Border(left: BorderSide(width: 3, color: color)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Challan: $challanNo',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '$qty $uom',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Date: $date',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          if (contractorName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Contractor: $contractorName',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditHistoryEntry(Map<String, dynamic> edit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: flutter.Border(left: BorderSide(width: 3, color: Colors.purple)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Edited by: ${edit['editedBy'] ?? 'Unknown'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                edit['editDate'] ?? '',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Changes:',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          ),
          const SizedBox(height: 4),
          ...((edit['changes'] as List<dynamic>?) ?? []).map(
            (change) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 2),
              child: Text(
                '• $change',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          if (edit['reason'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: ${edit['reason']}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

