// FaceRecognitionPlugin.kt
package com.example.my_face
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import com.example.face_recognition.ConfidenceLevel
import com.example.face_recognition.EnhancedMatchResult
import com.example.face_recognition.MatchType
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import kotlin.math.*
import androidx.core.graphics.scale

class FaceNetHelper(private val context: Context) {

    private var interpreter: Interpreter
    private var inputImageWidth: Int
    private var inputImageHeight: Int
    private var embeddingSize: Int

    init {
        val model = loadModelFile("facenetid.tflite")
        interpreter = Interpreter(model)

        val inputShape = interpreter.getInputTensor(0).shape()
        inputImageWidth = inputShape[1]
        inputImageHeight = inputShape[2]

        val outputShape = interpreter.getOutputTensor(0).shape()
        embeddingSize = outputShape[1]
    }

    private fun loadModelFile(modelName: String): MappedByteBuffer {
        val fileDescriptor = context.assets.openFd(modelName)
        FileInputStream(fileDescriptor.fileDescriptor).use { inputStream ->
            val fileChannel = inputStream.channel
            val startOffset = fileDescriptor.startOffset
            val declaredLength = fileDescriptor.declaredLength
            return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
        }
    }

    fun getFaceEmbedding(bitmap: Bitmap): FloatArray {
        val enhancedBitmap = enhanceImageQuality(bitmap)
        val resized = enhancedBitmap.scale(inputImageWidth, inputImageHeight)
        val inputBuffer = convertBitmapToBuffer(resized)

        val output = Array(1) { FloatArray(embeddingSize) }
        interpreter.run(inputBuffer, output)

        return enhancedL2Normalize(output[0])
    }

