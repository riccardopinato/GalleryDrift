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
