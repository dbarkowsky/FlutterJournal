
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedImageIndexNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? index) => state = index;
}

final selectedImageIndexProvider =
    NotifierProvider<SelectedImageIndexNotifier, int?>(SelectedImageIndexNotifier.new);

// ---------------------------------------------------------------------------
// Multi-select
// ---------------------------------------------------------------------------

class MultiSelectState {
  final bool isActive;
  final Set<int> selectedIds; // attachment IDs

  const MultiSelectState({
    this.isActive = false,
    this.selectedIds = const {},
  });

  MultiSelectState copyWith({bool? isActive, Set<int>? selectedIds}) {
    return MultiSelectState(
      isActive: isActive ?? this.isActive,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

class MultiSelectNotifier extends Notifier<MultiSelectState> {
  @override
  MultiSelectState build() => const MultiSelectState();

  /// Enter multi-select mode and immediately select [id].
  void enterMode(int id) {
    state = MultiSelectState(isActive: true, selectedIds: {id});
  }

  /// Toggle selection of [id]. Only has effect while in multi-select mode.
  void toggle(int id) {
    if (!state.isActive) return;
    final updated = Set<int>.from(state.selectedIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(selectedIds: updated);
  }

  /// Clear selection and exit multi-select mode.
  void deselectAll() {
    state = const MultiSelectState();
  }
}

final multiSelectProvider =
    NotifierProvider<MultiSelectNotifier, MultiSelectState>(MultiSelectNotifier.new);

// ---------------------------------------------------------------------------
// Refresh
// ---------------------------------------------------------------------------

class ImageListRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state++;
}

final imageListRefreshProvider =
    NotifierProvider<ImageListRefreshNotifier, int>(ImageListRefreshNotifier.new);
