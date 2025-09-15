package com.example.face_recognition

data class EnhancedMatchResult(
    val cosineSimilarity: Float,
    val euclideanDistance: Float,
    val compositeSimilarity: Float,
    val confidence: ConfidenceLevel,
    val isMatch: Boolean,
    val matchType: MatchType,
    val qualityScore: Float,
)

enum class ConfidenceLevel {
    LOW,
    MEDIUM,
    HIGH,
    VERY_HIGH
}

enum class MatchType {
    SAME_PERSON_HIGH_CONFIDENCE,
    SAME_PERSON_MEDIUM_CONFIDENCE,
    DIFFERENT_PEOPLE
}