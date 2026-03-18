
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
  /// Grid index of the last primary (non-shift) click. Used as the range anchor
  /// for subsequent shift-clicks.
  final int? anchorIndex;

  const MultiSelectState({
    this.isActive = false,
    this.selectedIds = const {},
    this.anchorIndex,
  });

  // Use a sentinel so that copyWith can explicitly clear anchorIndex to null.
  static const _sentinel = Object();

  MultiSelectState copyWith({
    bool? isActive,
    Set<int>? selectedIds,
    Object? anchorIndex = _sentinel,
  }) {
    return MultiSelectState(
      isActive: isActive ?? this.isActive,
      selectedIds: selectedIds ?? this.selectedIds,
      anchorIndex: identical(anchorIndex, _sentinel) ? this.anchorIndex : anchorIndex as int?,
    );
  }
}

class MultiSelectNotifier extends Notifier<MultiSelectState> {
  @override
  MultiSelectState build() => const MultiSelectState();

  /// Enter multi-select mode, immediately select [id], and set [index] as anchor.
  void enterMode(int id, int index) {
    state = MultiSelectState(isActive: true, selectedIds: {id}, anchorIndex: index);
  }

  /// Toggle selection of [id] at grid [index]. Updates anchor. Only has effect
  /// while in multi-select mode.
  void toggle(int id, int index) {
    if (!state.isActive) return;
    final updated = Set<int>.from(state.selectedIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = MultiSelectState(isActive: true, selectedIds: updated, anchorIndex: index);
  }

  /// Select the contiguous range between [anchorIndex] and [toIndex], using
  /// [orderedIds] as the source-of-truth for grid order.
  /// Replaces the current selection with just the range (like Windows Explorer).
  /// The anchor is NOT moved so repeated shift-clicks extend from the same point.
  void selectRange(int toIndex, List<int> orderedIds) {
    if (!state.isActive) return;
    final from = state.anchorIndex ?? toIndex;
    final lo = from < toIndex ? from : toIndex;
    final hi = from < toIndex ? toIndex : from;
    final rangeIds = <int>{};
    for (int i = lo; i <= hi && i < orderedIds.length; i++) {
      rangeIds.add(orderedIds[i]);
    }
    state = state.copyWith(selectedIds: rangeIds);
  }

  /// Clear selection and exit multi-select mode.
  void deselectAll() {
    state = const MultiSelectState();
  }
}

// ---------------------------------------------------------------------------
// Ordered attachment IDs — kept in sync by ImageGallerySidebar so that tiles
// can resolve index ranges without needing access to the full attachment list.
// ---------------------------------------------------------------------------

class AttachmentOrderNotifier extends Notifier<List<int>> {
  @override
  List<int> build() => const [];

  void setOrder(List<int> ids) => state = ids;
}

final attachmentOrderProvider =
    NotifierProvider<AttachmentOrderNotifier, List<int>>(AttachmentOrderNotifier.new);

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
