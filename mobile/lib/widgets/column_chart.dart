import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/stats.dart';

/// Histogramme vertical (port de ColumnChart.vue) : barres fines, extrémités arrondies, infobulle au tap.
/// Avec `counts`, la barre est empilée (de bas en haut, couleurs de [typeSegments]).
/// Trop de barres pour la largeur : défilement horizontal, positionné sur les plus récentes.
/// `bands` : frise sous l'axe, une ligne par bande.
class ColumnChart extends StatelessWidget {
  const ColumnChart({super.key, required this.items, this.bands = const []});

  final List<ChartItem> items;
  final List<ChartBand> bands;

  static const _height = 176.0;
  static const _minBarWidth = 22.0;
  static const _axisStyle = TextStyle(fontSize: 10, color: AppColors.muted, fontFeatures: [FontFeature.tabularFigures()]);

  @override
  Widget build(BuildContext context) {
    final ticks = chartTicks(items);
    // étiquettes sélectives : pas toutes les étiquettes de l'axe si trop nombreuses
    final labelEvery = max(1, (items.length / 8).ceil());
    double y(int v) => (1 - v / ticks.top) * _height;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // axe Y
        SizedBox(
          width: 24,
          height: _height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final t in ticks.values)
                Positioned(right: 0, top: y(t) - 7, child: Text('$t', style: _axisStyle)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: SizedBox(
                width: max(constraints.maxWidth, items.length * _minBarWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _height,
                      child: Stack(
                        children: [
                          // grille discrète
                          for (final t in ticks.values)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: y(t),
                              child: Container(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [for (final item in items) Expanded(child: _Bar(item: item, top: ticks.top))],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        for (final (i, item) in items.indexed)
                          Expanded(
                            child: SizedBox(
                              height: 14,
                              child: i % labelEvery == 0
                                  ? OverflowBox(minWidth: 0, maxWidth: double.infinity, child: Text(item.label, style: _axisStyle, maxLines: 1))
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    for (final b in bands) ...[
                      const SizedBox(height: 4),
                      _Band(band: b, count: items.length),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.item, required this.top});

  final ChartItem item;
  final int top;

  @override
  Widget build(BuildContext context) {
    final counts = item.counts;
    return Tooltip(
      message: item.tooltip,
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        color: Colors.transparent, // zone de tap sur toute la hauteur
        padding: const EdgeInsets.symmetric(horizontal: 1),
        alignment: Alignment.bottomCenter,
        child: item.value == 0
            ? null
            : LayoutBuilder(
                builder: (context, c) => SizedBox(
                  width: min(c.maxWidth * 0.6, 24),
                  height: c.maxHeight * item.value / top,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    child: counts == null
                        ? const ColoredBox(color: AppColors.primary)
                        : Column(
                            verticalDirection: VerticalDirection.up,
                            children: [
                              for (final (i, n) in counts.indexed)
                                if (n > 0)
                                  Expanded(
                                    flex: n,
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 1),
                                      color: typeSegments[i].color,
                                    ),
                                  ),
                            ],
                          ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({required this.band, required this.count});

  final ChartBand band;
  final int count;

  @override
  Widget build(BuildContext context) {
    final after = count - band.to - 1;
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          if (band.from > 0) Spacer(flex: band.from),
          Expanded(
            flex: band.to - band.from + 1,
            child: Tooltip(
              message: band.tooltip,
              triggerMode: TooltipTriggerMode.tap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(color: band.color, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(band.icon, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        band.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (after > 0) Spacer(flex: after),
        ],
      ),
    );
  }
}
