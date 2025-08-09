import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:app/shared/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();
  
  String _selectedUnits = SettingsService.unitsMetric;
  String _selectedLanguage = SettingsService.languageAuto;
  double _alertWind = 10.0;
  double _alertPrecip = 1.0;
  bool _notificationsEnabled = true;
  bool _cacheEnabled = true;
  int _cacheExpiry = 30;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settings.init();
    setState(() {
      _selectedUnits = _settings.units;
      _selectedLanguage = _settings.language;
      _alertWind = _settings.alertWindThreshold;
      _alertPrecip = _settings.alertPrecipThreshold;
      _notificationsEnabled = _settings.notificationsEnabled;
      _cacheEnabled = _settings.cacheEnabled;
      _cacheExpiry = _settings.cacheExpiryMinutes;
    });
  }

  Future<void> _saveSettings() async {
    await _settings.setUnits(_selectedUnits);
    await _settings.setLanguage(_selectedLanguage);
    await _settings.setAlertThresholds(_alertWind, _alertPrecip);
    await _settings.setNotificationsEnabled(_notificationsEnabled);
    await _settings.setCacheSettings(_cacheEnabled, _cacheExpiry);
    
    // Apply language change
    if (_selectedLanguage != SettingsService.languageAuto) {
      final locale = _selectedLanguage == SettingsService.languageRussian 
          ? const Locale('ru', 'RU') 
          : const Locale('en', 'US');
      await context.setLocale(locale);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.saved'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'settings.save'.tr(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.language'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    decoration: InputDecoration(
                      labelText: 'settings.language'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: SettingsService.languageAuto,
                        child: Text('settings.auto'.tr()),
                      ),
                      DropdownMenuItem(
                        value: SettingsService.languageEnglish,
                        child: Text('settings.english'.tr()),
                      ),
                      DropdownMenuItem(
                        value: SettingsService.languageRussian,
                        child: Text('settings.russian'.tr()),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedLanguage = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Units Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.units'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: SettingsService.unitsMetric,
                        label: Text('units.metric'.tr()),
                      ),
                      ButtonSegment(
                        value: SettingsService.unitsImperial,
                        label: Text('units.imperial'.tr()),
                      ),
                    ],
                    selected: {_selectedUnits},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() => _selectedUnits = selection.first);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedUnits == SettingsService.unitsMetric
                        ? '${'units.celsius'.tr()}, ${'units.ms'.tr()}, ${'units.mm'.tr()}, ${'units.hpa'.tr()}'
                        : '${'units.fahrenheit'.tr()}, ${'units.mph'.tr()}, ${'units.inches'.tr()}, ${'units.inhg'.tr()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Default Location
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.location'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(_settings.defaultLocationName),
                    subtitle: Text('${_settings.defaultLatitude.toStringAsFixed(4)}, ${_settings.defaultLongitude.toStringAsFixed(4)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showLocationDialog(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Alert Thresholds
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'alerts.thresholds'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('alerts.wind_threshold'.tr()),
                      Expanded(
                        child: Slider(
                          min: 0,
                          max: 30,
                          divisions: 30,
                          value: _alertWind,
                          label: _alertWind.toStringAsFixed(0),
                          onChanged: (value) {
                            setState(() => _alertWind = value);
                          },
                        ),
                      ),
                      Text(_alertWind.toStringAsFixed(0)),
                    ],
                  ),
                  Row(
                    children: [
                      Text('alerts.precip_threshold'.tr()),
                      Expanded(
                        child: Slider(
                          min: 0,
                          max: 10,
                          divisions: 20,
                          value: _alertPrecip,
                          label: _alertPrecip.toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() => _alertPrecip = value);
                          },
                        ),
                      ),
                      Text(_alertPrecip.toStringAsFixed(1)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Notifications
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.notifications'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text('settings.notifications'.tr()),
                    subtitle: Text('settings.notifications_desc'.tr()),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() => _notificationsEnabled = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Cache Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.cache'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text('settings.cache_enabled'.tr()),
                    subtitle: Text('settings.cache_desc'.tr()),
                    value: _cacheEnabled,
                    onChanged: (value) {
                      setState(() => _cacheEnabled = value);
                    },
                  ),
                  if (_cacheEnabled) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('settings.cache_expiry'.tr()),
                        Expanded(
                          child: Slider(
                            min: 5,
                            max: 120,
                            divisions: 23,
                            value: _cacheExpiry.toDouble(),
                            label: '$_cacheExpiry min',
                            onChanged: (value) {
                              setState(() => _cacheExpiry = value.toInt());
                            },
                          ),
                        ),
                        Text('$_cacheExpiry min'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // About
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.about'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: Text('settings.version'.tr()),
                    subtitle: const Text('1.0.0'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.code),
                    title: const Text('GitHub'),
                    subtitle: const Text('github.com/romanitalian/awesome-weather.app'),
                    onTap: () {
                      // TODO: Open GitHub URL
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationDialog() {
    final latController = TextEditingController(
      text: _settings.defaultLatitude.toStringAsFixed(4),
    );
    final lonController = TextEditingController(
      text: _settings.defaultLongitude.toStringAsFixed(4),
    );
    final nameController = TextEditingController(
      text: _settings.defaultLocationName,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.location'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'location.name'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: latController,
                    decoration: InputDecoration(
                      labelText: 'location.latitude'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: lonController,
                    decoration: InputDecoration(
                      labelText: 'location.longitude'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('app.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final lat = double.tryParse(latController.text) ?? _settings.defaultLatitude;
              final lon = double.tryParse(lonController.text) ?? _settings.defaultLongitude;
              final name = nameController.text.isNotEmpty ? nameController.text : _settings.defaultLocationName;
              
              await _settings.setDefaultLocation(lat, lon, name);
              Navigator.of(context).pop();
              _loadSettings();
            },
            child: Text('app.save'.tr()),
          ),
        ],
      ),
    );
  }
}

