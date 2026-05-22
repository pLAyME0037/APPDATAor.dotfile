import 'dart:math';

import 'package:flutter/foundation.dart';

class CalculatorModel extends ChangeNotifier {
  String  _display           = '0';
  double? _operand;
  String? _operator;
  double? _lastOperand;
  String? _lastOperator;
  bool    _waitingForOperand = false;
  bool    _justEvaluated     = false;
  bool    _error             = false;

  String get display => _display;

  String get clearLabel {
    if (!_error && _display == '0' && _operator == null && !_justEvaluated) {
      return 'AC';
    }
    return 'C';
  }

  void _formatDisplay(double value) {
    if (value.isNaN || value.isInfinite) {
      _display = 'Error';
      _error = true;
      return;
    }
    String str = value.toString();
    if (str.endsWith('.0')) {
      _display = str.substring(0, str.length - 2);
      return;
    } 
    int dotIndex = str.indexOf('.');
    if (dotIndex == -1 || str.length - dotIndex <= 10) {
      _display = str;
      return;
    }
    str = value.toStringAsFixed(10);
    str = str.replaceAll(RegExp(r'0+$'), ''); // zero(s) end
    if (str.endsWith('.')) {
      str = str.substring(0, str.length - 1);
    }
    _display = str;
  }

  void inputDigit(String digit) {
    if (_error) { clear(); return; }
    if (_justEvaluated || _waitingForOperand) {
      _display = digit;
      _justEvaluated = false;
      _waitingForOperand = false;
      return;
    }
    if (_display == '0') {
      _display = digit;
    } else {
      _display += digit;
    }
    notifyListeners();
  }

  void inputDecimal() {
    if (_error) { clear(); return; }
    if (_justEvaluated || _waitingForOperand) {
      _display = '0.';
      _justEvaluated = false;
      _waitingForOperand = false;
    } else if (!_display.contains('.')) {
      _display += '.';
    }
    notifyListeners();
  }

  void _compute() {
    if (_operator == null || _operand == null) return;
    double second = double.parse(_display);
    double result;
    switch (_operator) {
    case '+': result = _operand! + second; break;
    case '−': result = _operand! - second; break;
    case '×': result = _operand! * second; break;
    case '%': result = _operand! % second; break;
    case '^': result = pow(_operand!, second) as double; break;
    case '÷':
      if (second == 0) {
        _display = 'Error';
        _error = true;
        notifyListeners();
        return;
      }
      result = _operand! / second;
    break;
    default: return;
    }
    _operand = result;
    _formatDisplay(result);
  }

  void evaluate() {
    if (_error) return;
    if (_justEvaluated && (_lastOperator == null || _lastOperand == null)) return;
    if (_justEvaluated) {
      double current = double.parse(_display);
      double result;
      switch (_lastOperator) {
      case '+': result = current + _lastOperand!; break;
      case '−': result = current - _lastOperand!; break;
      case '×': result = current * _lastOperand!; break;
      case '%': result = current % _lastOperand!; break;
      case '÷':
        if (_lastOperand == 0) {
          _display = 'Error';
          _error = true;
          notifyListeners();
          return;
        }
        result = current / _lastOperand!;
      break;
      case '^': 
        result = pow(current, _lastOperand!) as double; 
      break;
      default: return;
      }
      _operand = result;
      _formatDisplay(result);
      notifyListeners();
      return;
    }
    if (_operator == null) return;
    _lastOperand  = double.parse(_display);
    _lastOperator = _operator;
    _compute();
    _operator = null;
    _justEvaluated = true;
    notifyListeners();
  }

  void inputOperator(String op) {
    if (_error) return;
    if (_justEvaluated) {
      _operand = double.parse(_display);
      _operator = op;
      _lastOperator = op;
      _waitingForOperand = true;
      _justEvaluated = false;
      notifyListeners();
      return;
    }
    if (_operator == null) { _operand = double.parse(_display); } 
    else if (!_waitingForOperand) { _compute(); }
    _operator = op;
    _waitingForOperand = true;
    _justEvaluated = false;
    notifyListeners();
  }

  void clear() {
    _display = '0';
    _operand = null;
    _operator = null;
    _lastOperand = null;
    _lastOperator = null;
    _waitingForOperand = false;
    _justEvaluated = false;
    _error = false;
    notifyListeners();
  }

  void clearEntry() {
    _display = '0';
    _waitingForOperand = true;
    _error = false;
    notifyListeners();
  }

  void backspace() {
    if (_error) { clear(); return; }
    if (_justEvaluated || _waitingForOperand) return;
    if (_display.length > 1) {
      _display = _display.substring(0, _display.length - 1);
    } else {
      _display = '0';
    }
    notifyListeners();
  }

  void negate() {
    if (_error || _display == '0') return;
    if (_display.startsWith('-')) {
      _display = _display.substring(1);
    } else {
      _display = '-$_display';
    }
    notifyListeners();
  }

  void sqrtOp() {
    if (_error) return;
    double value = double.parse(_display);
    _formatDisplay(sqrt(value));
    _justEvaluated = true;
    notifyListeners();
  }

  void percent() {
    if (_error) return;
    double value = double.parse(_display) / 100;
    _formatDisplay(value);
    notifyListeners();
  }
}
