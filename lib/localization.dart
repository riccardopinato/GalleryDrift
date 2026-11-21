import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// English fallback, six manually selectable interface languages.
abstract final class GalleryLocale {
  static const codes = ['it','en','fr','es','de','pt'];
  static const names = {'it':'Italiano','en':'English','fr':'Français',
    'es':'Español','de':'Deutsch','pt':'Português'};
  static final current = ValueNotifier<String>('it');

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('gallerydrift.locale') ?? 'it';
    current.value = codes.contains(code) ? code : 'it';
  }

  static Future<void> select(String code) async {
    if (!codes.contains(code)) return;
    current.value = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gallerydrift.locale',code);
  }

  static String t(String key) => (_texts[current.value] ?? _texts['en']!)[key] ??
    _texts['en']![key] ?? key;

  static const _texts = <String, Map<String,String>>{
    'it': {'search':'Cerca','favorites':'Preferiti','settings':'Impostazioni',
      'albums':'Cartelle visibili','grant':'Autorizza accesso alle foto',
      'none':'Nessuna cartella selezionata','choose':'Scegli le cartelle',
      'language':'Lingua','privacy':'Privacy e Google Play',
      'privacyBody':'Le foto restano sul dispositivo. L’app mostra solo le cartelle selezionate. Preferiti, lingua e posizione del canvas sono salvati localmente. Non ci sono account, annunci, analisi o caricamenti delle tue foto. Le dichiarazioni Google Play saranno verificate prima della pubblicazione.',
      'apply':'Applica','cancel':'Annulla','close':'Chiudi',
      'empty':'Seleziona almeno una cartella dalle impostazioni per esplorare la tua galleria.',
      'denied':'Accesso alle foto negato. Puoi abilitarlo dalle impostazioni di sistema.',
      'retry':'Riprova','noPhotos':'Nessuna foto disponibile nelle cartelle selezionate.',
      'info':'Informazioni','date':'Data','size':'Dimensioni',
      'trash':'Sposta nel cestino','confirmTrash':'Spostare questa foto nel cestino del dispositivo? Il sistema potrebbe richiedere conferma.',
      'error':'Operazione non riuscita','noResult':'Nessun risultato',
      'albumSwipeHint':'Scorri a sinistra o a destra per esplorare questa cartella',
      'albumReadError':'Impossibile leggere tutte le foto della cartella. Puoi comunque visualizzare quella aperta.'},
    'en': {'search':'Search','favorites':'Favorites','settings':'Settings',
      'albums':'Visible folders','grant':'Allow photo access',
      'none':'No folders selected','choose':'Choose folders',
      'language':'Language','privacy':'Privacy and Google Play',
      'privacyBody':'Photos stay on your device. Only chosen folders are shown. Favorites, language and canvas position are stored locally. No accounts, ads, analytics or photo uploads are enabled. Google Play declarations will be reviewed before release.',
      'apply':'Apply','cancel':'Cancel','close':'Close','empty':'Choose folders in settings to explore your gallery.',
      'denied':'Photo access denied. You can enable it in system settings.',
      'retry':'Retry','noPhotos':'No photos in the selected folders.',
      'info':'Information','date':'Date','size':'Dimensions','trash':'Move to trash',
      'confirmTrash':'Move this photo to device trash? System confirmation may be required.',
      'error':'Action failed','noResult':'No results',
      'albumSwipeHint':'Swipe left or right to browse this album',
      'albumReadError':'Could not load the album count. The opened photo is still available.'},
    'fr': {'search':'Rechercher','favorites':'Favoris','settings':'Paramètres',
      'albums':'Dossiers visibles','grant':'Autoriser les photos','none':'Aucun dossier choisi',
      'choose':'Choisir les dossiers','language':'Langue','privacy':'Confidentialité et Google Play',
      'privacyBody':'Les photos restent sur cet appareil. Seuls les dossiers choisis sont affichés. Favoris et préférences sont enregistrés localement. Aucun compte, publicité, analyse ou transfert de photo n’est actif. Déclarations Play à vérifier avant publication.',
      'apply':'Appliquer','cancel':'Annuler','close':'Fermer',
      'empty':'Choisissez des dossiers dans les paramètres.',
      'denied':'Accès aux photos refusé. Modifiez les autorisations du système.',
      'retry':'Réessayer','noPhotos':'Aucune photo dans les dossiers choisis.',
      'info':'Informations','date':'Date','size':'Dimensions','trash':'Déplacer vers la corbeille',
      'confirmTrash':'Déplacer cette photo vers la corbeille ?','error':'Échec','noResult':'Aucun résultat',
      'albumSwipeHint':'Balayez pour parcourir cet album',
      'albumReadError':'Impossible de lire toutes les photos du dossier. La photo ouverte reste disponible.'},
    'es': {'search':'Buscar','favorites':'Favoritos','settings':'Ajustes',
      'albums':'Carpetas visibles','grant':'Permitir acceso a fotos','none':'Ninguna carpeta seleccionada',
      'choose':'Elegir carpetas','language':'Idioma','privacy':'Privacidad y Google Play',
      'privacyBody':'Las fotos permanecen en el dispositivo. Solo se muestran las carpetas elegidas. Favoritos y preferencias se guardan localmente. Sin cuentas, anuncios, análisis ni subidas. Revisar declaraciones de Play antes de publicar.',
      'apply':'Aplicar','cancel':'Cancelar','close':'Cerrar',
      'empty':'Elige carpetas en los ajustes para explorar tu galería.',
      'denied':'Acceso denegado. Actívalo en los ajustes del sistema.',
      'retry':'Reintentar','noPhotos':'No hay fotos en las carpetas seleccionadas.',
      'info':'Información','date':'Fecha','size':'Dimensiones','trash':'Mover a papelera',
      'confirmTrash':'¿Mover esta foto a la papelera?','error':'Error','noResult':'Sin resultados',
      'albumSwipeHint':'Desliza para explorar esta carpeta',
      'albumReadError':'No se pudo leer el álbum completo. La foto abierta sigue disponible.'},
    'de': {'search':'Suchen','favorites':'Favoriten','settings':'Einstellungen',
      'albums':'Sichtbare Ordner','grant':'Fotozugriff erlauben','none':'Keine Ordner ausgewählt',
      'choose':'Ordner auswählen','language':'Sprache','privacy':'Datenschutz und Google Play',
      'privacyBody':'Fotos bleiben auf dem Gerät. Nur ausgewählte Ordner werden angezeigt. Favoriten und Einstellungen werden lokal gespeichert. Keine Konten, Werbung, Analyse oder Foto-Uploads. Play-Angaben vor Veröffentlichung prüfen.',
      'apply':'Übernehmen','cancel':'Abbrechen','close':'Schließen',
      'empty':'Wähle Ordner in den Einstellungen aus.',
      'denied':'Fotozugriff verweigert. Aktiviere ihn in den Systemeinstellungen.',
      'retry':'Erneut','noPhotos':'Keine Fotos in ausgewählten Ordnern.',
      'info':'Informationen','date':'Datum','size':'Abmessungen','trash':'In Papierkorb verschieben',
      'confirmTrash':'Dieses Foto in den Papierkorb verschieben?','error':'Fehler','noResult':'Keine Treffer',
      'albumSwipeHint':'Wische nach links oder rechts, um das Album zu durchsuchen',
      'albumReadError':'Das Album konnte nicht vollständig gelesen werden. Das geöffnete Foto ist verfügbar.'},
    'pt': {'search':'Pesquisar','favorites':'Favoritos','settings':'Definições',
      'albums':'Pastas visíveis','grant':'Permitir acesso às fotos','none':'Nenhuma pasta selecionada',
      'choose':'Selecionar pastas','language':'Idioma','privacy':'Privacidade e Google Play',
      'privacyBody':'As fotos permanecem no dispositivo. Apenas as pastas escolhidas são mostradas. Favoritos e preferências são guardados localmente. Sem contas, anúncios, análises ou envio de fotos. Rever declarações Play antes de publicar.',
      'apply':'Aplicar','cancel':'Cancelar','close':'Fechar',
      'empty':'Escolhe as pastas nas definições para explorar a galeria.',
      'denied':'Acesso negado. Ativa-o nas definições do sistema.',
      'retry':'Tentar novamente','noPhotos':'Sem fotos nas pastas escolhidas.',
      'info':'Informações','date':'Data','size':'Dimensões','trash':'Mover para o lixo',
      'confirmTrash':'Mover esta foto para o lixo?','error':'Falha','noResult':'Sem resultados',
      'albumSwipeHint':'Deslize para explorar esta pasta',
      'albumReadError':'Não foi possível ler todo o álbum. A foto aberta continua disponível.'},
  };
}
