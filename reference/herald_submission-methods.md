# Access and modify herald_submission properties

S3 methods for `$`, `$<-`, `[[`, and `print` on `herald_submission`
objects. `$` provides derived views (`xpt_files`, `json_files`,
`define_path`, `report_paths`) in addition to the raw S7 properties.

## Usage

``` r
# S3 method for class 'herald_submission'
x$name

# S3 method for class 'herald_submission'
x$name <- value

# S3 method for class 'herald_submission'
x[[i, ...]]

# S3 method for class 'herald_submission'
print(x, ...)
```

## Arguments

- x:

  A `herald_submission` object.

- name:

  Property name.

- value:

  Replacement value.

- i:

  Index (character).

- ...:

  Passed to underlying methods.

## Value

`$` returns the property value or a derived field. `$<-` returns the
modified object. `[[` returns the property value. `print` returns `x`
invisibly.

## See also

Other methods:
[`print.herald_define()`](https://vthanik.github.io/herald/reference/print.herald_define.md),
[`print.herald_dict_provider()`](https://vthanik.github.io/herald/reference/print.herald_dict_provider.md),
[`print.herald_result()`](https://vthanik.github.io/herald/reference/print.herald_result.md),
[`print.herald_spec()`](https://vthanik.github.io/herald/reference/print.herald_spec.md),
[`summary.herald_result()`](https://vthanik.github.io/herald/reference/summary.herald_result.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# `sub` is a herald_submission produced by an internal builder.
# Once obtained, use `$` to read raw S7 properties or derived views:

sub$output_dir       # raw S7 property
sub$herald_version
sub$timestamp

sub$xpt_files        # derived: character vector of XPT paths
sub$json_files       # derived: character vector of JSON paths
sub$define_path      # derived: single path or NULL
sub$report_paths     # derived: HTML / XLSX report paths

sub[["xpt_files"]]   # `[[` works identically to `$`

sub$files            # raw files table: path, type, size
} # }
```
