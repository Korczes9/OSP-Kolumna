import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/serwis_polaczenia.dart';
import '../services/serwis_alarmu.dart';
import '../services/serwis_wozu.dart';

/// Widget pokazujący status połączenia i umożliwiający synchronizację
class StatusPoloczeniaWidget extends StatefulWidget {
  const StatusPoloczeniaWidget({super.key});

  @override
  State<StatusPoloczeniaWidget> createState() => _StatusPoloczeniaWidgetState();
}

class _StatusPoloczeniaWidgetState extends State<StatusPoloczeniaWidget> {
  bool _czyOnline = true;
  bool _synchronizujeS = false;

  @override
  void initState() {
    super.initState();
    _sprawdzPolaczenie();
    _sluchajZmianPolaczenia();
  }

  Future<void> _sprawdzPolaczenie() async {
    final online = await SerwisPolaczenia.czyOnline();
    if (mounted) {
      setState(() {
        _czyOnline = online;
      });
    }
  }

  void _sluchajZmianPolaczenia() {
    SerwisPolaczenia.monitorujPolaczenie().listen((wynik) async {
      final online = wynik.contains(ConnectivityResult.mobile) ||
          wynik.contains(ConnectivityResult.wifi) ||
          wynik.contains(ConnectivityResult.ethernet);
      
      if (mounted) {
        setState(() {
          _czyOnline = online;
        });
      }

      // Automatyczna synchronizacja po powrocie połączenia
      if (online && !_synchronizujeS) {
        await _synchronizuj();
      }
    });
  }

  Future<void> _synchronizuj() async {
    if (!_czyOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Brak połączenia internetowego'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _synchronizujeS = true;
    });

    try {
      await AlarmService.synchronizujOperacjeOffline();
      await SerwisWozu.synchronizujOperacjeOffline();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Synchronizacja zakończona'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd synchronizacji: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _synchronizujeS = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _czyOnline ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _czyOnline ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _czyOnline ? Icons.cloud_done : Icons.cloud_off,
            color: _czyOnline ? Colors.green : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            _czyOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: _czyOnline ? Colors.green.shade900 : Colors.orange.shade900,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          if (!_czyOnline || _synchronizujeS) ...[
            const SizedBox(width: 8),
            if (_synchronizujeS)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              InkWell(
                onTap: _synchronizuj,
                child: Icon(
                  Icons.sync,
                  color: Colors.orange.shade900,
                  size: 18,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
