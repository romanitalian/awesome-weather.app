import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String units = 'metric';
  String lang = 'en';
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() { units = p.getString('units') ?? 'metric'; lang = p.getString('lang') ?? 'en'; _loading = false; });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('units', units);
    await p.setString('lang', lang);
    if (mounted) Navigator.of(context).pop({'units': units, 'lang': lang});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('settings.units'.tr()),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'metric', label: Text('units.metric')),
              ButtonSegment(value: 'imperial', label: Text('units.imperial')),
            ],
            selected: {units},
            onSelectionChanged: (s)=>setState(()=>units = s.first),
          ),
          const SizedBox(height: 16),
          Text('settings.language'.tr()),
          const SizedBox(height: 8),
          DropdownButton<String>(value: lang, items: const [
            DropdownMenuItem(value: 'en', child: Text('lang.en')),
            DropdownMenuItem(value: 'ru', child: Text('lang.ru')),
          ], onChanged: (v){ if (v!=null) setState(()=>lang=v); }),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: Text('refresh'.tr())),
        ],
      ),
    );
  }
}
