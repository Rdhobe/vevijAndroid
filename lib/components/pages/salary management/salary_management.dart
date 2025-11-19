import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:vevij/components/imports.dart';

class EmployeeSalaryPage extends StatefulWidget {
  final String userId;
  
  const EmployeeSalaryPage({super.key, required this.userId});

  @override
  State<EmployeeSalaryPage> createState() => _EmployeeSalaryPageState();
}

class _EmployeeSalaryPageState extends State<EmployeeSalaryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<SalaryRecord> _salaryRecords = [];
  Employee? _employee;
  bool _isLoading = true;
  SalaryRecord? _selectedRecord;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadEmployee(),
        _loadSalaryRecords(),
      ]);
    } catch (e) {
      _showError('Failed to load data: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadEmployee() async {
    final doc = await _firestore.collection('users').doc(widget.userId).get();
    if (doc.exists) {
      setState(() {
        _employee = Employee.fromMap(doc.data()!);
      });
    }
  }

  Future<void> _loadSalaryRecords() async {
    final snapshot = await _firestore
        .collection('salary_records')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('year', descending: true)
        .orderBy('month', descending: true)
        .get();

    setState(() {
      _salaryRecords = snapshot.docs
          .map((doc) => SalaryRecord.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'My Salary',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : isTablet ? _buildTabletLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        SizedBox(
          width: 380,
          child: _buildSalaryListView(),
        ),
        Expanded(
          child: _selectedRecord != null 
              ? _buildSalaryDetailsPanel(_selectedRecord!)
              : _buildEmptySelectionState(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    if (_selectedRecord != null) {
      return _buildSalaryDetailsPanel(_selectedRecord!);
    }
    return _buildSalaryListView();
  }

  Widget _buildSalaryListView() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Employee Info Header
          if (_employee != null)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo, Colors.indigo[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Text(
                      _employee!.empName.isNotEmpty ? _employee!.empName[0].toUpperCase() : 'E',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _employee!.empName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ID: ${_employee!.empCode}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          _employee!.designation,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Salary Records List
          Expanded(
            child: _salaryRecords.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: EdgeInsets.all(16),
                    itemCount: _salaryRecords.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildSalaryRecordCard(_salaryRecords[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryRecordCard(SalaryRecord record) {
    final isSelected = _selectedRecord?.id == record.id;
    final date = DateTime(record.year, record.month);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedRecord = record;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.indigo : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.indigo : Colors.indigo[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM').format(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.indigo,
                      ),
                    ),
                    Text(
                      '${record.year}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(date),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${record.presentDays} days present',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '  Rs.${record.netSalary.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalaryDetailsPanel(SalaryRecord record) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: !isTablet
          ? AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () {
                  setState(() {
                    _selectedRecord = null;
                  });
                },
              ),
              title: Text(
                DateFormat('MMMM yyyy').format(DateTime(record.year, record.month)),
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.download, color: Colors.indigo),
                  onPressed: () => _generateAndDownloadSlip(record),
                ),
              ],
            )
          : null,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Net Salary Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo, Colors.indigo[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Net Salary',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Rs.${record.netSalary.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (isTablet)
                          ElevatedButton.icon(
                            onPressed: () => _generateAndDownloadSlip(record),
                            icon: Icon(Icons.download),
                            label: Text('Download Slip'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.indigo,
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      DateFormat('MMMM yyyy').format(
                        DateTime(record.year, record.month),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Salary Breakdown
            _buildDetailSection(
              'Salary Breakdown',
              Icons.account_balance_wallet_outlined,
              [
                _buildDetailRow('Base Salary', '  Rs.${record.baseSalary.toStringAsFixed(0)}'),
                _buildDetailRow('Days in Month', '${record.daysPerMonth}'),
                _buildDetailRow('Per Day Salary', '  Rs.${record.perDaySalary.toStringAsFixed(2)}'),
                _buildDetailRow('Present Days', '${record.presentDays}', Colors.blue[700]),
                Divider(),
                _buildDetailRow('Salary as per Present', '  Rs.${record.salaryAsPerPresent.toStringAsFixed(0)}', Colors.blue[700], true),
              ],
            ),

            SizedBox(height: 16),

            // Allowances
            _buildDetailSection(
              'Allowances',
              Icons.add_circle_outline,
              [
                _buildDetailRow('Food Allowance', '  Rs.${record.foodAllowance.toStringAsFixed(0)}', Colors.green[700]),
                _buildDetailRow('Petrol Allowance', '  Rs.${record.petrolAllowance.toStringAsFixed(0)}', Colors.green[700]),
                _buildDetailRow('Travel Allowance', '  Rs.${record.travelAllowance.toStringAsFixed(0)}', Colors.green[700]),
                _buildDetailRow('Special Allowance', '  Rs.${record.specialAllowance.toStringAsFixed(0)}', Colors.green[700]),
                _buildDetailRow('Rent Allowance', '  Rs.${record.rentAllowance.toStringAsFixed(0)}', Colors.green[700]),
                _buildDetailRow('Overtime/Sunday', '  Rs.${record.overtimeAllowance.toStringAsFixed(0)}', Colors.green[700]),
                Divider(),
                _buildDetailRow('Total Allowances', '  Rs.${record.totalAllowances.toStringAsFixed(0)}', Colors.green[700], true),
              ],
            ),

            SizedBox(height: 16),

            // Gross Salary
            Card(
              elevation: 2,
              color: Colors.green[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.green[700]),
                        SizedBox(width: 8),
                        Text(
                          'Gross Salary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Rs.${record.grossSalary.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Deductions
            _buildDetailSection(
              'Deductions',
              Icons.remove_circle_outline,
              [
                _buildDetailRow('TDS', '  Rs.${record.tds.toStringAsFixed(0)}', Colors.red[700]),
                _buildDetailRow('Provident Fund', '  Rs.${record.pf.toStringAsFixed(0)}', Colors.red[700]),
                _buildDetailRow('Professional Tax', '  Rs.${record.pt.toStringAsFixed(0)}', Colors.red[700]),
                Divider(),
                _buildDetailRow('Total Deductions', '  Rs.${record.totalDeductions.toStringAsFixed(0)}', Colors.red[700], true),
              ],
            ),

            if (record.remarks.isNotEmpty) ...[
              SizedBox(height: 16),
              _buildDetailSection(
                'Remarks',
                Icons.note_outlined,
                [
                  Text(
                    record.remarks,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ],

            SizedBox(height: 24),

            // Download Button (Mobile)
            if (!isTablet)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _generateAndDownloadSlip(record),
                  icon: Icon(Icons.download, size: 20),
                  label: Text(
                    'Download Salary Slip',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, [Color? color, bool isBold = false]) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16),
          Text(
            'No Salary Records',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your salary records will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySelectionState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_outlined, size: 100, color: Colors.grey[300]),
          SizedBox(height: 24),
          Text(
            'Select a Salary Record',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Choose a salary record from the list to view details',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndDownloadSlip(SalaryRecord record) async {
    if (_employee == null) return;
    
    try {
      setState(() => _isLoading = true);
      
      final pdf = await _generateSalarySlipPdf(record, _employee!);
      
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/salary_slip_${record.employeeCode}_${record.month}_${record.year}.pdf');
      await file.writeAsBytes(await pdf.save());
      
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Salary Slip - ${record.employeeName}',
        text: 'Salary slip for ${DateFormat('MMMM yyyy').format(DateTime(record.year, record.month))}',
      );

      _showSuccess('Salary slip ready to download');
      
    } catch (e) {
      _showError('Failed to generate salary slip: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<pw.Document> _generateSalarySlipPdf(SalaryRecord record, Employee employee) async {
    final pdf = pw.Document();
    
    // Load logo
    final ByteData logoData = await rootBundle.load('assets/images/logoonly.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final pw.MemoryImage logoImage = pw.MemoryImage(logoBytes);
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header with Logo
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Logo
                pw.Container(
                  width: 80,
                  height: 80,
                  child: pw.Image(logoImage),
                ),
                pw.SizedBox(width: 20),
                // Header Text
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SALARY SLIP',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Period: ${DateFormat('MMMM yyyy').format(DateTime(record.year, record.month))}',
                        style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Generated: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),
            
            // Employee Details
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Employee: ${record.employeeName}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Employee ID: ${record.employeeCode}', style: pw.TextStyle(fontSize: 11)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Branch: ${employee.branch}', style: pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 24),
            
            // Earnings Section
            pw.Text('EARNINGS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(' Amount ( Rs.)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                _buildPdfTableRow('Basic Salary', record.baseSalary),
                _buildPdfTableRow('Present Days', record.presentDays.toDouble(), isAmount: false),
                _buildPdfTableRow('Per Day Salary', record.perDaySalary),
                _buildPdfTableRow('Salary as per Present', record.salaryAsPerPresent),
                if (record.foodAllowance > 0) _buildPdfTableRow('Food Allowance', record.foodAllowance),
                if (record.petrolAllowance > 0) _buildPdfTableRow('Petrol Allowance', record.petrolAllowance),
                if (record.travelAllowance > 0) _buildPdfTableRow('Travel Allowance', record.travelAllowance),
                if (record.specialAllowance > 0) _buildPdfTableRow('Special Allowance', record.specialAllowance),
                if (record.rentAllowance > 0) _buildPdfTableRow('Rent Allowance', record.rentAllowance),
                if (record.overtimeAllowance > 0) _buildPdfTableRow('Overtime/Sunday', record.overtimeAllowance),
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.green50),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('Total Earnings', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('  Rs.${record.grossSalary.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // Deductions Section
            pw.Text('DEDUCTIONS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(' Amount ( Rs.)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                if (record.tds > 0) _buildPdfTableRow('TDS', record.tds),
                if (record.pf > 0) _buildPdfTableRow('Provident Fund', record.pf),
                if (record.pt > 0) _buildPdfTableRow('Professional Tax', record.pt),
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.red50),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('Total Deductions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('  Rs.${record.totalDeductions.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // Net Salary
            pw.Container(
              padding: pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                border: pw.Border.all(color: PdfColors.blue200, width: 2),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'NET SALARY',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    '  Rs.${record.netSalary.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
            ),
            
            if (record.remarks.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text('Remarks:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 4),
              pw.Text(record.remarks, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
            ],
            
            pw.SizedBox(height: 30),
            
            // Footer
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'This is a computer-generated document',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page 1 of 1',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          ];
        },
      ),
    );
    
    return pdf;
  }

  pw.TableRow _buildPdfTableRow(String label, double value, {bool isAmount = true}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 10)),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(
            isAmount ? '  Rs.${value.toStringAsFixed(2)}' : value.toStringAsFixed(0),
            style: pw.TextStyle(fontSize: 10),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// Data Models
class SalaryRecord {
  final String id;
  final String userId;
  final String employeeName;
  final String employeeCode;
  final int month;
  final int year;
  final double baseSalary;
  final int daysPerMonth;
  final double perDaySalary;
  final int presentDays;
  final double salaryAsPerPresent;
  
  final double foodAllowance;
  final double petrolAllowance;
  final double travelAllowance;
  final double specialAllowance;
  final double rentAllowance;
  final double overtimeAllowance;
  final double totalAllowances;
  
  final double grossSalary;
  
  final double tds;
  final double pf;
  final double pt;
  final double totalDeductions;
  
  final double netSalary;
  final String remarks;
  final Timestamp createdAt;

  SalaryRecord({
    required this.id,
    required this.userId,
    required this.employeeName,
    required this.employeeCode,
    required this.month,
    required this.year,
    required this.baseSalary,
    required this.daysPerMonth,
    required this.perDaySalary,
    required this.presentDays,
    required this.salaryAsPerPresent,
    required this.foodAllowance,
    required this.petrolAllowance,
    required this.travelAllowance,
    required this.specialAllowance,
    required this.rentAllowance,
    required this.overtimeAllowance,
    required this.totalAllowances,
    required this.grossSalary,
    required this.tds,
    required this.pf,
    required this.pt,
    required this.totalDeductions,
    required this.netSalary,
    required this.remarks,
    required this.createdAt,
  });

  factory SalaryRecord.fromMap(String id, Map<String, dynamic> map) {
    return SalaryRecord(
      id: id,
      userId: map['userId'] as String,
      employeeName: map['employeeName'] as String,
      employeeCode: map['employeeCode'] as String,
      month: (map['month'] as num).toInt(),
      year: (map['year'] as num).toInt(),
      baseSalary: (map['baseSalary'] as num).toDouble(),
      daysPerMonth: (map['daysPerMonth'] as num).toInt(),
      perDaySalary: (map['perDaySalary'] as num).toDouble(),
      presentDays: (map['presentDays'] as num).toInt(),
      salaryAsPerPresent: (map['salaryAsPerPresent'] as num).toDouble(),
      foodAllowance: (map['foodAllowance'] as num).toDouble(),
      petrolAllowance: (map['petrolAllowance'] as num).toDouble(),
      travelAllowance: (map['travelAllowance'] as num).toDouble(),
      specialAllowance: (map['specialAllowance'] as num).toDouble(),
      rentAllowance: (map['rentAllowance'] as num).toDouble(),
      overtimeAllowance: (map['overtimeAllowance'] as num).toDouble(),
      totalAllowances: (map['totalAllowances'] as num).toDouble(),
      grossSalary: (map['grossSalary'] as num).toDouble(),
      tds: (map['tds'] as num).toDouble(),
      pf: (map['pf'] as num).toDouble(),
      pt: (map['pt'] as num).toDouble(),
      totalDeductions: (map['totalDeductions'] as num).toDouble(),
      netSalary: (map['netSalary'] as num).toDouble(),
      remarks: map['remarks'] as String? ?? '',
      createdAt: map['createdAt'] as Timestamp,
    );
  }
}