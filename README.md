# LocalFlow для iPhone

Офлайн-диктовка на русском для iPhone 11: нажал кнопку (или дважды стукнул по задней
панели) — пошла запись; нажал ещё раз — через несколько секунд распознанный текст с
пунктуацией уже в буфере обмена, на экране видно его и отметку «Скопировано». Распознаёт
Whisper прямо на телефоне, без интернета (whisper.cpp, MIT) — та же логика фильтров и
словаря замен, что в десктопном LocalFlow.

**Приложение ещё не проверено на телефоне.** Сборка в GitHub Actions зелёная (см. ниже),
но установка и диктовка на реальном iPhone 11 — следующий шаг, не этот документ его
подтверждает.

## Как собрать

Swift на машине разработки нет — сборка идёт только в GitHub Actions:

- `.github/workflows/core-tests.yml` — тесты ядра `LocalFlowCore` (`swift test`) на
  `ubuntu-latest`, при каждом push.
- `.github/workflows/ios-build.yml` — сборка `.ipa` без подписи на `macos-26`
  (XcodeGen 2.46.0 → `xcodebuild` → упаковка `LocalFlow.app` в `LocalFlow.ipa`); артефакт
  `LocalFlow.ipa` лежит в прогоне на вкладке Actions. Запуск — на push в `main` или
  вручную (`workflow_dispatch`).

## Сборка: минуты Actions

Репозиторий публичный — минуты GitHub Actions ничего не стоят: «GitHub Actions usage is
free for self-hosted runners and for public repositories that use standard
GitHub-hosted runners» (docs.github.com/en/billing/concepts/product-billing/github-actions).
**0 — публичный** репозиторий, та же ссылка.

Если бы репозиторий был приватным: на тарифе Free бесплатно 2 000 минут в месяц, дальше
$0,062 за минуту на раннере macOS против $0,006 на Linux (та же страница); как именно
считается квота минут на macOS (списывается ли быстрее, чем минута за минуту) — на
странице не сказано, **не проверено**.

## Развилка подписи

Бесплатный Apple ID подписывает приложение на 7 дней: «Provisioning profiles that enable
apps to be installed on a device will expire 7 days from issuance»
(developer.apple.com/support/compare-memberships). Платный Apple Developer Program это
снимает, но стоит 99 $ в год (developer.apple.com/programs) — оплата из России недоступна:
«As of April 1, 2026, payment for Apple subscriptions and digital purchases is no longer
available in Russia» (support.apple.com/en-us/126891). TrollStore подписи вообще не
требует, но на iOS 26.6.1 не работает: «Supported versions: 14.0 beta 2 - 16.6.1, 16.7 RC
(20H18), 17.0»; «17.0.1+ will NEVER be supported» (github.com/opa334/TrollStore) — на
iPhone 11 с iOS 26.6.1 невозможен.

| Путь | Деньги | Компьютер для продления | Ограничения | Источник |
|---|---|---|---|---|
| **SideStore + iloader — основной путь** | 0 | только один раз при установке; дальше продление кнопкой на телефоне | 3 приложения одновременно (считая сам SideStore), 10 разных в неделю | docs.sidestore.io (faq, installation/prerequisites); iloader — github.com/nab138/iloader, MIT |
| **Sideloadly — запасной путь** | 0 | да: раз в 7 дней ноутбук с Sideloadly в той же Wi-Fi (или кабель) | те же 3 приложения / 10 в неделю | sideloadly.io |
| AltStore Classic + AltServer | 0 | да: AltServer на ноутбуке в той же Wi-Fi, продление в фоне | 3 приложения одновременно, считая сам AltStore | faq.altstore.io (altstore-classic/app-ids, activating-apps) |
| Apple Developer Program | 99 $ / год | нет | TestFlight и App Store Connect только участникам | developer.apple.com/programs; оплата из России недоступна (support.apple.com/en-us/126891) |

Пошаговая установка по основному и запасным путям — `INSTALL-ru.md`.

## Как поставить

Пошагово, с Windows, через SideStore и iloader (запасные пути — Sideloadly,
AltServer/AltStore Classic) — `INSTALL-ru.md`. Что проверить на каждом шаге —
`CHECKS-ru.md`.

## Открытые компоненты

whisper.cpp, XcodeGen, Silero VAD, конвертация весов Whisper в ggml — все MIT, авторы
и полные тексты лицензий в `THIRD_PARTY.md`. GPL в сборке нет.

## Их приложение (Aiko) / наше

Сравнение по открытым материалам Aiko (App Store, sindresorhus.com/aiko):

