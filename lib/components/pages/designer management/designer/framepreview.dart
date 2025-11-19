import 'package:flutter/material.dart';

class FramePreviewPage extends StatefulWidget {
  final Map<String, dynamic> generatedFrames;
  final double minGap;
  final double maxGap;

  const FramePreviewPage({
    super.key,
    required this.generatedFrames,
    required this.minGap,
    required this.maxGap,
  });

  @override
  State<FramePreviewPage> createState() => _FramePreviewPageState();
}

class _FramePreviewPageState extends State<FramePreviewPage>
    with SingleTickerProviderStateMixin {
  int? expandedFrameIndex;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get frames =>
      widget.generatedFrames['frames'] as List<Map<String, dynamic>>;

  bool _shouldHighlightWallThickness(dynamic wallThickness) {
    if (wallThickness == null || wallThickness is! double) return false;
    return wallThickness >= 165;
  }

  bool _shouldHighlightGap(dynamic gap) {
    if (gap == null || gap is! double) return false;
    return gap == 25;
  }

  bool _shouldHighlightHeight(dynamic height) {
    if (height == null || height is! double) return false;
    return height == 2225;
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
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameCard(Map<String, dynamic> frame, int index) {
    final isExpanded = expandedFrameIndex == index;
    final measurements = frame['measurements'] as List<Map<String, dynamic>>;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      child: _buildModernCard(
        color: Colors.white,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  expandedFrameIndex = isExpanded ? null : index;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.indigo.shade50,
                      Colors.indigo.shade100.withOpacity(0.5),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.indigo.shade400,
                                Colors.indigo.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '#${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Frame Specification',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${measurements.length} measurement${measurements.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.indigo.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: Colors.indigo.shade700,
                          size: 28,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpecItem(
                            'Wall',
                            '${frame['frameWall']}mm',
                            Icons.border_all,
                            Colors.blue.shade600,
                            _shouldHighlightWallThickness(frame['frameWall']),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSpecItem(
                            'Width',
                            '${frame['frameWidth']}mm',
                            Icons.straighten,
                            Colors.orange.shade600,
                            false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSpecItem(
                            'Height',
                            '${frame['frameHeight']}mm',
                            Icons.height,
                            Colors.green.shade600,
                            _shouldHighlightHeight(frame['frameHeight']),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gap Ranges',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGapRange(
                            'Wall',
                            frame['minGaps']['wall'],
                            frame['maxGaps']['wall'],
                            Colors.blue.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildGapRange(
                            'Width',
                            frame['minGaps']['width'],
                            frame['maxGaps']['width'],
                            Colors.orange.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildGapRange(
                            'Height',
                            frame['minGaps']['height'],
                            frame['maxGaps']['height'],
                            Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Applicable Measurements (${measurements.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateColor.resolveWith(
                            (states) => Colors.grey.shade100,
                          ),
                          headingRowHeight: 45,
                          dataRowMaxHeight: 48,
                          columnSpacing: 16,
                          horizontalMargin: 16,
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Location',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Flat No',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Wall',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Width',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Height',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Wall Gap',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Width Gap',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Height Gap',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                          rows: measurements.map((m) {
                            final gaps = m['gaps'];
                            return DataRow(
                              cells: [
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      m['location'] ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    m['flatNo'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  _buildHighlightableCell(
                                    '${m['wallThickness']}mm',
                                    _shouldHighlightWallThickness(
                                      m['wallThickness'],
                                    ),
                                    Colors.blue,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${m['width']}mm',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                DataCell(
                                  _buildHighlightableCell(
                                    '${m['height']}mm',
                                    _shouldHighlightHeight(m['height']),
                                    Colors.green,
                                  ),
                                ),
                                DataCell(
                                  _buildHighlightableCell(
                                    '${gaps['wall'].toStringAsFixed(1)}mm',
                                    _shouldHighlightGap(gaps['wall']),
                                    Colors.purple,
                                  ),
                                ),
                                DataCell(
                                  _buildHighlightableCell(
                                    '${gaps['width'].toStringAsFixed(1)}mm',
                                    _shouldHighlightGap(gaps['width']),
                                    Colors.purple,
                                  ),
                                ),
                                DataCell(
                                  _buildHighlightableCell(
                                    '${gaps['height'].toStringAsFixed(1)}mm',
                                    _shouldHighlightGap(gaps['height']),
                                    Colors.purple,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightableCell(String text, bool highlight, Color color) {
    if (highlight) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      );
    }
    return Text(text, style: const TextStyle(fontSize: 11));
  }

  Widget _buildSpecItem(
    String label,
    String value,
    IconData icon,
    Color color,
    bool highlight,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.15) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? color : Colors.grey.shade300,
          width: highlight ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: highlight ? color : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGapRange(String label, double min, double max, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${min.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                ' - ',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              Text(
                '${max.toStringAsFixed(1)}mm',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Frame Preview',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.indigo.shade600, Colors.indigo.shade700],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.indigo.shade50.withOpacity(0.3),
                Colors.white.withOpacity(0.8),
              ],
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModernCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.indigo.shade400,
                                  Colors.indigo.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.analytics_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Configuration Summary',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Gap range: ${widget.minGap}mm - ${widget.maxGap}mm',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatsCard(
                              'Total Frames',
                              '${frames.length}',
                              Icons.widgets,
                              Colors.indigo.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatsCard(
                              'Avg per Frame',
                              '${(frames.fold<int>(0, (sum, f) => sum + (f['measurementCount'] as int)) / frames.length).toStringAsFixed(1)}',
                              Icons.trending_up,
                              Colors.green.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatsCard(
                              'Efficiency',
                              '${(frames.fold<int>(0, (sum, f) => sum + (f['measurementCount'] as int)) / frames.length).toStringAsFixed(1)}:1',
                              Icons.trending_up,
                              Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Frame Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                ...frames.asMap().entries.map((entry) {
                  return _buildFrameCard(entry.value, entry.key);
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}