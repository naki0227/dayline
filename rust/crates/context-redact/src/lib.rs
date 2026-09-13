#![doc = "Deterministic secret redaction before context persistence."]

use regex::{Captures, Regex};
use thiserror::Error;

const MASK: &str = "***";

#[derive(Debug, Error)]
pub enum RedactionError {
    #[error("built-in redaction pattern {name} is invalid")]
    InvalidPattern {
        name: &'static str,
        #[source]
        source: regex::Error,
    },
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RedactedText {
    value: String,
    redaction_count: usize,
}

impl RedactedText {
    #[must_use]
    pub fn value(&self) -> &str {
        &self.value
    }

    #[must_use]
    pub const fn redaction_count(&self) -> usize {
        self.redaction_count
    }
}

struct Rule {
    regex: Regex,
    replacement: Replacement,
}

enum Replacement {
    EntireMatch,
    PreservePrefix,
}

pub struct SecretRedactor {
    rules: Vec<Rule>,
}

impl SecretRedactor {
    /// Builds the built-in redaction policy.
    ///
    /// # Errors
    ///
    /// Returns [`RedactionError`] if a built-in regular expression cannot compile.
    pub fn new() -> Result<Self, RedactionError> {
        Ok(Self {
            rules: vec![
                rule(
                    "secret assignment",
                    r#"(?i)(\b(?:(?:[A-Z][A-Z0-9]*_)*(?:KEY|TOKEN|PASSWORD|SECRET)|APIKEY|ACCESSTOKEN)\b\s*=\s*)('[^']*'|"[^"]*"|[^\s;&|]+)"#,
                    Replacement::PreservePrefix,
                )?,
                rule(
                    "authorization bearer",
                    r"(?i)(\bauthorization\s*:\s*bearer\s+)([A-Za-z0-9._~+/=-]+)",
                    Replacement::PreservePrefix,
                )?,
                rule(
                    "github token",
                    r"\bgh[pousr]_[A-Za-z0-9_]{20,}\b",
                    Replacement::EntireMatch,
                )?,
                rule(
                    "aws access key",
                    r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b",
                    Replacement::EntireMatch,
                )?,
                rule(
                    "private key",
                    r"(?s)-----BEGIN [^-\r\n]*PRIVATE KEY-----.*?-----END [^-\r\n]*PRIVATE KEY-----",
                    Replacement::EntireMatch,
                )?,
            ],
        })
    }

    #[must_use]
    pub fn redact(&self, input: &str) -> RedactedText {
        let mut value = input.to_owned();
        let mut redaction_count = 0;
        for rule in &self.rules {
            let mut matches = 0;
            value = match rule.replacement {
                Replacement::EntireMatch => rule
                    .regex
                    .replace_all(&value, |_captures: &Captures<'_>| {
                        matches += 1;
                        MASK
                    })
                    .into_owned(),
                Replacement::PreservePrefix => rule
                    .regex
                    .replace_all(&value, |captures: &Captures<'_>| {
                        matches += 1;
                        format!(
                            "{}{}",
                            captures.get(1).map_or("", |value| value.as_str()),
                            MASK
                        )
                    })
                    .into_owned(),
            };
            redaction_count += matches;
        }
        RedactedText {
            value,
            redaction_count,
        }
    }
}

fn rule(
    name: &'static str,
    pattern: &str,
    replacement: Replacement,
) -> Result<Rule, RedactionError> {
    let regex =
        Regex::new(pattern).map_err(|source| RedactionError::InvalidPattern { name, source })?;
    Ok(Rule { regex, replacement })
}

#[cfg(test)]
mod tests {
    use super::SecretRedactor;

    #[test]
    fn redacts_assignments_and_preserves_names() -> Result<(), Box<dyn std::error::Error>> {
        let result = SecretRedactor::new()?.redact(
            "export API_KEY=value123 GITHUB_TOKEN='abc def' password=hunter2 ordinary=safe",
        );
        assert_eq!(
            result.value(),
            "export API_KEY=*** GITHUB_TOKEN=*** password=*** ordinary=safe"
        );
        assert_eq!(result.redaction_count(), 3);
        Ok(())
    }

    #[test]
    fn redacts_bearer_and_provider_tokens() -> Result<(), Box<dyn std::error::Error>> {
        let input =
            "Authorization: Bearer abc.def-123 ghp_abcdefghijklmnopqrstuvwxyz AKIA1234567890ABCDEF";
        let result = SecretRedactor::new()?.redact(input);
        assert_eq!(result.value(), "Authorization: Bearer *** *** ***");
        assert_eq!(result.redaction_count(), 3);
        Ok(())
    }

    #[test]
    fn redacts_multiline_private_keys() -> Result<(), Box<dyn std::error::Error>> {
        let input =
            "before\n-----BEGIN PRIVATE KEY-----\nsensitive\n-----END PRIVATE KEY-----\nafter";
        let result = SecretRedactor::new()?.redact(input);
        assert_eq!(result.value(), "before\n***\nafter");
        assert_eq!(result.redaction_count(), 1);
        Ok(())
    }

    #[test]
    fn leaves_non_secret_commands_unchanged() -> Result<(), Box<dyn std::error::Error>> {
        let input = "cargo test --workspace";
        let result = SecretRedactor::new()?.redact(input);
        assert_eq!(result.value(), input);
        assert_eq!(result.redaction_count(), 0);
        Ok(())
    }
}
