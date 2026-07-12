import 'package:backpackhelp/Ollama.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:backpackhelp/Bottem_bar.dart';
import 'package:backpackhelp/HomeScreen.dart';
import 'package:backpackhelp/Login.dart';
import 'package:backpackhelp/Connection.dart';
import 'package:backpackhelp/Profilepage.dart';
import 'package:backpackhelp/Scan.dart';
import 'package:backpackhelp/Signup.dart';
import 'package:backpackhelp/SplashScreen.dart';

import 'firebase_options.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: "/",
      routes: {
        //"/": (context) => Splashscreen(),
        "/login": (context) => LoginScreen(),
        "/homescreen": (context) => Homescreen(),
        "/scan": (context) => ScanScreen(),
        "/signupscreen": (context) => SignupScreen(),
        "/bottombar": (context) => bottom_bar(),
        "/profilepage": (context) => Profilepage(),
        "/connection": (context) => const ConnectionScreen(),
        "/": (context) => Ai(),

      },
    );
  }
}