    private fun enhanceImageQuality(bitmap: Bitmap): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
        val enhancedPixels = IntArray(pixels.size)
        for (i in pixels.indices) {
            val pixel = pixels[i]
            val r = (Color.red(pixel) * 1.1).coerceIn(0.0, 255.0).toInt()
            val g = (Color.green(pixel) * 1.1).coerceIn(0.0, 255.0).toInt()
            val b = (Color.blue(pixel) * 1.1).coerceIn(0.0, 255.0).toInt()
            enhancedPixels[i] = Color.rgb(r, g, b)
        }
        return Bitmap.createBitmap(enhancedPixels, width, height, Bitmap.Config.ARGB_8888)
    }

    private fun calculateCosineSimilarity(embedding1: FloatArray, embedding2: FloatArray): Float {
        var dot = 0f
        var norm1 = 0f
        var norm2 = 0f
        for (i in embedding1.indices) {
            dot += embedding1[i] * embedding2[i]
            norm1 += embedding1[i] * embedding1[i]
            norm2 += embedding2[i] * embedding2[i]
        }
        return if (norm1 > 0 && norm2 > 0) dot / (sqrt(norm1) * sqrt(norm2)) else 0f
    }

    private fun calculateEuclideanDistance(embedding1: FloatArray, embedding2: FloatArray): Float {
        var distance = 0f
        for (i in embedding1.indices) {
            val diff = embedding1[i] - embedding2[i]
            distance += diff * diff
        }
        return sqrt(distance)
    }

    fun getMatchingConfidence(embedding1: FloatArray, embedding2: FloatArray): EnhancedMatchResult {
        // Calculate the metrics here, before they are used in the return statement.
        val cosineSimilarity = calculateCosineSimilarity(embedding1, embedding2)
        val euclideanDist = calculateEuclideanDistance(embedding1, embedding2) // This is the missing line.
        val variance = calculateVariance(embedding1) // assuming similar variance for both

        val confidence = evaluateConfidenceLevel(cosineSimilarity, euclideanDist, variance)
        val isMatch = determineMatch(cosineSimilarity, euclideanDist, confidence, variance)
        val matchType = categorizeMatchType(cosineSimilarity, euclideanDist, confidence)

        return EnhancedMatchResult(
            cosineSimilarity = cosineSimilarity,
            euclideanDistance = euclideanDist, // Now this variable is defined and can be used.
            compositeSimilarity = cosineSimilarity, // simple for this example
            confidence = confidence,
            isMatch = isMatch,
            matchType = matchType,
            qualityScore = variance
        )
    }

    private fun calculateVariance(embedding: FloatArray): Float {
        val mean = embedding.average().toFloat()
        var variance = 0f
        for (value in embedding) {
            variance += (value - mean) * (value - mean)
        }
        return variance / embedding.size
    }

    private fun evaluateConfidenceLevel(cosineSim: Float, euclideanDist: Float, variance: Float): ConfidenceLevel {
        var score = 0
        when {
            cosineSim > 0.90f -> score += 4
            cosineSim > 0.80f -> score += 3
            cosineSim > 0.70f -> score += 2
            else -> score += 0
        }
        when {
            euclideanDist < 0.5f -> score += 4
            euclideanDist < 1.0f -> score += 3
            euclideanDist < 1.5f -> score += 2
            else -> score += 0
        }
        when {
            variance > 0.01f -> score += 2
            variance > 0.005f -> score += 1
            else -> score += 0
        }

        return when {
            score >= 8 -> ConfidenceLevel.VERY_HIGH
            score >= 6 -> ConfidenceLevel.HIGH
            score >= 4 -> ConfidenceLevel.MEDIUM
            else -> ConfidenceLevel.LOW
        }
    }

    private fun determineMatch(
        cosineSim: Float,
        euclideanDist: Float,
        confidence: ConfidenceLevel,
        variance: Float
    ): Boolean {
        val qualityMultiplier = if (variance > 0.01f) 1.0f else 0.9f
        val adjustedThreshold = 0.75f * qualityMultiplier
        return cosineSim > adjustedThreshold && euclideanDist < 1.2f
    }

    private fun categorizeMatchType(
        cosineSim: Float,
        euclideanDist: Float,
        confidence: ConfidenceLevel
    ): MatchType {
        return when {
            confidence >= ConfidenceLevel.VERY_HIGH && cosineSim > 0.85f && euclideanDist < 0.8f ->
                MatchType.SAME_PERSON_HIGH_CONFIDENCE
            confidence >= ConfidenceLevel.HIGH && cosineSim > 0.75f && euclideanDist < 1.2f ->
                MatchType.SAME_PERSON_MEDIUM_CONFIDENCE
            else ->
                MatchType.DIFFERENT_PEOPLE
        }
    }

    private fun convertBitmapToBuffer(bitmap: Bitmap): ByteBuffer {
        val inputSize = inputImageWidth * inputImageHeight * 3 * 4
        val byteBuffer = ByteBuffer.allocateDirect(inputSize)
        byteBuffer.order(ByteOrder.nativeOrder())

        val intValues = IntArray(inputImageWidth * inputImageHeight)
        bitmap.getPixels(intValues, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)

        var pixelIndex = 0
        for (y in 0 until inputImageHeight) {
            for (x in 0 until inputImageWidth) {
                val pixel = intValues[pixelIndex++]
                val r = (Color.red(pixel).toFloat() - 127.5f) / 127.5f
                val g = (Color.green(pixel).toFloat() - 127.5f) / 127.5f
                val b = (Color.blue(pixel).toFloat() - 127.5f) / 127.5f
                byteBuffer.putFloat(r)
                byteBuffer.putFloat(g)
                byteBuffer.putFloat(b)
            }
        }
        return byteBuffer
    }

    private fun enhancedL2Normalize(embedding: FloatArray): FloatArray {
        var norm = 0f
        for (v in embedding) {
            norm += v * v
        }
        norm = sqrt(norm)
        return if (norm > 1e-12f) {
            embedding.map { it / norm }.toFloatArray()
        } else {
            FloatArray(embedding.size) { 0f }
        }
    }
}