import 'dart:io';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:alerta_punk/Controllers/Auth/SignUpController.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final signUpController = SignUpController();
  bool isPasswordVisible = false;
  bool isLoading = false;
  File? profileImage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile != null) {
      setState(() {
        profileImage = File(pickedFile.path);
      });
    }
  }

  Future<String> uploadToImgBB(File imageFile) async {
    const apiKey = "2c68fb0d7ff2f04835d1da3cf672e0a3";
    final url = "https://api.imgbb.com/1/upload?key=$apiKey";
    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.files
        .add(await http.MultipartFile.fromPath('image', imageFile.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = json.decode(await response.stream.bytesToString());
      return responseData['data']['url'];
    } else {
      throw Exception("Error al subir la imagen a ImgBB");
    }
  }

  Future<void> onSignUp() async {
    final email = emailController.text;
    final password = passwordController.text;
    final name = nameController.text;

    if (email.isNotEmpty && password.isNotEmpty && name.isNotEmpty) {
      setState(() {
        isLoading = true;
      });

      try {
        String? imageUrl;
        if (profileImage != null) {
          // Subir la imagen a ImgBB
          imageUrl = await uploadToImgBB(profileImage!);
        }

        // Llamar al controlador para registrar al usuario
        await signUpController.signUp(name, email, password, imageUrl);

        Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen de perfil
                Center(
                  child: GestureDetector(
                    onTap: pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: profileImage != null
                          ? FileImage(profileImage!)
                          : const AssetImage('assets/images/default_profile.jpg')
                              as ImageProvider,
                      child: profileImage == null
                          ? const Icon(
                              Icons.camera_alt,
                              size: 30,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Crear una cuenta",
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "Regístrate para comenzar",
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 20),
                // Campo de nombre
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                // Campo de email
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                // Campo de contraseña
                TextFormField(
                  controller: passwordController,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Botón de registro
                Center(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 198, 12, 12),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text(
                            'Registrarse',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                // Enlace para iniciar sesión
                Center(
                  child: RichText(
                    text: TextSpan(
                      text: "¿Ya tienes una cuenta? ",
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Inicia sesión',
                          style: const TextStyle(
                            color: Color.fromARGB(255, 198, 12, 12),
                            fontWeight: FontWeight.bold,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pop(context);
                            },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
