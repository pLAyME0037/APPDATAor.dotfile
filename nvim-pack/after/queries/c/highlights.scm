;; extends

;; 1. Function definitions & declarators -> @function (func color)
(function_declarator
  declarator: (identifier) @function)

(function_definition
  declarator: (pointer_declarator
    declarator: (function_declarator
      declarator: (identifier) @function)))

;; 2. Regular and pointer parameters -> @variable.parameter
(parameter_declaration
  declarator: (identifier) @variable.parameter)

;; Handles single pointer: (char *buf)
(parameter_declaration
  declarator: (pointer_declarator
    declarator: (identifier) @variable.parameter))

;; Handles double pointer: (char **argv)
(parameter_declaration
  declarator: (pointer_declarator
    declarator: (pointer_declarator
      declarator: (identifier) @variable.parameter)))
