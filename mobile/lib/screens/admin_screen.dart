import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../main.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../utils/night.dart';
import '../utils/token.dart';
import '../widgets/app_header.dart';
import '../widgets/section_card.dart';

final _supabase = Supabase.instance.client;

/// Invitation à utiliser l'application (table `app_invites`)
class _AppInvite {
  _AppInvite(Map<String, dynamic> m)
      : id = m['id'] as String,
        token = m['token'] as String,
        note = m['note'] as String? ?? '',
        createdAt = DateTime.parse(m['created_at'] as String),
        expiresAt = DateTime.parse(m['expires_at'] as String),
        revoked = m['revoked_at'] != null,
        used = m['used_at'] != null,
        usedBy = (m['used_by_profile'] as Map<String, dynamic>?)?['display_name'] as String?;

  final String id;
  final String token;
  final String note;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool revoked;
  final bool used;
  final String? usedBy;

  ({String label, Color color, bool active}) get status {
    if (used) return (label: 'Utilisée par ${usedBy ?? 'un compte supprimé'}', color: AppColors.success, active: false);
    if (revoked) return (label: 'Révoquée', color: AppColors.muted, active: false);
    if (!expiresAt.isAfter(DateTime.now())) return (label: 'Expirée', color: AppColors.muted, active: false);
    return (label: "Active jusqu'au ${formatDateTime(expiresAt)}", color: AppColors.primary, active: true);
  }
}

/// Administration : invitations à créer un compte
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const _durations = [(label: '24 heures', days: 1), (label: '7 jours', days: 7), (label: '30 jours', days: 30)];

  var _invites = <_AppInvite>[];
  var _loading = true;
  final _note = TextEditingController();
  var _days = 7;
  var _creating = false;
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
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!syncService.online) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await _supabase
          .from('app_invites')
          .select(
              'id, token, note, created_at, expires_at, revoked_at, used_at, used_by_profile:profiles!app_invites_used_by_fkey(display_name)')
          .order('created_at', ascending: false);
      if (mounted) setState(() => _invites = rows.map(_AppInvite.new).toList());
    } catch (e) {
      if (mounted) showToast(context, 'Oups', description: errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final expires = DateTime.now().add(Duration(days: _days)).toUtc().toIso8601String();
      final row = await _supabase
          .from('app_invites')
          .insert({'token': randomToken(), 'note': _note.text.trim(), 'created_by': auth.user!.id, 'expires_at': expires})
          .select('token')
          .single();
      _note.clear();
      await _load();
      await _share(row['token'] as String);
    } catch (e) {
      if (mounted) showToast(context, 'Oups', description: errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _share(String token) =>
      shareLink('$webBaseUrl/inscription/$token', "Je t'invite à utiliser Pas ce soir, le journal des réveils de nos enfants");

  Future<void> _revoke(_AppInvite invite) async {
    try {
      await _supabase
          .from('app_invites')
          .update({'revoked_at': DateTime.now().toUtc().toIso8601String()}).eq('id', invite.id);
      if (mounted) showToast(context, 'Invitation révoquée');
      await _load();
    } catch (e) {
      if (mounted) showToast(context, 'Oups', description: errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = syncService.online;
    return Scaffold(
      appBar: const AppHeader(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text('Administration', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text(
            "Invitez quelqu'un à utiliser l'application. Il pourra créer son compte puis son propre journal.",
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (!online) ...[
            const InfoBanner(icon: Icons.wifi_off, title: 'Connexion internet requise'),
            const SizedBox(height: 16),
          ],
          SectionCard(
            title: 'Nouvelle invitation',
            subtitle: "Lien à usage unique : il ne sert qu'à créer un seul compte.",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'Pour qui ?',
                    hintText: 'ex. Julie (cousine)',
                    helperText: 'Note pour vous seul',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Validité', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in _durations)
                      ChoiceChip(
                        label: Text(d.label),
                        selected: _days == d.days,
                        onSelected: (_) => setState(() => _days = d.days),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: !online || _creating ? null : _create,
                  icon: const Icon(Icons.send),
                  label: const Text('Créer et partager le lien'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Invitations',
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _invites.isEmpty
                    ? const Text('Aucune invitation pour le moment.', style: TextStyle(fontSize: 14, color: AppColors.muted))
                    : Column(
                        children: [
                          for (final i in _invites)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(i.note.isNotEmpty ? i.note : 'Sans note', overflow: TextOverflow.ellipsis),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Créée le ${formatDateTime(i.createdAt)}', style: const TextStyle(fontSize: 12)),
                                  Text(i.status.label, style: TextStyle(fontSize: 12, color: i.status.color)),
                                ],
                              ),
                              trailing: i.status.active
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                            icon: const Icon(Icons.share), tooltip: 'Partager', onPressed: () => _share(i.token)),
                                        IconButton(
                                          icon: const Icon(Icons.link_off, color: AppColors.error),
                                          tooltip: 'Révoquer',
                                          onPressed: () => _revoke(i),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
