import 'package:flutter/material.dart';

import '../models/geomancy_figure_model.dart';
import 'geomancy_figure_widget.dart';

class GeomancyShieldChart extends StatelessWidget {
  final GeomancyChartModel chart;

  const GeomancyShieldChart({
    super.key,
    required this.chart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _sectionTitle('Mothers'),
        _figureRow([
          for (int i = 0; i < chart.mothers.length; i++)
            GeomancyFigureWidget(
              figure: chart.mothers[i],
              label: 'M${i + 1}',
              compact: true,
            ),
        ]),
        const SizedBox(height: 18),
        _sectionTitle('Daughters'),
        _figureRow([
          for (int i = 0; i < chart.daughters.length; i++)
            GeomancyFigureWidget(
              figure: chart.daughters[i],
              label: 'D${i + 1}',
              compact: true,
            ),
        ]),
        const SizedBox(height: 18),
        _sectionTitle('Nieces'),
        _figureRow([
          for (int i = 0; i < chart.nieces.length; i++)
            GeomancyFigureWidget(
              figure: chart.nieces[i],
              label: 'N${i + 1}',
              compact: true,
            ),
        ]),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 145,
                child: GeomancyFigureWidget(
                  figure: chart.leftWitness,
                  label: 'Left Witness',
                  compact: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 145,
                child: GeomancyFigureWidget(
                  figure: chart.rightWitness,
                  label: 'Right Witness',
                  compact: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GeomancyFigureWidget(
          figure: chart.judge,
          label: 'Judge',
          highlighted: true,
        ),
        const SizedBox(height: 14),
        GeomancyFigureWidget(
          figure: chart.reconciler,
          label: 'Reconciler',
        ),
      ],
    );
  }

  Widget _figureRow(List<Widget> children) {
    return SizedBox(
      height: 145,
      child: Row(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i != children.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFF2E2650),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF6B6080),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.7,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFF2E2650),
            ),
          ),
        ],
      ),
    );
  }
}
