# Архитектура LocalFlow

Указатели по коду. Откуда что берётся и куда идёт — ниже; как собрать и поставить — `README.md` / `INSTALL-ru.md`; почему решено так, а не иначе — `docs/adr/`; словарь терминов — `CONTEXT.md`.

## Поток данных: запись → проверка длительности → whisper.cpp → фильтры → буфер

Весь путь — один вызов `DictationController.toggle()` → `finish()` → `transcribe()` (`App/Dictation/DictationController.swift`), повторяет порядок `_finalize` десктопного LocalFlow:

1. **Запись** — `AudioRecorder.start()/stop()` (`App/Audio/AudioRecorder.swift`): `AVAudioEngine`, тап на входном узле, конвертация в 16 кГц mono Float прямо в обработчике тапа, накопление в `samples` под `NSLock`. Звук живёт только в памяти, на диск не пишется (R43).
2. **Проверка длительности** — `RecordingGuard.decide(hold:audio:)` (`Core/Sources/LocalFlowCore/RecordingGuard.swift`): `hold` — время от нажатия до отпускания, `audio` — секунды реально записанного звука (`samples.count / sampleRate`). Результат — `RecordingDecision`: `.reject(RejectReason)` (слишком коротко / потеря звука) или `.transcribe(keepLastSeconds:)`. Перевод `keepLastSeconds` в отсчёты (`Int(keepLastSeconds * sampleRate)`, обрезка `samples` по последним N отсчётам) — на вызывающей стороне, в `DictationController.finish()`, не в `LocalFlowCore`.
3. **whisper.cpp** — `WhisperEngine.transcribe(_:expectedModel:)` (`App/Engine/WhisperEngine.swift`, `actor`): C-API whisper.cpp напрямую, параметры — только из `ASRSettings` (`Core/Sources/LocalFlowCore/ASRSettings.swift`): язык `ru`, `beamSize = 5`, `noContext = true`, VAD Silero (`vadThreshold`, `vadMinSilenceMs`, `vadSpeechPadMs`, `vadMinSpeechMs` — умолчания faster-whisper, см. `docs/adr/0006`), `initialPrompt` дословно из LocalFlow `asr.py`. Клип короче `ASRSettings.minSamples` — пустая строка без вызова модели. `expectedModel` не совпал с `loadedModelID` движка — `EngineError.wrongModel`, без распознавания.
4. **Фильтры** — `TextPipeline.process(raw:replacements:)` (`Core/Sources/LocalFlowCore/TextPipeline.swift`): порядок фиксирован — выдумка Whisper (`Hallucinations.matches`) → слова-паразиты (`Fillers.remove`) → словарь замен (`Replacements.apply`). Пусто после фильтров → `.rejected(.empty)`.
5. **Буфер** — `DictationController.transcribe()` кладёt текст в `UIPasteboard.general.string`, включает вибро, ставит `state = .copied(text:)`.

На каждом шаге возможен отказ — заканчивается в `DictationState` (`App/Dictation/DictationState.swift`): `.rejected(RejectReason)` с готовым текстом для экрана (`RejectReason.message`) или `.failed(String)` (обрыв записи, ошибка движка).

## Границы модулей

### `LocalFlowCore` (`Core/`) — чистая логика, без iOS

Swift Package без зависимостей от UIKit/SwiftUI, только Foundation; тестируется `swift test` на Linux в CI (`docs/adr/0003`). Владеет: правилами отказа по длительности (`RecordingGuard`, `RejectReason`), списком выдумок Whisper (`Hallucinations`), вырезкой слов-паразитов (`Fillers`), словарём замен (`Replacements`), склейкой этого в один пайплайн (`TextPipeline`), параметрами ASR (`ASRSettings`), форматированием чисел с запятой (`DecimalComma`) и отчётом экрана «Замер» (`BenchReport`, `BenchRow`). Файлы — `Core/Sources/LocalFlowCore/*.swift`, один файл на тип; тесты зеркалят имена в `Core/Tests/LocalFlowCoreTests/`.

Граница держится в одну сторону: `App/` зависит от `LocalFlowCore`, обратной зависимости нет. Любая логика, которую можно проверить без iPhone, идёт в `Core`, а не в `App`.

### `App/` — iOS-приложение (SwiftUI, iOS 17+)

