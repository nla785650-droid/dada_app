import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/provider_application_model.dart';
import '../providers/become_provider_provider.dart';
import '../widgets/portfolio_picker.dart';

/// Step 2：根据类型显示动态表单
class Step2DynamicForm extends ConsumerStatefulWidget {
  const Step2DynamicForm({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  ConsumerState<Step2DynamicForm> createState() => _Step2DynamicFormState();
}

class _Step2DynamicFormState extends ConsumerState<Step2DynamicForm> {
  final _priceCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _introCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _gearCtrl = TextEditingController();
  final _scopeCtrl = TextEditingController();
  final _charCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    for (final c in [
      _priceCtrl, _regionCtrl, _introCtrl, _heightCtrl,
      _gearCtrl, _scopeCtrl, _charCtrl,
    ]) {
      c.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(becomeProviderProvider);
    final notifier = ref.read(becomeProviderProvider.notifier);
    final type = state.selectedType ?? ProviderType.cosCommission;
    final errors = state.validationErrors;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 类型标题
                _TypeHeader(type: type),
                const SizedBox(height: 20),

                // ── 通用字段 ──
                _SectionLabel('基本信息'),
                const SizedBox(height: 12),
                _FormField(
                  label: '所在地区',
                  hint: '如：北京 朝阳区',
                  controller: _regionCtrl,
                  errorText: errors['region'],
                  prefixIcon: Icons.location_on_rounded,
                  onChanged: notifier.setRegion,
                ),
                const SizedBox(height: 12),
                _FormField(
                  label: '基础定价（元/时）',
                  hint: '如：120',
                  controller: _priceCtrl,
                  errorText: errors['price'],
                  prefixIcon: Icons.monetization_on_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: notifier.setPrice,
                  suffix: const Text('元/时',
                      style: TextStyle(
                          color: AppTheme.onSurfaceVariant, fontSize: 13)),
                ),
                const SizedBox(height: 12),
                _MultilineField(
                  label: '自我介绍',
                  hint: '介绍一下你的特长、风格和服务理念（至少10字）',
                  controller: _introCtrl,
                  errorText: errors['selfIntro'],
                  onChanged: notifier.setSelfIntro,
                  maxLength: 200,
                ),

                const SizedBox(height: 24),

                // ── 类型专属字段 ──
                _SectionLabel(switch (type) {
                  ProviderType.cosCommission => 'Cos 专属信息',
                  ProviderType.photography => '摄影专属信息',
                  ProviderType.companion => '陪玩专属信息',
                }),
                const SizedBox(height: 12),

                if (type == ProviderType.cosCommission)
                  _CosFields(
                    heightCtrl: _heightCtrl,
                    charCtrl: _charCtrl,
                    state: state,
                    notifier: notifier,
                    errors: errors,
                  ),

                if (type == ProviderType.photography)
                  _PhotographyFields(
                    gearCtrl: _gearCtrl,
                    state: state,
                    notifier: notifier,
                    errors: errors,
                  ),

                if (type == ProviderType.companion)
                  _CompanionFields(
                    scopeCtrl: _scopeCtrl,
                    state: state,
                    notifier: notifier,
                    errors: errors,
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // ── 底部按钮 ──
        _BottomButtons(onBack: widget.onBack, onNext: widget.onNext),
      ],
    );
  }
}

// ──────────────────────────────────────────
// Cos 委托专属字段
// ──────────────────────────────────────────

class _CosFields extends StatelessWidget {
  const _CosFields({
    required this.heightCtrl,
    required this.charCtrl,
    required this.state,
    required this.notifier,
    required this.errors,
  });

  final TextEditingController heightCtrl;
  final TextEditingController charCtrl;
  final BecomeProviderState state;
  final BecomeProviderNotifier notifier;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormField(
          label: '身高（cm）',
          hint: '如：165',
          controller: heightCtrl,
          errorText: errors['height'],
          prefixIcon: Icons.height_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: notifier.setHeightCm,
        ),
        const SizedBox(height: 16),

        // 擅长角色 Chip 输入
        const Text(
          '擅长角色',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface),
        ),
        const SizedBox(height: 8),
        _CharacterInput(
          ctrl: charCtrl,
          characters: state.skilledCharacters,
          onAdd: notifier.addSkilledCharacter,
          onRemove: notifier.removeSkilledCharacter,
        ),
        const SizedBox(height: 20),

        PortfolioPicker(
          label: '近期 Cos 照',
          files: state.cosPhotoFiles,
          onAdd: notifier.addCosPhotos,
          onRemove: notifier.removeCosPhoto,
          maxCount: 6,
          minCount: 1,
          hint: '展示你的最佳 Cos 状态',
          errorText: errors['cosPhotos'],
        ),
        const SizedBox(height: 20),

