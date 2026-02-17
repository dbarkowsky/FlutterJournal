
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedImageIndexNotifier extends Notifier<int?> {
	@override
	int? build() => null;

	void select(int? index) => state = index;
}

final selectedImageIndexProvider =
		NotifierProvider<SelectedImageIndexNotifier, int?>(SelectedImageIndexNotifier.new);
