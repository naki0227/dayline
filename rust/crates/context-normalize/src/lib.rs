#![doc = "Deterministic text normalization for model-ready context."]

use thiserror::Error;

#[derive(Debug, Error, Eq, PartialEq)]
pub enum NormalizationError {
    #[error("context content is too large to measure")]
    ContentTooLarge,
}

#[must_use]
pub fn normalize_model_text(input: &str) -> String {
    input
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .collect::<Vec<_>>()
        .join("\n")
}

#[must_use]
pub fn deduplication_key(input: &str) -> String {
    input
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase()
}

/// Estimates tokens without depending on a model-specific tokenizer.
///
/// Swift must measure the assembled bundle with the selected Apple model and may
/// request another shrink pass. The estimate deliberately rounds up.
///
/// # Errors
///
/// Returns an error only when the platform string length cannot fit in `u64`.
pub fn estimate_tokens(input: &str) -> Result<u64, NormalizationError> {
    let characters =
        u64::try_from(input.chars().count()).map_err(|_| NormalizationError::ContentTooLarge)?;
    Ok(characters.div_ceil(4).max(1))
}

#[cfg(test)]
mod tests {
    use super::{deduplication_key, estimate_tokens, normalize_model_text};

    #[test]
    fn normalizes_lines_without_destroying_structure() {
        assert_eq!(
            normalize_model_text("  first  \n\n second line \n"),
            "first\nsecond line"
        );
    }

    #[test]
    fn deduplication_ignores_case_and_whitespace() {
        assert_eq!(
            deduplication_key(" Dayline\n  CONTEXT "),
            deduplication_key("dayline context")
        );
    }

    #[test]
    fn token_estimate_rounds_up_and_never_returns_zero() {
        assert_eq!(estimate_tokens("").ok(), Some(1));
        assert_eq!(estimate_tokens("12345").ok(), Some(2));
    }
}
