# Открытые компоненты

Список того, что собранное приложение использует из чужого открытого кода и чужих
моделей. Правило проекта: MIT/Apache-2.0/BSD — можно, GPL — только с «да» Рустема.
Ниже только MIT, GPL нет.

---

## whisper.cpp

- Автор: The ggml authors (репозиторий `ggml-org/whisper.cpp`)
- Версия/релиз: `b5454` — готовый XCFramework, подключается в сборке
  (`.github/workflows/ios-build.yml`), скачивается и проверяется по sha256
  `e57f8c48933000acabc13bb913fbe82805d483a2deff692cc6738836bd92393b`
- Лицензия: MIT
- Источник текста лицензии: локальная копия `rea-lab/targets/whisper.cpp/LICENSE`
  (тот же текст, что в репозитории `ggml-org/whisper.cpp`)

```
MIT License

Copyright (c) 2023-2026 The ggml authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## XcodeGen

- Автор: Yonas Kolb и соавторы (репозиторий `yonaskolb/XcodeGen`)
- Версия: 2.46.0 — скачивается на раннере со сверкой sha256
  `4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806`
  (`.github/workflows/ios-build.yml`); используется только во время сборки,
  в само приложение не попадает
- Лицензия: MIT
- Источник: `github.com/yonaskolb/XcodeGen/blob/master/LICENSE`

```
MIT License

Copyright (c) 2018 Yonas Kolb

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Silero VAD

- Автор: Silero Team (репозиторий `snakers4/silero-vad`)
- Что используем: модель `ggml-silero-v6.2.0.bin` (864 КБ), встроена в whisper.cpp,
  скачивается в сборке с `huggingface.co/ggml-org/whisper-vad`, закреплена на коммит
  `9ffd54a1e1ee413ddf265af9913beaf518d1639b`, sha256
  `2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987`
- Лицензия: MIT
- Источник: `github.com/snakers4/silero-vad/blob/master/LICENSE`

```
MIT License

Copyright (c) 2020-present Silero Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Веса моделей Whisper

- Автор оригинала: OpenAI
- Источник лицензии кода и весов: README репозитория `github.com/openai/whisper` —
  дословно: «Whisper's code and model weights are released under the MIT License.»
  Файл `LICENSE` там же: «Copyright (c) 2022 OpenAI», текст MIT (тот же шаблон, что выше).
- Файлы, которые реально скачивает приложение, — не сами веса OpenAI, а их конвертация
  в формат ggml для whisper.cpp, сделанная Georgi Gerganov и проектом `ggml-org/whisper.cpp`,
  выложена на `huggingface.co/ggerganov/whisper.cpp`. Карточка репозитория на Hugging Face
  указывает «License: mit» и описывает файлы как «OpenAI's Whisper models converted to ggml
  format for use with whisper.cpp». Конвертация и квантование не меняют лицензию: MIT это
  разрешает (изменение, слияние, распространение).
- Три файла, которые скачивает экран «Модели» (имя, точный размер в байтах по Hugging Face API,
  §6 спецификации):
  - `ggml-small.bin` — 487 601 967 байт
  - `ggml-medium-q5_0.bin` — 539 212 467 байт
  - `ggml-large-v3-turbo-q5_0.bin` — 574 041 195 байт
  - все три — `huggingface.co/ggerganov/whisper.cpp/resolve/main/<имя файла>`

---

## GPL и прочее

GPL/AGPL-компонентов в сборке нет. Других открытых зависимостей, кроме перечисленных
выше, приложение и ядро не используют (только Foundation и системные фреймворки Apple).
