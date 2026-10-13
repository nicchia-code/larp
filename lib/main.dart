import 'dart:async';

import 'package:flutter/material.dart';

import 'call/call_controller.dart';
import 'call/call_screen.dart';

void main() {
  final controller = CallController();
  unawaited(controller.checkModels());
  runApp(MainApp(controller: controller));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key, required this.controller});

  final CallController controller;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CallToRecord',
      debugShowCheckedModeBanner: false,
      home: CallScreen(controller: widget.controller),
    );
  }
}
