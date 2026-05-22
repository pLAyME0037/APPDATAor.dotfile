import 'package:flutter/material.dart';
import 'calculator_model.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final CalculatorModel _model = CalculatorModel();

  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () => setState(() {});
    _model.addListener(_listener);
  }

  @override
  void dispose() {
    _model.removeListener(_listener);
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculator')),
      body: Column(children: [
          Expanded(child: _buildDisplay()),
          Expanded(flex: 2, child: _buildButtons())
      ]
    ));
  }

  Widget _buildDisplay() {
    return Container(
      alignment: Alignment.bottomRight,
      padding: const EdgeInsets.all(24),
      child: Text(_model.display,
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w300),
                  maxLines: 2,));
  }

  Widget _buildButtons() {
    return Column(
      children: [
        _buildRow([_model.clearLabel, '±', '^', '%']),
        _buildRow(['000', '0.01', '√', '÷']),
        _buildRow(['7', '8', '9', '×']),
        _buildRow(['4', '5', '6', '−']),
        _buildRow(['1', '2', '3', '+']),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: FilledButton(
                    onPressed: () => _model.inputDigit('0'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontSize: 22),
                    ),
                    child: const Text('0'),
                  ),
                ),
              ),
              _buildButton('.'),
              _buildButton('='),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(List<String> labels) {
    return Expanded(child: Row(children: labels.map((l) => _buildButton(l)).toList()));
  }

  Widget _buildButton(String label) {
    return Expanded(child: Padding(padding: const EdgeInsets.all(4),
                                   child: _buttonWidget(label)));
  }

  Widget _buttonWidget(String label) {
    final bool isOperator = ['+', '−', '×', '÷', '='].contains(label);
    final bool isClear = label == 'AC' || label == 'C';
    final bool isEquals = label == '=';

    Color bgColor;
    Color fgColor;
    if (isOperator || isEquals) {
      bgColor = Colors.orange;
      fgColor = Colors.white;
    } else if (isClear) {
      bgColor = Colors.grey.shade300;
      fgColor = Colors.black87;
    } else {
      bgColor = Colors.grey.shade200;
      fgColor = Colors.black87;
    }

    return FilledButton(
      onPressed: () => _onButtonPressed(label),
      style: FilledButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          fontSize: isEquals ? 28 : 22,
          fontWeight: isOperator || isEquals ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      child: Text(label),
    );
  }

  void _onButtonPressed(String label) {
    switch (label) {
    case 'AC': _model.clear();              break;
    case 'C' : _model.clearEntry();         break;
    case '±' : _model.negate();             break;
    case '=' : _model.evaluate();           break;
    case '√' : _model.sqrtOp();             break;
    case '0.01': _model.percent();          break;
    case '+' :
    case '−' :
    case '×' :
    case '%' :
    case '^' :
    case '÷' : _model.inputOperator(label); break;
    case '.' : _model.inputDecimal();       break;
    default  : _model.inputDigit(label);
    }
  }
}
