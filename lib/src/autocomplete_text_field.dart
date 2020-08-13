import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AutocompleteTextField extends StatefulWidget {
  final Duration animationDuration;
  final List<String> suggestions;
  final Function(String value) onChanged;
  final Function(String value) onSubmitted;
  final Function(String value) onEditingComplete;
  final Function(String value) itemBuilder;
  final FocusNode focusNode;
  final TextEditingController controller;
  final bool closeKeyboardOnSuggestionPress;
  final bool resetScrollPositionOnSuggestionPress;
  final bool resetScrollPositionOnTextChange;
  final bool showSuggestionsOnSelection;
  final bool onTapShowSuggestions;
  final Function onTap;
  final String initialValue;
  final BoxConstraints constraints;
  final int maxItemCount;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final int maxLines;
  final int minLines;
  final InputDecoration decoration;
  final int maxLength;
  final TextInputAction textInputAction;
  final TextStyle style;
  final String separator;

  AutocompleteTextField({
    Key key,
    this.animationDuration = const Duration(milliseconds: 200),
    @required this.suggestions,
    this.itemBuilder,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.focusNode,
    this.controller,
    this.closeKeyboardOnSuggestionPress = false,
    this.resetScrollPositionOnSuggestionPress = true,
    this.onTapShowSuggestions = true,
    this.resetScrollPositionOnTextChange = false,
    this.showSuggestionsOnSelection = true,
    this.onTap,
    this.initialValue,
    this.constraints,
    this.maxItemCount,
    this.textCapitalization,
    this.autocorrect,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines,
    this.minLines,
    this.decoration,
    this.maxLength,
    this.textInputAction,
    this.style,
    this.separator,
  }) : super(key: key);

  @override
  AutocompleteTextFieldState createState() => AutocompleteTextFieldState();
}

