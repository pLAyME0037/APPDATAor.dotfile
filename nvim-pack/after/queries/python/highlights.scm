;; extends

;; 1. Module and package names in import statements
(import_statement
  name: (dotted_name (identifier) @module))

(import_from_statement
  module_name: (dotted_name (identifier) @module))

(import_from_statement
  name: (dotted_name (identifier) @type))

(aliased_import
  name: (dotted_name (identifier) @module))

;; 2. Magic / Dunder methods (__init__, __str__, __repr__, etc.)
((identifier) @constructor
  (#lua-match? @constructor "^__[a-zA-Z0-9_]+__$"))

;; 3. Keyword arguments in function calls: func(key=val)
(keyword_argument
  name: (identifier) @variable.parameter)
