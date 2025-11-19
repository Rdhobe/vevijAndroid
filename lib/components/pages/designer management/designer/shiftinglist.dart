import 'package:flutter/material.dart';

class ShiftinglistPage extends StatefulWidget {
  const ShiftinglistPage({super.key});

  @override
  State<ShiftinglistPage> createState() => _ShiftinglistPageState();
}

class _ShiftinglistPageState extends State<ShiftinglistPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shifting List'),
      ),
      body: const Center(
        child: Text('Shifting List Page'),   
      )
    );
  }
}