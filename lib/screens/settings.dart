import 'package:flutter/material.dart';
import 'package:pinwall/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Sample values
  String _interval = "30m";
  bool _shuffle = true;
  String _applyTo = "Both";

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // Interval dropdown
          _buildCard(
            title: "Change Interval",
            child: DropdownButton<String>(
              value: _interval,
              isExpanded: true,
              underline: const SizedBox(),
              items: [
                "15m",
                "30m",
                "1h",
                "6h",
                "Daily",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) {
                setState(() => _interval = val!);
              },
            ),
          ),

          const SizedBox(height: 16),

          // Shuffle toggle
          _buildCard(
            title: "Shuffle Wallpaper",
            child: Switch(
              value: _shuffle,
              activeColor: AppColors.primary,
              onChanged: (val) {
                setState(() => _shuffle = val);
              },
            ),
          ),

          const SizedBox(height: 16),

          // Apply to
          _buildCard(
            title: "Apply To",
            child: DropdownButton<String>(
              value: _applyTo,
              isExpanded: true,
              underline: const SizedBox(),
              items: [
                "Home Screen",
                "Lock Screen",
                "Both",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) {
                setState(() => _applyTo = val!);
              },
            ),
          ),

          const SizedBox(height: 24),

          // Save Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Settings Saved ✅")));
            },
            child: const Text(
              "Save Settings",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.secondary,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
