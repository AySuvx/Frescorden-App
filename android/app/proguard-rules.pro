# ProGuard/R8 — reglas de conservación para compilación de release.
#
# Nota de arquitectura importante: R8 solo procesa bytecode JVM (Java/Kotlin
# del engine de Flutter y de los plugins nativos) — NUNCA toca el código
# Dart de la app (Product, Recipe, HouseholdModel, etc.). Ese código se
# compila a código máquina nativo vía AOT, y su propia ofuscación de
# símbolos la controla el flag `--obfuscate` de `flutter build`, no estas
# reglas. Como el proyecto serializa JSON con `fromJson`/`toJson` manuales
# (acceso a claves de Map, no reflexión), no hay riesgo de reflexión rota
# del lado Dart. Estas reglas cubren únicamente la capa Android nativa.

# Flutter engine y generado de plugins.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Play Core (componentes diferidos) — el engine de Flutter referencia estas
# clases aunque la app no use split/deferred components; sin este
# `-dontwarn`, R8 falla con "Missing class" en vez de advertir.
-dontwarn com.google.android.play.core.**

# Firebase SDKs (Auth, Firestore, Storage, App Check, Analytics, AI/Vertex)
# y Google Play Services (google_sign_in) — usan reflexión/Gson
# internamente en varios puntos.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Gson (usado transitivamente por varios SDKs de Firebase/Google).
-keep class com.google.gson.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# flutter_local_notifications — regla oficial del plugin: sus receivers
# usan Gson para (de)serializar notificaciones programadas.
-keep class com.dexterous.** { *; }

# android_alarm_manager_plus — dispara alarmas tras reinicio del sistema
# invocando su BroadcastReceiver/Service por nombre calificado (ver
# AndroidManifest.xml); si R8 los renombra, el sistema no los encuentra.
-keep class dev.fluttercommunity.plus.androidalarmmanager.** { *; }

# Red de seguridad general: cualquier BroadcastReceiver/Service que un
# plugin registre en el Manifest debe conservar su nombre calificado
# completo, sin importar cuál lo declare.
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.app.Service
