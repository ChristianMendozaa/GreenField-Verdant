import 'package:alerta_punk/Models/UserModel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> signUp(
      String name, String email, String password, String? profileImageUrl) async {
    try {
      // Crear usuario en Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user != null) {
        // Guardar datos del usuario en Firestore
        final userModel = UserModel(uid: user.uid, email: email);

        await _firestore.collection('users').doc(user.uid).set({
          'uid': userModel.uid,
          'email': userModel.email,
          'name': name,
          'profileImage': profileImageUrl, // URL de la imagen de perfil
        });
      }
    } catch (e) {
      throw Exception('Error al registrar el usuario: $e');
    }
  }
}
