# Gallery Drift — firma stabile Android

Questo repository possiede la propria signing identity, separata dall'altra app Drift.
Identità Android attesa: `com.riccardopinato.gallerydrift`.

## Il punto critico
Gli APK precedenti sono stati compilati sulla lane interna di GitHub (default debug signing). Non presumere che possano essere aggiornati in-place con una nuova release key. Prima di distribuire nuovi APK confronta la SHA-256 del certificato del file già installato e quella del file nuovo. Non ricreare a ogni build la keystore.

## Generazione UNA VOLTA sul PC fidato (Windows / PowerShell)
Con il JDK e `keytool` installati:

```powershell
keytool -genkeypair -v -keystore "gallerydrift-release.jks" -alias "gallerydrift-release" -keyalg RSA -keysize 4096 -validity 10000 -storetype PKCS12
keytool -list -v -keystore ".\\gallerydrift-release.jks" -alias "gallerydrift-release"
```

Salva il file JKS/P12 ed entrambe le password in due backup sicuri; i secret NON vanno in chat, in PR o in repository. Per il Base64 da inserire in GitHub senza stamparlo:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path ".\\gallerydrift-release.jks"))) | Set-Clipboard
```

In **Settings → Secrets and variables → Actions → Repository secrets** crea:

- `ANDROID_KEYSTORE_BASE64`: contenuto Base64 della keystore (copiato negli appunti).
- `ANDROID_KEYSTORE_PASSWORD`: password keystore.
- `ANDROID_KEY_ALIAS`: `gallerydrift-release` (o il tuo alias reale).
- `ANDROID_KEY_PASSWORD`: password della chiave.

In **Repository variables** crea `ANDROID_CERT_SHA256` con il fingerprint SHA-256 mostrato da `keytool -list -v` (dato pubblico). Imposta ciascuna voce nel repository di questa specifica app; se le chiavi sono diverse, i valori saranno diversi.

## Compilazione manuale
Apri Actions → **Gallery Drift — stable signed APK** → Run workflow sulla versione `main`. Il workflow fallisce se secret o fingerprint mancano o se il certificato dell'APK non coincide. L'APK viene distribuito solo come artifact GitHub Actions, non su Google Play.

## Verifica aggiornamento
Aggiornamento possibile solo con `applicationId` uguale, SHA-256 certificato compatibile, `versionCode` maggiore. Testa installazione senza disinstallare dopo aver creato la prima release firmata con questa keystore. Per versioni Play App Signing il certificato del download da Play può differire dalla chiave upload.

## Verifica preventiva delle password (PKCS12)
Lo script locale `Setup-Drift-Signing.ps1` crea `-storetype PKCS12` con `keytool`.
La password della chiave privata è la **stessa** password della keystore.
Entrambi i secret `ANDROID_KEYSTORE_PASSWORD` e `ANDROID_KEY_PASSWORD` devono
quindi contenere la **medesima password originale** scelta durante la creazione
del file, senza creare una keystore nuova. Non condividere password in chat o
issue. Il check `scripts/VerifySigning.java` prova ad aprire la chiave e verifica
il fingerprint prima dell'analisi e della lenta compilazione Android.
Se fallisce `KEY_PASSWORD_INVALID`, riesegui lo script di setup esistente
in modalità riuso della keystore, inserendo la password originale in entrambi
i campi. Non rigenerare la key e non cancellare i dati dell'app.


## 22/11/2026 — Riduzione APK ARM64
L'APK precedente (0.3.2+6, firma di produzione) pesava 48,5 MiB e conteneva
librerie native ML Kit per ARM64, ARM32 e x86_64. Flutter 3.50 non ha
rispettato il solo `defaultConfig.ndk.abiFilters` per le librerie JNI:
la CI lo ha dimostrato. Combinare `abiFilters` e gli split ABI causa invece
un errore Gradle ("Conflicting configuration").

Usare **soltanto** `flutter build apk --release --split-per-abi
--target-platform android-arm64`, distribuendo esclusivamente
`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
Il controllo `scripts/verify_arm64_apk.py` deve bloccare il rilascio
se l'APK include ABI diverse da `arm64-v8a`, manca il runtime Flutter
o la libreria ML Kit, oppure supera 36 MiB.

La versione è `0.3.3+7`, package `com.riccardopinato.gallerydrift`,
con la keystore di produzione invariata. Gli APK split hanno un versionCode
specifico per ABI e tutte le future versioni ARM64 devono continuare
a usare la stessa modalità (o versionCode crescenti).
Per altri processori servono APK compatibili separati e verificati.