| У Aiko | У нас | Почему |
|---|---|---|
| Офлайн на устройстве | повторено | — |
| whisper.cpp | повторено | открытый, MIT, работает на A13 без Core ML |
| Модель medium/small по свободной памяти, автоматически | изменено: три модели, выбор по замеру на телефоне | скорость на A13 не была известна заранее |
| Large v2 вместо v3 | не повторено напрямую: v2 как large не влезает; turbo (v3) — в замере | на телефоне large-v2 не помещается; turbo хорошо работает в LocalFlow |
| Модель внутри сборки (1,8 ГБ) | изменено: однократная загрузка с Hugging Face | три модели для сравнения, сборка меньше |
| Язык — только автоопределение | не повторено: всегда `ru` | в LocalFlow автоопределение ошибалось на коротких фразах |
| Prompt в настройках | повторено как фиксированный русский `initial_prompt` | — |
| «Skip silent parts» | повторено: Silero VAD 0,3 / 500 мс + порог тишины whisper.cpp | — |
| Против выдумок — только настройка | добавлено: список известных выдумок Whisper + проверки длительности и потери звука | — |
| Пунктуацию советуют чинить ChatGPT | не повторено | облачный сервис; отдельной чистки текста в LocalFlow нет |
| Словаря замен нет | добавлено, правится на телефоне (вкладка «Словарь») | — |
| Без live-текста, приложение держать открытым | повторено | ограничение iOS, см. ниже |
| «Команды» | повторено: «Начать диктовку» + двойное касание задней панели | — |
| Экспорт JSON/CSV/SRT | не повторено | цель — буфер обмена, не файлы |
| Клавиатуры нет | так же нет | у клавиатуры-расширения нет доступа к микрофону (см. ниже) |
| Задержка: не установлена по открытым материалам | **не проверено** | у нас — **не замерено на моём телефоне**; на вкладке «Замер» цель не больше 5 c после второго нажатия, это критерий приёмки, не факт |
| Батарея: не установлена по открытым материалам | **не проверено** | у нас — **не замерено на моём телефоне** |
| Экраны и шаги: запись или готовый файл → расшифровка при открытом приложении → экспорт | кнопка «Диктовка» → распознавание при открытом приложении → текст сразу в буфере обмена | цель — вставить текст одним движением, не хранить файлы |
| Данные (не собирает): «The developer does not collect any data from this app» (apps.apple.com/us/app/aiko/id1672085276) | то же: сеть — только разовая загрузка модели с Hugging Face по нажатию кнопки, аналитики и трекеров нет (см. раздел «Ограничения iOS» ниже) | распознавание и хранение — только на телефоне у обоих |
| 24 $ в App Store | 0 — публичный репозиторий, бесплатный Apple ID | — |

## Ограничения iOS

| Ограничение | Что значит для нас | Источник |
|---|---|---|
| Клавиатуры-расширения не имеют доступа к микрофону — «Custom keyboards, like all app extensions in iOS 8.0, have no access to the device microphone, so dictation input is not possible.» | клавиатуру не делаем, запись — только в основном приложении | developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html |
| Лимит памяти клавиатуры-расширения | Apple не публикует; README проекта Dictus указывает «~50 MB» — Whisper в такой лимит не поместился бы, это ещё одна причина не делать клавиатуру | github.com/getdictus/dictus-ios |
| Запись на iOS идёт, только пока приложение открыто | так же у нас: запуск через «Команды» открывает приложение, а не держит его в фоне | FAQ Aiko: «iOS apps are fundamentally restricted from operating in the background» |
| App Intents, `openAppWhenRun` — «consider the app intent even if its app is not in the foreground» (iOS 16+; начиная с iOS 26 помечен устаревшим: «Use supportedModes instead») | команда «Начать диктовку» открывает приложение; на iOS 26+ используем `supportedModes` | developer.apple.com/documentation/appintents/appintent/openappwhenrun |
| `AudioRecordingIntent` (iOS 18+) — «you must start a Live Activity … If you don't start a Live Activity, the audio recording stops» | запись без открытия приложения руками возможна только через Live Activity | developer.apple.com/documentation/appintents/audiorecordingintent |
| Live Activity (iOS 18+) — та же страница, что выше про `AudioRecordingIntent` | не делаем в этой сборке: усложняет сборку, запись и так начинается через открытие приложения | developer.apple.com/documentation/appintents/audiorecordingintent |
| Двойное касание задней панели: iPhone 8+, iOS 14+ | iPhone 11 подходит | support.apple.com/guide/shortcuts/apd897693606/ios; support.apple.com/en-us/111772 |
| Минимальная iOS приложения — 17.0 | покрывает любую систему на iPhone 11 (поддерживает iOS 26 и 27) | project.yml, support.apple.com (списки совместимости) |

## Модели

Три модели для сравнения на вкладке «Замер» — выбор модели по умолчанию делается
после замера на телефоне, замер ещё не проведён.

| Модель | Файл, байт (Hugging Face API) | Память (README whisper.cpp) | Русский, WER FLEURS (arXiv 2212.04356, табл. 13) | Скорость на A13 |
|---|---|---|---|---|
| small | 487 601 967 | ~852 МБ | 11,4 % | **не замерено на моём телефоне** |
| medium-q5_0 | 539 212 467 | не указана (у полной medium ~2,1 ГБ) | 7,2 % у полной medium; у сжатой — не проверено | **не замерено на моём телефоне** |
| large-v3-turbo-q5_0 | 574 041 195 | не указана | в статье нет (turbo вышла позже) — не проверено | **не замерено на моём телефоне** |

Все три скачиваются по кнопке с `huggingface.co/ggerganov/whisper.cpp` (конвертация
весов Whisper в формат ggml, MIT) — подробности и ссылки в `THIRD_PARTY.md` и
`INSTALL-ru.md`.

## Документы

- `INSTALL-ru.md` — как поставить на iPhone с Windows.
- `CHECKS-ru.md` — как проверить каждый шаг самому.
- `THIRD_PARTY.md` — открытые компоненты и лицензии.
