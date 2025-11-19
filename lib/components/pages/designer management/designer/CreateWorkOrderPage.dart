import 'package:flutter/material.dart';

class CreateWorkOrderPage extends StatefulWidget {
  const CreateWorkOrderPage({super.key});

  @override
  State<CreateWorkOrderPage> createState() => _CreateWorkOrderPageState();
}

class _CreateWorkOrderPageState extends State<CreateWorkOrderPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Work Order'),
      ),
      body: const Center(
        child: Text('Create Work Order Page'),
      ),
    );
  }
}