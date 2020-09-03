import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vulcain/db.dart';
import 'package:vulcain/login.dart';
import 'package:vulcain/map.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    openDb().then((_) {
      setState(() => ready = true);
    });
  }

  Widget _getLandingPage() {
    if (!ready) {
      return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Center(child: CircularProgressIndicator())]));
    }
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
