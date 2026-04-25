# IEEE 754 <-> IBM 370 floating-point conversion
# All functions are @noRd (not exported)
#
# IBM 370 double (8 bytes):
#   Bit 0:     sign (0=positive, 1=negative)
#   Bits 1-7:  exponent (biased by 64, base-16)
#   Bits 8-63: fraction (56 bits, base-16 normalised)
#
# IEEE 754 double (8 bytes):
#   Bit 0:      sign (0=positive, 1=negative)
#   Bits 1-11:  exponent (biased by 1023, base-2)
#   Bits 12-63: fraction (52 bits, implicit leading 1)

#' SAS missing value byte pattern for standard missing (.)
#' @noRd
sas_missing_raw <- function() {
  as.raw(c(0x2E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
}

#' All SAS special missing byte patterns (.A-.Z, ._, .)
#' First byte is the ASCII code of the missing indicator
#' @noRd
sas_missing_patterns <- function() {
  # . = 0x2E, ._ = 0x5F, .A = 0x41, .B = 0x42, ..., .Z = 0x5A
  first_bytes <- c(
    0x2E, # .
    0x5F, # ._
    seq.int(0x41, 0x5A) # .A through .Z
  )
  lapply(first_bytes, function(b) {
    as.raw(c(b, rep(0x00, 7L)))
  })
}

#' Check if 8 raw bytes represent a SAS missing value
#' @noRd
is_sas_missing <- function(raw8) {
  # All SAS missing values have bytes 2-8 as zero and byte 1 is the indicator
  if (!all(raw8[2:8] == as.raw(0x00))) {
    return(FALSE)
  }
  first <- as.integer(raw8[1L])
  # Standard missing (0x2E), underscore missing (0x5F), or .A-.Z (0x41-0x5A)
  first == 0x2EL || first == 0x5FL || (first >= 0x41L && first <= 0x5AL)
}

#' Convert IEEE 754 doubles to IBM 370 format (vectorised)
#'
#' @param x Numeric vector
#' @return Raw vector of length `8 * length(x)`
#' @noRd
ieee_to_ibm <- function(x) {
  x <- vctrs::vec_cast(x, double())
  n <- length(x)
  if (n == 0L) {
    return(raw(0L))
  }

  result <- raw(8L * n)

  # -- Special values -> SAS missing (NA, NaN, Inf, -Inf) --------------------
  is_special <- !is.finite(x) # TRUE for NA, NaN, Inf, -Inf
  if (any(is_special)) {
    sp_pos <- which(is_special)
    dest_sp <- as.integer(outer(0L:7L, (sp_pos - 1L) * 8L + 1L, "+"))
    result[dest_sp] <- rep(sas_missing_raw(), length(sp_pos))
  }

  # -- Non-zero regular values -----------------------------------------------
  # Zeros stay as raw(0) (already zero-initialised).
  is_nz <- !is_special & x != 0
  if (!any(is_nz)) {
    return(result)
  }

  xnz <- x[is_nz]
  nnz <- length(xnz)

  # Get all IEEE big-endian bytes at once (one writeBin for the whole vector).
  ieee_bytes <- writeBin(xnz, raw(), size = 8L, endian = "big")
  m <- matrix(as.integer(ieee_bytes), nrow = 8L) # 8 x nnz integer matrix

  b1 <- m[1L, ]
  b2 <- m[2L, ]

  sign_bit <- bitwShiftR(b1, 7L)
  ieee_exp <- bitwOr(bitwShiftL(bitwAnd(b1, 0x7FL), 4L), bitwShiftR(b2, 4L))
  fexp <- ieee_exp - 1023L

  # IEEE: value = 2^fexp x mantissa   IBM: value = 16^(ibm_exp-64) x ibm_frac/2^56
  # ibm_exp = 64 + ceil((fexp+1)/4);   lshift = fexp+4 - 4(ibm_exp-64)  in {0,1,2,3}
  ibm_exp <- 64L + ((fexp + 4L) %/% 4L) # equiv. 64 + ceil((fexp+1)/4)
  lshift <- fexp + 4L - 4L * (ibm_exp - 64L)

  # Classify within the nonzero set
  is_subnorm <- ieee_exp == 0L # treat as zero (leave zeroed)
  is_overflow <- ibm_exp > 127L # -> SAS missing
  is_underflow <- ibm_exp < 0L # -> zero (leave zeroed)
  is_reg <- !is_subnorm & !is_overflow & !is_underflow

  # Overflow -> SAS missing
  if (any(is_overflow)) {
    ov_global <- which(is_nz)[is_overflow]
    dest_ov <- as.integer(outer(0L:7L, (ov_global - 1L) * 8L + 1L, "+"))
    result[dest_ov] <- rep(sas_missing_raw(), sum(is_overflow))
  }

  if (!any(is_reg)) {
    return(result)
  }

  # -- Regular values: build 8 x nreg output matrix -------------------------
  frac_m <- m[2:8, is_reg, drop = FALSE] # 7 x nreg (bytes 2-8 = mantissa)
  ib_exp <- ibm_exp[is_reg]
  ls <- lshift[is_reg]
  sb <- sign_bit[is_reg]

  # Set implicit leading 1 and clear exponent bits from byte 2 (row 1 of frac_m)
  frac_m[1L, ] <- bitwOr(bitwAnd(frac_m[1L, ], 0x0FL), 0x10L)

  # Left-shift the 7-byte mantissa by ls bits (0-3) to align to IBM hex digits.
  # bitwShiftL/R accept vector shift amounts  --  one vectorised call per row pair.
  # When ls == 0: (x << 0 | y >> 8) & 0xFF = x (no-op, correct).
  for (j in seq_len(6L)) {
    frac_m[j, ] <- bitwAnd(
      bitwOr(
        bitwShiftL(frac_m[j, ], ls),
        bitwShiftR(frac_m[j + 1L, ], 8L - ls)
      ),
      0xFFL
    )
  }
  frac_m[7L, ] <- bitwAnd(bitwShiftL(frac_m[7L, ], ls), 0xFFL)

  # Assemble: byte1 = sign|ibm_exp, bytes 2-8 = shifted mantissa
  out_m <- rbind(bitwOr(bitwShiftL(sb, 7L), ib_exp), frac_m) # 8 x nreg

  # as.integer(out_m) is column-major = obs1_b1...obs1_b8, obs2_b1... (ok)
  reg_global <- which(is_nz)[is_reg]
  dest_reg <- as.integer(outer(0L:7L, (reg_global - 1L) * 8L + 1L, "+"))
  result[dest_reg] <- as.raw(as.integer(out_m))

  result
}

#' Convert IBM 370 format to IEEE 754 doubles (vectorised)
#'
#' @param raw_vec Raw vector (must be multiple of 8 in length)
#' @return Numeric vector of length `length(raw_vec) / 8`
#' @noRd
ibm_to_ieee <- function(raw_vec) {
  n <- length(raw_vec) %/% 8L
  if (n == 0L) {
    return(numeric(0L))
  }

  # Reshape to 8 x n integer matrix  --  each column is one IBM double
  m <- matrix(as.integer(raw_vec), nrow = 8L) # 8 x n

  b1 <- m[1L, ] # first byte of every value

  # -- Special value masks ---------------------------------------------------
  col_sums <- colSums(m)
  lower_sums <- colSums(m[2:8, , drop = FALSE])

  is_zero <- col_sums == 0L
  is_missing <- lower_sums == 0L &
    (b1 == 0x2EL | b1 == 0x5FL | (b1 >= 0x41L & b1 <= 0x5AL))
  regular <- !is_zero & !is_missing

  result <- numeric(n)
  result[is_missing] <- NA_real_
  # zeros and non-regular values stay 0

  # -- Tag each missing with its SAS indicator character --------------------
  # sas_missing attr: character vector, NA_character_ for non-missing slots.
  #   0x2E       -> "."   (standard missing)
  #   0x41--0x5A  -> ".A"--".Z" (extended special missing)
  #   0x5F       -> "._"  (underscore missing)
  if (any(is_missing)) {
    tags <- rep(NA_character_, n)
    miss_b1 <- b1[is_missing]
    tags[is_missing] <- ifelse(
      miss_b1 == 0x2EL,
      ".",
      ifelse(
        miss_b1 == 0x5FL,
        "._",
        paste0(".", intToUtf8(miss_b1, multiple = TRUE))
      )
    )
    attr(result, "sas_missing") <- tags
  }

  if (!any(regular)) {
    return(result)
  }

  # -- Vectorised IBM -> IEEE conversion for regular values ------------------
  #
  # IBM 370 double: value = (-1)^s x 16^(E-64) x F
  #   where F = fraction bytes interpreted as base-256 fraction:
  #   F = (b2x256^6 + b3x256^5 + ... + b8x256^0) / 256^7
  #
  # No bit-shifting needed  --  pure floating-point arithmetic.

  reg_m <- m[, regular, drop = FALSE]
  reg_b1 <- b1[regular]

  sign_v <- ifelse(reg_b1 >= 128L, -1, 1) # bit 7 of b1
  ibm_exp <- reg_b1 - sign_v * 128L * (sign_v < 0) # clear sign bit
  ibm_exp <- reg_b1 %% 128L # low 7 bits = exponent

  # Fraction: weighted sum of bytes 2--8 as a base-256 fraction
  weights <- 256^(6:0) # 256^6 ... 256^0
  frac_val <- colSums(reg_m[2:8, , drop = FALSE] * weights) / (256^7)

  result[regular] <- sign_v * (16^(ibm_exp - 64L)) * frac_val

  result
}
