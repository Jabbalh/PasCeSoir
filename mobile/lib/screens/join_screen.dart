import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../widgets/app_header.dart';

final _supabase = Supabase.instance.client;

enum _State { loading, ready, invalid, joining }

/// Rejoindre un journal par son lien de partage (`/rejoindre/<jeton>`)
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.token});

  final String token;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  var _state = _State.loading;
  String? _journalName;
  String? _childName;
  var _wasOnline = syncService.online;

  @override
  void initState() {
    super.initState();
    syncService.addListener(_onSync);
    _load();
  }

  void _onSync() {
    final online = syncService.online;
    if (online && !_wasOnline) _load();
    _wasOnline = online;
    setState(() {});
  }

  @override
  void dispose() {
    syncService.removeListener(_onSync);
    super.dispose();
  }

  Future<void> _load() async {
    if (!syncService.online) return;
    setState(() => _state = _State.loading);
    try {
      final rows = await _supabase.rpc('invitation_preview', params: {'p_token': widget.token}) as List<dynamic>;
      if (!mounted) return;
      if (rows.isEmpty) {
        setState(() => _state = _State.invalid);
        return;
      }
      final preview = rows.first as Map<String, dynamic>;
      setState(() {
        _journalName = preview['journal_name'] as String?;
        _childName = preview['child_name'] as String?;
        _state = _State.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _state = _State.invalid);
    }
  }

  Future<void> _join() async {
    setState(() => _state = _State.joining);
    try {
      final journalId = await _supabase.rpc('join_journal', params: {'p_token': widget.token}) as String;
      await syncService.sync();
      if (!mounted) return;
      showToast(context, 'Bienvenue dans le journal !');
      context.go('/journal/$journalId');
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Oups', description: errorMessage(e), error: true);
      setState(() => _state = _State.ready);
    }
  }

  Widget _empty(IconData icon, String title, String description, {Widget? action}) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(description, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      );

  @override
  Widget build(BuildContext context) {
    final child = !syncService.online
        ? _empty(Icons.wifi_off, 'Connexion requise', 'Connectez-vous à internet pour rejoindre ce journal.')
        : switch (_state) {
            _State.loading => const CircularProgressIndicator(),
            _State.invalid => _empty(
                Icons.link_off,
                'Lien invalide',
                "Ce lien d'invitation n'existe pas ou a été désactivé. Demandez-en un nouveau.",
                action: TextButton(onPressed: () => context.go('/'), child: const Text('Mes journaux')),
              ),
            _ => Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.primary),
                      const SizedBox(height: 12),
                      const Text('Vous êtes invité à rejoindre', style: TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 4),
                      Text(_journalName ?? '',
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      if (_childName?.isNotEmpty ?? false)
                        Text('le journal des nuits de $_childName',
                            style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _state == _State.joining ? null : _join,
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Rejoindre le journal'),
                      ),
                    ],
                  ),
                ),
              ),
          };

    return Scaffold(
      appBar: const AppHeader(),
      body: Center(child: Padding(padding: const EdgeInsets.all(16), child: child)),
    );
  }
}