| Модуль | Файл | Владеет | Открывает |
|---|---|---|---|
| `AudioRecorder` | `App/Audio/AudioRecorder.swift` | микрофон, `AVAudioEngine`, перевод в 16 кГц mono Float | `requestPermission()`, `permission`, `start() throws`, `stop() -> [Float]`, `level` |
| `WhisperEngine` (actor) | `App/Engine/WhisperEngine.swift` | C-контекст whisper.cpp, одна модель в памяти | `load(model:vad:id:) throws`, `transcribe(_:expectedModel:) async throws -> String`, `unload()`, `isLoaded`, `loadedModelID` |
| `ModelStore` | `App/Models/ModelStore.swift` | каталог моделей, загрузка/импорт/удаление, общие файлы iTunes, выбранная модель, состояние движка | `catalog`, `downloaded`, `selected`, `engineState`, `download(_:progress:) async throws`, `importFile(at:) async throws`, `adoptSharedFiles() async`, `delete(_:) async throws`, `select(_:) async`, `loadSelected() async` |
| `ModelInfo` | `App/Models/ModelInfo.swift` | каталог трёх моделей (id, title, fileName, url, bytes, sha256) | `catalog`, `identify(bytes:in:)`, `formatBytes(_:)`, `catalogListText` |
| `MemoryProbe` | `App/Engine/MemoryProbe.swift` | замер памяти процесса (`phys_footprint`) | `currentMB() -> Double` |
| `DictationController` | `App/Dictation/DictationController.swift` | состояние диктовки, порядок шагов, таймер записи, буфер обмена | `state`, `toggle()`, `startFromIntent()`, `lastText`, `lastDuration`, `isBenchRunning` |
| `DictationReplacements` | `App/Dictation/DictationReplacements.swift` | единая точка входа в словарь замен для диктовки | `current() -> Replacements` |
| `ReplacementsFile` | `App/Dictionary/ReplacementsFile.swift` | файл словаря в Documents | `load() -> Replacements`, `save(_:) throws` |
| `AppNavigation` | `App/Dictation/AppNavigation.swift` | выбранная вкладка `TabView` | `tab: AppTab` |
| `StartDictationIntent` | `App/Intents/StartDictationIntent.swift` | App Intent «Начать диктовку» для «Команд» | открывает приложение, вызывает `startFromIntent()` |
| `BenchRunner`, `PhraseRecorder`, `DeviceInfo` | `App/Bench/*.swift` | прогон «Замер»: своя запись фразы, прогон через каждую модель, сбор `BenchRow` | использует `WhisperEngine.shared` и `ModelStore.shared` напрямую |

Экраны (`App/UI/*.swift`): `DictationView`, `ModelsView`, `DictionaryView`, `BenchView` — навигация `TabView` в `App/LocalFlowApp.swift`.

Состояния:

```swift
enum DictationState: Equatable {
    case noModel, micDenied, idle
    case recording(since: Date)
    case transcribing
    case copied(text: String)
    case rejected(RejectReason)
    case failed(String)
}

enum EngineState: Equatable {
    case empty, loading(String)
    case loaded(ModelInfo.ID)
    case failed(String)
}
```

`engineState == .loaded(id)` выставляется только когда `WhisperEngine.loadedModelID == id` — рассинхрон (например, во время переключения модели) не выдаётся за готовность.

## Соглашения

- Имена в коде — английские, тексты для пользователя — русские (см. заголовок `CONTEXT.md`).
- Один публичный тип — один файл и в `Core/Sources`, и в `App/`.
- Числа в интерфейсе — только через `DecimalComma.string(_:digits:)`, второй форматтер не писать.
- Модель в `WhisperEngine` всегда одна; перед `load` прежняя обязательно выгружается.
- Сеть — только `ModelStore.download` (Hugging Face, по кнопке пользователя); обычная `URLSession`, не фоновая (`docs/adr/0005`) — при уходе из приложения загрузка может оборваться, это осознанно.
- Файл модели опознаётся по точному размеру в байтах (`ModelInfo.identify`), принимается — только после сверки sha256; при несовпадении файл удаляется, причина — в `ModelStoreError`.
- Вкладку «Модели» нельзя убирать из `TabView` — её создание будит `ModelStore.shared`, без этого хоть одна вкладка должна трогать `ModelStore.shared` при запуске.
- «Замер» (`App/Bench/BenchRunner.swift`) временно подменяет модель в `WhisperEngine.shared`; обязан снять `DictationController.isBenchRunning` только после `ModelStore.shared.loadSelected()`, иначе диктовка после замера может стартовать на чужой модели.

## Сборка

- `project.yml` (XcodeGen) описывает таргет `LocalFlow`, зависимость на пакет `Core` и на `build/vendor/whisper.xcframework`; `.xcodeproj` в git не хранится.
- `whisper.xcframework` (релиз `b5454`, MIT) и VAD-модель `ggml-silero-v6.2.0.bin` (Silero, MIT) кладёт `.github/workflows/ios-build.yml` перед `xcodegen generate` — в git их нет (`docs/adr/0001`).
- sha256 обеих закачек, XcodeGen и трёх моделей Whisper закреплён и в workflow, и в `App/Models/ModelInfo.swift` — расхождение ломает загрузку/сборку намеренно, а не тихо.
- `.github/workflows/core-tests.yml` — `swift test` в `Core/` на `ubuntu-latest`, при каждом push.
- `.github/workflows/ios-build.yml` — `macos-26`, собирает `LocalFlow.ipa` без подписи, кладёт артефактом прогона.

## Швы для тестов

Тестируется только публичный API `LocalFlowCore` (раздел «Границы модулей» выше) — `swift test` в CI. `App/` проверяется сборкой в CI и руками на телефоне по `INSTALL-ru.md` / `CHECKS-ru.md`; локального запуска нет (Swift на машине разработки не установлен).
