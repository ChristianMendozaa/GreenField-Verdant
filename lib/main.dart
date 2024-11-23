import 'package:alerta_punk/firebase_options.dart';
import 'package:alerta_punk/pages/Auth/login.dart';
import 'package:alerta_punk/pages/Auth/signup.dart';
import 'package:alerta_punk/pages/home_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await _checkAndRequestPermissions();

  runApp(const MyApp());
}

Future<void> _checkAndRequestPermissions() async {
  final Location location = Location();

  // Verificar si los servicios de ubicación están habilitados
  bool serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) {
      throw Exception('Los servicios de ubicación están deshabilitados.');
    }
  }

  // Verificar si los permisos están otorgados
  PermissionStatus permissionGranted = await location.hasPermission();
  if (permissionGranted == PermissionStatus.denied) {
    permissionGranted = await location.requestPermission();
    if (permissionGranted != PermissionStatus.granted) {
      throw Exception('Permisos de ubicación denegados.');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Greenfield',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // Determinar la pantalla inicial
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginView(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Verificar si hay un usuario autenticado
    final user = FirebaseAuth.instance.currentUser;

    // Si el usuario está autenticado, redirigir a HomePage; de lo contrario, a LoginView
    if (user != null) {
      return const HomePage();
    } else {
      return const LoginView();
    }
  }
}
