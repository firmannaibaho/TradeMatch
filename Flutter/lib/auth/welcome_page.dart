import 'package:flutter/material.dart';
import 'package:trade_match/auth/auth_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Image.asset('assets/images/onboarding.png', height: 140, errorBuilder: (_, __, ___) => const Icon(Icons.swap_horiz, size: 120, color: Colors.grey)),
                    const SizedBox(height: 18),
                    Text('TradeMatch', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: primary)),
                    const SizedBox(height: 8),
                    const Text('Swap things you don\'t need for things you want. Safe, local, and social.', textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text('How it works', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _featureRow(Icons.photo, 'Post items with photos'),
              const SizedBox(height: 8),
              _featureRow(Icons.swap_horiz, 'Swipe to discover and match'),
              const SizedBox(height: 8),
              _featureRow(Icons.map, 'Pick a meetup spot and confirm trades'),
              const Spacer(),

              // Buttons
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // Open AuthPage on Register tab
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage(initialTabIndex: 1)));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primary),
                  child: const Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage(initialTabIndex: 0)));
                  },
                  child: const Text('Sign In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
