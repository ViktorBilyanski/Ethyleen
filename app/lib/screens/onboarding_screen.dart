import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = const [
    _PageData(
      icon: Icons.eco,
      color: Color(0xFF66BB6A),
      title: 'Welcome to Ethyleen',
      subtitle:
          'A smart food freshness monitor that detects spoilage gases in your fridge before food goes bad.',
    ),
    _PageData(
      icon: Icons.sensors,
      color: Color(0xFF42A5F5),
      title: 'Three Gas Sensors',
      subtitle:
          'MQ-135 detects ammonia from meat and dairy.\n'
          'MQ-3 detects ethanol from fruits and bread.\n'
          'MQ-9 detects methane from sealed food decay.',
    ),
    _PageData(
      icon: Icons.kitchen,
      color: Color(0xFFFFA726),
      title: 'Set It Up',
      subtitle:
          'Place the device in your fridge, connect to WiFi, and calibrate using the tune icon in the app. '
          'Calibrate with only fresh food inside for the best baseline.',
    ),
    _PageData(
      icon: Icons.notifications_active,
      color: Color(0xFFE53935),
      title: 'Stay Notified',
      subtitle:
          'You\'ll get alerts when spoilage is detected. '
          'Customize thresholds and mute alerts in Settings. '
          'Check the History tab to see trends over time.',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      SettingsService().setOnboardingCompleted(true);
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121220),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () {
                  SettingsService().setOnboardingCompleted(true);
                  widget.onComplete();
                },
                child: Text(
                  _page < _pages.length - 1 ? 'Skip' : '',
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _buildPage(_pages[i]),
              ),
            ),

            // Dots
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF42A5F5)
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Next / Get Started button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _page < _pages.length - 1 ? 'Next' : 'Get Started',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_PageData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 56, color: data.color),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageData {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _PageData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}
