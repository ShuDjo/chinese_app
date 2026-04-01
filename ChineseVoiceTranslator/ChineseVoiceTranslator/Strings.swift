struct Strings {
    let lang: AppLanguage
    init(_ lang: AppLanguage) { self.lang = lang }

    // MARK: - Tab labels

    var tabTranslate: String { switch lang {
        case .english: return "Translate"
        case .serbianCyrillic: return "Превод"
        case .serbianLatin: return "Prevod" } }

    var tabExam: String { switch lang {
        case .english: return "Exam"
        case .serbianCyrillic: return "Испит"
        case .serbianLatin: return "Ispit" } }

    var tabCharacters: String { switch lang {
        case .english: return "Characters"
        case .serbianCyrillic: return "Знакови"
        case .serbianLatin: return "Znakovi" } }

    var tabFlashCards: String { switch lang {
        case .english: return "Flash Cards"
        case .serbianCyrillic: return "Картице"
        case .serbianLatin: return "Kartice" } }

    var tabSettings: String { switch lang {
        case .english: return "Settings"
        case .serbianCyrillic: return "Подешавања"
        case .serbianLatin: return "Podešavanja" } }

    // MARK: - ContentView (Translate tab)

    var translateSubtitle: String { switch lang {
        case .english: return "Speak. Transcribe. Learn."
        case .serbianCyrillic: return "Говори. Забележи. Учи."
        case .serbianLatin: return "Govori. Zabeleži. Uči." } }

    var translateBannerTitle: String { switch lang {
        case .english: return "Record, transcribe & build your vocabulary"
        case .serbianCyrillic: return "Снимај, забележи и гради речник"
        case .serbianLatin: return "Snimi, зabeleži i gradi rečnik" } }

    var translateBannerBody: String { switch lang {
        case .english: return "Speak any Chinese sentence and get an instant word-by-word breakdown with translations, pinyin and characters."
        case .serbianCyrillic: return "Реци bilo коју реченицу на кинеском и добићеш тренутни приказ речи по реч са преводима, пинјином и знаковима."
        case .serbianLatin: return "Reci bilo koju rečenicu na kineskom i dobićeš trenutni prikaz reči po reč sa prevodima, pinjinom i znakovima." } }

    var translateBannerBodyType: String { switch lang {
        case .english: return "Type any sentence in English, Serbian, or pinyin to get translation, pinyin and characters."
        case .serbianCyrillic: return "Укуцај реченицу или реч на енглеском, српском или пинјину и добићеш превод, пинјин и знакове."
        case .serbianLatin: return "Ukucaj rečenicu ili reč na engleskom, srpskom ili pinjinu i dobićeš prevod, pinjin i znakove." } }

    var modeMic: String { switch lang {
        case .english: return "Mic"
        case .serbianCyrillic: return "Микрофон"
        case .serbianLatin: return "Mikrofon" } }

    var modeType: String { switch lang {
        case .english: return "Type"
        case .serbianCyrillic: return "Унeси"
        case .serbianLatin: return "Unesi" } }

    var transcribing: String { switch lang {
        case .english: return "Transcribing…"
        case .serbianCyrillic: return "Забележавање…"
        case .serbianLatin: return "Zabeležavanje…" } }

    var lookingUp: String { switch lang {
        case .english: return "Looking up…"
        case .serbianCyrillic: return "Претрага…"
        case .serbianLatin: return "Pretraga…" } }

    var typeEnglishOrPinyin: String { switch lang {
        case .english: return "Type English, Serbian, or pinyin…"
        case .serbianCyrillic: return "Унеси енглески, српски или пинјин…"
        case .serbianLatin: return "Unesi engleski, srpski ili pinjin…" } }

    var noChineseDetected: String { switch lang {
        case .english: return "No Chinese detected. Please speak in Chinese."
        case .serbianCyrillic: return "Нису препознате кинеске речи. Говори на кинеском."
        case .serbianLatin: return "Nisu prepoznate kineske reči. Govori na kineskom." } }

    var lookUp: String { switch lang {
        case .english: return "Look Up"
        case .serbianCyrillic: return "Потражи"
        case .serbianLatin: return "Potraži" } }

    var addedToVocabulary: String { switch lang {
        case .english: return "Added to vocabulary"
        case .serbianCyrillic: return "Додато у речник"
        case .serbianLatin: return "Dodato u rečnik" } }

    var saving: String { switch lang {
        case .english: return "Saving…"
        case .serbianCyrillic: return "Чување…"
        case .serbianLatin: return "Čuvanje…" } }

    var addToVocabulary: String { switch lang {
        case .english: return "Add to Vocabulary"
        case .serbianCyrillic: return "Додај у речник"
        case .serbianLatin: return "Dodaj u rečnik" } }

    var wordsTapToSeeStrokes: String { switch lang {
        case .english: return "Tap a word to watch its stroke order animation"
        case .serbianCyrillic: return "Додирни реч да видиш анимацију редоследа потеза"
        case .serbianLatin: return "Dodirni reč da vidiš animaciju redosleda poteza" } }

    var tapToStop: String { switch lang {
        case .english: return "Tap to stop"
        case .serbianCyrillic: return "Додирни да зауставиш"
        case .serbianLatin: return "Dodirni da zaustaviš" } }

    var tapToRecord: String { switch lang {
        case .english: return "Tap to record"
        case .serbianCyrillic: return "Додирни да снимиш"
        case .serbianLatin: return "Dodirni da snimiš" } }

    var acceptAndSave: String { switch lang {
        case .english: return "Accept and save to your dictionary"
        case .serbianCyrillic: return "Прихвати и сачувај у речник"
        case .serbianLatin: return "Prihvati i sačuvaj u rečnik" } }

    // MARK: - QuizView (Exam tab)

    var examSubtitle: String { switch lang {
        case .english: return "Chinese Examination Simulator"
        case .serbianCyrillic: return "Симулатор кинеског испита"
        case .serbianLatin: return "Simulator kineskog ispita" } }

    var examBannerTitle: String { switch lang {
        case .english: return "AI-powered Chinese oral examination"
        case .serbianCyrillic: return "AI-подржан усмени испит из кинеског"
        case .serbianLatin: return "AI-podržan usmeni ispit iz kineskog" } }

    var examBannerBody: String { switch lang {
        case .english: return "Select a lesson or topic. The AI examiner asks all questions in Chinese, adapts to your answers, and evaluates your performance at the end with a detailed score and feedback."
        case .serbianCyrillic: return "Изабери лекцију или тему. AI испитивач поставља сва питања на кинеском, прилагођава се твојим одговорима и на крају даје оцену и детаљне повратне информације."
        case .serbianLatin: return "Izaberi lekciju ili temu. AI ispitivač postavlja sva pitanja na kineskom, prilagođava se tvojim odgovorima i na kraju daje ocenu i detaljne povratne informacije." } }

    var quickStart: String { switch lang {
        case .english: return "Quick Start"
        case .serbianCyrillic: return "Брзи почетак"
        case .serbianLatin: return "Brzi početak" } }

    var random: String { switch lang {
        case .english: return "Random"
        case .serbianCyrillic: return "Случајно"
        case .serbianLatin: return "Slučajno" } }

    var byLesson: String { switch lang {
        case .english: return "By Lesson"
        case .serbianCyrillic: return "По лекцији"
        case .serbianLatin: return "Po lekciji" } }

    var selectALesson: String { switch lang {
        case .english: return "Select a lesson:"
        case .serbianCyrillic: return "Изабери лекцију:"
        case .serbianLatin: return "Izaberi lekciju:" } }

    func coversAllMaterialUpTo(_ name: String) -> String { switch lang {
        case .english: return "Covers all material up to \(name)"
        case .serbianCyrillic: return "Обухвата сав материјал до \(name)"
        case .serbianLatin: return "Obuhvata sav materijal do \(name)" } }

    var customTopic: String { switch lang {
        case .english: return "Custom Topic"
        case .serbianCyrillic: return "Произвољна тема"
        case .serbianLatin: return "Proizvoljna tema" } }

    var topicPlaceholder: String { switch lang {
        case .english: return "e.g. greetings, measure words, tones"
        case .serbianCyrillic: return "нпр. поздрави, мерне речи, тонови"
        case .serbianLatin: return "npr. pozdravi, merne reči, tonovi" } }

    var preparingExamination: String { switch lang {
        case .english: return "Preparing examination…"
        case .serbianCyrillic: return "Припрема испита…"
        case .serbianLatin: return "Priprema ispita…" } }

    var beginExam: String { switch lang {
        case .english: return "Begin Exam"
        case .serbianCyrillic: return "Започни испит"
        case .serbianLatin: return "Započni ispit" } }

    var topicLabel: String { switch lang {
        case .english: return "Topic"
        case .serbianCyrillic: return "Тема"
        case .serbianLatin: return "Tema" } }

    var loadingQuestion: String { switch lang {
        case .english: return "Loading question…"
        case .serbianCyrillic: return "Учитавање питања…"
        case .serbianLatin: return "Učitavanje pitanja…" } }

    var questionLabel: String { switch lang {
        case .english: return "Question"
        case .serbianCyrillic: return "Питање"
        case .serbianLatin: return "Pitanje" } }

    var hideTranslation: String { switch lang {
        case .english: return "Hide translation"
        case .serbianCyrillic: return "Сакриј превод"
        case .serbianLatin: return "Sakrij prevod" } }

    var revealTranslation: String { switch lang {
        case .english: return "Reveal translation"
        case .serbianCyrillic: return "Открај превод"
        case .serbianLatin: return "Otkrij prevod" } }

    var yourAnswer: String { switch lang {
        case .english: return "Your answer"
        case .serbianCyrillic: return "Твој одговор"
        case .serbianLatin: return "Tvoj odgovor" } }

    var evaluatingSession: String { switch lang {
        case .english: return "Evaluating answers…"
        case .serbianCyrillic: return "Евалуација одговора…"
        case .serbianLatin: return "Evaluacija odgovora…" } }

    var stopAndEvaluate: String { switch lang {
        case .english: return "Stop & Evaluate"
        case .serbianCyrillic: return "Заустави и оцени"
        case .serbianLatin: return "Zaustavi i oceni" } }

    var examComplete: String { switch lang {
        case .english: return "Exam Complete"
        case .serbianCyrillic: return "Испит завршен"
        case .serbianLatin: return "Ispit završen" } }

    var strengths: String { switch lang {
        case .english: return "Strengths"
        case .serbianCyrillic: return "Предности"
        case .serbianLatin: return "Prednosti" } }

    var toImprove: String { switch lang {
        case .english: return "To Improve"
        case .serbianCyrillic: return "За побољшање"
        case .serbianLatin: return "Za poboljšanje" } }

    var mistakes: String { switch lang {
        case .english: return "Mistakes"
        case .serbianCyrillic: return "Грешке"
        case .serbianLatin: return "Greške" } }

    func yourAnswerWas(_ answer: String) -> String { switch lang {
        case .english: return "Your answer: \(answer)"
        case .serbianCyrillic: return "Твој одговор: \(answer)"
        case .serbianLatin: return "Tvoj odgovor: \(answer)" } }

    var newSession: String { switch lang {
        case .english: return "New Session"
        case .serbianCyrillic: return "Нова сесија"
        case .serbianLatin: return "Nova sesija" } }

    // MARK: - CharacterView

    var characterSubtitle: String { switch lang {
        case .english: return "Look up stroke order and see animations"
        case .serbianCyrillic: return "Претражи редослед потеза и погледај анимације"
        case .serbianLatin: return "Pretraži redosled poteza i pogledaj animacije" } }

    var characterBannerTitle: String { switch lang {
        case .english: return "Look up any character & learn its strokes"
        case .serbianCyrillic: return "Потражи знак и научи редослед потеза"
        case .serbianLatin: return "Potraži znak i nauči redosled poteza" } }

    var characterBannerBody: String { switch lang {
        case .english: return "Search by English word, Serbian word, pinyin, or Chinese characters to instantly see the meaning, pronunciation, and an animated stroke-by-stroke drawing of every character."
        case .serbianCyrillic: return "Претражи реч на енглеском или српском, пинјину или кинеском знаку и одмах види значење, изговор и анимирани цртеж сваког знака потез по потез."
        case .serbianLatin: return "Pretraži reč na engleskom ili srpskom, pinjinu ili kineskom znaku i odmah vidi značenje, izgovor i animirani crtež svakog znaka potez po potez." } }

    var englishPinyinOrChinese: String { switch lang {
        case .english: return "English, Serbian, Pinyin, or Chinese"
        case .serbianCyrillic: return "Енглески, српски, пинјин или кинески"
        case .serbianLatin: return "Engleski, srpski, pinjin ili kineski" } }

    var characterPlaceholder: String { switch lang {
        case .english: return "e.g.  hello  •  zdravo  •  ni hao  •  你好"
        case .serbianCyrillic: return "нпр.  zdravo  •  ni hao  •  你好"
        case .serbianLatin: return "npr.  zdravo  •  ni hao  •  你好" } }

    var characterHint: String { switch lang {
        case .english: return "Works with any English or Serbian word, pinyin (e.g. ni hao), or Chinese characters."
        case .serbianCyrillic: return "Ради са bilo којом енглеском или српском речи, пинјином (нпр. ni hao) или кинеским знаком."
        case .serbianLatin: return "Radi sa bilo kojom engleskom ili srpskom reči, pinjinom (npr. ni hao) ili kineskim znakom." } }

    // MARK: - FlashcardView

    var flashcardSubtitle: String { switch lang {
        case .english: return "Test what you've learned"
        case .serbianCyrillic: return "Тестирај своје знање"
        case .serbianLatin: return "Testiraj svoje znanje" } }

    var flashcardBannerTitle: String { switch lang {
        case .english: return "Quiz yourself on your saved vocabulary"
        case .serbianCyrillic: return "Тестирај се на сачуваном речнику"
        case .serbianLatin: return "Testiraj se na sačuvanom rečniku" } }

    var flashcardBannerBody: String { switch lang {
        case .english: return "A random character from your vocabulary is shown — type its English meaning, Serbian meaning, or pinyin to test your memory. Use Show Answer if you're stuck, then move on to keep the streak going."
        case .serbianCyrillic: return "Приказује се случајни знак из твог речника — унеси значење на енглеском, српском или пинјин да тестираш памћење. Употреби Прикажи одговор ако заглавиш, па настави."
        case .serbianLatin: return "Prikazuje se slučajni znak iz tvog rečnika — unesi značenje na engleskom, srpskom ili pinjin da testiraš pamćenje. Upotrebi Prikaži odgovor ako zaglaviš, pa nastavi." } }

    var whatDoesThisMean: String { switch lang {
        case .english: return "What does this mean?"
        case .serbianCyrillic: return "Шта ово значи?"
        case .serbianLatin: return "Šta ovo znači?" } }

    var englishOrPinyin: String { switch lang {
        case .english: return "English, Serbian, or Pinyin"
        case .serbianCyrillic: return "Енглески, српски или пинјин"
        case .serbianLatin: return "Engleski, srpski ili pinjin" } }

    var typeYourAnswer: String { switch lang {
        case .english: return "Type your answer..."
        case .serbianCyrillic: return "Унеси одговор..."
        case .serbianLatin: return "Unesi odgovor..." } }

    var correct: String { switch lang {
        case .english: return "Correct!"
        case .serbianCyrillic: return "Тачно!"
        case .serbianLatin: return "Tačno!" } }

    var incorrect: String { switch lang {
        case .english: return "Incorrect"
        case .serbianCyrillic: return "Нетачно"
        case .serbianLatin: return "Netačno" } }

    func englishValue(_ v: String) -> String { switch lang {
        case .english: return "English: \(v)"
        case .serbianCyrillic: return "Енглески: \(v)"
        case .serbianLatin: return "Engleski: \(v)" } }

    func pinyinValue(_ v: String) -> String { switch lang {
        case .english: return "Pinyin: \(v)"
        case .serbianCyrillic: return "Пинјин: \(v)"
        case .serbianLatin: return "Pinjin: \(v)" } }

    func serbianValue(_ v: String) -> String { switch lang {
        case .english: return "Serbian: \(v)"
        case .serbianCyrillic: return "Српски: \(v)"
        case .serbianLatin: return "Srpski: \(v)" } }

    var showAnswer: String { switch lang {
        case .english: return "Show Answer"
        case .serbianCyrillic: return "Прикажи одговор"
        case .serbianLatin: return "Prikaži odgovor" } }

    var nextCard: String { switch lang {
        case .english: return "Next Card"
        case .serbianCyrillic: return "Следећа картица"
        case .serbianLatin: return "Sledeća kartica" } }

    var submit: String { switch lang {
        case .english: return "Submit"
        case .serbianCyrillic: return "Потврди"
        case .serbianLatin: return "Potvrdi" } }

    var start: String { switch lang {
        case .english: return "Start"
        case .serbianCyrillic: return "Почни"
        case .serbianLatin: return "Počni" } }

    var tryAgain: String { switch lang {
        case .english: return "Try Again"
        case .serbianCyrillic: return "Покушај поново"
        case .serbianLatin: return "Pokušaj ponovo" } }

    // MARK: - SharedComponents (WordRowView)

    var speak: String { switch lang {
        case .english: return "Speak"
        case .serbianCyrillic: return "Изговори"
        case .serbianLatin: return "Izgovori" } }

    var pinyin: String { switch lang {
        case .english: return "Pinyin"
        case .serbianCyrillic: return "Пинјин"
        case .serbianLatin: return "Pinjin" } }

    var english: String { switch lang {
        case .english: return "English"
        case .serbianCyrillic: return "Енглески"
        case .serbianLatin: return "Engleski" } }

    var typePinyin: String { switch lang {
        case .english: return "Type pinyin…"
        case .serbianCyrillic: return "Унеси пинјин…"
        case .serbianLatin: return "Unesi pinjin…" } }

    var typeEnglish: String { switch lang {
        case .english: return "Type English…"
        case .serbianCyrillic: return "Унеси енглески…"
        case .serbianLatin: return "Unesi engleski…" } }

    func answerWas(_ value: String) -> String { switch lang {
        case .english: return "Answer: \(value)"
        case .serbianCyrillic: return "Одговор: \(value)"
        case .serbianLatin: return "Odgovor: \(value)" } }

    // MARK: - SettingsView

    var settingsTitle: String { switch lang {
        case .english: return "Language"
        case .serbianCyrillic: return "Језик"
        case .serbianLatin: return "Jezik" } }

    var settingsSubtitle: String { switch lang {
        case .english: return "Choose display language"
        case .serbianCyrillic: return "Изабери језик приказа"
        case .serbianLatin: return "Izaberi jezik prikaza" } }
}
