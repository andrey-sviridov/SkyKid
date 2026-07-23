#!/usr/bin/env python3
"""Generate and validate SkyKid .strings files with local translation models."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ElementTree
from collections import Counter
from pathlib import Path
from typing import Iterable


PROJECT_ROOT = Path(__file__).resolve().parents[1]
APP_SOURCE_ROOTS = (PROJECT_ROOT / "SkyKid", PROJECT_ROOT / "SkyKidWidget")
APP_RESOURCES = PROJECT_ROOT / "SkyKid" / "Resources"
WIDGET_RESOURCES = PROJECT_ROOT / "SkyKidWidget"
MODEL_NAME = os.environ.get("SKYKID_TRANSLATION_MODEL", "translategemma:12b")
KAZAKH_MODEL_NAME = "deepvk/kazRush-ru-kk"
CHINESE_MODEL_NAME = "Helsinki-NLP/opus-mt-en-zh"
ARGOS_MODELS_ROOT = Path(
    os.environ.get("SKYKID_ARGOS_MODELS_ROOT", "/tmp/skykid-argos-models")
)
ARGOS_PYTHON_ROOT = Path(
    os.environ.get("SKYKID_ARGOS_PYTHON_ROOT", "/tmp/skykid-ct2")
)
OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
LOCALES = {
    "kk": "Kazakh",
    "en": "English",
    "fr": "French",
    "zh-Hans": "Simplified Chinese",
}
MANUAL_OVERRIDES = {
    "en": {
        "Рекомендация для ребёнка": "Recommendation for your child",
        "Возраст: %@ · группа %@": "Age: %@ · group %@",
        "Высокая уверенность": "High confidence",
        "Средняя уверенность": "Medium confidence",
        "Низкая уверенность": "Low confidence",
        "Что надеть": "What to wear",
        "Почему": "Why",
        "Что проверить": "What to check",
        "Проверьте после начала прогулки": "Check after the walk begins",
        "Проверьте живот или заднюю поверхность шеи, затем отметьте ощущение ребёнка.": "Check your child’s belly or the back of their neck, then record how they felt.",
        "Проверьте живот или заднюю поверхность шеи: кожа должна быть тёплой и сухой. Холодные кисти и стопы сами по себе не означают, что ребёнок замёрз.": "Check your child’s belly or the back of their neck: the skin should feel warm and dry. Cool hands and feet alone do not mean that your child is cold.",
        "Через 10–15 минут и при смене условий проверьте живот или заднюю поверхность шеи: тёплая и сухая кожа — комфортно; горячая или влажная — снимите один лёгкий слой; прохладная — добавьте слой. Холодные кисти и стопы сами по себе не означают, что ребёнок замёрз.": "After 10–15 minutes, and whenever conditions change, check your child’s belly or the back of their neck. Warm, dry skin means they are comfortable; hot or damp skin means remove one light layer; cool skin means add a layer. Cool hands and feet alone do not mean that your child is cold.",
        "Ребёнку меньше 3 месяцев: прогулку отмените. При 38°C и выше немедленно обратитесь за медицинской помощью.": "If your baby is under 3 months old, cancel the walk. Seek medical care immediately if their temperature is 38°C or higher.",
        "При повышенной температуре прогулку отмените. SkyKid не оценивает тяжесть болезни; ориентируйтесь на состояние ребёнка и рекомендации врача.": "Cancel the walk if your child has a fever. SkyKid cannot assess the severity of an illness; follow your child’s condition and your clinician’s advice.",
        "Не надевайте объёмную куртку или комбинезон под ремни автокресла. Используйте тонкие слои, затяните ремни по инструкции, а плед положите поверх пристёгнутых ремней.": "Do not put a bulky coat or snowsuit under the car-seat harness. Use thin layers, tighten the harness as instructed, and place a blanket over the fastened harness.",
        "Под дождевиком может быстро накапливаться тепло. Снимите его вне дождя, уйдите в тень, восстановите вентиляцию и проверьте живот или заднюю поверхность шеи ребёнка.": "Heat can build up quickly under a stroller rain cover. Remove it when it is not raining, move into the shade, restore airflow, and check your child’s belly or the back of their neck.",
        "Перед выходом откройте лицо ребёнка и обеспечьте приток воздуха: дождевик и поднятый капюшон не должны создавать закрытый карман.": "Before going out, keep your child’s face uncovered and allow airflow. A rain cover and raised hood must not create an enclosed pocket.",
        "Измерьте температуру термометром. ": "Measure your child’s temperature with a thermometer. ",
        "Прогулку отмените": "Cancel the walk",
        "Сегодня без прогулки": "No walk today",
        "Перенесите прогулку": "Reschedule the walk",
        "☀️ Ясно · 18°": "☀️ Clear · 18°",
        "✏️ Редактирование": "✏️ Editing",
        "❄️ Зима": "❄️ Winter",
        "❄️ Зима · 4 мес": "❄️ Winter · 4 months",
        "🌧 Дождь": "🌧 Rain",
        "🎛 Весна · 12°": "🎛 Spring · 12°",
        "🎛 Зима · −8°": "🎛 Winter · −8°",
        "👕 Гардероб": "👕 Wardrobe",
        "👤 Профиль": "👤 Profile",
        "📝 Онбординг": "📝 Onboarding",
        "🧥 Весна · 2 года": "🧥 Spring · 2 years",
    },
    "fr": {
        "Рекомендация для ребёнка": "Recommandation pour votre enfant",
        "Возраст: %@ · группа %@": "Âge : %@ · groupe %@",
        "Высокая уверенность": "Fiabilité élevée",
        "Средняя уверенность": "Fiabilité moyenne",
        "Низкая уверенность": "Fiabilité faible",
        "Что надеть": "Comment l’habiller",
        "Почему": "Pourquoi",
        "Что проверить": "À vérifier",
        "Проверьте после начала прогулки": "Vérifiez après le début de la promenade",
        "Проверьте живот или заднюю поверхность шеи, затем отметьте ощущение ребёнка.": "Vérifiez le ventre ou la nuque de votre enfant, puis indiquez comment il s’est senti.",
        "Проверьте живот или заднюю поверхность шеи: кожа должна быть тёплой и сухой. Холодные кисти и стопы сами по себе не означают, что ребёнок замёрз.": "Vérifiez le ventre ou la nuque de votre enfant : la peau doit être chaude et sèche. Des mains et des pieds frais ne signifient pas à eux seuls que votre enfant a froid.",
        "Через 10–15 минут и при смене условий проверьте живот или заднюю поверхность шеи: тёплая и сухая кожа — комфортно; горячая или влажная — снимите один лёгкий слой; прохладная — добавьте слой. Холодные кисти и стопы сами по себе не означают, что ребёнок замёрз.": "Après 10 à 15 minutes, et chaque fois que les conditions changent, vérifiez le ventre ou la nuque de votre enfant. Une peau chaude et sèche indique qu’il est à l’aise ; si elle est très chaude ou humide, retirez une couche légère ; si elle est fraîche, ajoutez une couche. Des mains et des pieds frais ne signifient pas à eux seuls que votre enfant a froid.",
        "Ребёнку меньше 3 месяцев: прогулку отмените. При 38°C и выше немедленно обратитесь за медицинской помощью.": "Si votre bébé a moins de 3 mois, annulez la promenade. Consultez immédiatement un professionnel de santé si sa température atteint 38°C ou plus.",
        "При повышенной температуре прогулку отмените. SkyKid не оценивает тяжесть болезни; ориентируйтесь на состояние ребёнка и рекомендации врача.": "Annulez la promenade si votre enfant a de la fièvre. SkyKid ne peut pas évaluer la gravité d’une maladie ; tenez compte de l’état de votre enfant et des conseils du professionnel de santé.",
        "Не надевайте объёмную куртку или комбинезон под ремни автокресла. Используйте тонкие слои, затяните ремни по инструкции, а плед положите поверх пристёгнутых ремней.": "Ne placez pas de manteau épais ni de combinaison de neige sous le harnais du siège-auto. Utilisez des couches fines, serrez le harnais conformément à la notice et posez une couverture par-dessus le harnais attaché.",
        "Под дождевиком может быстро накапливаться тепло. Снимите его вне дождя, уйдите в тень, восстановите вентиляцию и проверьте живот или заднюю поверхность шеи ребёнка.": "La chaleur peut s’accumuler rapidement sous l’habillage pluie de la poussette. Retirez-le lorsqu’il ne pleut pas, mettez-vous à l’ombre, rétablissez la circulation de l’air et vérifiez le ventre ou la nuque de votre enfant.",
        "Перед выходом откройте лицо ребёнка и обеспечьте приток воздуха: дождевик и поднятый капюшон не должны создавать закрытый карман.": "Avant de sortir, laissez le visage de votre enfant découvert et assurez une bonne circulation de l’air. L’habillage pluie et la capote relevée ne doivent pas former un espace fermé.",
        "Измерьте температуру термометром. ": "Mesurez la température de votre enfant avec un thermomètre. ",
        "Прогулку отмените": "Annulez la promenade",
        "Сегодня без прогулки": "Pas de promenade aujourd’hui",
        "Перенесите прогулку": "Reportez la promenade",
        "☀️ Ясно · 18°": "☀️ Dégagé · 18°",
        "✏️ Редактирование": "✏️ Modification",
        "❄️ Зима": "❄️ Hiver",
        "❄️ Зима · 4 мес": "❄️ Hiver · 4 mois",
        "🌧 Дождь": "🌧 Pluie",
        "🎛 Весна · 12°": "🎛 Printemps · 12°",
        "🎛 Зима · −8°": "🎛 Hiver · −8°",
        "👕 Гардероб": "👕 Garde-robe",
        "👤 Профиль": "👤 Profil",
        "📝 Онбординг": "📝 Prise en main",
        "🧥 Весна · 2 года": "🧥 Printemps · 2 ans",
    },
    "zh-Hans": {
        "Рекомендация для ребёнка": "孩子的穿衣建议",
        "Возраст: %@ · группа %@": "年龄：%@ · 分组：%@",
        "Высокая уверенность": "可信度高",
        "Средняя уверенность": "可信度中等",
        "Низкая уверенность": "可信度低",
        "Что надеть": "穿什么",
        "Почему": "原因",
        "Что проверить": "需要检查",
        "Проверьте после начала прогулки": "开始散步后请检查",
        "Проверьте живот или заднюю поверхность шеи, затем отметьте ощущение ребёнка.": "检查孩子的腹部或颈后，然后记录孩子的感受。",
        "Проверьте живот или заднюю поверхность шеи: кожа должна быть тёплой и сухой. Холодные кисти и стопы сами по себе не означают, что ребёнок замёрз.": "检查孩子的腹部或颈后：皮肤应温暖、干燥。仅仅手脚偏凉并不代表孩子觉得冷。",
        "Через 10–15 минут и при смене условий проверьте живот или заднюю поверхность шеи: тёплая и сухая кожа — комфортно; горячая или влажная — снимите один лёгкий слой; прохладная — добавьте слой. Холодные кисти и стопы сами по себе не означают, что ребёнок замёрз.": "10–15 分钟后以及环境变化时，请检查孩子的腹部或颈后。皮肤温暖、干燥表示舒适；皮肤发热或潮湿时脱掉一层薄衣；皮肤偏凉时加一层。仅仅手脚偏凉并不代表孩子觉得冷。",
        "Ребёнку меньше 3 месяцев: прогулку отмените. При 38°C и выше немедленно обратитесь за медицинской помощью.": "如果宝宝不足 3 个月，请取消散步。体温达到 38°C 或更高时，请立即就医。",
        "При повышенной температуре прогулку отмените. SkyKid не оценивает тяжесть болезни; ориентируйтесь на состояние ребёнка и рекомендации врача.": "孩子发热时请取消散步。SkyKid 无法判断病情严重程度；请根据孩子的状态并遵循医生建议。",
        "Не надевайте объёмную куртку или комбинезон под ремни автокресла. Используйте тонкие слои, затяните ремни по инструкции, а плед положите поверх пристёгнутых ремней.": "不要让孩子穿着厚外套或厚连体衣系汽车安全座椅的安全带。请穿薄层衣物，按说明收紧安全带，并将毯子盖在已扣好的安全带外面。",
        "Под дождевиком может быстро накапливаться тепло. Снимите его вне дождя, уйдите в тень, восстановите вентиляцию и проверьте живот или заднюю поверхность шеи ребёнка.": "婴儿车雨罩下可能很快积热。雨停后请取下雨罩，移到阴凉处，恢复空气流通，并检查孩子的腹部或颈后。",
        "Перед выходом откройте лицо ребёнка и обеспечьте приток воздуха: дождевик и поднятый капюшон не должны создавать закрытый карман.": "出门前请确保孩子的面部无遮挡并保持空气流通。雨罩和抬起的车篷不能形成封闭空间。",
        "Измерьте температуру термометром. ": "请用体温计测量孩子的体温。 ",
        "Прогулку отмените": "取消散步",
        "Сегодня без прогулки": "今天不要散步",
        "Перенесите прогулку": "改期散步",
        "Туман": "雾",
        "Уверенность: %@. %@": "可信度：%@。%@",
        "☀️ Ясно · 18°": "☀️ 晴 · 18°",
        "✏️ Редактирование": "✏️ 编辑",
        "❄️ Зима": "❄️ 冬季",
        "❄️ Зима · 4 мес": "❄️ 冬季 · 4 个月",
        "🌧 Дождь": "🌧 雨",
        "🎛 Весна · 12°": "🎛 春季 · 12°",
        "🎛 Зима · −8°": "🎛 冬季 · −8°",
        "👕 Гардероб": "👕 衣橱",
        "👤 Профиль": "👤 个人资料",
        "📝 Онбординг": "📝 新手引导",
        "🧥 Весна · 2 года": "🧥 春季 · 2 岁",
    },
    "kk": {
        "Рекомендация для ребёнка": "Балаға арналған киім ұсынымы",
        "Возраст: %@ · группа %@": "Жасы: %@ · %@ тобы",
        "Высокая уверенность": "Жоғары сенімділік",
        "Средняя уверенность": "Орташа сенімділік",
        "Низкая уверенность": "Төмен сенімділік",
        "Что надеть": "Не кигізу керек",
        "Почему": "Неліктен",
        "Что проверить": "Нені тексеру керек",
        "Проверьте после начала прогулки": "Серуен басталғаннан кейін тексеріңіз",
        "Проверьте живот или заднюю поверхность шеи, затем отметьте ощущение ребёнка.": "Баланың ішін немесе мойнының артқы жағын тексеріп, содан кейін оның қалай сезінгенін белгілеңіз.",
        "Проверьте живот или заднюю поверхность шеи: кожа должна быть тёплой и сухой. Холодные кисти и стопы сами по себе не означают, что ребёнок замёрз.": "Баланың ішін немесе мойнының артқы жағын тексеріңіз: терісі жылы әрі құрғақ болуы керек. Қолдары мен аяқтарының салқын болуы өздігінен баланың тоңғанын білдірмейді.",
        "Через 10–15 минут и при смене условий проверьте живот или заднюю поверхность шеи: тёплая и сухая кожа — комфортно; горячая или влажная — снимите один лёгкий слой; прохладная — добавьте слой. Холодные кисти и стопы сами по себе не означают, что ребёнок замёрз.": "10–15 минуттан кейін және жағдай өзгерген сайын баланың ішін немесе мойнының артқы жағын тексеріңіз. Жылы әрі құрғақ тері — жайлы; ыстық немесе ылғал тері болса, бір жеңіл қабатты шешіңіз; салқын болса, бір қабат қосыңыз. Қолдары мен аяқтарының салқын болуы өздігінен баланың тоңғанын білдірмейді.",
        "Ребёнку меньше 3 месяцев: прогулку отмените. При 38°C и выше немедленно обратитесь за медицинской помощью.": "Егер сәби 3 айға толмаған болса, серуеннен бас тартыңыз. Дене қызуы 38°C немесе одан жоғары болса, дереу медициналық көмекке жүгініңіз.",
        "При повышенной температуре прогулку отмените. SkyKid не оценивает тяжесть болезни; ориентируйтесь на состояние ребёнка и рекомендации врача.": "Баланың дене қызуы көтерілсе, серуеннен бас тартыңыз. SkyKid аурудың ауырлығын бағаламайды; баланың жағдайын және дәрігердің ұсынымдарын басшылыққа алыңыз.",
        "Не надевайте объёмную куртку или комбинезон под ремни автокресла. Используйте тонкие слои, затяните ремни по инструкции, а плед положите поверх пристёгнутых ремней.": "Автокресло белдіктерінің астына қалың күрте немесе комбинезон кигізбеңіз. Жұқа қабаттарды пайдаланыңыз, белдіктерді нұсқаулыққа сай тартыңыз, ал жамылғыны тағылған белдіктердің үстіне жабыңыз.",
        "Под дождевиком может быстро накапливаться тепло. Снимите его вне дождя, уйдите в тень, восстановите вентиляцию и проверьте живот или заднюю поверхность шеи ребёнка.": "Арбаның жаңбыр жапқышының астында жылу тез жиналуы мүмкін. Жаңбыр тоқтағанда оны шешіңіз, көлеңкеге өтіңіз, ауа айналымын қалпына келтіріп, баланың ішін немесе мойнының артқы жағын тексеріңіз.",
        "Перед выходом откройте лицо ребёнка и обеспечьте приток воздуха: дождевик и поднятый капюшон не должны создавать закрытый карман.": "Шығар алдында баланың бетін ашық қалдырып, ауа ағынын қамтамасыз етіңіз. Жаңбыр жапқышы мен көтерілген капюшон жабық кеңістік жасамауы керек.",
        "Измерьте температуру термометром. ": "Баланың дене қызуын термометрмен өлшеңіз. ",
        "Прогулку отмените": "Серуеннен бас тартыңыз",
        "Сегодня без прогулки": "Бүгін серуенге шықпаңыз",
        "Перенесите прогулку": "Серуенді кейінге қалдырыңыз",
        "☀️ Ясно · 18°": "☀️ Ашық · 18°",
        "✏️ Редактирование": "✏️ Өңдеу",
        "❄️ Зима": "❄️ Қыс",
        "❄️ Зима · 4 мес": "❄️ Қыс · 4 ай",
        "🌧 Дождь": "🌧 Жаңбыр",
        "🎛 Весна · 12°": "🎛 Көктем · 12°",
        "🎛 Зима · −8°": "🎛 Қыс · −8°",
        "👕 Гардероб": "👕 Гардероб",
        "👤 Профиль": "👤 Профиль",
        "📝 Онбординг": "📝 Алғашқы баптау",
        "🧥 Весна · 2 года": "🧥 Көктем · 2 жас",
    },
}
MANUAL_OVERRIDES["en"].update({
    "вещь": "item",
    "вещи": "items",
    "вещей": "items",
    "%lld вещей": "%lld items",
    "%lld выбрано": "%lld selected",
    "В наличии %lld из %lld предметов": "%lld of %lld items available",
    "Варежки": "Mittens",
    "Кофта": "Sweater",
    "ОРВИ без температуры": "Cold symptoms without fever",
    "ОРВИ без температуры и мороз: SkyKid не определяет, безопасна ли прогулка при болезни. Сократите или отложите выход; не закрывайте ребёнку рот и нос тканью.": "Cold symptoms without fever in freezing weather: SkyKid cannot determine whether a walk is safe during an illness. Shorten or postpone the outing, and do not cover your child’s mouth or nose with fabric.",
})
MANUAL_OVERRIDES["fr"].update({
    "вещь": "article",
    "вещи": "articles",
    "вещей": "articles",
    "%lld вещей": "%lld articles",
    "%lld выбрано": "%lld sélectionnés",
    "В наличии %lld из %lld предметов": "%lld articles disponibles sur %lld",
    "Варежки": "Moufles",
    "Кофта": "Pull",
    "ОРВИ без температуры": "Symptômes de rhume sans fièvre",
    "ОРВИ без температуры и мороз: SkyKid не определяет, безопасна ли прогулка при болезни. Сократите или отложите выход; не закрывайте ребёнку рот и нос тканью.": "Symptômes de rhume sans fièvre par temps de gel : SkyKid ne peut pas déterminer si une promenade est sans danger pendant une maladie. Raccourcissez ou reportez la sortie et ne couvrez pas la bouche ni le nez de votre enfant avec du tissu.",
})
MANUAL_OVERRIDES["kk"].update({
    "вещь": "зат",
    "вещи": "зат",
    "вещей": "зат",
    "%lld вещей": "%lld зат",
    "%lld выбрано": "%lld таңдалды",
    "В наличии %lld из %lld предметов": "%lld заттың %lld-і бар",
    "Пол": "Жынысы",
})
MANUAL_OVERRIDES["zh-Hans"].update({
    "вещь": "件",
    "вещи": "件",
    "вещей": "件",
    "%.1f мм": "%.1f 毫米",
    "%lld м/с": "%lld 米/秒",
    "%lld мин": "%lld 分钟",
    "%lld нед.": "%lld 周",
    "%lld недель": "%lld 周",
    "%lld вещей": "%lld 件",
    "%lld выбрано": "已选 %lld 件",
    "%@ и ещё %lld": "%@，另有 %lld 件",
    "В наличии %lld из %lld предметов": "现有 %lld/%lld 件",
    "%1$@, %2$lld градусов, обновлено %3$@, %4$@": "%1$@，%2$lld 度，更新于 %3$@，%4$@",
    "%@, %lld градусов, обновлено %@, %@": "%@，%lld 度，更新于 %@，%@",
    "На улице %lld° · ощущается %lld° · эффективная %lld°": "室外 %lld° · 体感 %lld° · 有效温度 %lld°",
    "На улице %lld°, в условиях ребёнка около %lld°. Учтены %@.": "室外 %lld°，孩子所处环境约 %lld°。已考虑：%@。",
    "%lld° · ощущается %lld°C": "%lld° · 体感 %lld°C",
    "Ощущается как %lld°": "体感 %lld°",
    "V_calc = %.1f км/ч": "V_calc = %.1f 公里/小时",
    "Комплект %.1f TOG · цель %.1f TOG": "搭配 %.1f TOG · 目标 %.1f TOG",
    "Цель %.1f TOG, доступный комплект даёт %.1f TOG.": "目标 %.1f TOG，现有搭配为 %.1f TOG。",
    "цель одежда: %.1f TOG": "衣物目标：%.1f TOG",
    "Без дождевика: %.1f → %.1f TOG": "无雨罩：%.1f → %.1f TOG",
    "Использован осторожный ветер %.1f м/с": "采用保守风速 %.1f 米/秒",
    "Использована осторожная влажность %lld%%": "采用保守湿度 %lld%%",
    "Скорр. возраст %lld нед.": "矫正年龄 %lld 周",
    "Более подходящее время для прогулки: %@–%@": "更适合散步的时间：%@–%@",
    "Более подходящее время для прогулки: завтра %@–%@": "明天更适合散步的时间：%@–%@",
    "Расчётное окно начинается в %@. Перед выходом обновите погоду и проверьте самочувствие ребёнка.": "预计时间段从 %@ 开始。出门前请更新天气并确认孩子的状态。",
    "Собираем повторные наблюдения: %lld из %lld.": "正在收集重复反馈：%lld/%lld。",
    "Сильный ветер %d км/ч. Сократите выход, избегайте открытых мест и следите за защитой лица без перекрытия дыхания.": "强风 %d 公里/小时。请缩短外出时间，避开空旷处；保护面部时不要遮挡呼吸。",
    "сильный ветер (%lld м/с) будет продувать": "强风（%lld 米/秒）会增加风寒",
    "При %lld° прогулка опасна для ребёнка.": "%lld° 时散步对孩子有危险。",
    "При %lld° высок риск переохлаждения.": "%lld° 时体温过低风险很高。",
    "По консервативному правилу SkyKid прогулку лучше отложить: расчётно %.0f°C, возрастной ориентир приложения %d°C. Одежда не отменяет это ограничение.": "按照 SkyKid 的保守规则，建议推迟散步：计算温度约 %.0f°C，应用内该年龄的参考界限为 %d°C。增加衣物不能消除这一限制。",
    "По консервативному правилу SkyKid прогулку лучше перенести: с учётом жары около %.0f°C, возрастной ориентир приложения %d°C.": "按照 SkyKid 的保守规则，建议改期散步：考虑高温后约 %.0f°C，应用内该年龄的参考界限为 %d°C。",
    "Высокий UV %d: младенца до 6 месяцев держите в тени и вне прямого солнца; выбирайте лёгкую закрывающую одежду и широкополую панаму. Избегайте пиковых часов 10:00–16:00.": "紫外线指数 %d（高）：6 个月以下婴儿应待在阴凉处并避开阳光直射；选择轻薄、遮盖皮肤的衣物和宽边遮阳帽。避开 10:00–16:00 的高峰时段。",
    "Высокий UV %d: выбирайте тень, лёгкую закрывающую одежду и широкополую панаму; избегайте пиковых часов 10:00–16:00.": "紫外线指数 %d（高）：选择阴凉处、轻薄且遮盖皮肤的衣物和宽边遮阳帽；避开 10:00–16:00 的高峰时段。",
    "UV %d: младенца до 6 месяцев держите в тени и вне прямого солнца; используйте лёгкую закрывающую одежду и широкополую панаму.": "紫外线指数 %d：6 个月以下婴儿应待在阴凉处并避开阳光直射；穿轻薄、遮盖皮肤的衣物并戴宽边遮阳帽。",
    "UV %d: используйте тень, лёгкую закрывающую одежду и широкополую панаму.": "紫外线指数 %d：选择阴凉处，穿轻薄、遮盖皮肤的衣物并戴宽边遮阳帽。",
    "%@ активно двигается, но ещё не может сказать, что замёрз. Ориентируйтесь на шею и грудку — они тёплые у согретого ребёнка. Ручки и ушки у грудничков холодные в норме.": "%@ 活动得很积极，但还不会表达自己冷不冷。请摸孩子的颈后和胸部；保暖合适时这里应是温暖的。婴儿手和耳朵偏凉可能是正常现象。",
    "%@ в этом возрасте часто не замечает, что замёрз, пока не начнёт хныкать. Следите за затылком и щёчками — надёжные индикаторы в этом возрасте.": "%@ 在这个年龄可能直到烦躁时才意识到冷。请留意颈后和面颊。",
    "%@ ещё не умеет самостоятельно регулировать температуру тела — механизм терморегуляции созревает к 3–6 месяцам. Проверяйте шею и спинку: если тёплые — всё хорошо. Холодные ручки у грудничков в норме.": "%@ 还不能自行调节体温；体温调节能力会在 3–6 个月逐渐成熟。请检查颈后和背部：温暖表示合适。婴儿手部偏凉可能是正常现象。",
    "%@ много бегает и разогревается, но быстро остывает, когда остановится. Одевайте слоями — легко снять, если станет жарко.": "%@ 活动时容易发热，停下来后也会较快变凉。请分层穿衣，热时方便脱掉一层。",
    "%@ сейчас очень холодно — %@ мёрзнет даже в тёплой одежде": "现在对 %@ 来说非常冷——即使穿得很暖，%@ 仍可能觉得冷",
    "%@ будет тепло": "%@ 会觉得暖和",
    "%@ жарко": "%@ 会觉得热",
    "%@ холодно": "%@ 会觉得冷",
    "Для %@ комфортно": "%@ 会觉得舒适",
    "Для %@ прохладно": "%@ 会觉得偏凉",
    "Для %@ свежо": "%@ 会觉得清爽",
    "Условия прогулки. %@": "散步条件：%@",
    "Что надеть · %@": "穿衣建议 · %@",
    "Оптимально для %@": "适合 %@",
    "Базовый — низ": "基础层 — 下装",
    "Бафф / снуд": "脖套 / 围脖",
    "Боди, длинный рукав": "长袖连体衣",
    "Боди-кимоно (дл. рукав)": "和服式长袖连体衣",
    "Боди-кимоно (кор. рукав)": "和服式短袖连体衣",
    "В коляске или начинает ползать": "坐婴儿车或刚开始爬行",
    "В коляске ребёнок не двигается — нужен тёплый конверт": "孩子在婴儿车内活动少，需要保暖睡袋",
    "Варежки": "连指手套",
    "Ветровочный комбез (без подклада)": "无衬里防风连体衣",
    "Ветрозащитный чехол на коляску": "婴儿车防风罩",
    "Гардероб ограничивает точность": "衣橱限制了搭配精度",
    "Демисезонный комбез (80–120г)": "春秋连体衣（80–120 克填充）",
    "для коляски": "用于婴儿车",
    "Защита от дождя для малыша в коляске": "婴儿车雨罩",
    "Зимний конверт / комбез (250–300г)": "冬季睡袋 / 连体衣（250–300 克填充）",
    "Комбинезон Softshell": "软壳连体衣",
    "Кофта": "针织衫",
    "Лонгслив (тонкая кофта)": "薄款长袖上衣",
    "Манишка / Снуд флисовый": "抓绒护颈 / 围脖",
    "Мороз (ниже 0°C)": "冰点以下（低于 0°C）",
    "Мороз — защита ручек": "冰点以下 — 保护双手",
    "Мороз — максимальная защита для малыша в коляске": "冰点以下 — 为婴儿车内的宝宝提供充分保暖",
    "Мороз — плотный утеплитель для малыша": "冰点以下 — 宝宝需要厚保暖层",
    "Мороз — плотный утеплитель обязателен": "冰点以下 — 必须使用厚保暖层",
    "Мороз — шапка обязательна": "冰点以下 — 必须戴保暖帽",
    "Непромокаемый конверт / дождевик на коляску": "防水睡袋 / 婴儿车雨罩",
    "Ок": "确定",
    "ОРВИ без температуры": "感冒症状，无发热",
    "ОРВИ без температуры и мороз: SkyKid не определяет, безопасна ли прогулка при болезни. Сократите или отложите выход; не закрывайте ребёнку рот и нос тканью.": "孩子有感冒症状但不发热，同时天气低于冰点：SkyKid 无法判断生病时散步是否安全。请缩短或推迟外出，不要用布遮住孩子的口鼻。",
    "Откройте SkyKid": "打开 SkyKid",
    "Откройте SkyKid, обновите погоду и проверьте самочувствие ребёнка перед выходом.": "请打开 SkyKid，更新天气，并在出门前确认孩子的状态。",
    "Откройте SkyKid: приложение обновит погоду и подберёт одежду для текущей прогулки.": "打开 SkyKid：应用会更新天气，并为本次散步推荐衣物。",
    "Откройте Настройки → SkyKid → Геолокация": "打开“设置”→ SkyKid →“位置”",
    "Пелёнка-кокон (молния)": "拉链襁褓睡袋",
    "Ползунки (еврорезинка)": "婴儿连脚裤（宽腰）",
    "Слинг / эргорюкзак": "婴儿背巾 / 人体工学背带",
    "Спит": "睡眠",
    "Спросить Siri": "询问 Siri",
    "Шапка-шлем (зимняя)": "冬季护耳帽",
    "SkyKid не показывает одежду для этого сценария и не заменяет медицинскую оценку. Если состояние ребёнка вызывает тревогу, обращайтесь за неотложной помощью.": "SkyKid 不会在此情况下显示穿衣建议，也不能替代医学评估。如果孩子的状况令人担忧，请寻求紧急医疗帮助。",
    "Включён более осторожный режим для недоношенности или особенностей сердца/дыхания. Индивидуальный план врача важнее расчёта SkyKid.": "由于早产或心脏、呼吸方面的情况，已启用更谨慎的模式。医生制定的个体方案优先于 SkyKid 的计算结果。",
    "+1.5° к порогу одевания": "穿衣阈值 +1.5°",
    "−1.5° к порогу одевания": "穿衣阈值 −1.5°",
    "−2° к порогу одевания": "穿衣阈值 −2°",
    "Облачно · Прогулочная коляска": "阴天 · 婴儿推车",
    "Сургут": "苏尔古特",
    "а": "а",
    "ж": "ж",
    "ч": "ч",
})
MANUAL_OVERRIDES["en"].update({
    "Язык приложения": "App language",
    "Как в системе": "Use system language",
    "Изменения применяются сразу": "Changes apply immediately",
})
MANUAL_OVERRIDES["fr"].update({
    "Язык приложения": "Langue de l’application",
    "Как в системе": "Langue du système",
    "Изменения применяются сразу": "Les modifications s’appliquent immédiatement",
})
MANUAL_OVERRIDES["kk"].update({
    "Язык приложения": "Қолданба тілі",
    "Как в системе": "Жүйе тілін қолдану",
    "Изменения применяются сразу": "Өзгерістер бірден қолданылады",
})
MANUAL_OVERRIDES["zh-Hans"].update({
    "Язык приложения": "应用语言",
    "Как в системе": "跟随系统",
    "Изменения применяются сразу": "更改会立即生效",
})
CYRILLIC_PATTERN = re.compile(r"[А-Яа-яЁё]")
SWIFT_STRING_PATTERN = re.compile(r'"((?:\\.|[^"\\])*)"')
L10N_PATTERN = re.compile(
    r'L10n\.(?:text|format)\(\s*"((?:\\.|[^"\\])*)"',
    re.DOTALL,
)
PRINTF_PATTERN = re.compile(
    r"%(?:\d+\$)?(?:@|lld|ld|d|u|lu|llu|(?:\.\d+)?f|%)"
)
XLIFF_NAMESPACE = {"x": "urn:oasis:names:tc:xliff:document:1.2"}
FORBIDDEN_TRANSLATION_FRAGMENTS = (
    "▁",
    "⁇",
    "XQZ",
    "ZXCV",
    "????",
    "&quot;",
)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch-size", type=int, default=20)
    parser.add_argument(
        "--cache",
        type=Path,
        default=Path("/tmp/skykid-localization-cache.json"),
    )
    parser.add_argument(
        "--locales",
        nargs="+",
        choices=tuple(LOCALES),
        default=list(LOCALES),
    )
    parser.add_argument(
        "--engine",
        choices=("argos", "ollama"),
        default="argos",
        help="Translation engine for English, French, and Chinese.",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Validate the committed app and widget catalogs without models.",
    )
    return parser.parse_args()


def decode_swift_literal(value: str) -> str:
    replacements = {
        r"\\": "\\",
        r"\"": '"',
        r"\n": "\n",
        r"\r": "\r",
        r"\t": "\t",
        r"\0": "\0",
    }
    for escaped, decoded in replacements.items():
        value = value.replace(escaped, decoded)
    return value


def export_xliff() -> Path:
    export_root = Path(tempfile.mkdtemp(prefix="skykid-localizations-"))
    command = [
        "xcodebuild",
        "-project",
        "SkyKid.xcodeproj",
        "-scheme",
        "SkyKid",
        "-exportLocalizations",
        "-localizationPath",
        str(export_root),
        "-exportLanguage",
        "ru",
    ]
    result = subprocess.run(
        command,
        cwd=PROJECT_ROOT,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Xcode localization export failed:\n{result.stderr}")

    xliff = export_root / "ru.xcloc" / "Localized Contents" / "ru.xliff"
    if not xliff.exists():
        raise RuntimeError("Xcode did not produce ru.xliff")
    return xliff


def xliff_keys(path: Path) -> set[str]:
    root = ElementTree.parse(path).getroot()
    return {
        source.text or ""
        for source in root.findall(".//x:trans-unit/x:source", XLIFF_NAMESPACE)
        if source.text
    }


def swift_keys() -> set[str]:
    keys: set[str] = set()

    for source_root in APP_SOURCE_ROOTS:
        for path in source_root.rglob("*.swift"):
            source = path.read_text(encoding="utf-8")

            for match in L10N_PATTERN.finditer(source):
                keys.add(decode_swift_literal(match.group(1)))

            for match in SWIFT_STRING_PATTERN.finditer(source):
                literal = match.group(1)
                if r"\(" in literal:
                    continue
                decoded = decode_swift_literal(literal)
                if CYRILLIC_PATTERN.search(decoded):
                    keys.add(decoded)

    return keys


def load_cache(path: Path) -> dict[str, dict[str, str]]:
    if not path.exists():
        return {}
    value = json.loads(path.read_text(encoding="utf-8"))
    return value if isinstance(value, dict) else {}


def save_cache(path: Path, cache: dict[str, dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(cache, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def placeholder_counter(value: str) -> Counter[str]:
    return Counter(PRINTF_PATTERN.findall(value))


def mask_placeholders(value: str) -> tuple[str, dict[str, str]]:
    placeholders: dict[str, str] = {}

    def replace(match: re.Match[str]) -> str:
        token = f"XQZ{len(placeholders)}"
        placeholders[token] = match.group(0)
        return token

    return PRINTF_PATTERN.sub(replace, value), placeholders


def restore_placeholders(value: str, placeholders: dict[str, str]) -> str:
    for token, placeholder in placeholders.items():
        value = value.replace(token, placeholder)
    return value


def clean_translation(locale: str, value: str) -> str:
    separator = "" if locale == "zh-Hans" else " "
    value = value.replace("▁", separator)
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r"\s+([,.;:!?])", r"\1", value)
    value = re.sub(r"([’'])\s+", r"\1", value)
    return value.strip()


def ollama_request(prompt: str) -> str:
    payload = json.dumps(
        {
            "model": MODEL_NAME,
            "prompt": prompt,
            "stream": False,
            "keep_alive": "20m",
            "options": {
                "temperature": 0,
                "num_ctx": 8192,
                "num_predict": 4096,
            },
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        OLLAMA_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            body = json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError) as error:
        raise RuntimeError(f"Ollama request failed: {error}") from error
    return str(body["response"]).strip()


def translation_prompt(
    target_name: str,
    values: dict[str, str],
) -> str:
    return f"""Translate every value in the JSON object from Russian into {target_name}.
