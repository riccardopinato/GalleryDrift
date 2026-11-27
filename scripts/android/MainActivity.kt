package com.riccardopinato.gallerydrift

import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.util.Size
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/** Android system trash is authoritative; no private simulated trash. */
class MainActivity : FlutterActivity() {
  private val requestCode = 8431
  private var pendingResult: MethodChannel.Result? = null
  private var pendingUris = emptyList<String>()

  override fun configureFlutterEngine(engine: FlutterEngine) {
    super.configureFlutterEngine(engine)
    MethodChannel(engine.dartExecutor.binaryMessenger, "gallerydrift/system_trash")
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "supported" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
          "list" -> runCatching { listTrashed() }
            .onSuccess { result.success(it) }
            .onFailure { result.error("TRASH_QUERY_FAILED", it.message, null) }
          "thumbnail" -> {
            val uri = call.argument<String>("uri")
            if(uri == null) { result.error("BAD_URI","Missing URI",null); return@setMethodCallHandler }
            Thread {
              val bytes = runCatching {
                if(!isTrashed(uri)) null
                else {
                  val bmp = contentResolver.loadThumbnail(Uri.parse(uri), Size(192,192),null)
                  val stream = ByteArrayOutputStream()
                  bmp.compress(Bitmap.CompressFormat.JPEG, 75, stream)
                  bmp.recycle()
                  stream.toByteArray()
                }
              }.getOrNull()
              runOnUiThread { result.success(bytes) }
            }.start()
          }
          "restore", "deleteForever" -> mutate(call, result)
          else -> result.notImplemented()
        }
      }
  }

  private fun listTrashed(): List<Map<String,Any?>> {
    if(Build.VERSION.SDK_INT < 30) return emptyList()
    val uri = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
    val extras = Bundle().apply {
      putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_ONLY)
    }
    val fields = arrayOf(
      MediaStore.MediaColumns._ID,
      MediaStore.MediaColumns.DISPLAY_NAME,
      MediaStore.MediaColumns.MIME_TYPE,
      MediaStore.MediaColumns.SIZE,
      MediaStore.MediaColumns.DATE_EXPIRES,
      MediaStore.MediaColumns.VOLUME_NAME,
      MediaStore.MediaColumns.IS_TRASHED,
    )
    val result = arrayListOf<Map<String,Any?>>()
    contentResolver.query(uri,fields,extras,null)?.use { cursor ->
      val idCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
      val nameCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
      val mimeCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE)
      val bytesCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
      val expiresCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_EXPIRES)
      val volumeCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.VOLUME_NAME)
      val trashCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.IS_TRASHED)
      while(cursor.moveToNext()){
        if(cursor.getInt(trashCol) != 1) continue
        val mime=cursor.getString(mimeCol) ?: ""
        val volume=cursor.getString(volumeCol) ?: MediaStore.VOLUME_EXTERNAL_PRIMARY
        // Action URIs must reference the concrete volume, not the synthetic
        // union volume used for listing files across storage devices.
        val itemBase = when {
          mime.startsWith("image/") -> MediaStore.Images.Media.getContentUri(volume)
          mime.startsWith("video/") -> MediaStore.Video.Media.getContentUri(volume)
          else -> continue
        }
        val rowUri=ContentUris.withAppendedId(itemBase,cursor.getLong(idCol))
        result.add(mapOf(
          "uri" to rowUri.toString(),
          "name" to (cursor.getString(nameCol) ?: ""),
          "mime" to mime,
          "bytes" to cursor.getLong(bytesCol),
          "expires" to (if(cursor.isNull(expiresCol)) null else cursor.getLong(expiresCol)),
        ))
      }
    }
    return result
  }

  private fun isTrashed(uriString:String):Boolean {
    if(Build.VERSION.SDK_INT < 30) return false
    val uri=Uri.parse(uriString)
    if(uri.scheme != "content" || uri.authority != MediaStore.AUTHORITY) return false
    val extras=Bundle().apply {
      putInt(MediaStore.QUERY_ARG_MATCH_TRASHED,MediaStore.MATCH_INCLUDE)
    }
    contentResolver.query(uri,
      arrayOf(MediaStore.MediaColumns.IS_TRASHED),extras,null)?.use { c ->
      return c.moveToFirst() && c.getInt(0) == 1
    }
    return false
  }

  private fun mutate(call:MethodCall,result:MethodChannel.Result) {
    if(Build.VERSION.SDK_INT < 30) {
      result.error("UNSUPPORTED","Android 11+ required",null);return
    }
    if(pendingResult != null) {
      result.error("BUSY","System operation is pending",null);return
    }
    val requested=call.argument<List<String>>("uris") ?: emptyList()
    if(requested.isEmpty() || requested.size > 100 ||
       requested.distinct().size != requested.size) {
      result.error("BAD_SELECTION","Select between 1 and 100 distinct files",null);return
    }
    try {
      val allowed=listTrashed().map { it["uri"] as String }.toSet()
      if(!requested.all { allowed.contains(it) && isTrashed(it) }) {
        result.error("STALE_SELECTION","Selected media are no longer accessible in trash",null)
        return
      }
      val uris=requested.map(Uri::parse)
      val pending=if(call.method == "deleteForever")
        MediaStore.createDeleteRequest(contentResolver,uris)
        else MediaStore.createTrashRequest(contentResolver,uris,false)
      pendingResult=result
      pendingUris=requested
      startIntentSenderForResult(
        pending.intentSender,requestCode,null,0,0,0)
    }catch(t:Throwable){
      pendingResult=null
      pendingUris=emptyList()
      result.error("TRASH_REQUEST_FAILED",t.message,null)
    }
  }

  override fun onActivityResult(request:Int,status:Int,data:Intent?) {
    super.onActivityResult(request,status,data)
    if(request!=requestCode)return
    val result=pendingResult ?: return
    val uris=pendingUris
    pendingResult=null
    pendingUris=emptyList()
    if(status != Activity.RESULT_OK){result.success(emptyList<String>());return}
    try {
      val stillTrashed=listTrashed().map { it["uri"] as String }.toSet()
      result.success(uris.filter { !stillTrashed.contains(it) })
    } catch(t:Throwable){
      result.error("VERIFY_FAILED",t.message,null)
    }
  }
}
