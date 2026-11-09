import 'package:flutter/material.dart';

class ShellSection {
  const ShellSection({required this.label, required this.icon, required this.builder});

  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

/// Keng ekranda yon panel, telefonda menyu tugmasi (B: kompyuter, planshet, telefon).
class TegioShell extends StatefulWidget {
  const TegioShell({super.key, required this.title, required this.sections});

  static const double wideBreakpoint = 840;

  final String title;
  final List<ShellSection> sections;

  @override
  State<TegioShell> createState() => _TegioShellState();
}

class _TegioShellState extends State<TegioShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final section = widget.sections[_index];
    final wide = MediaQuery.sizeOf(context).width >= TegioShell.wideBreakpoint;
    final destinations = [
      for (final s in widget.sections) NavigationDrawerDestination(icon: Icon(s.icon), label: Text(s.label)),
    ];
    final drawer = NavigationDrawer(
      selectedIndex: _index,
      onDestinationSelected: (index) {
        setState(() => _index = index);
        if (!wide) Navigator.of(context).pop();
      },
      children: destinations,
    );
    final content = KeyedSubtree(key: ValueKey(_index), child: section.builder(context));

    return Scaffold(
      appBar: AppBar(title: Text(wide ? widget.title : section.label)),
      drawer: wide ? null : drawer,
      body: wide
          ? Row(
              children: [
                SizedBox(width: 280, child: drawer),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }
}

/// Hali qurilmagan bo'lim uchun.
class SectionPending extends StatelessWidget {
  const SectionPending({super.key, required this.requirements});

  final String requirements;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Bu bo\'lim hali qurilmagan. Talablar: $requirements', textAlign: TextAlign.center),
      ),
    );
  }
}
