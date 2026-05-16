import 'package:flutter/material.dart'
    show BuildContext, Scaffold, StatelessWidget, Text, Widget;
import 'package:flutter/cupertino.dart' hide Text;

class ShowCase extends StatelessWidget {
  const ShowCase({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Text('show/hide combinators need symbol-level splitting'),
    );
  }
}
