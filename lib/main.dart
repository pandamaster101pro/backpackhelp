import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:backpackhelp/Bottem_bar.dart';
import 'package:backpackhelp/checklist.dart';
import 'package:backpackhelp/HomeScreen.dart';
import 'package:backpackhelp/Login.dart';
import 'package:backpackhelp/Connection.dart';
import 'package:backpackhelp/notification_service.dart';
import 'package:backpackhelp/Profilepage.dart';
import 'package:backpackhelp/reminders.dart';
import 'package:backpackhelp/Scan.dart';
import 'package:backpackhelp/Signup.dart';
import 'package:backpackhelp/SplashScreen.dart';

import 'constants.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();
  await NotificationService.scheduleAll();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backpack Help',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.teal,
          surface: AppColors.surface,
          error: AppColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.ink,
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ink,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
          ),
        ),
      ),
      initialRoute: "/",
      routes: {
        "/": (context) => Splashscreen(),
        "/login": (context) => LoginScreen(),
        "/homescreen": (context) => Homescreen(),
        "/scan": (context) => ScanScreen(),
        "/checklist": (context) => ChecklistScreen(),
        "/reminders": (context) => RemindersScreen(),
        "/signupscreen": (context) => SignupScreen(),
        "/bottombar": (context) => bottom_bar(),
        "/profilepage": (context) => Profilepage(),
        "/connection": (context) => const ConnectionScreen(),
      },
    );
  }
}
