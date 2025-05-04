import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:stockwatcher/firebase_options.dart';
import 'package:stockwatcher/app/app.dart';
import 'package:stockwatcher/services/config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize configs
  await ConfigService().initialize();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const StockWatcherApp());
}
