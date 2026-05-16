part of 'profile_screen.dart';

class ProfileFields extends StatelessWidget {
  const ProfileFields({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        CupertinoTextField(),
        SizedBox(height: 12),
        Text('Part files inherit imports from the library file'),
      ],
    );
  }
}