        PortfolioPicker(
          label: '生活照',
          files: state.lifePhotoFiles,
          onAdd: notifier.addLifePhotos,
          onRemove: notifier.removeLifePhoto,
          maxCount: 4,
          minCount: 1,
          hint: '真实生活状态照片，增加买家信任',
          errorText: errors['lifePhotos'],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────
// 摄影陪拍专属字段
// ──────────────────────────────────────────

class _PhotographyFields extends StatelessWidget {
  const _PhotographyFields({
    required this.gearCtrl,
    required this.state,
    required this.notifier,
    required this.errors,
  });

  final TextEditingController gearCtrl;
  final BecomeProviderState state;
  final BecomeProviderNotifier notifier;
  final Map<String, String> errors;

  static const _styleTags = [
    '日系清新', '暗黑哥特', '韩系氛围', '复古胶片', '户外生态',
    '棚拍写真', '汉服古风', '街头纪实', '星空长曝', 'ins 风',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormField(
          label: '主力设备型号',
          hint: '如：Sony A7M4 + 85mm F1.4',
          controller: gearCtrl,
          errorText: errors['gear'],
          prefixIcon: Icons.camera_alt_rounded,
          onChanged: notifier.setCameraGear,
        ),
        const SizedBox(height: 20),

        TagSelector(
          label: '擅长风格标签（可多选）',
          allTags: _styleTags,
          selectedTags: state.styleTags,
          onToggle: notifier.toggleStyleTag,
        ),
        const SizedBox(height: 20),

        PortfolioPicker(
          label: '作品集',
          files: state.portfolioFiles,
          onAdd: notifier.addPortfolioFiles,
          onRemove: notifier.removePortfolioFile,
          maxCount: 18,
          minCount: 6,
          hint: '至少上传 6 张代表作品，展示真实水准',
          errorText: errors['portfolio'],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────
// 社交陪玩专属字段
// ──────────────────────────────────────────

class _CompanionFields extends StatelessWidget {
  const _CompanionFields({
    required this.scopeCtrl,
    required this.state,
    required this.notifier,
    required this.errors,
  });

  final TextEditingController scopeCtrl;
  final BecomeProviderState state;
  final BecomeProviderNotifier notifier;
  final Map<String, String> errors;

  static const _personalTags = [
    '开朗活泼', '文静知性', '二次元资深', '游戏达人', '漫展常客',
    '电影迷', '美食探店', '宅家舒适', '户外冒险', '音乐爱好',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TagSelector(
          label: '个人标签（可多选）',
          allTags: _personalTags,
          selectedTags: state.personalTags,
          onToggle: notifier.togglePersonalTag,
          errorText: errors['tags'],
        ),
        const SizedBox(height: 20),

        _MultilineField(
          label: '服务范围',
          hint: '描述你可以提供的场景和活动类型\n如：漫展同行、游戏陪玩、观影陪同等',
          controller: scopeCtrl,
          errorText: errors['scope'],
          onChanged: notifier.setServiceScope,
          maxLength: 150,
        ),
        const SizedBox(height: 16),

        // 提示：建议完成真身认证
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.15), width: 1),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_rounded, size: 18, color: AppTheme.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '建议同时完成「真身认证」，提升买家信任度并优先展示',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.primary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────
// 角色 Chip 输入
// ──────────────────────────────────────────

class _CharacterInput extends StatelessWidget {
  const _CharacterInput({
    required this.ctrl,
    required this.characters,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController ctrl;
  final List<String> characters;
  final void Function(String) onAdd;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: '输入角色名后按回车添加',
                  hintStyle: const TextStyle(
                      color: AppTheme.onSurfaceVariant, fontSize: 14),
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                onSubmitted: (v) {
                  onAdd(v);
                  ctrl.clear();
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                onAdd(ctrl.text);
                ctrl.clear();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('添加'),
            ),
          ],
        ),
        if (characters.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              characters.length,
              (i) => Chip(
                label: Text(characters[i]),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => onRemove(i),
                backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                side: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.2), width: 1),
                labelStyle: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500),
                deleteIconColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ──────────────────────────────────────────
// 通用表单组件
// ──────────────────────────────────────────

class _TypeHeader extends StatelessWidget {
  const _TypeHeader({required this.type});

  final ProviderType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(type.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(
            '${type.label} · 入驻资料',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.errorText,
    this.prefixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.suffix,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final void Function(String) onChanged;
  final String? errorText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: AppTheme.onSurfaceVariant, fontSize: 14),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20, color: AppTheme.onSurfaceVariant)
                : null,
            suffix: suffix,
            errorText: errorText,
            errorStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _MultilineField extends StatelessWidget {
  const _MultilineField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.errorText,
    this.maxLength = 200,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final void Function(String) onChanged;
  final String? errorText;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 4,
          maxLength: maxLength,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: AppTheme.onSurfaceVariant, fontSize: 14),
            errorText: errorText,
            errorStyle: const TextStyle(fontSize: 12),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _BottomButtons extends StatelessWidget {
  const _BottomButtons({required this.onBack, required this.onNext});

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppTheme.glassBg,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.onSurfaceVariant,
              side: const BorderSide(color: AppTheme.divider, width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('上一步'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('下一步',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