These are concise UI strings for an iOS child-weather and clothing application.
Preserve the JSON keys, placeholders such as XQZ0, SkyKid, TOG, Open-Meteo,
technical identifiers, punctuation, degree symbols, and newline characters.
Use natural, parent-friendly language. Do not add explanations.
Return only one valid JSON object containing exactly the same keys.

INPUT:
{json.dumps(values, ensure_ascii=False)}"""


def parse_json_response(response: str) -> dict[str, str]:
    response = response.strip()
    if response.startswith("```"):
        response = re.sub(r"^```(?:json)?\s*", "", response)
        response = re.sub(r"\s*```$", "", response)

    start = response.find("{")
    end = response.rfind("}")
    if start < 0 or end < start:
        raise ValueError("Model response does not contain a JSON object")

    parsed = json.loads(response[start : end + 1])
    if not isinstance(parsed, dict):
        raise ValueError("Model response is not a JSON object")
    return {str(key): str(value) for key, value in parsed.items()}


def translate_batch(
    locale: str,
    sources: list[str],
    attempts: int = 3,
) -> dict[str, str]:
    masked_sources: dict[str, str] = {}
    placeholder_maps: dict[str, dict[str, str]] = {}

    for index, source in enumerate(sources):
        item_id = f"k{index:03d}"
        masked, placeholders = mask_placeholders(source)
        masked_sources[item_id] = masked
        placeholder_maps[item_id] = placeholders

    last_error: Exception | None = None
    for _ in range(attempts):
        try:
            response = ollama_request(
                translation_prompt(LOCALES[locale], masked_sources)
            )
            parsed = parse_json_response(response)
            if set(parsed) != set(masked_sources):
                raise ValueError("Model changed the JSON keys")

            result: dict[str, str] = {}
            for index, source in enumerate(sources):
                item_id = f"k{index:03d}"
                restored = restore_placeholders(
                    parsed[item_id],
                    placeholder_maps[item_id],
                )
                restored = clean_translation(locale, restored)
                if placeholder_counter(restored) != placeholder_counter(source):
                    raise ValueError(f"Placeholders changed for {source!r}")
                result[source] = restored
            return result
        except (KeyError, ValueError, RuntimeError) as error:
            last_error = error
            time.sleep(0.5)

    if len(sources) > 1:
        middle = len(sources) // 2
        left = translate_batch(locale, sources[:middle], attempts)
        right = translate_batch(locale, sources[middle:], attempts)
        return left | right

    raise RuntimeError(
        f"Could not translate {sources[0]!r} into {locale}: {last_error}"
    )


def chunks(values: list[str], size: int) -> Iterable[list[str]]:
    for index in range(0, len(values), size):
        yield values[index : index + size]


class KazakhTranslator:
    """Fast local Russian→Kazakh translation using the dedicated T5 model."""

    def __init__(self) -> None:
        import torch
        from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

        self._torch = torch
        self._tokenizer = AutoTokenizer.from_pretrained(
            KAZAKH_MODEL_NAME,
            use_fast=False,
            local_files_only=True,
        )
        self._device = "mps" if torch.backends.mps.is_available() else "cpu"
        self._model = AutoModelForSeq2SeqLM.from_pretrained(
            KAZAKH_MODEL_NAME,
            local_files_only=True,
        ).to(self._device).eval()

    def translate(self, sources: list[str]) -> dict[str, str]:
        masked_sources: list[str] = []
        placeholder_maps: list[dict[str, str]] = []
        for source in sources:
            masked, placeholders = mask_placeholders(source)
            masked_sources.append(masked)
            placeholder_maps.append(placeholders)

        inputs = self._tokenizer(
            masked_sources,
            return_tensors="pt",
            padding=True,
            truncation=True,
        ).to(self._device)
        with self._torch.inference_mode():
            output = self._model.generate(
                **inputs,
                max_new_tokens=128,
                num_beams=1,
                do_sample=False,
                no_repeat_ngram_size=3,
                repetition_penalty=1.1,
            )
        decoded = self._tokenizer.batch_decode(
            output,
            skip_special_tokens=True,
        )

        translations: dict[str, str] = {}
        for source, value, placeholders in zip(
            sources,
            decoded,
            placeholder_maps,
        ):
            restored = restore_placeholders(value, placeholders).strip()
            restored = clean_translation("kk", restored)
            if not restored:
                restored = source
            if placeholder_counter(restored) != placeholder_counter(source):
                raise RuntimeError(
                    f"Kazakh model changed placeholders for {source!r}: "
                    f"{restored!r}"
                )
            translations[source] = restored
        return translations


class ArgosModel:
    """Direct CTranslate2 runner for one unpacked Argos language package."""

    def __init__(self, pair: str) -> None:
        if ARGOS_PYTHON_ROOT.exists():
            sys.path.insert(0, str(ARGOS_PYTHON_ROOT))

        import ctranslate2
        import sentencepiece

        pair_root = ARGOS_MODELS_ROOT / pair
        package_roots = sorted(pair_root.glob("translate-*"))
        if len(package_roots) != 1:
            raise RuntimeError(
                f"Expected one unpacked Argos package in {pair_root}"
            )

        package_root = package_roots[0]
        self._sentencepiece = sentencepiece.SentencePieceProcessor(
            model_file=str(package_root / "sentencepiece.model")
        )
        self._translator = ctranslate2.Translator(
            str(package_root / "model"),
            device="cpu",
            inter_threads=4,
            intra_threads=2,
        )

    def translate(self, values: list[str]) -> list[str]:
        tokenized = [
            self._sentencepiece.encode(value, out_type=str)
            for value in values
        ]
        results = self._translator.translate_batch(
            tokenized,
            beam_size=4,
        )
        return [
            self._sentencepiece.decode(result.hypotheses[0]).strip()
            for result in results
        ]


class HelsinkiChineseModel:
    """English→Chinese Marian model used after the Russian→English stage."""

    def __init__(self) -> None:
        import torch
        from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

        self._torch = torch
        offline = os.environ.get("HF_HUB_OFFLINE") == "1"
        self._tokenizer = AutoTokenizer.from_pretrained(
            CHINESE_MODEL_NAME,
            local_files_only=offline,
        )
        self._device = "mps" if torch.backends.mps.is_available() else "cpu"
        self._model = AutoModelForSeq2SeqLM.from_pretrained(
            CHINESE_MODEL_NAME,
            local_files_only=offline,
        ).to(self._device).eval()

    def translate(self, values: list[str]) -> list[str]:
        inputs = self._tokenizer(
            values,
            return_tensors="pt",
            padding=True,
            truncation=True,
        ).to(self._device)
        with self._torch.inference_mode():
            output = self._model.generate(
                **inputs,
                max_new_tokens=256,
                do_sample=False,
            )
        return [
            value.strip()
            for value in self._tokenizer.batch_decode(
                output,
                skip_special_tokens=True,
            )
        ]


class ArgosTranslator:
    """Russian→English with optional English→French/Chinese pivot."""

    def __init__(self, locale: str) -> None:
        self._locale = locale
        self._russian_to_english = ArgosModel("ru_en")
        if locale == "en":
            self._english_to_target = None
            self._chinese_placeholder_model = None
        elif locale == "zh-Hans":
            self._english_to_target = HelsinkiChineseModel()
            self._chinese_placeholder_model = ArgosModel("en_zh")
        else:
            self._english_to_target = ArgosModel(f"en_{locale[:2]}")
            self._chinese_placeholder_model = None

    def translate(self, sources: list[str]) -> dict[str, str]:
        masked_sources: list[str] = []
        placeholder_maps: list[dict[str, str]] = []
        for source in sources:
            masked, placeholders = mask_placeholders(source)
            masked_sources.append(masked)
            placeholder_maps.append(placeholders)

        values = self._russian_to_english.translate(masked_sources)
        if self._english_to_target is not None:
            if self._locale == "zh-Hans":
                translated = list(values)
                plain_indices = [
                    index
                    for index, placeholders in enumerate(placeholder_maps)
                    if not placeholders
                ]
                templated_indices = [
                    index
                    for index, placeholders in enumerate(placeholder_maps)
                    if placeholders
                ]
                plain_values = self._english_to_target.translate(
                    [values[index] for index in plain_indices]
                )
                for index, value in zip(plain_indices, plain_values):
                    translated[index] = value

                if self._chinese_placeholder_model is not None:
                    templated_values = self._chinese_placeholder_model.translate(
                        [
                            re.sub(r"XQZ(\d+)", r"ZXCVBNM\1", values[index])
                            for index in templated_indices
                        ]
                    )
                    for index, value in zip(
                        templated_indices,
                        templated_values,
                    ):
                        translated[index] = re.sub(
                            r"(?:ZXCV+BNM|ZCV+BNM|XCV+BNM|CV+BNM)\s*(\d+)",
                            r"XQZ\1",
                            value,
                        )
                values = translated
            else:
                values = self._english_to_target.translate(values)

        translations: dict[str, str] = {}
        for source, value, placeholders in zip(
            sources,
            values,
            placeholder_maps,
        ):
            restored = restore_placeholders(value, placeholders).strip()
            restored = clean_translation(self._locale, restored)
            if not restored:
                restored = source
            if placeholder_counter(restored) != placeholder_counter(source):
                raise RuntimeError(
                    f"Argos changed placeholders for {source!r}: "
                    f"{restored!r}"
                )
            translations[source] = restored
        return translations


def translate_locale(
    locale: str,
    keys: list[str],
    cache: dict[str, dict[str, str]],
    cache_path: Path,
    batch_size: int,
    engine: str,
) -> dict[str, str]:
    translations = cache.setdefault(locale, {})
    pending = [
        key
        for key in keys
        if CYRILLIC_PATTERN.search(key) and not translations.get(key)
    ]
    total_batches = (len(pending) + batch_size - 1) // batch_size
    kazakh_translator = KazakhTranslator() if locale == "kk" and pending else None
    argos_translator = (
        ArgosTranslator(locale)
        if locale != "kk" and engine == "argos" and pending
        else None
    )

    print(
        f"[{locale}] {len(keys) - len(pending)}/{len(keys)} cached; "
        f"{len(pending)} to translate",
        flush=True,
    )
    for batch_index, batch in enumerate(chunks(pending, batch_size), start=1):
        if kazakh_translator is not None:
            translations.update(kazakh_translator.translate(batch))
        elif argos_translator is not None:
            translations.update(argos_translator.translate(batch))
        else:
            translations.update(translate_batch(locale, batch))
        save_cache(cache_path, cache)
        print(
            f"[{locale}] batch {batch_index}/{total_batches} complete",
            flush=True,
        )

    translations.update(MANUAL_OVERRIDES.get(locale, {}))
    return {
        key: clean_translation(locale, translations.get(key, key))
        if CYRILLIC_PATTERN.search(key)
        else key
        for key in keys
    }


def escape_strings_value(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', r"\"")
        .replace("\n", r"\n")
        .replace("\r", r"\r")
        .replace("\t", r"\t")
    )


def strings_document(values: dict[str, str]) -> str:
    lines = [
        "/* Generated from Russian source strings. See scripts/generate_localizations.py. */",
        "",
    ]
    for key in sorted(values, key=str.casefold):
        escaped_key = escape_strings_value(key)
        escaped_value = escape_strings_value(values[key])
        lines.append(f'"{escaped_key}" = "{escaped_value}";')
    return "\n".join(lines) + "\n"


def write_locale(locale: str, values: dict[str, str]) -> None:
    document = strings_document(values)
    destinations = (
        APP_RESOURCES / f"{locale}.lproj" / "Localizable.strings",
        WIDGET_RESOURCES / f"{locale}.lproj" / "Localizable.strings",
    )
    for destination in destinations:
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(document, encoding="utf-8")


def read_strings(path: Path) -> dict[str, str]:
    result = subprocess.run(
        ["plutil", "-convert", "json", "-o", "-", str(path)],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Could not read {path}:\n{result.stderr}")
    parsed = json.loads(result.stdout)
    if not isinstance(parsed, dict):
        raise RuntimeError(f"{path} is not a strings dictionary")
    return {str(key): str(value) for key, value in parsed.items()}


def validate(localizations: dict[str, dict[str, str]], keys: list[str]) -> None:
    expected = set(keys)
    for locale, values in localizations.items():
        if set(values) != expected:
            raise RuntimeError(f"{locale} has a different localization key set")
        for key, value in values.items():
            if not value:
                raise RuntimeError(f"{locale} has an empty value for {key!r}")
            if placeholder_counter(value) != placeholder_counter(key):
                raise RuntimeError(
                    f"{locale} changed placeholders for {key!r}: {value!r}"
                )
            if any(
                fragment in value
                for fragment in FORBIDDEN_TRANSLATION_FRAGMENTS
            ):
                raise RuntimeError(
                    f"{locale} contains a translation artifact for "
                    f"{key!r}: {value!r}"
                )


def validate_existing_catalogs() -> None:
    localizations: dict[str, dict[str, str]] = {}
    expected_keys: list[str] | None = None

    for locale in ("ru", *LOCALES):
        app_path = (
            APP_RESOURCES / f"{locale}.lproj" / "Localizable.strings"
        )
        widget_path = (
            WIDGET_RESOURCES / f"{locale}.lproj" / "Localizable.strings"
        )
        app_values = read_strings(app_path)
        widget_values = read_strings(widget_path)
        if app_values != widget_values:
            raise RuntimeError(
                f"App and widget catalogs differ for {locale}"
            )
        if expected_keys is None:
            expected_keys = sorted(app_values, key=str.casefold)
        localizations[locale] = app_values

    validate(localizations, expected_keys or [])
    print(
        "Existing app and widget localization catalogs are valid",
        flush=True,
    )


def main() -> None:
    arguments = parse_arguments()
    if arguments.validate_only:
        validate_existing_catalogs()
        return

    xliff = export_xliff()
    keys = sorted(xliff_keys(xliff) | swift_keys(), key=str.casefold)
    print(f"Collected {len(keys)} localization keys", flush=True)

    cache = load_cache(arguments.cache)
    localizations: dict[str, dict[str, str]] = {
        "ru": {key: key for key in keys}
    }
    for locale in arguments.locales:
        localizations[locale] = translate_locale(
            locale,
            keys,
            cache,
            arguments.cache,
            arguments.batch_size,
            arguments.engine,
        )

    for locale in ("ru", *arguments.locales):
        write_locale(locale, localizations[locale])

    validate(localizations, keys)
    print("Localization files generated and validated", flush=True)


if __name__ == "__main__":
    main()
