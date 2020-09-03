import 'dart:io';

import 'package:apple_sign_in/apple_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _login() async {
    GoogleSignInAccount account;

    account = await _googleSignIn.signIn();
    final GoogleSignInAuthentication auth = await account.authentication;
    final AuthCredential credential = GoogleAuthProvider.getCredential(
        accessToken: auth.accessToken, idToken: auth.idToken);
    FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> _loginApple() async {
    final AuthorizationResult result = await AppleSignIn.performRequests([
      AppleIdRequest(requestedScopes: [Scope.email, Scope.fullName])
    ]);
    final AppleIdCredential appleIdCredential = result.credential;

    OAuthProvider oAuthProvider = new OAuthProvider(providerId: "apple.com");
    final AuthCredential credential = oAuthProvider.getCredential(
      idToken: String.fromCharCodes(appleIdCredential.identityToken),
      accessToken: String.fromCharCodes(appleIdCredential.authorizationCode),
    );
    FirebaseAuth.instance.signInWithCredential(credential);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Platform.isIOS ? Colors.black : Colors.white,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
                child: Platform.isAndroid
                    ? SignInButton(
                        Buttons.Google,
                        onPressed: () => _login(),
                      )
                    : SignInButton(
                        Buttons.Apple,
                        onPressed: () => _loginApple(),
                      ))
          ],
        ));
  }
}
