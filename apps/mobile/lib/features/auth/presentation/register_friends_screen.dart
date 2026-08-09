import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../onboarding/presentation/onboarding_common.dart';

/// Un ami fictif proposé dans la liste **placeholder** d'ajout d'amis.
class _FakeFriend {
  const _FakeFriend(this.name, this.handle, this.color);

  final String name;
  final String handle;
  final Color color;
}

/// Écran post-création **placeholder** : suggestion d'amis à ajouter. Liste
/// d'avatars fictifs avec cases à cocher bleues ; le CTA affiche le nombre
/// sélectionné (« AJOUTER N AMIS »). Aucune logique réelle — d'où le tag
/// « Bientôt ». Le CTA mène à l'écran de bienvenue.
class RegisterFriendsScreen extends StatefulWidget {
  const RegisterFriendsScreen({super.key});

  @override
  State<RegisterFriendsScreen> createState() => _RegisterFriendsScreenState();
}

class _RegisterFriendsScreenState extends State<RegisterFriendsScreen> {
  static const List<_FakeFriend> _friends = <_FakeFriend>[
    _FakeFriend('Léa Moreau', '@lea.azure', Color(0xFF6C5CE7)),
    _FakeFriend('Karim Bensaïd', '@karim.dev', Color(0xFF00B894)),
    _FakeFriend('Emma Rossi', '@emma.cloud', Color(0xFFE17055)),
    _FakeFriend('Thomas Girard', '@tom.aks', Color(0xFF0984E3)),
    _FakeFriend('Nadia Cherif', '@nadia.ai', Color(0xFFD63031)),
  ];

  final Set<int> _selected = <int>{};

  void _toggle(int index) {
    setState(() {
      if (!_selected.add(index)) _selected.remove(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final int count = _selected.length;
    final String label = count == 0 ? 'CONTINUER' : 'AJOUTER $count AMI${count > 1 ? 'S' : ''}';

    return OnboardingScaffold(
      progress: 0.85,
      primaryLabel: label,
      onPrimary: () => context.go('/register/profile-created'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Ajoute tes premiers amis'),
          const SizedBox(height: 12),
          const Align(alignment: Alignment.centerLeft, child: SoonTag()),
          const SizedBox(height: 20),
          for (int i = 0; i < _friends.length; i++) ...<Widget>[
            ChoiceTile(
              key: Key('register-friend-$i'),
              title: _friends[i].name,
              trailingLabel: _friends[i].handle,
              leading: _Avatar(friend: _friends[i]),
              selected: _selected.contains(i),
              onTap: () => _toggle(i),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Pastille d'avatar fictif : initiale sur fond coloré (aucune image réseau).
class _Avatar extends StatelessWidget {
  const _Avatar({required this.friend});

  final _FakeFriend friend;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: friend.color, shape: BoxShape.circle),
      child: Text(
        friend.name.characters.first,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
      ),
    );
  }
}