class AutocompleteTextFieldState extends State<AutocompleteTextField>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController _animationController;
  final _layerLink = LayerLink();
  OverlayEntry _overlayEntry;
  TextField _textField;
  String _currentText = "";
  String get currentText => _currentText;
  List<String> _filteredSuggestions = [];
  bool _isVisible = false;
  bool get isVisible => _isVisible;
  Offset _overlayOffset;
  double _overlayWidth;
  double _lastApplicationWidth;
  bool _listViewResetKey = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _textField = TextField(
      style: widget.style,
      textInputAction: widget.textInputAction,
      maxLength: widget.maxLength,
      textCapitalization: widget.textCapitalization,
      autocorrect: widget.autocorrect,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      controller: widget.controller ?? TextEditingController(),
      focusNode: widget.focusNode ?? FocusNode(),
      decoration: widget.decoration,
      onSubmitted: (String value) {
        if (widget.onSubmitted != null) {
          widget.onSubmitted(value);
        }
      },
      onEditingComplete: () {
        if (widget.onEditingComplete != null) {
          widget.onEditingComplete(_currentText);
        }

        _close(closeKeyboard: true, resetScrollPosition: true);
      },
      onChanged: (String value) {
        if (widget.onChanged != null) {
          widget.onChanged(value);
        }

        _currentText = value;
        _updateOverlay(value);
      },
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap();
        }

        if (widget.onTapShowSuggestions) {
          _updateOverlay(_currentText);
        }
      },
    );

    if (!widget.showSuggestionsOnSelection) {
      _textField.controller.addListener(() {
        final selection = _textField.controller.selection;
        // Selected text.
        if (selection.start != selection.end) {
          _close();
        }
      });
    }

    if (widget.initialValue != null) {
      _currentText = widget.initialValue;
      _textField.controller.text = _currentText;
    }

    _filteredSuggestions = [...widget.suggestions];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _textField.focusNode.dispose();
    _textField.controller.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: _textField,
    );
  }

  @override
  void didChangeMetrics() {
    final width = WidgetsBinding.instance.window.physicalSize.width;
    if (width == _lastApplicationWidth) {
      return;
    }

    _lastApplicationWidth = width;

    if (!_isVisible) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final textFieldSize = (context.findRenderObject() as RenderBox).size;
      if (_overlayWidth != textFieldSize.width) {
        _overlayWidth = textFieldSize.width;
      }
      if (_overlayOffset.dy != textFieldSize.height) {
        _overlayOffset = Offset(0, textFieldSize.height);
      }
      _overlayEntry.markNeedsBuild();
    });
  }

  void open({bool resetScrollPosition = false}) {
    _open(resetScrollPosition: resetScrollPosition);
  }

  void close({
    bool closeKeyboard = true,
    bool resetScrollPosition = true,
    bool removeOverlayEntry = false,
  }) {
    _close(
      closeKeyboard: closeKeyboard,
      resetScrollPosition: resetScrollPosition,
      removeOverlayEntry: removeOverlayEntry,
    );
  }

  void _updateOverlay([String query]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final textFieldSize = (context.findRenderObject() as RenderBox).size;

      if (_overlayWidth == null || _overlayWidth != textFieldSize.width) {
        _overlayWidth = textFieldSize.width;
      }
      if (_overlayOffset?.dy != textFieldSize.height) {
        _overlayOffset = Offset(0, textFieldSize.height);
      }

      if (_overlayEntry == null) {
        _overlayEntry = OverlayEntry(
          builder: (context) {
            return Positioned(
              width: _overlayWidth,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: _overlayOffset,
                child: SizeTransition(
                  sizeFactor: _animationController,
                  child: Container(
                    constraints:
                        widget.constraints ?? BoxConstraints(maxHeight: 150),
                    child: Card(
                      margin: EdgeInsets.only(top: 2.5),
                      child: ListView.builder(
                        key: Key("listView_$_listViewResetKey"),
                        padding: EdgeInsets.all(5),
                        shrinkWrap: true,
                        itemCount:
                            widget.maxItemCount ?? _filteredSuggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _filteredSuggestions[index];
                          return InkWell(
                            child: widget.itemBuilder != null
                                ? widget.itemBuilder(suggestion)
                                : _AutocompleteTextFieldItem(suggestion),
                            onTap: () {
                              _onSuggestionTap(suggestion);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );

        Overlay.of(context).insert(_overlayEntry);
      }

      if (query != null) {
        final textSelection = _textField.controller.selection;
        _filteredSuggestions = _getFilteredSuggestions(
            query: query,
            separator: widget.separator,
            selection: textSelection);

        if (_filteredSuggestions.isEmpty) {
          _close();
        } else {
          _open(resetScrollPosition: widget.resetScrollPositionOnTextChange);
        }
      }

      _overlayEntry.markNeedsBuild();
    });
  }

  void _open({bool resetScrollPosition = false}) {
    if (_isVisible) {
      if (resetScrollPosition) {
        _listViewResetKey = !_listViewResetKey;
      }

      return;
    }

    _animationController.forward();
    _isVisible = true;
  }

  void _close({
    bool removeOverlayEntry = false,
    bool closeKeyboard = false,
    bool resetScrollPosition = false,
  }) {
    if (closeKeyboard) {
      _textField.focusNode.unfocus();
    }

    if (!_isVisible) {
      return;
    }

    _animationController.reverse().whenComplete(() {
      if (removeOverlayEntry && _overlayEntry != null) {
        _overlayEntry.remove();
        _overlayEntry = null;
      }

      if (resetScrollPosition) {
        _listViewResetKey = !_listViewResetKey;
        _overlayEntry?.markNeedsBuild();
      }
    });

    _isVisible = false;
  }

  // TODO: Fix if keyboardType == multiline and cursor is on the new line
  List<String> _getFilteredSuggestions({
    @required String query,
    @required String separator,
    @required TextSelection selection,
  }) {
    if (separator != null && query.contains(separator)) {
      final autocompleteText = _getAutocompleteText(
        query: query,
        separator: separator,
        selection: selection,
      );
      query = autocompleteText.suggestion;
    }

    final suggestions = <String>[];
    for (final item in widget.suggestions) {
      if (item.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(item);
      }
    }

    return suggestions;
  }

  // TODO: Fix if keyboardType == multiline and cursor is on the new line
  _AutocompleteText _parseAutocompleteSuggestionText({
    @required String text,
    @required String suggestion,
    @required String separator,
    @required TextSelection selection,
  }) {
    if (separator != null && text.contains(separator)) {
      // Selected text.
      if (selection.start != selection.end) {
        final replacedText = text.replaceRange(
          selection.start,
          selection.end,
          suggestion,
        );

        return _AutocompleteText(
          start: selection.start,
          end: selection.end,
          suggestion: suggestion,
          text: replacedText,
        );
      }

      final autocompleteText = _getAutocompleteText(
        query: text,
        separator: separator,
        selection: selection,
      );

      final replacedText = text.replaceRange(
        autocompleteText.start != null ? autocompleteText.start + 1 : 0,
        autocompleteText.end != null ? autocompleteText.end : text.length,
        suggestion,
      );

      return _AutocompleteText(
        start: autocompleteText.start,
        end: autocompleteText.end,
        suggestion: suggestion,
        text: replacedText,
      );
    }

    return _AutocompleteText(
      start: selection.start,
      end: selection.end,
      suggestion: suggestion,
      text: suggestion,
    );
  }

  _AutocompleteText _getAutocompleteText({
    @required String query,
    @required String separator,
    @required TextSelection selection,
  }) {
    int start;
    var startText = "";
    for (var i = selection.start - 1; i >= 0; i--) {
      final char = query[i];
      if (char == separator) {
        start = i;
        break;
      }

      startText += char;
    }

    int end;
    var endText = "";
    for (var i = selection.end; i < query.length; i++) {
      final char = query[i];
      if (char == separator) {
        end = i;
        break;
      }

      endText += char;
    }

    return _AutocompleteText(
      start: start,
      end: end,
      suggestion: "${_reverseText(startText)}$endText",
      text: query,
    );
  }

  String _reverseText(String text) {
    if (text == null || text.isEmpty || text.length == 1) {
      return text;
    }

    final strBuffer = StringBuffer();
    for (var i = text.length - 1; i >= 0; i--) {
      strBuffer.write(text[i]);
    }
    return strBuffer.toString();
  }

  void _onSuggestionTap(String suggestion) {
    if (widget.onChanged != null) {
      widget.onChanged(_currentText);
    }

    final selection = _textField.controller.selection;
    final autocompleteText = _parseAutocompleteSuggestionText(
      text: _currentText,
      suggestion: suggestion,
      separator: widget.separator,
      selection: selection,
    );

    final newSelection = _calculateTextSelection(
      selection,
      autocompleteText,
    );

    _currentText = autocompleteText.text;
    _textField.controller.value = TextEditingValue(
      text: autocompleteText.text,
      selection: newSelection,
    );

    _close(
      resetScrollPosition: widget.resetScrollPositionOnSuggestionPress,
      closeKeyboard: widget.closeKeyboardOnSuggestionPress,
    );
  }

  TextSelection _calculateTextSelection(
      TextSelection selection, _AutocompleteText autocompleteText) {
    final suggestionLength = autocompleteText.suggestion.length;

    // Selected text.
    if (selection.start != selection.end) {
      return TextSelection.collapsed(
        offset: selection.start + suggestionLength,
      );
    }

    final textLength = autocompleteText.text.length;
    var offset = 0;

    if (autocompleteText.start == null) {
      offset = suggestionLength;
    } else if (autocompleteText.end == null) {
      offset = textLength;
    } else {
      offset = autocompleteText.start + suggestionLength + 1;
    }

    if (offset > textLength) {
      offset = textLength;
    }

    return TextSelection.collapsed(offset: offset);
  }
}

class _AutocompleteTextFieldItem extends StatelessWidget {
  final String value;

  _AutocompleteTextFieldItem(this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 2.5),
      child: Text(
        value,
        style: TextStyle(fontSize: 16),
      ),
    );
  }
}

class _AutocompleteText {
  final int start;
  final int end;
  final String suggestion;
  final String text;

  _AutocompleteText({
    @required this.start,
    @required this.end,
    @required this.suggestion,
    @required this.text,
  });

  @override
  String toString() {
    return "start: $start, end: $end, suggestion: $suggestion, text: $text";
  }
}
