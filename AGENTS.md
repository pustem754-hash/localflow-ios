<!-- autopilot:start -->
# LocalFlow для iPhone

Офлайн-диктовка на русском для iPhone 11: нажал кнопку, сказал фразу — текст с пунктуацией в буфере обмена. Для владельца репозитория, бесплатно, сборка с Windows.

Репозиторий публичный: `github.com/pustem754-hash/localflow-ios`, ветка `main`.

## Где что лежит

- Архитектура, поток данных, границы модулей — `docs/architecture.md`.
- Решения и почему так — `docs/adr/0001`…`0006`.
- Словарь терминов проекта — `CONTEXT.md`.
- Логика без iOS (фильтры, проверки длительности, замены) — `Core/Sources/LocalFlowCore`, тесты — `Core/Tests/LocalFlowCoreTests`.
- iOS-приложение (SwiftUI) — `App/`; сборка собирается из него через `project.yml` (XcodeGen).
- Как собрать и поставить на телефон — `README.md`, `INSTALL-ru.md`; что проверить на телефоне — `CHECKS-ru.md`.
- Открытые зависимости и лицензии — `THIRD_PARTY.md`.

## Как проверить (локально Swift нет — только CI)

```sh
git push origin main
gh run list -R pustem754-hash/localflow-ios --limit 10
gh run watch <id> -R pustem754-hash/localflow-ios --exit-status   # core-tests и ios-build — отдельные id
```

Зелёные `core-tests` и `ios-build` на `HEAD` — проверка пройдена. Красный — `gh run view <id> --log-failed -R pustem754-hash/localflow-ios`, чинить, снова.

Артефакт сборки — `LocalFlow.ipa` (смотреть в `gh run view <id> -R pustem754-hash/localflow-ios`, раздел Artifacts).

Не проверено здесь (нужен Mac): `cd Core && swift test`; `xcodegen generate` по `project.yml` — шаги см. `.github/workflows/ios-build.yml`.

## Подводные камни

- На Windows нет Swift — любая проверка идёт только через GitHub Actions (`core-tests.yml`, `ios-build.yml`).
- `whisper.xcframework` и VAD-модель (`ggml-silero-v6.2.0.bin`) кладёт `ios-build.yml` перед сборкой — в git их нет (`.gitignore`: `*.xcframework/`, `*.bin`).
- sha256 загрузок (whisper.xcframework, VAD-модель, XcodeGen, веса Whisper) закреплён и в workflow, и в `App/Models/ModelInfo.swift` — расходиться не должны.
- Вкладку «Модели» в `TabView` (`App/Dictation/AppNavigation.swift`) не убирать — она будит `ModelStore.shared`, без неё приложение не видит скачанные модели.
- «Замер» (`App/Bench/BenchRunner.swift`) обязан снимать `DictationController.isBenchRunning` только после `ModelStore.shared.loadSelected()` — иначе диктовка стартует на чужой модели в движке.
- Перевод `keepLastSeconds` (из `RecordingGuard.decide`) в отсчёты делает вызывающий код (`DictationController.finish()`), не `LocalFlowCore`.

## Как здесь работает Autopilot

Сборка ведётся навыком `/autopilot`. Требования, спецификация и таски — в `.autopilot/`.
Прогресс — `.autopilot/dashboard.html`. Требование из `manifest.md` может снять
только пользователь. Прерванную сборку продолжает «продолжи автопилот».

`.autopilot/` и `BRIEF.md` — локальные, в публичный репозиторий не попадают (`.gitignore`).

### Правка без автопилота

Мелкий баг или доводка после сборки — обычная сессия, без прогона.

Сначала прочитай:
1. `.autopilot/PROGRESS.md` — что не доделано, известные баги, о чём договорились с пользователем.
2. Что правили после последней сборки — первая строка таблицы в «История git».
3. Только если правка их касается: почему сделано так — `docs/adr/`; что значат слова — `CONTEXT.md`;
   что именно просили — `manifest.md` в папке сборки (указана в начале `PROGRESS.md`).

После правки:
- коммит — по правилам из «История git»;
- строка в «Правки без автопилота» в `PROGRESS.md`: дата — что — почему;
- починенный пункт из «Не доделано» или «Известные баги» — удали;
- договорились с пользователем о том, что следующая сборка не должна пересматривать, —
  строка в «Договорились», его словами.

### История git

Целиком не читай — бери срез под вопрос:

| Вопрос | Команда |
|---|---|
| что правили после последней сборки | `git log --oneline "$(git log -1 --format=%h --grep='^Autopilot: сборка сдана')"..HEAD -- . ':(exclude).autopilot'` |
| всё, что делали ради требования | `git log --oneline --grep="R02"` |
| история файла | `git log --oneline -10 -- <файл>` |
| когда появился или исчез код | `git log --oneline -S "<фрагмент>"` |
| почему строка такая | `git blame -L <с>,<по> <файл>`, затем `git show <sha>` |
| что внутри коммита | `git show --stat <sha>` |

Срез длиннее ~30 коммитов — отдай его субагенту и возьми выжимку в десять строк.

Коммит: заголовок — что (`fix: даты в одном формате`), тело — почему, трейлер
`--trailer "Requirements: R02"`, если правка касается требования из `manifest.md`.
Заголовок `Autopilot: сборка сдана` пишет только автопилот — по нему находят последнюю сборку.
<!-- autopilot:end -->
