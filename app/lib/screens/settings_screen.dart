import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();

  // Custom threshold sliders
  late double _mq135Warning;
  late double _mq135Spoiled;
  late double _mq3Warning;
  late double _mq3Spoiled;
  late double _mq9Warning;
  late double _mq9Spoiled;
  bool _customEnabled = false;

  @override
  void initState() {
    super.initState();
    final t = _settings.customThresholds;
    _customEnabled = t != null;
    _mq135Warning = t?['mq135_warning'] ?? 4.0;
    _mq135Spoiled = t?['mq135_spoiled'] ?? 10.0;
    _mq3Warning = t?['mq3_warning'] ?? 0.5;
    _mq3Spoiled = t?['mq3_spoiled'] ?? 2.0;
    _mq9Warning = t?['mq9_warning'] ?? 1.5;
    _mq9Spoiled = t?['mq9_spoiled'] ?? 5.0;
  }

  void _saveThresholds() {
    if (_customEnabled) {
      _settings.setCustomThresholds({
        'mq135_warning': _mq135Warning,
        'mq135_spoiled': _mq135Spoiled,
        'mq3_warning': _mq3Warning,
        'mq3_spoiled': _mq3Spoiled,
        'mq9_warning': _mq9Warning,
        'mq9_spoiled': _mq9Spoiled,
      });
    } else {
      _settings.setCustomThresholds(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ===== Appearance =====
          _sectionTitle('Appearance'),
          SwitchListTile(
            title: const Text('Dark mode'),
            subtitle: const Text('Toggle dark/light theme'),
            value: _settings.isDarkMode.value,
            onChanged: (v) {
              _settings.setDarkMode(v);
              setState(() {});
            },
          ),

          const Divider(),

          // ===== Notifications =====
          _sectionTitle('Notifications'),
          SwitchListTile(
            title: const Text('Enable alerts'),
            subtitle: const Text('Get notified when spoilage is detected'),
            value: _settings.notificationsEnabled,
            onChanged: (v) {
              _settings.setNotifications(v);
              setState(() {});
            },
          ),
          ListTile(
            title: const Text('Mute alerts'),
            subtitle: Text(_settings.alertsMuted
                ? 'Muted until ${TimeOfDay.fromDateTime(_settings.alertsMutedUntil!).format(context)}'
                : 'Not muted'),
            trailing: _settings.alertsMuted
                ? TextButton(
                    onPressed: () {
                      _settings.unmuteAlerts();
                      setState(() {});
                    },
                    child: const Text('Unmute'),
                  )
                : null,
            onTap: _settings.alertsMuted ? null : () => _showMuteOptions(),
          ),

          const Divider(),

          // ===== Device =====
          _sectionTitle('Device'),
          ListTile(
            title: const Text('Power bank capacity'),
            subtitle: Text('${_settings.powerBankCapacity} mAh'),
            onTap: () => _showCapacityPicker(),
          ),

          const Divider(),

          // ===== Environment =====
          _sectionTitle('Environment'),
          ListTile(
            title: const Text('Preset'),
            subtitle: Text(
              _settings.idealTempMax <= 10 ? 'Fridge (2-8°C, 30-50% RH)' : 'Room (18-24°C, 40-60% RH)',
            ),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fridge', label: Text('Fridge')),
                ButtonSegment(value: 'room', label: Text('Room')),
              ],
              selected: {_settings.idealTempMax <= 10 ? 'fridge' : 'room'},
              onSelectionChanged: (v) {
                setState(() {
                  if (v.first == 'fridge') {
                    _settings.applyFridgePreset();
                  } else {
                    _settings.applyRoomPreset();
                  }
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          _rangeSlider(
            'Temperature range',
            '${_settings.idealTempMin.toStringAsFixed(0)}°C - ${_settings.idealTempMax.toStringAsFixed(0)}°C',
            _settings.idealTempMin,
            _settings.idealTempMax,
            -5, 35,
            (min, max) {
              setState(() => _settings.setIdealTemp(min, max));
            },
          ),
          _rangeSlider(
            'Humidity range',
            '${_settings.idealHumidityMin.toStringAsFixed(0)}% - ${_settings.idealHumidityMax.toStringAsFixed(0)}%',
            _settings.idealHumidityMin,
            _settings.idealHumidityMax,
            0, 100,
            (min, max) {
              setState(() => _settings.setIdealHumidity(min, max));
            },
          ),

          const Divider(),

          // ===== Custom Thresholds =====
          _sectionTitle('Custom Alert Thresholds'),
          SwitchListTile(
            title: const Text('Use custom thresholds'),
            subtitle: const Text('Override calibration-based thresholds'),
            value: _customEnabled,
            onChanged: (v) {
              setState(() => _customEnabled = v);
              _saveThresholds();
            },
          ),
          if (_customEnabled) ...[
            _thresholdSlider('MQ-135 Warning', _mq135Warning, 0.5, 20.0,
                (v) => setState(() { _mq135Warning = v; _saveThresholds(); })),
            _thresholdSlider('MQ-135 Spoiled', _mq135Spoiled, 1.0, 40.0,
                (v) => setState(() { _mq135Spoiled = v; _saveThresholds(); })),
            const SizedBox(height: 8),
            _thresholdSlider('MQ-3 Warning', _mq3Warning, 0.1, 5.0,
                (v) => setState(() { _mq3Warning = v; _saveThresholds(); })),
            _thresholdSlider('MQ-3 Spoiled', _mq3Spoiled, 0.2, 10.0,
                (v) => setState(() { _mq3Spoiled = v; _saveThresholds(); })),
            const SizedBox(height: 8),
            _thresholdSlider('MQ-9 Warning', _mq9Warning, 0.2, 10.0,
                (v) => setState(() { _mq9Warning = v; _saveThresholds(); })),
            _thresholdSlider('MQ-9 Spoiled', _mq9Spoiled, 0.5, 20.0,
                (v) => setState(() { _mq9Spoiled = v; _saveThresholds(); })),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _mq135Warning = 4.0; _mq135Spoiled = 10.0;
                    _mq3Warning = 0.5; _mq3Spoiled = 2.0;
                    _mq9Warning = 1.5; _mq9Spoiled = 5.0;
                  });
                  _saveThresholds();
                },
                child: const Text('Reset to defaults'),
              ),
            ),
          ],

          const Divider(),

          // ===== About =====
          _sectionTitle('About'),
          ListTile(
            title: const Text('Show onboarding'),
            subtitle: const Text('View the intro tutorial again'),
            leading: const Icon(Icons.help_outline),
            onTap: () {
              _settings.setOnboardingCompleted(false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restart the app to see the onboarding')),
              );
            },
          ),
          const ListTile(
            title: Text('Version'),
            subtitle: Text('1.0.0'),
            leading: Icon(Icons.info_outline),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _thresholdSlider(
      String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 13)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min) * 10).round(),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text('${value.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _rangeSlider(String label, String valueText, double curMin, double curMax,
      double absMin, double absMax, void Function(double, double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 13)),
              ),
              Text(valueText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          RangeSlider(
            values: RangeValues(curMin.clamp(absMin, absMax), curMax.clamp(absMin, absMax)),
            min: absMin,
            max: absMax,
            divisions: (absMax - absMin).round(),
            onChanged: (v) => onChanged(v.start.roundToDouble(), v.end.roundToDouble()),
          ),
        ],
      ),
    );
  }

  void _showMuteOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Mute alerts for...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              title: const Text('1 hour'),
              onTap: () { _mute(const Duration(hours: 1)); },
            ),
            ListTile(
              title: const Text('4 hours'),
              onTap: () { _mute(const Duration(hours: 4)); },
            ),
            ListTile(
              title: const Text('8 hours'),
              onTap: () { _mute(const Duration(hours: 8)); },
            ),
            ListTile(
              title: const Text('24 hours'),
              onTap: () { _mute(const Duration(hours: 24)); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _mute(Duration d) {
    _settings.muteAlerts(d);
    Navigator.pop(context);
    setState(() {});
  }

  void _showCapacityPicker() {
    final capacities = [5000, 10000, 15000, 20000, 30000];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Power bank capacity',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...capacities.map((c) => ListTile(
                  title: Text('$c mAh'),
                  trailing: c == _settings.powerBankCapacity
                      ? const Icon(Icons.check, color: Color(0xFF42A5F5))
                      : null,
                  onTap: () {
                    _settings.setPowerBankCapacity(c);
                    Navigator.pop(context);
                    setState(() {});
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
