# value-arith-check

## Intent

*"`<TARGET>` = `<MINUEND>` - `<SUBTRAHEND>`"* (change-from-baseline)
or *"`<TARGET>` = ((`<MINUEND>` - `<SUBTRAHEND>`) / `<DENOMINATOR>`) * 100"*
(percent change). Fires when the stored value doesn't match the
computed value within a small epsilon (P21 fuzzy-eq default 0.001).

Canonical message forms:
 - `<TARGET> is populated and is not equal to <MINUEND> - <SUBTRAHEND>`
 - `<TARGET> is populated and is not equal to ((<MINUEND> - <SUBTRAHEND>)/<DENOM>)*100`

## CDISC source

ADaM-IG Section 3.3 (Basic Data Structure) standard derived
variables:
- CHG = AVAL - BASE (ADaM-223)
- PCHG = ((AVAL - BASE) / BASE) * 100 (ADaM-225)
- BCHG = BASE - AVAL (ADaM-582; reversed operands)
- PBCHG = ((BASE - AVAL) / AVAL) * 100 (ADaM-586; reversed)

## P21 conceptual parallel (reference only)

P21 uses the DSL functions `:DIFF(a, b)` and `:PCTDIFF(a, b)` with
the fuzzy-eq operator `@feq`:

```
val:Condition PublisherID="AD0223"
  Test = CHG @feq :DIFF(AVAL, BASE)
  When = CHG != '' @and AVAL != '' @and BASE != ''

val:Condition PublisherID="AD0225"
  Test = PCHG @feq :PCTDIFF(AVAL, BASE)
  When = PCHG != '' @and AVAL != '' @and BASE != '' @and BASE != '0'
```

`@feq` epsilon default is 0.001
(Comparison.java:38 `DEFAULT_EPSILON = 0.001`); configurable via
`Engine.FuzzyTolerance`. herald's `op_is_not_diff` and
`op_is_not_pct_diff` implement the arithmetic directly in R with
the same default epsilon.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| Fuzzy-equality `@feq` uses BigDecimal subtraction with epsilon tolerance | `Comparison.java:183-192 nearlyEqual` | `.nearly_equal` uses `abs(a - b) <= epsilon` on double-precision R numerics; matches P21's semantic for the range of CDISC values. |
| Default epsilon 0.001 | `Comparison.java:38` | `op_is_not_diff` / `op_is_not_pct_diff` default `epsilon = 0.001`. Matches. |
| `Engine.FuzzyTolerance` override | `Comparison.java:114-117` | herald's ops accept `epsilon` slot on the check_tree leaf; per-rule override. |
| Div-by-zero guard on PCHG when BASE=0 -- P21 `When="BASE != '0'"` | XML When clause | herald's op returns NA when `denominator == 0` (div-by-zero -> NA -> advisory). |
| NA on any of target/minuend/subtrahend -> Test fails? P21: `hasValue() == false` -> Test false -> rule passes? Actually P21's NullComparison on `@feq` returns false -> Test fails -> fire | `Comparison.java:165-180 + NullComparison` | herald's `.nearly_equal` returns NA on any NA input; under a single leaf, NA -> advisory (not fire). **More conservative** than P21: herald emits advisory on missing inputs rather than fires. Documented. |
| Epsilon-aware compare vs strict `==` | P21's `==` path would not use epsilon | herald's `op_is_not_diff` always uses epsilon for safety; CDISC arithmetic involves fractions (percent change), so epsilon is essential. Matches P21's `@feq` choice for these specific rules. |
| `:DIFF` / `:PCTDIFF` DSL function names | `Functions.java` + alias table | Not DSL-copied; herald ops named by semantic (`is_not_diff`, `is_not_pct_diff`). |

## herald check_tree template (subtract)

```yaml check_tree
operator: is_not_diff
name: %target%
minuend: %minuend%
subtrahend: %subtrahend%
```

## herald check_tree template (pct_diff)

The pct_diff rules need a different template; authored per-rule.

## Expected outcome

- Positive: target stored with a value >0.001 off from the computed
  (minuend - subtrahend) -> fires.
- Negative: target matches computed within epsilon -> no fire.
- Either side missing -> NA -> advisory (no false fire).

## Batch scope

4 rules: ADaM-223 (CHG), ADaM-225 (PCHG), ADaM-582 (BCHG),
ADaM-586 (PBCHG). Two different templates are used (diff vs
pct_diff); ids CSV carries an `operator` slot.
