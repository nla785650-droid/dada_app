import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/become_provider_provider.dart';

/// Step 3：协议确认 + 提交
class Step3Agreement extends ConsumerWidget {
  const Step3Agreement({
    super.key,
    required this.userId,
    required this.onBack,
  });

  final String userId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(becomeProviderProvider);
    final notifier = ref.read(becomeProviderProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                const Text(
                  '最后一步',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '请仔细阅读并同意以下条款',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // ── 申请信息摘要卡片 ──
                _SummaryCard(state: state),
                const SizedBox(height: 24),

                // ── 协议区 ──
                const _AgreementHeader(),
                const SizedBox(height: 16),

                _AgreementItem(
                  title: '搭哒达人服务协议',
                  description:
                      '包含服务规范、定价规则、违规处理等核心条款，保障买卖双方权益',
                  isChecked: state.agreedToTerms,
                  onChanged: notifier.setAgreedToTerms,
                  onReadMore: () => _showAgreementSheet(
                    context,
                    title: '达人服务协议',
                    content: _termsContent,
                  ),
                ),
                const SizedBox(height: 12),

                _AgreementItem(
                  title: '隐私保护声明',
                  description: '说明核验视频、照片等敏感信息的使用方式与存储规范',
                  isChecked: state.agreedToPrivacy,
                  onChanged: notifier.setAgreedToPrivacy,
                  onReadMore: () => _showAgreementSheet(
                    context,
                    title: '隐私保护声明',
                    content: _privacyContent,
                  ),
                ),
                const SizedBox(height: 12),

                _AgreementItem(
                  title: '安全行为准则',
                  description: '禁止虚假信息、欺诈及任何违法交易，违规将永久封禁账号',
                  isChecked: state.agreedToSafety,
                  onChanged: notifier.setAgreedToSafety,
                  onReadMore: () => _showAgreementSheet(
                    context,
                    title: '安全行为准则',
                    content: _safetyContent,
                  ),
                  accentColor: AppTheme.error,
                ),
                const SizedBox(height: 24),

                // ── 全选快捷 ──
                GestureDetector(
                  onTap: () {
                    final all = state.allTermsAgreed;
                    notifier.setAgreedToTerms(!all);
                    notifier.setAgreedToPrivacy(!all);
                    notifier.setAgreedToSafety(!all);
                  },
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: state.allTermsAgreed
                              ? AppTheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: state.allTermsAgreed
                                ? AppTheme.primary
                                : AppTheme.onSurfaceVariant,
                            width: 1.5,
                          ),
                        ),
                        child: state.allTermsAgreed
                            ? const Icon(Icons.check_rounded,
                                size: 15, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '我已阅读并同意以上全部条款',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),

                // 错误提示
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.error.withValues(alpha: 0.3),
                          width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 16, color: AppTheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // ── 底部按钮 ──
        _SubmitBar(
          canSubmit: state.allTermsAgreed && !state.isUploading,
          onBack: onBack,
          onSubmit: () async {
            await ref
                .read(becomeProviderProvider.notifier)
                .submit(userId);
          },
        ),
      ],
    );
  }

  void _showAgreementSheet(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 拖拽条
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.onSurfaceVariant,
                      height: 1.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// 申请信息摘要卡片
// ──────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});

  final BecomeProviderState state;

  @override
  Widget build(BuildContext context) {
    final type = state.selectedType;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize_rounded,
                  size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              const Text(
                '申请摘要',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: AppTheme.divider),
          if (type != null)
            _SummaryRow(
              label: '达人类型',
              value: '${type.emoji} ${type.label}',
            ),
          if (state.region != null && state.region!.isNotEmpty)
            _SummaryRow(label: '所在地区', value: state.region!),
          if (state.pricePerHour != null)
            _SummaryRow(
                label: '基础定价',
                value: '¥${state.pricePerHour!.toStringAsFixed(0)}/时'),
          _SummaryRow(
            label: '已上传图片',
            value: '${state.totalPhotos} 张',
            valueColor: state.totalPhotos > 0
                ? AppTheme.success
                : AppTheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// 协议 UI 组件
// ──────────────────────────────────────────

class _AgreementHeader extends StatelessWidget {
  const _AgreementHeader();

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
        const Text(
          '平台协议',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _AgreementItem extends StatelessWidget {
  const _AgreementItem({
    required this.title,
    required this.description,
    required this.isChecked,
    required this.onChanged,
    required this.onReadMore,
    this.accentColor,
  });

  final String title;
  final String description;
  final bool isChecked;
  final void Function(bool) onChanged;
  final VoidCallback onReadMore;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.primary;
    return GestureDetector(
      onTap: () => onChanged(!isChecked),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isChecked
              ? color.withValues(alpha: 0.05)
              : AppTheme.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isChecked
                ? color.withValues(alpha: 0.3)
                : AppTheme.divider,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 自定义 Checkbox
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isChecked ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isChecked ? color : AppTheme.onSurfaceVariant,
                    width: 1.5,
                  ),
                ),
                child: isChecked
                    ? const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                isChecked ? color : AppTheme.onSurface,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onReadMore,
                        child: Text(
                          '查看全文',
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            decoration: TextDecoration.underline,
                            decorationColor: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// 提交按钮栏
// ──────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.canSubmit,
    required this.onBack,
    required this.onSubmit,
  });

  final bool canSubmit;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

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
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: canSubmit ? 1.0 : 0.45,
              child: ElevatedButton(
                onPressed: canSubmit ? onSubmit : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      '提交入驻申请',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// 协议内容（模拟）
// ──────────────────────────────────────────

const _termsContent = '''
搭哒达人服务协议

第一条 服务定义
搭哒平台（以下简称"平台"）为达人提供展示、接单和结算的技术服务。达人须为具备完全民事行为能力的自然人。

第二条 定价规范
2.1 达人可自主设定基础定价，平台建议参考市场水平合理定价。
2.2 实际成交价以双方确认订单为准，不得在平台外私下交易。
2.3 平台对每笔订单收取10%的服务费用。

第三条 服务质量
3.1 达人须如实填写个人资料，不得使用虚假照片或虚构技能。
3.2 达人须按时赴约，如需取消须提前24小时通知，否则将影响信用评分。
3.3 连续3次爽约将暂停服务资格。

第四条 违规处理
4.1 若发现虚假宣传、欺诈行为，平台有权立即冻结账号并追究责任。
4.2 涉及违法行为将移交相关部门处理。

第五条 修改权利
平台保留随时修改本协议的权利，修改后通过站内消息通知达人。
''';

const _privacyContent = '''
隐私保护声明

一、信息收集
平台收集的信息包括：注册信息、核验视频、上传照片及服务记录。

二、信息使用
2.1 核验视频仅用于身份真实性核验，加密存储，不对外分享。
2.2 作品集照片用于平台内展示，不得用于商业授权。
2.3 服务记录用于评分计算和客服纠纷处理。

三、信息安全
3.1 平台采用 AES-256 加密存储敏感信息。
3.2 未经用户授权，不向第三方分享个人信息。
3.3 如发生数据泄露，平台将在24小时内通知受影响用户。

四、用户权利
用户可随时申请删除账号及相关数据，处理周期为15个工作日。
''';

const _safetyContent = '''
安全行为准则

严禁以下行为：

1. 虚假信息
禁止使用非本人照片、虚假学历或技能证书进行入驻申请。

2. 欺诈行为
禁止虚报定价、私下加价或拒绝履行已确认订单。

3. 违法交易
严禁任何形式的违法交易，包括但不限于色情、赌博相关内容。

4. 隐私侵犯
禁止未经授权拍摄、录制或传播买家的个人信息和影像。

5. 平台外交易
禁止引导买家在平台外完成交易，违者将永久封禁。

处罚措施：
· 轻微违规：警告 + 扣除信用分
· 中度违规：暂停服务 7-30 天
· 严重违规：永久封禁 + 法律追责
''';
