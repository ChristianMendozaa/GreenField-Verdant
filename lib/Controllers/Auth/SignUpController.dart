import 'package:alerta_punk/Models/UserModel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class SignUpController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> signUp(
      String name, String email, String password, File? profileImage) async {
    try {
      // Crear usuario en Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user != null) {
        String? profileImageUrl;

        // Subir imagen de perfil a Firebase Storage
        if (profileImage != null) {
          final storageRef =
              _storage.ref().child('imagenes/${user.uid}/profile.jpg');
          final uploadTask = await storageRef.putFile(profileImage);
          profileImageUrl = await uploadTask.ref.getDownloadURL();
        }

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
