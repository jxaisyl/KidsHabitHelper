import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers/child_provider.dart';

const _avatarOptions = [
  '👦', '👧', '🧒', '👶', '👦🏽', '👧🏽', '🐱', '🐶', '🦊', '⭐'
];

class ChildFormPage extends ConsumerStatefulWidget {
  final ChildrenData? child;

  const ChildFormPage({super.key, this.child});

  @override
  ConsumerState<ChildFormPage> createState() => _ChildFormPageState();
}

class _ChildFormPageState extends ConsumerState<ChildFormPage> {
  late final _nameController =
      TextEditingController(text: widget.child?.name);
  late String _selectedAvatar = widget.child?.avatar ?? '👦';
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.child != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑小孩' : '添加小孩'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '姓名',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入姓名' : null,
            ),
            const SizedBox(height: 24),
            Text('选择头像',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _avatarOptions.map((avatar) {
                final selected = avatar == _selectedAvatar;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAvatar = avatar),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? Colors.teal
                            : Colors.grey.shade300,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(avatar,
                          style: const TextStyle(fontSize: 28)),
                    ),
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
    final repo = ref.read(childRepositoryProvider);
    if (widget.child != null) {
      await repo.update(ChildrenData(
        id: widget.child!.id,
        name: _nameController.text.trim(),
        avatar: _selectedAvatar,
        createdAt: widget.child!.createdAt,
      ));
    } else {
      await repo.add(_nameController.text.trim(), _selectedAvatar);
    }
    if (mounted) Navigator.of(context).pop();
  }
}
