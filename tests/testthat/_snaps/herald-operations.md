# .register_operation() error snapshot for non-character name

    Code
      herald:::.register_operation(123L, fn)
    Condition
      Error:
      ! `name` must be a non-empty scalar character string.

