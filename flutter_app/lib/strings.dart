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
  String get translateBannerTitle => _s('How it works', 'Како ради', 'Kako radi');
  String get translateBannerBody =>
      _s('Speak any Chinese sentence and get an instant word-by-word breakdown with translations, pinyin and characters.',
         'Изговорите било коју кинеску реченицу и добијте тренутну разраду реч по реч са преводима, пинјином и карактерима.',
         'Izgovorite bilo koju kinesku rečenicu i dobijte trenutnu razradu reč po reč sa prevodima, pinjiinom i karakterima.');
  String get translateBannerBodyType =>
      _s('Type any sentence in English, Serbian, or pinyin to get translation, pinyin and characters.',
         'Укуцајте било коју реченицу на енглеском, српском или пинјину да добијете превод, пинјин и карактере.',
         'Ukucajte bilo koju rečenicu na engleskom, srpskom ili pinjinu da dobijete prevod, pinjin i karaktere.');
  String get modeMic => _s('Mic', 'Микрофон', 'Mikrofon');
  String get modeType => _s('Type', 'Куцај', 'Kucaj');
  String get tapToRecord => _s('Tap to record', 'Додирните за снимање', 'Dodirnite za snimanje');
  String get tapToStop => _s('Tap to stop', 'Додирните за заустављање', 'Dodirnite za zaustavljanje');
  String get transcribing => _s('Transcribing…', 'Транскрипција…', 'Transkripcija…');
  String get lookingUp => _s('Looking up…', 'Претрага…', 'Pretraga…');
  String get typeEnglishOrPinyin => _s('Type English, Serbian, or pinyin…', 'Укуцајте енглески, српски или пинјин…', 'Kucajte engleski, srpski ili pinjin…');
  String get lookUp => _s('Search', 'Претражи', 'Pretraži');
  String get acceptAndSave => _s('Accept and save to your dictionary', 'Прихвати и сачувај у речник', 'Prihvati i sačuvaj u rečnik');
  String get addToVocabulary => _s('Add to vocabulary', 'Додај у речник', 'Dodaj u rečnik');
  String get addedToVocabulary => _s('Added to vocabulary!', 'Додато у речник!', 'Dodato u rečnik!');
  String get saving => _s('Saving…', 'Чување…', 'Čuvanje…');
  String get wordsTapToSeeStrokes => _s('Tap a word to watch its stroke order animation', 'Додирните реч да видите анимацију редоследа потеза', 'Dodirnite reč da vidite animaciju redosleda poteza');
  String get sentenceTranslation => _s('Sentence translation', 'Превод реченице', 'Prevod rečenice');
  String get noChineseDetected => _s('No Chinese speech detected. Please try again.', 'Није детектован кинески говор. Покушајте поново.', 'Nije detektovan kineski govor. Pokušajte ponovo.');
  String get micPermissionDenied => _s('Microphone permission denied. Please enable it in Settings.', 'Дозвола за микрофон одбијена. Омогућите је у Подешавањима.', 'Dozvola za mikrofon odbijena. Omogućite je u Podešavanjima.');
  String get noAnswerTranscribed => _s('No answer transcribed. Please try again.', 'Одговор није транскрибован. Покушајте поново.', 'Odgovor nije transkribovan. Pokušajte ponovo.');

  // Characters screen
  String get characterTitle => _s('My Dictionary', 'Мој речник', 'Moj rečnik');
  String get characterSubtitle => _s('Stroke Order & Search', 'Редослед потеза и претрага', 'Redosled poteza i pretraga');
  String get characterBannerTitle => _s('Search your dictionary', 'Претражи свој речник', 'Pretraži svoj rečnik');
  String get characterBannerBody =>
      _s('Look up any Chinese word, English meaning, Serbian translation, or pinyin from your saved vocabulary.',
         'Потражите било коју кинеску реч, енглеско значење, српски превод или пинјин из сачуваног речника.',
         'Potražite bilo koju kinesku reč, englesko značenje, srpski prevod ili pinjin iz sačuvanog rečnika.');
  String get englishPinyinOrChinese => _s('English, pinyin, or Chinese', 'Енглески, пинјин или кинески', 'Engleski, pinjin ili kineski');
  String get characterPlaceholder => _s('e.g. hello, nǐhǎo, 你好', 'нпр. здраво, nǐhǎo, 你好', 'npr. zdravo, nǐhǎo, 你好');
  String get characterPlaceholderEnglish => _s('e.g. hello, thank you…', 'нпр. здраво, хвала…', 'npr. zdravo, hvala…');
  String get characterPlaceholderSerbian => _s('e.g. zdravo, hvala…', 'нпр. здраво, хвала…', 'npr. zdravo, hvala…');
  String get characterPlaceholderPinyin  => _s('e.g. nǐhǎo, xièxie…', 'нпр. nǐhǎo, xièxie…', 'npr. nǐhǎo, xièxie…');
  String get characterHint => _s('Search works across all saved words', 'Претрага ради по свим сачуваним речима', 'Pretraga radi po svim sačuvanim rečima');
  String get notInDictionary =>
      _s('This word is not in your dictionary yet. Save words via the Translate tab to build your collection.',
         'Ова реч још није у твом речнику. Додај речи преко картице Превод да изградиш свој речник.',
         'Ova reč još nije u tvom rečniku. Dodaj reči preko kartice Prevod da izgradiš svoj rečnik.');
  String get repeatAnimation => _s('Repeat', 'Понови', 'Ponovi');

  // Flashcards screen
  String get flashcardTitle => _s('Flash Cards', 'Картице', 'Kartice');
  String get flashcardSubtitle => _s('Test yourself', 'Тестирај се', 'Testiraj se');
  String get flashcardBannerTitle => _s('Practice your vocabulary', 'Вежбај речник', 'Vežbaj rečnik');
  String get flashcardBannerBody =>
      _s('Type the pinyin or English translation for each character from your saved vocabulary. Serbian words count too!',
         'Унеси пинјин или енглески превод за сваки карактер из сачуваног речника. Српске речи важе!',
         'Unesi pinjin ili engleski prevod za svaki karakter iz sačuvanog rečnika. Srpske reči važe!');
  String get typeAnswer => _s('Type pinyin or English…', 'Укуцај пинјин или енглески…', 'Ukucaj pinjin ili engleski…');
  String get typeAnswerEnglish => _s('Type English…', 'Укуцај енглески…', 'Ukucaj engleski…');
  String get typeAnswerSerbian => _s('Type Serbian…', 'Укуцај српски…', 'Ukucaj srpski…');
  String get typeAnswerPinyin  => _s('Type pinyin…', 'Укуцај пинјин…', 'Ukucaj pinjin…');
  String get check => _s('Check', 'Провери', 'Proveri');
  String get next => _s('Next', 'Следеће', 'Sledeće');
  String get correct => _s('Correct!', 'Тачно!', 'Tačno!');
  String get incorrect => _s('Not quite', 'Није тачно', 'Nije tačno');
  String get answer => _s('Answer:', 'Одговор:', 'Odgovor:');
  String get showAnswer => _s('Show answer', 'Прикажи одговор', 'Prikaži odgovor');
  String get noWordsYet =>
      _s('No words saved yet. Use the Translate tab to add words to your vocabulary.',
         'Нема сачуваних речи. Користи картицу Превод да додаш речи.',
         'Nema sačuvanih reči. Koristi Prevod karticu da dodaš reči.');

  // Exam screen
  String get examTitle => _s('Exam', 'Испит', 'Ispit');
  String get examSubtitle => _s('AI-powered quiz', 'Квиз са вештачком интелигенцијом', 'Kviz sa veštačkom inteligencijom');
  String get chooseLessons => _s('Choose lessons (optional)', 'Изабери лекције (опционо)', 'Izaberi lekcije (opciono)');
  String get topic => _s('Topic', 'Тема', 'Tema');
  String get topicPlaceholder => _s('e.g. greetings, food, travel…', 'нпр. поздрави, храна, путовање…', 'npr. pozdravi, hrana, putovanje…');
  String get beginExam => _s('Begin Exam', 'Почни испит', 'Počni ispit');
  String get typeYourAnswer => _s('Type your answer…', 'Укуцај одговор…', 'Ukucaj odgovor…');
  String get submit => _s('Submit', 'Пошаљи', 'Pošalji');
  String get endSession => _s('End Session', 'Заврши сесију', 'Završi sesiju');
  String get evaluating => _s('Evaluating…', 'Евалуација…', 'Evaluacija…');
  String get overallScore => _s('Overall Score', 'Укупан резултат', 'Ukupan rezultat');
  String get strengths => _s('Strengths', 'Предности', 'Prednosti');
  String get improvements => _s('Areas to improve', 'Области за побољшање', 'Oblasti za poboljšanje');
  String get startOver => _s('Start Over', 'Почни изнова', 'Počni iznova');
  String get hint => _s('Hint', 'Наговештај', 'Nagoveštaj');
  String get loadingQuestion => _s('Loading question…', 'Учитавање питања…', 'Učitavanje pitanja…');
  String get examRandomLesson => _s('Random lesson', 'Насумична лекција', 'Nasumična lekcija');
  String get examRandomSubtitle => _s('Picks a random lesson from your library', 'Бира насумичну лекцију из твоје библиотеке', 'Bira nasumičnu lekciju iz tvoje biblioteke');
  String get examRandomSubtitleEmpty => _s('Will use general Chinese topics', 'Користиће опште кинеске теме', 'Koristiće opšte kineske teme');
  String get examChooseLesson => _s('Choose a lesson', 'Изабери лекцију', 'Izaberi lekciju');
  String get examChooseSubtitle => _s('Select one of your saved lessons', 'Изабери једну од сачуваних лекција', 'Izaberi jednu od sačuvanih lekcija');
  String get examNoLessons => _s('No lessons found. Save words via Translate first.', 'Нема лекција. Прво сачувај речи преко Превода.', 'Nema lekcija. Prvo sačuvaj reči preko Prevoda.');
  String get examSelectLesson => _s('Select a lesson…', 'Изабери лекцију…', 'Izaberi lekciju…');
  String get examEnterTopic => _s('Enter a topic', 'Унеси тему', 'Unesi temu');
  String get examEnterTopicSubtitle => _s('Type any topic — greetings, food, travel…', 'Укуцај тему — поздрави, храна, путовање…', 'Ukucaj temu — pozdravi, hrana, putovanje…');
  String get examErrorSelectLesson => _s('Please select a lesson first.', 'Прво изабери лекцију.', 'Prvo izaberi lekciju.');
  String get examErrorEnterTopic => _s('Please enter a topic first.', 'Прво унеси тему.', 'Prvo unesi temu.');
  String get examSummary => _s('Summary', 'Резиме', 'Rezime');
  String get examMistakes => _s('Mistakes', 'Грешке', 'Greške');
  String get examComplete => _s('Exam Complete', 'Испит завршен', 'Ispit završen');
  String get examNewSession => _s('New Session', 'Нова сесија', 'Nova sesija');
  String get examStopAndEvaluate => _s('Stop & Evaluate', 'Заустави и оцени', 'Zaustavi i oceni');
  String get examEvaluatingSession => _s('Evaluating your session…', 'Евалуација сесије…', 'Evaluacija sesije…');
  String get examPreparingQuestion => _s('Preparing exam…', 'Припремање испита…', 'Pripremanje ispita…');
  String get examTopicLabel => _s('Topic', 'Тема', 'Tema');
  String get examQuestionLabel => _s('Question', 'Питање', 'Pitanje');
  String get examYourAnswer => _s('Your answer', 'Твој одговор', 'Tvoj odgovor');
  String get examRevealTranslation => _s('Reveal translation', 'Прикажи превод', 'Prikaži prevod');
  String get examHideTranslation => _s('Hide translation', 'Сакриј превод', 'Sakrij prevod');
  String get transcribed => _s('Transcribed:', 'Транскрибовано:', 'Transkribovano:');
  String get clearAndType => _s('Clear & type instead', 'Обриши и откуцај', 'Obriši i otkucaj');
  String get aiTranslationBadge => _s('AI translation · not in your dictionary yet', 'АИ превод · још није у твом речнику', 'AI prevod · još nije u tvom rečniku');

  // Settings
  String get settingsTitle => _s('Settings', 'Подешавања', 'Podešavanja');
  String get language => _s('Language', 'Језик', 'Jezik');
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
  String get retry => _s('Retry', 'Покушај поново', 'Pokušaj ponovo');
  String get speak => _s('Speak', 'Изговори', 'Izgovori');

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
