package org.thaney.ambatopia;
import android.app.*;
import android.os.*;
import android.webkit.*;
import android.view.*;
import android.content.*;
import android.net.Uri;
import android.provider.MediaStore;
import android.util.*;
import android.widget.Toast;
import java.io.*;
import java.net.URLConnection;
import java.util.*;
public final class MainActivity extends Activity {
 private org.json.JSONObject assetPaths; private WebView view; private boolean qa; private ValueCallback<Uri[]> chooser;
 private static final String HOST="appassets.androidplatform.net";
 @Override public void onCreate(Bundle state){super.onCreate(state);qa=getPackageName().endsWith(".qa");getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);getWindow().setFlags(1024,1024);
 try(InputStream in=getAssets().open("web-index.json")){ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] buffer=new byte[8192];int n;while((n=in.read(buffer))!=-1)out.write(buffer,0,n);assetPaths=new org.json.JSONObject(out.toString("UTF-8"));}catch(Exception e){throw new RuntimeException("Resource index missing",e);}
 view=new WebView(this);setContentView(view);view.setBackgroundColor(0xff54cde2);WebSettings s=view.getSettings();s.setJavaScriptEnabled(true);s.setDomStorageEnabled(true);s.setAllowFileAccess(false);s.setAllowContentAccess(false);s.setMediaPlaybackRequiresUserGesture(true);s.setSupportZoom(false);s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);WebView.setWebContentsDebuggingEnabled(qa);view.addJavascriptInterface(new Bridge(),"AmbatopiaAndroid");
 view.setWebViewClient(new WebViewClient(){
 @Override public WebResourceResponse shouldInterceptRequest(WebView v,WebResourceRequest r){Uri u=r.getUrl();if("https".equals(u.getScheme())&&HOST.equals(u.getHost())){
 String path=u.getPath();if(path.endsWith("/"))path+="index.html";
 if(path.contains("..")||path.contains("\\"))return error(403,"Invalid resource");
 try{String mime=URLConnection.guessContentTypeFromName(path);if(path.endsWith(".js"))mime="application/javascript";else if(path.endsWith(".json"))mime="application/json";else if(path.endsWith(".wasm"))mime="application/wasm";else if(path.endsWith(".ttf"))mime="font/ttf";if(mime==null)mime="application/octet-stream";
 InputStream data=getAssets().open("web-objects/"+assetPaths.getString(path));Map<String,String> headers=new HashMap<>();headers.put("Cache-Control","no-cache");headers.put("X-Content-Type-Options","nosniff");return new WebResourceResponse(mime,mime.startsWith("text/")||mime.contains("javascript")?"UTF-8":null,200,"OK",headers,data);
 }catch(Exception e){Log.w("Ambatopia","MISSING_ASSET "+path);return error(404,"Packaged resource unavailable");}}
 if("hbptqogoihmguhdizqcf.supabase.co".equals(u.getHost())&&"https".equals(u.getScheme()))return null;
 Log.w("Ambatopia","BLOCKED_RESOURCE "+u.getHost()+u.getPath());return error(403,"External resource blocked");}
 @Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest r){Uri u=r.getUrl();if(HOST.equals(u.getHost())&&"https".equals(u.getScheme()))return false;if(r.isForMainFrame()&&"https".equals(u.getScheme())){startActivity(new Intent(Intent.ACTION_VIEW,u));}return true;}
 });
 view.setWebChromeClient(new WebChromeClient(){@Override public boolean onConsoleMessage(ConsoleMessage m){if(qa&&(m.message().startsWith("QA_")||m.messageLevel()==ConsoleMessage.MessageLevel.ERROR))Log.i("Ambatopia","WEB "+m.message().substring(0,Math.min(m.message().length(),3000)));return true;}
 @Override public boolean onShowFileChooser(WebView v,ValueCallback<Uri[]> callback,FileChooserParams params){if(chooser!=null)chooser.onReceiveValue(null);chooser=callback;try{startActivityForResult(params.createIntent(),27);return true;}catch(Exception e){chooser=null;return false;}}
 });
 view.loadUrl("https://"+HOST+"/"+(qa&&getIntent().getBooleanExtra("qa_run",false)?"?qa=1":""));immersive();}
 private WebResourceResponse error(int code,String text){return new WebResourceResponse("text/plain","UTF-8",code,code==404?"Not Found":"Forbidden",Collections.emptyMap(),new ByteArrayInputStream(text.getBytes()));}
 private void immersive(){getWindow().getDecorView().setSystemUiVisibility(5894);}
 @Override public void onWindowFocusChanged(boolean focus){super.onWindowFocusChanged(focus);if(focus)immersive();}
 @Override public void onPause(){super.onPause();view.onPause();}
 @Override public void onResume(){super.onResume();if(view!=null)view.onResume();}
 @Override public void onBackPressed(){view.evaluateJavascript("window.AmbatopiaBack?window.AmbatopiaBack():history.back()",null);}
 @Override protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);if(request==27&&chooser!=null){chooser.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(result,data));chooser=null;}}
 final class Bridge {
 @JavascriptInterface public void record(String json){if(qa&&json.length()<100000){try(FileOutputStream out=openFileOutput("web-qa.json",MODE_PRIVATE)){out.write(json.getBytes("UTF-8"));}catch(Exception e){Log.e("Ambatopia","QA_REPORT_WRITE_FAILED");}}}
 @JavascriptInterface public void saveDownload(String filename,String mime,String base64){if(base64.length()>48000000)return;filename=filename.replaceAll("[^A-Za-z0-9._-]","_");try{byte[] bytes=android.util.Base64.decode(base64,android.util.Base64.DEFAULT);if(Build.VERSION.SDK_INT>=29){ContentValues values=new ContentValues();values.put(MediaStore.Downloads.DISPLAY_NAME,filename);values.put(MediaStore.Downloads.MIME_TYPE,mime);values.put(MediaStore.Downloads.RELATIVE_PATH,"Download/Ambatopia");Uri uri=getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI,values);try(OutputStream out=getContentResolver().openOutputStream(uri)){out.write(bytes);}}else{File file=new File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),filename);try(FileOutputStream out=new FileOutputStream(file)){out.write(bytes);}}runOnUiThread(()->Toast.makeText(MainActivity.this,"Export saved",Toast.LENGTH_SHORT).show());}catch(Exception e){Log.e("Ambatopia","EXPORT_FAILED");}}
 }
}
