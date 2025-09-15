package com.example.my_face

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.annotation.NonNull
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.IOException
import kotlin.math.max
import kotlin.math.min

class MainActivity : FlutterActivity() {

    private lateinit var faceNetHelper: FaceNetHelper
    private val CHANNEL = "com.example.my_face/facerecognition"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        faceNetHelper = FaceNetHelper(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "compareFaces" -> {
                    val bytes1 = call.argument<ByteArray>("bytes1")
                    val bytes2 = call.argument<ByteArray>("bytes2")

                    if (bytes1 == null || bytes2 == null) {
                        result.error("INVALID_ARGUMENT", "One or both image bytes are missing.", null)
                        return@setMethodCallHandler
                    }

                    // Use a Coroutine to perform heavy work on a background thread
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val bitmap1 = BitmapFactory.decodeByteArray(bytes1, 0, bytes1.size)
                            val bitmap2 = BitmapFactory.decodeByteArray(bytes2, 0, bytes2.size)
                            val cropped1 = cropFace(bitmap1)
                            val cropped2 = cropFace(bitmap2)

                            if (cropped1 == null || cropped2 == null) {
                                withContext(Dispatchers.Main) {
                                    result.error("FACE_NOT_FOUND", "Could not detect face in one of the images.", null)
                                }
                                return@launch
                            }

                            val emb1 = faceNetHelper.getFaceEmbedding(cropped1)
                            val emb2 = faceNetHelper.getFaceEmbedding(cropped2)
                            val enhancedResult = faceNetHelper.getMatchingConfidence(emb1, emb2)

                            // Map the result to a Dart-compatible format
                            val resultMap = mapOf(
                                "isMatch" to enhancedResult.isMatch,
                                "matchType" to enhancedResult.matchType.toString(),
                                "cosineSimilarity" to enhancedResult.cosineSimilarity,
                                "euclideanDistance" to enhancedResult.euclideanDistance,
                                "compositeSimilarity" to enhancedResult.compositeSimilarity,
                                "confidence" to enhancedResult.confidence.toString()
                            )

                            withContext(Dispatchers.Main) {
                                result.success(resultMap)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("PROCESSING_ERROR", "Error during face comparison: ${e.message}", e.toString())
                            }
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // In MainActivity.kt
    private fun loadAssetBitmap(fileName: String): Bitmap {
        return applicationContext.assets.open(fileName).use { inputStream ->
            if (inputStream.available() == 0) {
                // This is a sign that the asset is not correctly bundled or is an empty file.
                throw IOException("Asset file is empty: $fileName")
            }
            BitmapFactory.decodeStream(inputStream)
        }
    }

    private suspend fun cropFace(originalBitmap: Bitmap): Bitmap? {
        val detector = FaceDetection.getClient()
        val image = InputImage.fromBitmap(originalBitmap, 0)
        val faces = detector.process(image).await()

        return if (faces.isNotEmpty()) {
            val face = faces.first()
            val boundingBox = face.boundingBox
            val padding = 20
            val left = max(0, boundingBox.left - padding)
            val top = max(0, boundingBox.top - padding)
            val right = min(originalBitmap.width, boundingBox.right + padding)
            val bottom = min(originalBitmap.height, boundingBox.bottom + padding)
            val width = right - left
            val height = bottom - top

            if (width > 0 && height > 0) {
                Bitmap.createBitmap(originalBitmap, left, top, width, height)
            } else {
                null
            }
        } else {
            null
        }
    }
}