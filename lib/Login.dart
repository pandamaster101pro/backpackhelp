import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:backpackhelp/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String error = "";
  final formKey = GlobalKey<FormState>();

  final email_controller = TextEditingController();
  final password_controller = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    email_controller.dispose();
    password_controller.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      error = "";
      isLoading = true;
    });

    //Checks to see if email and password is valid
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email_controller.text.trim(),
        password: password_controller.text.trim(),
      );
      if (mounted) Navigator.pushReplacementNamed(context, "/bottombar");
    } catch (e) {
      setState(() => error = "Incorrect email or password. Please try again.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF7F7F5),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Heading
              const Text(
                "Welcome back",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Sign in to your account",
                style: TextStyle(fontSize: 14, color: Colors.black45),
              ),

              const SizedBox(height: 32),

              // Fields card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    // Email field
                    TextFormField(
                      controller: email_controller,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return "Email is required";
                        if (!v.contains('@')) return "Enter a valid email";
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                        prefixIcon: const Icon(Icons.mail_outline, size: 18, color: Colors.black38),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.black26, width: 1),
                        ),
                        errorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.redAccent, width: 1),
                        ),
                        focusedErrorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.redAccent, width: 1),
                        ),
                      ),
                    ),

                    const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0EE)),

                    // Password field
                    TextFormField(
                      controller: password_controller,
                      obscureText: obscurePassword,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Password is required";
                        if (v.length < 6) return "Minimum 6 characters";
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: "Password",
                        labelStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                        prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Colors.black38),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: Colors.black38,
                          ),
                          onPressed: () => setState(() => obscurePassword = !obscurePassword),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.black26, width: 1),
                        ),
                        errorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.redAccent, width: 1),
                        ),
                        focusedErrorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.redAccent, width: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Error message
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          error,
                          style: const TextStyle(fontSize: 13, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),

              // Login button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.black26,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    "Log In",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sign up link
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, "/signupscreen"),
                  style: TextButton.styleFrom(foregroundColor: Colors.black54),
                  child: const Text(
                    "Don't have an account? Sign up",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}