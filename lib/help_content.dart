import 'package:flutter/material.dart';
import 'app_settings.dart';

/// Один раздел справки: значки кнопок, о которых идёт речь (рисуются рядом с
/// заголовком — так не нужны юникод-символы, которые на части телефонов
/// превращаются в пустые квадраты), заголовок и текст.
class HelpSection {
  final List<IconData> icons;
  final String title;
  final String body;
  const HelpSection(this.icons, this.title, this.body);
}

List<HelpSection> helpSections(AppLanguage lang) => _help[lang]!;

const _help = <AppLanguage, List<HelpSection>>{
  AppLanguage.ru: [
    HelpSection(
      [Icons.piano],
      'Что это за приложение',
      'Играйте на пианино на экране — приложение само записывает вашу игру '
          'нотами. Ноты можно сохранить в PDF, распечатать или отправить '
          'ученику, а ученик откроет этот же файл в приложении и будет '
          'тренироваться по нему.',
    ),
    HelpSection(
      [Icons.fiber_manual_record, Icons.stop, Icons.refresh],
      'Запись нот',
      'Нажмите кнопку записи (кружок) в верхней панели и играйте. Отсчёт '
          'начинается с первой нажатой клавиши, а ноты появляются на стане '
          'сразу, пока вы играете. Чтобы закончить, нажмите «Стоп». Кнопка со '
          'стрелками по кругу стирает всё и начинает заново.\n\n'
          'Темп задаётся в Настройках («Темп»): играйте в этом темпе — тогда '
          'ноты получатся точнее.',
    ),
    HelpSection(
      [Icons.piano, Icons.remove, Icons.add],
      'Клавиатура',
      'Касайтесь клавиш. Если вести пальцем по клавишам, не отрывая, '
          'прозвучит каждая (глиссандо). Полоска над клавишами — мини-карта: '
          'коснитесь её, чтобы перейти к другой октаве. Кнопки «−» и «+» '
          'слева меняют размер клавиш. Кнопка с пианино в верхней панели '
          'скрывает или показывает клавиатуру.\n\n'
          'На компьютере: нижний ряд Z…M (чёрные — S D G H J) — октава от До '
          'первой октавы; верхний ряд Q…I (чёрные — 2 3 5 6 7) — на октаву выше.',
    ),
    HelpSection(
      [Icons.circle_outlined],
      'Педаль',
      'Круглая кнопка справа над клавишами — педаль (сустейн), как правая '
          'педаль пианино. Когда она красная, ноты продолжают звучать после '
          'того, как вы отпустили клавишу, и записываются длинными. Нажмите '
          'ещё раз — педаль отпущена, и звук затихает.',
    ),
    HelpSection(
      [Icons.music_note],
      'Нотный стан: «Просто» и «Про»',
      'Выбирается в Настройках («Нотный стан»).\n\n'
          '«Просто (1 ключ)» — все ноты на одном стане со скрипичным ключом. '
          'Легче читать новичку, особенно если играете одной рукой.\n\n'
          '«Про (2 руки)» — как в настоящих нотах для фортепиано: скрипичный '
          'ключ (правая рука, от До первой октавы и выше) и басовый ключ '
          '(левая рука, ниже), соединённые фигурной скобкой.\n\n'
          'Очень высокие и низкие ноты рисуются со знаком 8va / 15ma (читать '
          'выше на одну/две октавы) или 8vb / 15mb (ниже), чтобы не рисовать '
          'кучу добавочных линеек. Две одинаковые ноты, соединённые дугой '
          '(лигой), — это одна долгая нота.',
    ),
    HelpSection(
      [Icons.picture_as_pdf],
      'Сохранить и поделиться',
      'Кнопка PDF: «Сохранить PDF» — записать файл в память устройства; '
          '«Поделиться PDF» — отправить через мессенджер или другое '
          'приложение. Такой PDF — это и ноты для печати, и файл для '
          'тренировки.',
    ),
    HelpSection(
      [
        Icons.folder_open,
        Icons.play_arrow,
        Icons.pause,
        Icons.stop,
        Icons.close,
      ],
      'Тренировка по нотам',
      'Кнопка с папкой открывает PDF, созданный в этом приложении (чужие PDF '
          'не подойдут). Режим выбирается в Настройках:\n\n'
          '«Тренажёр» — приложение ждёт, пока вы нажмёте мигающую голубую '
          'клавишу, и переходит к следующей ноте.\n\n'
          '«Автоигра» — приложение играет пьесу само.\n\n'
          'Кнопки: «Играть», «Пауза», «Стоп» (в начало). Крестик закрывает '
          'пьесу и возвращает к записи.',
    ),
    HelpSection(
      [Icons.settings],
      'Звук, язык, тема',
      'В Настройках: звук (пианино, электро, синтезатор), язык, светлая или '
          'тёмная тема и темп.',
    ),
  ],
  AppLanguage.uz: [
    HelpSection(
      [Icons.piano],
      'Bu ilova nima',
      'Ekrandagi pianinoda çaling — ilova óyiningizni óziyoq notaga yozib '
          'boradi. Notalarni PDF qilib saqlaş, çop etiş yoki óquvçiga yuboriş '
          'mumkin, óquvçi esa şu faylni ilovada oçib, uning bóyiça maşq qiladi.',
    ),
    HelpSection(
      [Icons.fiber_manual_record, Icons.stop, Icons.refresh],
      'Notaga yoziş',
      'Yuqoridagi panelda yoziş tugmasini (doira) bosing va çaling. Hisob '
          'birinçi bosilgan klavişdan boşlanadi, notalar óyin vaqtidayoq '
          'notalar tórida paydo bóladi. Tugatiş uçun «Tóxtatiş» ni bosing. '
          'Aylana strelkali tugma hammasini óçirib, qaytadan boşlaydi.\n\n'
          'Tezlik Sozlamalarda («Tezlik») belgilanadi: şu tezlikda çalsangiz, '
          'notalar aniqroq çiqadi.',
    ),
    HelpSection(
      [Icons.piano, Icons.remove, Icons.add],
      'Klaviatura',
      'Klavişlarga tegiling. Barmoqni klavişlar bóylab uzmay sirpantirsangiz, '
          'har bir klaviş yangraydi (glissando). Klavişlar ustidagi çiziq — '
          'mini-xarita: boşqa oktavaga ótiş uçun unga tegiling. Çapdagi «−» va '
          '«+» tugmalari klavişlar ólçamini ózgartiradi. Yuqori paneldagi '
          'pianino tugmasi klaviaturani yaşiradi yoki kórsatadi.\n\n'
          'Kompyuterda: pastki qator Z…M (qora klavişlar: S D G H J) — '
          'birinçi oktava Do dan; yuqori qator Q…I (qora: 2 3 5 6 7) — bir '
          'oktava yuqori.',
    ),
    HelpSection(
      [Icons.circle_outlined],
      'Pedal',
      'Klavişlar tepasidagi, óng tomondagi doira tugma — pianinoning óng '
          'pedali (sustain). U qizil bólsa, klavişni qóyib yuborganingizdan '
          'keyin ham nota yangrashda davom etadi va uzun nota bólib yoziladi. '
          'Yana bossangiz, pedal qóyib yuboriladi va ovoz tinadi.',
    ),
    HelpSection(
      [Icons.music_note],
      'Notalar tóri: oddiy va Pro',
      'Sozlamalarda tanlanadi («Notalar tóri»).\n\n'
          '«Oddiy (1 kalit)» — barça notalar skripka kaliti bilan bitta tórda. '
          'Boşlovçilar uçun yengilroq, ayniqsa bir qól bilan çalsangiz.\n\n'
          '«Pro (2 qól)» — haqiqiy pianino notalaridek: skripka kaliti (óng '
          'qól, birinçi oktava Do dan yuqori) va bas kaliti (çap qól, '
          'pastroq), figurali qavs bilan birlaştirilgan.\n\n'
          'Juda baland yoki past notalar 8va / 15ma (yuqori) yoki 8vb / 15mb '
          '(past) belgisi bilan çiziladi — qóşimça çiziqlar kóp bólmasligi '
          'uçun. Yoy (liga) bilan bóǵlangan bir xil ikki nota — bitta uzun '
          'nota.',
    ),
    HelpSection(
      [Icons.picture_as_pdf],
      'Saqlaş va ulaşiş',
      'PDF tugmasi: «PDF ni saqlaş» — faylni qurilmaga yozadi; «PDF ni '
          'ulaşiş» — messenjer yoki boşqa ilova orqali yuboradi. Bu PDF ham '
          'çop etiladigan notalar, ham maşq uçun fayl.',
    ),
    HelpSection(
      [
        Icons.folder_open,
        Icons.play_arrow,
        Icons.pause,
        Icons.stop,
        Icons.close,
      ],
      'Notalar bóyiça maşq',
      'Papka tugmasi şu ilovada yaratilgan PDF ni oçadi (boşqa PDF lar mos '
          'kelmaydi). Rejim Sozlamalarda tanlanadi:\n\n'
          '«Trenajyor» — yonib-óçib turadigan kók klavişni bosişingizni '
          'kutadi, keyin keyingi notaga ótadi.\n\n'
          '«Avtomatik ijro» — ilovaning ózi çaladi.\n\n'
          'Tugmalar: «Ijro», «Pauza», «Tóxtatiş» (boşidan). X tugmasi asarni '
          'yopib, yozuvga qaytaradi.',
    ),
    HelpSection(
      [Icons.settings],
      'Ovoz, til, mavzu',
      'Sozlamalarda: ovoz (pianino, elektro, sintezator), til, yoruǵ yoki '
          'qoronǵu mavzu va tezlik.',
    ),
  ],
  AppLanguage.en: [
    HelpSection(
      [Icons.piano],
      'What is this app',
      'Play the on-screen piano and the app writes down your playing as '
          'sheet music. You can save the notes as a PDF, print it or send it '
          'to a student — the student opens the same file in the app and '
          'practises with it.',
    ),
    HelpSection(
      [Icons.fiber_manual_record, Icons.stop, Icons.refresh],
      'Recording',
      'Tap the record button (the circle) in the top bar and play. Timing '
          'starts from the first key you press, and the notes appear on the '
          'staff live while you play. Tap "Stop" to finish. The circular '
          'arrow button clears everything and starts over.\n\n'
          'Set the tempo in Settings ("Tempo") and play at that speed — the '
          'notes will come out more accurate.',
    ),
    HelpSection(
      [Icons.piano, Icons.remove, Icons.add],
      'Keyboard',
      'Tap the keys. Slide your finger across keys without lifting and each '
          'one sounds (glissando). The strip above the keys is a mini-map: '
          'tap it to jump to another octave. The "−" and "+" buttons on the '
          'left change the key size. The piano button in the top bar hides '
          'or shows the keyboard.\n\n'
          'On a computer: bottom row Z…M (black keys S D G H J) is the octave '
          'from middle C; top row Q…I (black keys 2 3 5 6 7) is one octave '
          'higher.',
    ),
    HelpSection(
      [Icons.circle_outlined],
      'Pedal',
      'The round button at the right above the keys is the sustain pedal, '
          'like the right pedal of a piano. While it is red, notes keep '
          'sounding after you release the key and are written as long '
          'notes. Tap it again to release the pedal and the sound fades.',
    ),
    HelpSection(
      [Icons.music_note],
      'Staff: Simple and Pro',
      'Choose in Settings ("Staff").\n\n'
          '"Simple (1 clef)" — all notes on one treble staff. Easier for '
          'beginners, especially when playing with one hand.\n\n'
          '"Pro (2 hands)" — like real piano sheet music: treble clef (right '
          'hand, from middle C upwards) and bass clef (left hand, lower) '
          'joined by a brace.\n\n'
          'Very high or low notes are drawn with 8va / 15ma (read one/two '
          'octaves higher) or 8vb / 15mb (lower) so there are not too many '
          'ledger lines. Two same notes joined by a curve (a tie) are one '
          'long note.',
    ),
    HelpSection(
      [Icons.picture_as_pdf],
      'Save and share',
      'The PDF button: "Save PDF" writes the file to the device; "Share PDF" '
          'sends it through a messenger or another app. This PDF is both '
          'printable sheet music and a file for practising.',
    ),
    HelpSection(
      [
        Icons.folder_open,
        Icons.play_arrow,
        Icons.pause,
        Icons.stop,
        Icons.close,
      ],
      'Practice mode',
      'The folder button opens a PDF made by this app (other PDFs will not '
          'work). Pick the mode in Settings:\n\n'
          '"Trainer" — the app waits for you to press the blinking blue key, '
          'then moves to the next note.\n\n'
          '"Auto-play" — the app plays the piece by itself.\n\n'
          'Buttons: Play, Pause, Stop (back to the start). The X closes the '
          'piece and returns to recording.',
    ),
    HelpSection(
      [Icons.settings],
      'Sound, language, theme',
      'In Settings: sound (piano, electric, synth), language, light or dark '
          'theme and tempo.',
    ),
  ],
};
