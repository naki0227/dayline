#![doc = "Platform-neutral domain contracts for the Dayline context engine."]

/// Current version of the cross-language context contract.
pub const CONTEXT_SCHEMA_VERSION: u32 = 1;

#[cfg(test)]
mod tests {
    use super::CONTEXT_SCHEMA_VERSION;

    #[test]
    fn schema_version_starts_at_one() {
        assert_eq!(CONTEXT_SCHEMA_VERSION, 1);
    }
}
