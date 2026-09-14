#![doc = "Deterministic, platform-neutral relevance scoring."]

use time::OffsetDateTime;

pub struct RankingCandidate<'a> {
    pub text: &'a str,
    pub occurred_at: OffsetDateTime,
    pub source_weight: f64,
}

pub struct RelevanceRanker {
    reference_time: OffsetDateTime,
    normalized_hint: Option<String>,
}

impl RelevanceRanker {
    #[must_use]
    pub fn new(reference_time: OffsetDateTime, project_hint: Option<&str>) -> Self {
        Self {
            reference_time,
            normalized_hint: project_hint.map(str::to_lowercase),
        }
    }

    #[must_use]
    pub fn score(&self, candidate: &RankingCandidate<'_>) -> f64 {
        let age_seconds = (self.reference_time - candidate.occurred_at)
            .whole_seconds()
            .max(0);
        #[allow(clippy::cast_precision_loss)]
        let age_hours = age_seconds as f64 / 3600.0;
        let recency = 1.0 / (1.0 + age_hours / 24.0);
        let source = if candidate.source_weight.is_finite() {
            candidate.source_weight.clamp(0.0, 1.0)
        } else {
            0.0
        };
        let hint = self.normalized_hint.as_ref().map_or(0.0, |hint| {
            if candidate.text.to_lowercase().contains(hint) {
                0.2
            } else {
                0.0
            }
        });
        (recency * 0.55 + source * 0.25 + hint).clamp(0.0, 1.0)
    }
}

#[cfg(test)]
mod tests {
    use time::macros::datetime;

    use super::{RankingCandidate, RelevanceRanker};

    #[test]
    fn recent_and_matching_context_ranks_higher() {
        let ranker = RelevanceRanker::new(datetime!(2026-09-14 12:00:00 UTC), Some("dayline"));
        let recent = ranker.score(&RankingCandidate {
            text: "Dayline contract work",
            occurred_at: datetime!(2026-09-14 11:00:00 UTC),
            source_weight: 0.8,
        });
        let old = ranker.score(&RankingCandidate {
            text: "Unrelated work",
            occurred_at: datetime!(2026-09-07 12:00:00 UTC),
            source_weight: 0.8,
        });
        assert!(recent > old);
    }

    #[test]
    fn score_is_bounded_for_invalid_weights_and_future_dates() {
        let ranker = RelevanceRanker::new(datetime!(2026-09-14 12:00:00 UTC), None);
        for weight in [f64::NAN, -10.0, 10.0] {
            let score = ranker.score(&RankingCandidate {
                text: "context",
                occurred_at: datetime!(2026-09-15 12:00:00 UTC),
                source_weight: weight,
            });
            assert!((0.0..=1.0).contains(&score));
        }
    }
}
