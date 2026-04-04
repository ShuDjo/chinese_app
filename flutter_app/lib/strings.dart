import 'language_manager.dart';

class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  // Tab labels
  String get tabTranslate => _s('Translate', 'Превод', 'Prevod');
  String get tabExam => _s('Exam', 'Испит', 'Ispit');
  String get tabCharacters => _s('My Dictionary', 'Мој речник', 'Moj rečnik');
  String get tabFlashcards => _s('Flash Cards', 'Картице', 'Kartice');
  String get tabSettings => _s('Settings', 'Подешавања', 'Podešavanja');

  // Translate screen
  String get translateTitle => _s('XuéBàn', 'XuéBàn', 'XuéBàn');
  String get translateSubtitle => _s('Chinese Translator', 'Кинески преводилац', 'Kineski prevodilac');
  String get translateBannerTitle => _s('How it works', 'Kako radi', 'Kako radi');
  String get translateBannerBody =>
      _s('Speak any Chinese sentence and get an instant word-by-word breakdown with translations, pinyin and characters.',
         'Изговорите bilo koju кинеску реченицу и добијте тренутну разраду реч по реч са преводима, пинијином и карактерима.',
         'Izgovorite bilo koju kinesku rečenicu i dobijte trenutnu razradu reč po reč sa prevodima, pinjiinom i karakterima.');
  String get translateBannerBodyType =>
      _s('Type any sentence in English, Serbian, or pinyin to get translation, pinyin and characters.',
         'Укуцајте bilo коју реченицу на енглеском, српском или пинијину да добијете превод, пинијин и карактере.',
         'Ukucajte bilo koju rečenicu na engleskom, srpskom ili pinjinu da dobijete prevod, pinjin i karaktere.');
  String get modeMic => _s('Mic', 'Mikrofon', 'Mikrofon');
  String get modeType => _s('Type', 'Kucaj', 'Kucaj');
  String get tapToRecord => _s('Tap to record', 'Dodirnite za snimanje', 'Dodirnite za snimanje');
  String get tapToStop => _s('Tap to stop', 'Dodirnite za zaustavljanje', 'Dodirnite za zaustavljanje');
  String get transcribing => _s('Transcribing…', 'Transkripcija…', 'Transkripcija…');
  String get lookingUp => _s('Looking up…', 'Pretraga…', 'Pretraga…');
  String get typeEnglishOrPinyin => _s('Type English, Serbian, or pinyin…', 'Кucajте енgleski, srpski ili pinjin…', 'Kucajte engleski, srpski ili pinjin…');
  String get lookUp => _s('Search', 'Pretraži', 'Pretraži');
  String get acceptAndSave => _s('Accept and save to your dictionary', 'Prihvati i sačuvaj u rečnik', 'Prihvati i sačuvaj u rečnik');
  String get addToVocabulary => _s('Add to vocabulary', 'Dodaj u rečnik', 'Dodaj u rečnik');
  String get addedToVocabulary => _s('Added to vocabulary!', 'Dodato u rečnik!', 'Dodato u rečnik!');
  String get saving => _s('Saving…', 'Čuvanje…', 'Čuvanje…');
  String get wordsTapToSeeStrokes => _s('Tap a word to watch its stroke order animation', 'Dodirnite reč da vidite animaciju redosleda poteza', 'Dodirnite reč da vidite animaciju redosleda poteza');
  String get sentenceTranslation => _s('Sentence translation', 'Prevod rečenice', 'Prevod rečenice');
  String get noChineseDetected => _s('No Chinese speech detected. Please try again.', 'Nije detektovan kineski govor. Pokušajte ponovo.', 'Nije detektovan kineski govor. Pokušajte ponovo.');

  // Characters screen
  String get characterTitle => _s('My Dictionary', 'Мој речник', 'Moj rečnik');
  String get characterSubtitle => _s('Stroke Order & Search', 'Редослед потеза и претрага', 'Redosled poteza i pretraga');
  String get characterBannerTitle => _s('Search your dictionary', 'Претражи свој речник', 'Pretraži svoj rečnik');
  String get characterBannerBody =>
      _s('Look up any Chinese word, English meaning, Serbian translation, or pinyin from your saved vocabulary.',
         'Potražite bilo koju kinesku reč, englesko značenje, srpski prevod ili pinjin iz sačuvanog rečnika.',
         'Potražite bilo koju kinesku reč, englesko značenje, srpski prevod ili pinjin iz sačuvanog rečnika.');
  String get englishPinyinOrChinese => _s('English, pinyin, or Chinese', 'Engleski, pinjin ili kineski', 'Engleski, pinjin ili kineski');
  String get characterPlaceholder => _s('e.g. hello, nǐhǎo, 你好', 'npr. zdravo, nǐhǎo, 你好', 'npr. zdravo, nǐhǎo, 你好');
  String get characterHint => _s('Search works across all saved words', 'Pretraga radi po svim sačuvanim rečima', 'Pretraga radi po svim sačuvanim rečima');
  String get notInDictionary =>
      _s('This word is not in your dictionary yet. Save words via the Translate tab to build your collection.',
         'Ова реч још није у твом речнику. Додај речи преко картице Превод да изградиш свој речник.',
         'Ova reč još nije u tvom rečniku. Dodaj reči preko kartice Prevod da izgradiš svoj rečnik.');
  String get repeatAnimation => _s('Repeat', 'Ponovi', 'Ponovi');

  // Flashcards screen
  String get flashcardTitle => _s('Flash Cards', 'Kartice', 'Kartice');
  String get flashcardSubtitle => _s('Test yourself', 'Testiraj se', 'Testiraj se');
  String get flashcardBannerTitle => _s('Practice your vocabulary', 'Vežbaj rečnik', 'Vežbaj rečnik');
  String get flashcardBannerBody =>
      _s('Type the pinyin or English translation for each character from your saved vocabulary. Serbian words count too!',
         'Unesi pinjin ili engleski prevod za svaki karakter iz sačuvanog rečnika. Srpske reči važe!',
         'Unesi pinjin ili engleski prevod za svaki karakter iz sačuvanog rečnika. Srpske reči važe!');
  String get typeAnswer => _s('Type pinyin or English…', 'Ukucaj pinjin ili engleski…', 'Ukucaj pinjin ili engleski…');
  String get check => _s('Check', 'Proveri', 'Proveri');
  String get next => _s('Next', 'Sledeće', 'Sledeće');
  String get correct => _s('Correct!', 'Tačno!', 'Tačno!');
  String get incorrect => _s('Not quite', 'Nije tačno', 'Nije tačno');
  String get answer => _s('Answer:', 'Odgovor:', 'Odgovor:');
  String get noWordsYet =>
      _s('No words saved yet. Use the Translate tab to add words to your vocabulary.',
         'Nema sačuvanih reči. Koristi Prevod karticu da dodaš reči.',
         'Nema sačuvanih reči. Koristi Prevod karticu da dodaš reči.');

  // Exam screen
  String get examTitle => _s('Exam', 'Ispita', 'Ispita');
  String get examSubtitle => _s('AI-powered quiz', 'Quiz sa veštačkom inteligencijom', 'Quiz sa veštačkom inteligencijom');
  String get chooseLessons => _s('Choose lessons (optional)', 'Izaberi lekcije (opciono)', 'Izaberi lekcije (opciono)');
  String get topic => _s('Topic', 'Tema', 'Tema');
  String get topicPlaceholder => _s('e.g. greetings, food, travel…', 'npr. pozdravi, hrana, putovanje…', 'npr. pozdravi, hrana, putovanje…');
  String get beginExam => _s('Begin Exam', 'Počni Ispit', 'Počni Ispit');
  String get typeYourAnswer => _s('Type your answer…', 'Ukucaj odgovor…', 'Ukucaj odgovor…');
  String get submit => _s('Submit', 'Pošalji', 'Pošalji');
  String get endSession => _s('End Session', 'Završi sesiju', 'Završi sesiju');
  String get evaluating => _s('Evaluating…', 'Evaluacija…', 'Evaluacija…');
  String get overallScore => _s('Overall Score', 'Ukupan rezultat', 'Ukupan rezultat');
  String get strengths => _s('Strengths', 'Prednosti', 'Prednosti');
  String get improvements => _s('Areas to improve', 'Oblasti za poboljšanje', 'Oblasti za poboljšanje');
  String get startOver => _s('Start Over', 'Počni iznova', 'Počni iznova');
  String get hint => _s('Hint', 'Nagoveštaj', 'Nagoveštaj');
  String get loadingQuestion => _s('Loading question…', 'Učitavanje pitanja…', 'Učitavanje pitanja…');

  // Settings
  String get settingsTitle => _s('Settings', 'Podešavanja', 'Podešavanja');
  String get language => _s('Language', 'Jezik', 'Jezik');
  String get english => 'English';
  String get serbianCyrillic => 'Српски (ћирилица)';
  String get serbianLatin => 'Srpski (latinica)';

  // Input type selector
  String get inputTypeEnglish => _s('English', 'Енглески', 'Engleski');
  String get inputTypePinyin  => _s('Pinyin',  'Пинјин',  'Pinjin');
  String get inputTypeSerbian => _s('Serbian', 'Српски',  'Srpski');
  String get inputErrorEnglish => _s(
      'Please type in English only.',
      'Молимо укуцајте само на енглеском.',
      'Molimo ukucajte samo na engleskom.');
  String get inputErrorPinyin => _s(
      'Please type in pinyin only (e.g. nǐ hǎo).',
      'Молимо укуцајте само пинјин (нпр. nǐ hǎo).',
      'Molimo ukucajte samo pinjin (npr. nǐ hǎo).');
  String get inputErrorSerbian => _s(
      'Please type in Serbian only (Latin or Cyrillic).',
      'Молимо укуцајте само на српском (латиница или ћирилица).',
      'Molimo ukucajte samo na srpskom (latinica ili ćirilica).');

  // Common
  String get retry => _s('Retry', 'Pokušaj ponovo', 'Pokušaj ponovo');
  String get speak => _s('Speak', 'Izgovori', 'Izgovori');

  String _s(String en, String cyrl, String lat) {
    switch (lang) {
      case AppLanguage.serbianCyrillic:
        return cyrl;
      case AppLanguage.serbianLatin:
        return lat;
      default:
        return en;
    }
  }
}
