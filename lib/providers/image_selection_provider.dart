
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedImageIndexNotifier extends Notifier<int?> {
	@override
	int? build() => null;

	void select(int? index) => state = index;
}

final selectedImageIndexProvider =
		NotifierProvider<SelectedImageIndexNotifier, int?>(SelectedImageIndexNotifier.new);

class ImageListRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state++;
}

final imageListRefreshProvider =
    NotifierProvider<ImageListRefreshNotifier, int>(ImageListRefreshNotifier.new);
