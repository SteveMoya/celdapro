# Reglas de R8 para la compilación de release.
#
# El plugin de reconocimiento de texto de ML Kit referencia también los
# reconocedores de chino, devanagari, japonés y coreano, pero los declara como
# opcionales (`compileOnly`): sus clases no vienen en el APK porque CeldaPro
# solo usa el alfabeto latino.
#
# Sin estas reglas, R8 falla en release con «Missing class» aunque el APK de
# depuración compile sin problema (en depuración no se optimiza, así que el
# fallo solo aparece al compilar la versión de verdad).
#
# No se pierde nada por silenciarlas: son clases que no existen en el APK y a
# las que la app nunca llama, porque solo pide el script `latin`.
#
# Las genera el propio R8 en
# build/app/outputs/mapping/release/missing_rules.txt

-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
