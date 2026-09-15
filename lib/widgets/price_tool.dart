import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/plan_math.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/scope.dart';

/// "How much does 20 g of protein cost *here*?"
///
/// The user types a local price once per source; the card ranks them, prices a
/// fixed amount of protein from each, and builds the cheapest basket that
/// reaches today's protein target. That is the budget half of the plan: the
/// same 150 g can cost half as much depending on which shelf you shop from.
class PriceToolCard extends StatelessWidget {
  const PriceToolCard({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final food = st.content.food;
    final tool = food.priceTool;
    final sources = food.priceableSources;
    if (tool.isEmpty || sources.isEmpty) return const SizedBox.shrink();

    final cur = st.currency;
    final byId = {for (final s in sources) s.id: s};

    // Cheapest protein first; anything without a price yet goes last.
    final priced = st.rankedSources;
    final pricedIds = priced.map((e) => e.id).toSet();
    final rest = sources.where((s) => !pricedIds.contains(s.id)).toList();
    final basket = priced.length >= 2 ? st.proteinBasket : null;

    return SectionCard(
      emoji: '💰',
      title: st.t(tool.title),
      accent: C.green,
      subtitle: st.isArabic
          ? 'ثمن ${tool.perGrams} جم بروتين من كل مصدر — اضغط لتكتب السعر'
          : 'what ${tool.perGrams} g of protein costs from each source - tap to price it',
      trailing: TextButton(
        onPressed: () => _editCurrency(context, st),
        child: Text(cur),
      ),
      children: [
        if (!tool.note.isEmpty) ...[
          Text(st.t(tool.note), style: Theme.of(context).textTheme.bodySmall),
          const Gap(10),
        ],
        for (var i = 0; i < priced.length; i++)
          _PriceRow(
            src: byId[priced[i].id]!,
            spec: priced[i],
            rank: i + 1,
            perGrams: tool.perGrams.toDouble(),
            currency: cur,
            onTap: () => _editPrice(context, st, byId[priced[i].id]!),
          ),
        for (final s in rest)
          _PriceRow(
            src: s,
            spec: SourcePrice(id: s.id, proteinPerUnitG: s.proteinPerUnitG),
            rank: null,
            perGrams: tool.perGrams.toDouble(),
            currency: cur,
            onTap: () => _editPrice(context, st, s),
          ),
        if (basket != null && !basket.isEmpty) ...[
          const Gap(14),
          _BasketCard(basket: basket, byId: byId, currency: cur, tool: tool),
        ] else ...[
          const Gap(10),
          Text(l.basketEmpty, style: Theme.of(context).textTheme.labelSmall),
        ],
      ],
    );
  }

  Future<void> _editPrice(BuildContext context, AppState st, ProteinSource s) async {
    final cur = st.currency;
    final ctrl = TextEditingController(text: _plain(st.priceOf(s.id)));
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(st.t(s.name), style: const TextStyle(fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${st.t(s.unit)} · ${compact(s.proteinPerUnitG)} g ${context.l10n.protein}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            if (s.maxUnits > 0 && !s.maxUnitsLabel.isEmpty)
              Text(
                '${context.l10n.perDay}: ${st.t(s.maxUnitsLabel)}',
                style: Theme.of(ctx).textTheme.labelSmall,
              ),
            const Gap(10),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(
                hintText: context.l10n.enterPrice,
                suffixText: cur,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text(context.l10n.reset, style: const TextStyle(color: C.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (res == null) return;
    final v = parseAmount(res);
    await st.setPrice(s.id, v);
  }

  Future<void> _editCurrency(BuildContext context, AppState st) async {
    final ctrl = TextEditingController(text: st.currency);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.yourCurrency, style: const TextStyle(fontSize: 17)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 8,
          decoration: const InputDecoration(hintText: 'EGP / ج.م / \$/ €'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (res != null) await st.setCurrency(res);
  }
}

/// `12.5` -> `"12.5"`, `null` -> `""`. Never a trailing `.0` in the field.
String _plain(double? v) => v == null ? '' : compact(v);

/// Accepts `12`, `12.5` and `12,5`; null when it is not a usable price.
double? parseAmount(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || !v.isFinite || v <= 0) return null;
  return v;
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.src,
    required this.spec,
    required this.rank,
    required this.perGrams,
    required this.currency,
    required this.onTap,
  });

  final ProteinSource src;
  final SourcePrice spec;
  final int? rank;
  final double perGrams;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final t = Theme.of(context);
    final cost = spec.costPer(perGrams);
    final color = rank == null
        ? C.border
        : rank == 1
            ? C.green
            : rank == 2
                ? C.cyan
                : C.amber;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: rank == null ? 0.03 : 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: rank == null ? 0.18 : 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: rank == null ? 0.10 : 0.22),
                shape: BoxShape.circle,
              ),
              child: Text(
                rank == null ? '–' : '$rank',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(st.t(src.name), style: t.textTheme.titleSmall),
                  Text(
                    cost == null
                        ? '${st.t(src.unit)} · ${context.l10n.notPriced}'
                        : '${st.t(src.unit)} · ${compact(src.proteinPerUnitG)}g',
                    style: t.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  cost == null ? '—' : '${money(cost)} $currency',
                  style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cost == null ? t.textTheme.bodySmall?.color : color,
                  ),
                ),
                if (spec.price != null)
                  Text(
                    '${money(spec.price!)} $currency / ${st.t(src.unit)}',
                    style: t.textTheme.labelSmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BasketCard extends StatelessWidget {
  const _BasketCard({
    required this.basket,
    required this.byId,
    required this.currency,
    required this.tool,
  });

  final Basket basket;
  final Map<String, ProteinSource> byId;
  final String currency;
  final PriceTool tool;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final t = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: C.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.green.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_basket_rounded, size: 17, color: C.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.cheapestBasket,
                  style: t.textTheme.titleSmall?.copyWith(color: C.green),
                ),
              ),
            ],
          ),
          const Gap(10),
          for (final line in basket.lines)
            if (byId[line.id] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${compact(line.units)} × ${st.t(byId[line.id]!.unit)} '
                        '· ${st.t(byId[line.id]!.name)}',
                        style: t.textTheme.bodySmall,
                      ),
                    ),
                    Text('${compact(line.grams)}g', style: t.textTheme.labelSmall),
                    const SizedBox(width: 10),
                    Text('${money(line.cost)} $currency',
                        style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
          const Gap(8),
          Container(height: 1, color: C.green.withValues(alpha: 0.25)),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${compact(basket.grams)}g ${l.protein}',
                  style: t.textTheme.titleSmall,
                ),
              ),
              Text('${money(basket.cost)} $currency / ${l.perDay}',
                  style: t.textTheme.titleSmall?.copyWith(color: C.green, fontWeight: FontWeight.w800)),
            ],
          ),
          if (!basket.reached) ...[
            const Gap(8),
            InfoBanner(
              st.isArabic
                  ? 'بهذه الأسعار والحدود لا تصل للهدف كله — سدّ الباقي من مصدر لم تسعّره بعد.'
                  : 'With these prices and caps the target is not fully reachable - cover the rest from a source you have not priced yet.',
              color: C.amber,
              icon: Icons.info_outline_rounded,
            ),
          ],
          if (!tool.basketNote.isEmpty) ...[
            const Gap(8),
            Text(st.t(tool.basketNote), style: t.textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}

/// Money text without pointless zeros: 12 -> "12", 12.5 -> "12.50" is too long,
/// so under 100 keep one decimal, above that none.
String money(double v) {
  if (!v.isFinite) return '0';
  if (v >= 100) return v.round().toString();
  if (v >= 10) return roundTo(v, 1).toStringAsFixed(1);
  return roundTo(v, 2).toStringAsFixed(2);
}
