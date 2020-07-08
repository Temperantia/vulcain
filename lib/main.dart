import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vulcain/db.dart';
import 'package:vulcain/login.dart';
import 'package:vulcain/map.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await openDb();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  Widget _getLandingPage() {
    return StreamBuilder<FirebaseUser>(
      stream: FirebaseAuth.instance.onAuthStateChanged,
      builder: (BuildContext context, snapshot) {
        if (snapshot.hasData) {
          return MapPage();
        } else {
          return LoginPage();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vulcain',
      home: SafeArea(child: _getLandingPage()),
    );
  }
}
