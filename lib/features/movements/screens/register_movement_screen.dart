import 'package:flutter/material.dart';
import '../../../data/models/movement.dart';

class RegisterMovementScreen extends StatelessWidget {
  final MovementType type;
  const RegisterMovementScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final title = type == MovementType.entry ? 'Register Entry' : 'Register Exit';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('Register movement form')),
    );
  }
}
