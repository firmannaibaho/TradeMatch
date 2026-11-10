import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black87), title: const Text('Forgot Password', style: TextStyle(color: Colors.black87))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text('Enter your email and we\'ll send a password reset link.', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 18),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.isEmpty) ? 'Please enter your email' : null,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendReset,
                  child: _isSending ? const CircularProgressIndicator(color: Colors.white) : const Text('Send Reset Link'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendReset() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset sent (demo)')));
      Navigator.pop(context);
    });
  }
}
