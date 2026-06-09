import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../blocs/items/items_cubit.dart';
import '../../../blocs/items/items_state.dart';
import '../../../models/item.dart';
import '../../../repositories/items_repository.dart';
import 'detail_screen.dart';

// ============================================================
// ListScreen – Tab 2 – lista + pull-to-refresh
// ============================================================

class ListScreen extends StatelessWidget {
  const ListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ItemsCubit(
        repository: context.read<ItemsRepository>(),
      )..loadItems(),
      child: const _ListView(),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Lista'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => context.read<ItemsCubit>().refresh(),
        child: BlocBuilder<ItemsCubit, ItemsState>(
          builder: (context, state) {
            return switch (state) {
              ItemsLoading() => const AppLoadingIndicator(),
              ItemsError(message: final msg) => CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      child: Center(
                        child: AppEmptyState(
                          icon: LucideIcons.circleX,
                          title: 'Hiba történt',
                          subtitle: msg,
                          action: AppButton(
                            label: 'Újrapróbálás',
                            fullWidth: false,
                            onTap: () => context.read<ItemsCubit>().refresh(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ItemsLoaded(items: final items) => items.isEmpty
                  ? const CustomScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          child: Center(
                            child: AppEmptyState(
                              icon: LucideIcons.inbox,
                              title: 'Nincsenek elemek',
                              subtitle: 'Adj hozzá az első elemet!',
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) => _ItemCard(item: items[i]),
                    ),
              _ => const AppLoadingIndicator(),
            };
          },
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Item item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
      ),
      child: AppListTile(
        title: item.title,
        subtitle: item.description,
        leading: AppAvatar(
          name: item.title,
          color: item.isActive
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.surfaceVariant,
        ),
        badgeLabel: item.isActive ? 'Aktív' : 'Inaktív',
        badgeVariant: item.isActive
            ? AppBadgeVariant.success
            : AppBadgeVariant.neutral,
      ),
    );
  }
}
