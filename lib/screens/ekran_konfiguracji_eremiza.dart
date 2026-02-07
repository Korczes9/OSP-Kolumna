import 'package:flutter/material.dart';
import '../services/eremiza_service.dart';

class EkranKonfiguracjiEremiza extends StatefulWidget {
  const EkranKonfiguracjiEremiza({super.key});

  @override
  State<EkranKonfiguracjiEremiza> createState() => _EkranKonfiguracjiEremizaState();
}

class _EkranKonfiguracjiEremizaState extends State<EkranKonfiguracjiEremiza> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _eremizaService = EremizaService();
  
  bool _isLoading = false;
  bool _autoSyncEnabled = false;
  DateTime? _lastSyncTime;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _eremizaService.loadCredentials();
    final lastSync = await _eremizaService.getLastSyncTime();
    
    setState(() {
      _autoSyncEnabled = _eremizaService.isConfigured();
      _lastSyncTime = lastSync;
    });
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _eremizaService.setCredentials(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      await _eremizaService.login();

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Połączenie z eRemiza OK!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() => _autoSyncEnabled = true);

    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Błąd: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _manualSync() async {
    if (!_eremizaService.isConfigured()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Najpierw skonfiguruj połączenie')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _eremizaService.syncAlarms();
      final lastSync = await _eremizaService.getLastSyncTime();

      setState(() => _lastSyncTime = lastSync);

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Synchronizacja zakończona!\n'
            'Dodano: ${result['added']}, Pominięto: ${result['skipped']}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Błąd synchronizacji: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleAutoSync(bool value) {
    if (value) {
      if (!_eremizaService.isConfigured()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Najpierw skonfiguruj połączenie')),
        );
        return;
      }
      _eremizaService.startAutoSync();
    } else {
      _eremizaService.stopAutoSync();
    }

    setState(() => _autoSyncEnabled = value);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wylogować z eRemiza?'),
        content: const Text('Automatyczna synchronizacja zostanie wyłączona.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wyloguj'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _eremizaService.logout();
      _emailController.clear();
      _passwordController.clear();
      
      setState(() {
        _autoSyncEnabled = false;
        _lastSyncTime = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Wylogowano z eRemiza')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integracja eRemiza'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Automatyczna synchronizacja',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Alarmy z eRemiza będą automatycznie dodawane do wyjazdów.\n'
                        '• Synchronizacja co 5 minut\n'
                        '• Tylko alarmy z SK KP\n'
                        '• Działa gdy aplikacja jest uruchomiona',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email eRemiza',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Podaj email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Hasło eRemiza',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Podaj hasło';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Test connection button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _testConnection,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: Text(_isLoading ? 'Łączę...' : 'Testuj połączenie'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 16),

              // Manual sync button
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _manualSync,
                icon: const Icon(Icons.sync),
                label: const Text('Synchronizuj teraz'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Auto-sync toggle
              SwitchListTile(
                title: const Text('Automatyczna synchronizacja'),
                subtitle: const Text('Synchronizuj alarmy co 5 minut'),
                value: _autoSyncEnabled,
                onChanged: _toggleAutoSync,
                activeThumbColor: Colors.green,
              ),

              if (_lastSyncTime != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Ostatnia synchronizacja'),
                    subtitle: Text(
                      '${_lastSyncTime!.day}.${_lastSyncTime!.month}.${_lastSyncTime!.year} '
                      '${_lastSyncTime!.hour}:${_lastSyncTime!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],

              if (_eremizaService.isConfigured()) ...[
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Wyloguj z eRemiza',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
