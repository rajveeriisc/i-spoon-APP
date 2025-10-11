import 'package:flutter/material.dart';
import 'package:smartspoon/features/profile/widgets/profile_section_card.dart';

class FaqSectionCard extends StatelessWidget {
  const FaqSectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    const faqs = <_Faq>[
      _Faq(
        'How do I pair my iSpoon?',
        'Go to Add Device on Home → enable Bluetooth & Location → select your spoon in the list.',
      ),
      _Faq(
        'What temperatures are considered safe?',
        'Food below 50°C is safe. You will see alerts above this; wait until the gauge returns to green.',
      ),
      _Faq(
        'Why is the app asking for permissions?',
        'Bluetooth and Location are required by the OS for BLE scanning. Photos access is only used for your avatar.',
      ),
      _Faq(
        'How is my data used?',
        'Only your meal insights are stored. You can delete your account/data from Settings → Privacy.',
      ),
    ];

    return ProfileSectionCard(
      title: 'FAQ',
      children: faqs.map((f) => _FaqTile(question: f.q, answer: f.a)).toList(),
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 0.0),
        initiallyExpanded: false,
        onExpansionChanged: (v) => setState(() => _expanded = v),
        title: Row(
          children: [
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.question,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 32.0, right: 4.0, bottom: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.answer,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Faq {
  final String q;
  final String a;
  const _Faq(this.q, this.a);
}
