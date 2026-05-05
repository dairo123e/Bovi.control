import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';
import 'menu_option.dart';

class HeroDashboardCard extends StatelessWidget {
  final String role;
  final int totalVacas;
  final double litros7;
  final double litros30;
  final ImageProvider<Object>? bgImage;
  final VoidCallback? onChangePhoto;

  const HeroDashboardCard({
    super.key,
    required this.role,
    required this.totalVacas,
    required this.litros7,
    required this.litros30,
    required this.bgImage,
    this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Stack(
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.brandForest, Color(0xFF36785F)],
              ),
              image: bgImage == null
                  ? null
                  : DecorationImage(
                      image: bgImage!,
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.4),
                        BlendMode.darken,
                      ),
                    ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.insights,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Resumen',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(child: _miniKpi('Vacas', '$totalVacas')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _miniKpi(
                          '7 dias',
                          '${litros7.toStringAsFixed(1)} L',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _miniKpi(
                          '30 dias',
                          '${litros30.toStringAsFixed(1)} L',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onChangePhoto,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniKpi(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class QuickLecheCard extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> vacas;
  final bool canManage;
  final TextEditingController litrosCtrl;
  final String? animalIdSeleccionado;
  final bool guardandoLeche;
  final ValueChanged<String?> onAnimalChanged;
  final VoidCallback onRegistrar;

  const QuickLecheCard({
    super.key,
    required this.vacas,
    required this.canManage,
    required this.litrosCtrl,
    required this.animalIdSeleccionado,
    required this.guardandoLeche,
    required this.onAnimalChanged,
    required this.onRegistrar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: AppColors.brandForest.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.water_drop_outlined,
                  color: AppColors.brandForest,
                ),
                SizedBox(width: 8),
                Text(
                  'Registro de leche diaria',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (vacas.isEmpty)
              const Text('Primero debes registrar al menos una vaca.')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 360;
                  final fields = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SELECCIONAR VACA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: vacas.any((v) => v.id == animalIdSeleccionado)
                            ? animalIdSeleccionado
                            : vacas.first.id,
                        items: vacas
                            .map(
                              (v) => DropdownMenuItem(
                                value: v.id,
                                child: Text(
                                  (v.data()['nombre'] ?? 'Sin nombre')
                                      .toString(),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: canManage ? onAnimalChanged : null,
                        decoration: const InputDecoration(
                          hintText: 'Selecciona una vaca',
                          prefixIcon: Icon(Icons.pets),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'LITROS DE HOY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: litrosCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        enabled: canManage,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.water_drop_outlined),
                          suffixText: 'L',
                        ),
                      ),
                    ],
                  );

                  final button = ElevatedButton.icon(
                    onPressed: guardandoLeche ? null : onRegistrar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandForest,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    icon: guardandoLeche
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(guardandoLeche ? 'Guardando...' : 'Registrar'),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        fields,
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: button),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: fields),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 110,
                        child: button,
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class SearchBarMenu extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const SearchBarMenu({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.brandForest.withOpacity(0.08)),
        boxShadow: AppShadows.subtle,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

class HintChip extends StatelessWidget {
  final String label;
  const HintChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.circle, size: 8, color: AppColors.brandLeaf),
      label: Text(label),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      side: BorderSide(color: AppColors.brandForest.withOpacity(0.12)),
      backgroundColor: Colors.white,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class MenuTile extends StatelessWidget {
  final MenuOption option;
  const MenuTile({super.key, required this.option});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => option.page),
        );
      },
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              option.color.withOpacity(0.09),
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: AppShadows.soft,
          border: Border.all(color: option.color.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: option.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: _MenuIcon(option: option)),
              ),
              const SizedBox(height: 10),
              Text(
                option.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActivityItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String tone;
  final VoidCallback? onTap;

  const ActivityItemCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = _resolveIcon(tone);
    final color = _resolveColor(tone);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: color.withOpacity(0.18)),
          boxShadow: AppShadows.subtle,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
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

  IconData _resolveIcon(String tipo) {
    final key = tipo.toLowerCase();
    if (key.contains('salud') || key.contains('vacuna')) {
      return Icons.vaccines_outlined;
    }
    if (key.contains('alerta')) return Icons.warning_amber_rounded;
    if (key.contains('ordeño') || key.contains('leche')) {
      return Icons.water_drop_outlined;
    }
    return Icons.notifications_none_rounded;
  }

  Color _resolveColor(String tipo) {
    final key = tipo.toLowerCase();
    if (key.contains('alerta')) return AppColors.warning;
    if (key.contains('salud') || key.contains('vacuna')) {
      return const Color(0xFF4E7BFF);
    }
    if (key.contains('ordeño') || key.contains('leche')) {
      return AppColors.brandLeaf;
    }
    return AppColors.brandForest;
  }
}

class _MenuIcon extends StatelessWidget {
  final MenuOption option;
  const _MenuIcon({required this.option});

  @override
  Widget build(BuildContext context) {
    const double size = 30;
    if (option.assetPath != null) {
      return Image.asset(
        option.assetPath!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.image_not_supported, size: size, color: option.color),
      );
    }
    return Icon(option.icon, size: size, color: option.color);
  }
}
