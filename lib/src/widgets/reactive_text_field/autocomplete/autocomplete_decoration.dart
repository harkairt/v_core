import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:v_core/src/widgets/reactive_text_field/autocomplete/raw_autocomplete_decoration.dart';
import 'package:v_core/v_core.dart';

class AutocompleteDecoration<K, T> extends HookWidget {
  const AutocompleteDecoration({
    required this.child,
    required this.options,
    required this.onSelected,
    required this.displayStringForOption,
    required this.listBuilder,
    required this.control,
    this.groupBuilder = defaultGroupAutocompleteBuilder,
    this.valueBuilder,
    this.customBuilder,
    this.customWidget,
    this.selectedKey,
    this.focusNode,
    this.depthLeftInset = 0.0,
    this.maxDropdownHeight = 400.0,
    super.key,
  });

  final Widget child;
  final CompositeNode<K, T> options;
  final K? selectedKey;
  final void Function(CompositeValue<K, T>?) onSelected;
  final String Function(T?) displayStringForOption;
  final double depthLeftInset;
  final double maxDropdownHeight;
  final FocusNode? focusNode;
  final Widget Function(DepthCompositeGroup<K, T> node, bool isHighlighted) groupBuilder;
  final Widget Function(DepthCompositeValue<K, T> node, bool isSelected, bool isHighlighted, void Function() select)?
      valueBuilder;
  final Widget? Function(String value)? customBuilder;
  final Widget? customWidget;
  final FormControl<K> control;
  final Widget Function(ScrollController controller, List<Widget> children) listBuilder;

  CompositeValue<K, T>? get selectedValue => options.findByKey(selectedKey);

  @override
  Widget build(BuildContext context) {
    final inheritedFocusNode = context.requireExtension<ReactiveTextFieldBehavior>().focusNode;
    final effectiveFocusNode = focusNode ?? inheritedFocusNode ?? useFocusNode();

    final inheritedController = context.requireExtension<ReactiveTextFieldBehavior>().controller;
    final effectiveController = inheritedController ?? useTextEditingController();

    final hasFinishedSelection = useValueNotifier(false);

    void applySelectedValueToField() {
      if (selectedValue != null) {
        final displayValue = displayStringForOption(selectedValue?.value);
        control.patchValue(selectedKey);
        if (effectiveController.isEntirelySelected) {
          effectiveController.value = effectiveController.value.copyWith(
            text: displayValue,
            selection: TextSelection(baseOffset: 0, extentOffset: displayValue.length),
          );
        } else {
          effectiveController.setTextWithKeptSelection(displayValue);
          effectiveController.triggerValueChanged();
        }
      }
    }

    usePlainPostFrameEffect(
      () => applySelectedValueToField(),
      [selectedKey],
    );

    useOnChangeNotifierNotified(
      effectiveFocusNode,
      () {
        if (effectiveFocusNode.hasFocus) {
          effectiveController.selectAll();
          hasFinishedSelection.value = true;
        } else {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            applySelectedValueToField();
            hasFinishedSelection.value = false;
          });
        }
      },
      [options, selectedKey],
    );

    final filteredOptions = useMemoized2(
      () {
        final selection = effectiveController.selection;
        if (effectiveController.isEntirelySelected || !selection.isValid || !hasFinishedSelection.value) {
          return options.flattened;
        } else {
          return options.pruneByLabel(displayStringForOption, effectiveController.text).flattened;
        }
      },
      [
        options.flattened.uniqueIdentifier,
      ],
      [
        useSelectChangeNotifier(effectiveController, select: (it) => it.selection),
      ],
    );

    return RawAutocompleteDecoration<K, T>(
      control: control,
      selectedKey: selectedKey,
      options: filteredOptions,
      onSelected: onSelected,
      maxDropdownHeight: maxDropdownHeight,
      customBuilder: customBuilder,
      customWidget: customWidget,
      listBuilder: listBuilder,
      focusNode: effectiveFocusNode,
      controller: effectiveController,
      groupBuilder: groupBuilder,
      valueBuilder: (node, isSelected, isHighlighted, select) {
        if (valueBuilder != null) {
          return valueBuilder!(node, isSelected, isHighlighted, select);
        }

        return defaultValueAutocompleteBuilder(
          node: node,
          isSelected: isSelected,
          isHighlighted: isHighlighted,
          select: select,
          displayStringForOption: displayStringForOption,
        );
      },
      child: child,
    );
  }
}

extension on TextEditingController {
  void selectAll() {
    selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
  }

  bool get isEntirelySelected => (selection.end - selection.start) == text.length;
}