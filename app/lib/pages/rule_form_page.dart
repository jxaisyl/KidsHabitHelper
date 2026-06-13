import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers/rule_provider.dart';

const _iconOptions = [
  '✅', '🧹', '📖', '📱', '💯', '🎹', '🏃', '🎨', '⭐', '💤', '🎮', '🍽️'
];

class RuleFormPage extends ConsumerStatefulWidget {
  final Rule? rule;

  const RuleFormPage({super.key, this.rule});

  @override
  ConsumerState<RuleFormPage> createState() => _RuleFormPageState();
}

class _RuleFormPageState extends ConsumerState<RuleFormPage> {
  late final _nameController =
      TextEditingController(text: widget.rule?.name);
  late final _minutesController = TextEditingController(
    text: widget.rule != null
        ? widget.rule!.minutesChange.abs().toString()
        : '',
  );
  late bool _isNegative =
      widget.rule?.minutesChange != null && widget.rule!.minutesChange < 0;
  late String _selectedIcon = widget.rule?.icon ?? '✅';
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.rule != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '编辑规则' : '添加规则')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '规则名称',
                border: OutlineInputBorder(),
                hintText: '如：做家务、阅读、超时使用',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入名称' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minutesController,
                    decoration: const InputDecoration(
                      labelText: '分钟数',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请输入分钟数';
                      if (int.tryParse(v) == null) return '请输入有效数字';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('+增加')),
                    ButtonSegment(value: true, label: Text('-扣减')),
                  ],
                  selected: {_isNegative},
                  onSelectionChanged: (v) =>
                      setState(() => _isNegative = v.first),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('选择图标',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _iconOptions.map((icon) {
                final selected = icon == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? Colors.teal
                            : Colors.grey.shade300,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: Center(
                        child:
                            Text(icon, style: const TextStyle(fontSize: 24))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final minutes = int.parse(_minutesController.text);
    final actualMinutes = _isNegative ? -minutes : minutes;
    final repo = ref.read(ruleRepositoryProvider);

    if (widget.rule != null) {
      await repo.update(Rule(
        id: widget.rule!.id,
        name: _nameController.text.trim(),
        minutesChange: actualMinutes,
        icon: _selectedIcon,
      ));
    } else {
      await repo.add(
          _nameController.text.trim(), actualMinutes, _selectedIcon);
    }
    if (mounted) Navigator.of(context).pop();
  }
}
