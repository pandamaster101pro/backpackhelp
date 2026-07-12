import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:backpackhelp/GuestSession.dart';
import 'package:backpackhelp/Login.dart';
import 'constants.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  //a variable to store error
  String error = "";
  //Controller that stores text form feild info
  final formKey = GlobalKey<FormState>();

  final name_controller = TextEditingController();
  final email_controller = TextEditingController();
  final password_controller = TextEditingController();
  final confirm_password_controller = TextEditingController();
  //quality of life ui
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  //function to free up space
  @override
  void dispose() {
    name_controller.dispose();
    email_controller.dispose();
    password_controller.dispose();
    confirm_password_controller.dispose();
    super.dispose();
  }

  Future<void> signup() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      error = "";
      isLoading = true;
    });
    //if any code above break it goes to catch ifelse foes to finally

    try {
      //Creates a account where it sends the users input to firebase (firebase auth)
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email_controller.text.trim(),
        password: password_controller.text.trim(),
      );

      //it stores the new user’s info in Firestore by creating a document in the Users collection containing their unique UID, name, and email.
      await FirebaseFirestore.instance
          .collection("users")
          .doc(credential.user!.uid)
          .set({
        "name": name_controller.text.trim(),
        "email": email_controller.text.trim(),
      });

      if (mounted) Navigator.pushReplacementNamed(context, "/bottombar");

    } catch (e) {
      setState(() => error = "Failed to create account. Please try again.");
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
                "Create account",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Fill in your details to get started",
                style: TextStyle(fontSize: 14, color: Colors.black45),
              ),

              const SizedBox(height: 32),


              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    _SignupField(
                      controller: name_controller,
                      label: "Name",
                      icon: Icons.person_outline,
                      isFirst: true,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Name is required" : null,
                    ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0EE)),
                    _SignupField(
                      controller: email_controller,
                      label: "Email",
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        // validator makes sure the email is valid
                        if (v == null || v.trim().isEmpty) return "Email is required";
                        if (!v.contains('@')) return "Enter a valid email";
                        return null;
                      },
                    ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0EE)),
                    _SignupField(
                      controller: password_controller,
                      label: "Password",
                      icon: Icons.lock_outline,
                      obscureText: obscurePassword,
                      toggleObscure: () =>
                          setState(() => obscurePassword = !obscurePassword),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Password is required";
                        if (v.length < 6) return "Minimum 6 characters";
                        return null;
                      },
                    ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0EE)),
                    _SignupField(
                      controller: confirm_password_controller,
                      label: "Confirm Password",
                      icon: Icons.lock_outline,
                      //obscure button
                      obscureText: obscureConfirm,
                      isLast: true,
                      toggleObscure: () =>
                          setState(() => obscureConfirm = !obscureConfirm),
                      validator: (v) => v != password_controller.text
                          ? "Passwords do not match"
                          : null,
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
                      const Icon(Icons.error_outline,
                          size: 14, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Text(
                        error,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),

              // Sign up button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : signup,
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
                    "Sign Up",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Login link
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, "/login"),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black54,
                  ),
                  child: const Text(
                    "Already have an account? Log in",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),

              // Guest link
              Center(
                child: TextButton(
                  onPressed: () {
                    GuestSession.start();
                    Navigator.pushReplacementNamed(context, "/bottombar");
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.black38),
                  child: const Text(
                    "Continue as Guest",
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

// ── Field widget --> custom class that will return text form field --> format for the text form feild for all imput on page

class _SignupField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? toggleObscure;
  final String? Function(String?)? validator;

  const _SignupField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.isFirst = false,
    this.isLast = false,
    this.toggleObscure,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Colors.black38),
        prefixIcon: Icon(icon, size: 18, color: Colors.black38),
        suffixIcon: toggleObscure != null
            ? IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
            color: Colors.black38,
          ),
          onPressed: toggleObscure,
        )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.only(
            topLeft: isFirst ? const Radius.circular(12) : Radius.zero,
            topRight: isFirst ? const Radius.circular(12) : Radius.zero,
            bottomLeft: isLast ? const Radius.circular(12) : Radius.zero,
            bottomRight: isLast ? const Radius.circular(12) : Radius.zero,
          ),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.only(
            topLeft: isFirst ? const Radius.circular(12) : Radius.zero,
            topRight: isFirst ? const Radius.circular(12) : Radius.zero,
            bottomLeft: isLast ? const Radius.circular(12) : Radius.zero,
            bottomRight: isLast ? const Radius.circular(12) : Radius.zero,
          ),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.only(
            topLeft: isFirst ? const Radius.circular(12) : Radius.zero,
            topRight: isFirst ? const Radius.circular(12) : Radius.zero,
            bottomLeft: isLast ? const Radius.circular(12) : Radius.zero,
            bottomRight: isLast ? const Radius.circular(12) : Radius.zero,
          ),
          borderSide: const BorderSide(color: Colors.black26, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.only(
            topLeft: isFirst ? const Radius.circular(12) : Radius.zero,
            topRight: isFirst ? const Radius.circular(12) : Radius.zero,
            bottomLeft: isLast ? const Radius.circular(12) : Radius.zero,
            bottomRight: isLast ? const Radius.circular(12) : Radius.zero,
          ),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.only(
            topLeft: isFirst ? const Radius.circular(12) : Radius.zero,
            topRight: isFirst ? const Radius.circular(12) : Radius.zero,
            bottomLeft: isLast ? const Radius.circular(12) : Radius.zero,
            bottomRight: isLast ? const Radius.circular(12) : Radius.zero,
          ),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),
    );
  }
}