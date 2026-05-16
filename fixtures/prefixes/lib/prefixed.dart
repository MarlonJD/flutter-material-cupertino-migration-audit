import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';

class PrefixedCase extends StatelessWidget {
  const PrefixedCase({super.key});

  @override
  Widget build(BuildContext context) {
    return material.Scaffold(
      body: material.TextButton(
        onPressed: () {},
        child: const Text('Already has widgets import'),
      ),
    );
  }
}
