import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Widget _buildCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    List<Color>? gradientColors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors ?? [Colors.deepPurple, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowStep({
    required IconData icon,
    required String title,
    required String description,
    required Color color1,
    required Color color2,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color1.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(value * 5, 0), // move arrow slightly
            child: const Icon(
              Icons.arrow_forward,
              color: Colors.deepPurple,
              size: 26,
            ),
          );
        },
        onEnd: () {
          // loop animation
          Future.delayed(const Duration(milliseconds: 300), () {
            if (context.mounted) setState(() {});
          });
        },
      ),
    );
  }

  Widget _buildFlowDiagram() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // background of big card
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(2, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Flow Diagram",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _flowStep(
                  icon: Icons.add_box,
                  title: "create project",
                  description: "Create a new \nproject",
                  color1: Colors.indigo,
                  color2: Colors.indigoAccent,
                ),
                _animatedArrow(),
                _flowStep(
                  icon: Icons.straighten,
                  title: "Measurements",
                  description: "Record all required measurements",
                  color1: Colors.indigo,
                  color2: Colors.indigoAccent,
                ),
                _animatedArrow(),
                _flowStep(
                  icon: Icons.list_alt,
                  title: "Working List",
                  description: "Prepare working items list",
                  color1: Colors.teal,
                  color2: Colors.tealAccent,
                ),
                _animatedArrow(),
                _flowStep(
                  icon: Icons.swap_horiz,
                  title: "Shifting List",
                  description: "Track shifting details",
                  color1: Colors.orange,
                  color2: Colors.deepOrangeAccent,
                ),
                _animatedArrow(),
                _flowStep(
                  icon: Icons.assignment,
                  title: "Work Order",
                  description: "Finalize and lock work order",
                  color1: Colors.purple,
                  color2: Colors.pinkAccent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "⚠️ Notes: Can't make changes after Work Order is finalized.",
              style: TextStyle(
                color: Colors.red,
                backgroundColor: Colors.yellow,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Decide grid count based on screen width
    int crossAxisCount = MediaQuery.of(context).size.width > 900
        ? 5
        : MediaQuery.of(context).size.width > 600
        ? 3
        : 2;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2, // smaller height, balanced look
              children: [
                _buildCard(
                  icon: Icons.straighten,
                  title: "Create Project",
                  gradientColors: [Colors.indigo, Colors.indigoAccent],
                  onTap: () => Navigator.pushNamed(context, '/createproject'),
                ),
                _buildCard(
                  icon: Icons.straighten,
                  title: "Measurements",
                  gradientColors: [Colors.indigo, Colors.indigoAccent],
                  onTap: () => Navigator.pushNamed(context, '/measurements'),
                ),
                _buildCard(
                  icon: Icons.list_alt,
                  title: "Working List",
                  gradientColors: [Colors.teal, Colors.tealAccent],
                  onTap: () => Navigator.pushNamed(context, '/workinglist'),
                ),
                _buildCard(
                  icon: Icons.swap_horiz,
                  title: "Shifting List",
                  gradientColors: [Colors.orange, Colors.deepOrangeAccent],
                  onTap: () => Navigator.pushNamed(context, '/shiftinglist'),
                ),
                _buildCard(
                  icon: Icons.assignment,
                  title: "Work Order",
                  gradientColors: [Colors.purple, Colors.pinkAccent],
                  onTap: () => Navigator.pushNamed(context, '/createworkorder'),
                ),
              ],
            ),
            const SizedBox(height: 24),
             SizedBox(),
          ],
        ),
      ),
    );
  }
}
