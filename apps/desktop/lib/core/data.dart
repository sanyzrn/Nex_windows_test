/// Emoji data ported 1:1 from the original ui.html: category key,
/// then "emoji keywords" entries. Search matches the keywords.
const Map<String, String> kEmojiCategories = {
  '😀':
      '😀 grinning happy|😃 smiley happy|😄 smile|😁 grin|😆 laughing|😅 sweat smile|🤣 rofl laugh|😂 joy tears laugh|🙂 slight smile|🙃 upside down|😉 wink|😊 blush smile|😇 angel innocent|🥰 love hearts|😍 heart eyes love|🤩 star struck|😘 kiss|😋 yum tasty|😛 tongue|😜 wink tongue|🤪 zany crazy|🤑 money|🤗 hug|🤭 oops|🤫 shush quiet|🤔 thinking|🤐 zipper|🤨 raised eyebrow|😐 neutral|😑 expressionless|😶 no mouth|😏 smirk|😒 unamused|🙄 eye roll|😬 grimace|😌 relieved|😔 pensive sad|😪 sleepy|😴 sleeping|😷 mask sick|🤒 fever sick|🤢 nausea|🤮 vomit|🥵 hot|🥶 cold|🥴 woozy|😵 dizzy|🤯 mind blown|🤠 cowboy|🥳 party|😎 cool sunglasses|🤓 nerd|🧐 monocle|😕 confused|😟 worried|🙁 frown|😮 open mouth wow|😲 astonished|😳 flushed|🥺 pleading|😦 frowning|😨 fearful|😰 anxious|😢 cry sad|😭 sob cry|😱 scream|😖 confounded|😣 persevere|😞 disappointed|😓 downcast|😩 weary|😫 tired|🥱 yawn|😤 triumph|😡 angry mad|😠 angry|🤬 swear|😈 devil|💀 skull dead|💩 poop|🤡 clown|👻 ghost|👽 alien|🤖 robot',
  '👍':
      '👍 thumbs up yes like|👎 thumbs down no|👌 ok|✌️ peace victory|🤞 fingers crossed luck|🤟 love you|🤘 rock|🤙 call me|👈 left|👉 right|👆 up|👇 down|☝️ point up|✋ hand stop|👋 wave hello bye|🖐️ hand|🖖 vulcan|👏 clap|🙌 raise hands|👐 open hands|🤲 palms|🤝 handshake deal|🙏 pray thanks please|✍️ write|💪 muscle strong|👀 eyes look|👁️ eye|🧠 brain|👂 ear|👃 nose|👄 mouth|🫶 heart hands|🤌 pinched|🫡 salute',
  '❤️':
      '❤️ red heart love|🧡 orange heart|💛 yellow heart|💚 green heart|💙 blue heart|💜 purple heart|🖤 black heart|🤍 white heart|🤎 brown heart|💔 broken heart|❣️ heart exclamation|💕 two hearts|💞 revolving hearts|💓 beating heart|💗 growing heart|💖 sparkling heart|💘 cupid|💝 heart gift|💯 hundred|💢 anger|💥 boom collision|💫 dizzy|💦 sweat drops|💨 dash|💬 speech|💭 thought|💤 zzz sleep|✨ sparkles|🔥 fire lit|⭐ star|🌟 glowing star|⚡ zap lightning|🎉 tada party|🎊 confetti',
  '🐶':
      '🐶 dog|🐱 cat|🐭 mouse|🐹 hamster|🐰 rabbit bunny|🦊 fox|🐻 bear|🐼 panda|🐨 koala|🐯 tiger|🦁 lion|🐮 cow|🐷 pig|🐸 frog|🐵 monkey|🐔 chicken|🐧 penguin|🐦 bird|🦄 unicorn|🐝 bee|🦋 butterfly|🐢 turtle|🐍 snake|🐙 octopus|🐬 dolphin|🐳 whale|🦈 shark|🌵 cactus|🌲 tree|🌴 palm|🍀 clover luck|🌸 blossom flower|🌹 rose|🌻 sunflower|🌈 rainbow|☀️ sun|🌙 moon|☁️ cloud|❄️ snow|🌊 wave ocean',
  '🍕':
      '🍎 apple|🍌 banana|🍉 watermelon|🍇 grapes|🍓 strawberry|🍒 cherry|🍑 peach|🥑 avocado|🍆 eggplant|🌶️ pepper hot|🥕 carrot|🌽 corn|🍞 bread|🧀 cheese|🍔 burger|🍟 fries|🍕 pizza|🌭 hotdog|🌮 taco|🍣 sushi|🍜 ramen noodles|🍩 donut|🍪 cookie|🎂 cake birthday|🍫 chocolate|🍿 popcorn|☕ coffee|🍵 tea|🧋 boba|🍺 beer|🍷 wine|🥂 cheers',
  '💡':
      '⚽ soccer football|🏀 basketball|🎮 game controller|🎲 dice|🎯 target dart|🏆 trophy win|🥇 gold medal|🎸 guitar|🎹 piano|🎧 headphones music|🎵 music note|🎬 movie|📷 camera|💻 laptop|🖥️ desktop computer|⌨️ keyboard|🖱️ mouse|📱 phone|🔋 battery|💡 idea bulb|🔦 flashlight|📚 books|📝 memo note|✏️ pencil|📌 pin|📎 paperclip|✂️ scissors|🔒 lock|🔑 key|🔨 hammer|🛠️ tools|⚙️ gear settings|🧲 magnet|💰 money bag|💳 card|📦 package box|✉️ envelope mail|📅 calendar|⏰ alarm clock|⌛ hourglass|🚀 rocket|✈️ plane|🚗 car|🏠 house home|🎁 gift',
  '✅':
      '✅ check done yes|☑️ checkbox|✔️ check mark|❌ cross no wrong|❎ cross box|➕ plus|➖ minus|➗ divide|✖️ multiply|❓ question|❗ exclamation|‼️ double exclamation|⚠️ warning|🚫 prohibited|⛔ no entry|🔴 red circle|🟠 orange circle|🟡 yellow circle|🟢 green circle|🔵 blue circle|🟣 purple circle|⚫ black circle|⚪ white circle|🔺 triangle|🔶 diamond|▶️ play|⏸️ pause|⏹️ stop|🔁 repeat|🔀 shuffle|⬆️ up arrow|⬇️ down arrow|⬅️ left arrow|➡️ right arrow|↩️ return|🔗 link|©️ copyright|®️ registered|™️ trademark|#️⃣ hash|🆗 ok|🆕 new|🆒 cool|🔞 18',
};

class EmojiEntry {
  const EmojiEntry(this.emoji, this.keywords, this.category);
  final String emoji;
  final String keywords;
  final String category;
}

final List<EmojiEntry> kAllEmoji = [
  for (final e in kEmojiCategories.entries)
    for (final item in e.value.split('|'))
      EmojiEntry(
        item.substring(0, item.indexOf(' ')),
        item.substring(item.indexOf(' ') + 1),
        e.key,
      ),
];

/// Default dock/more widget order, ported 1:1.
const List<String> kDefaultDock = [
  'emoji',
  'clip',
  'color',
  'shot',
  'note',
  'more',
];
const List<String> kDefaultMore = [
  'calc',
  'timer',
  'stopwatch',
  'search',
  'snippets',
  'text',
  'media',
  'clock',
  'gen',
  'pass',
  'unit',
  'folders',
  'awake',
  'pinwin',
  'desktop',
  'screenoff',
  'lock',
  'taskmgr',
  'winset',
];

/// Web search engines, ported 1:1.
const Map<String, String> kEngines = {
  'Google': 'https://www.google.com/search?q=%s',
  'YouTube': 'https://www.youtube.com/results?search_query=%s',
  'Wikipedia': 'https://en.wikipedia.org/w/index.php?search=%s',
  'Translate': 'https://translate.google.com/?sl=auto&tl=en&text=%s',
  'Maps': 'https://www.google.com/maps/search/%s',
  'GitHub': 'https://github.com/search?q=%s',
  'DuckDuckGo': 'https://duckduckgo.com/?q=%s',
};

/// Color palette on the Color panel.
const List<int> kPalette = [
  0xFFEF4444,
  0xFFF97316,
  0xFFF59E0B,
  0xFFEAB308,
  0xFF84CC16,
  0xFF22C55E,
  0xFF10B981,
  0xFF14B8A6,
  0xFF06B6D4,
  0xFF0EA5E9,
  0xFF3B82F6,
  0xFF6366F1,
  0xFF8B5CF6,
  0xFFA855F7,
  0xFFD946EF,
  0xFFEC4899,
  0xFFF43F5E,
  0xFF78716C,
  0xFF64748B,
  0xFF111827,
  0xFF374151,
  0xFF9CA3AF,
  0xFFE5E7EB,
  0xFFFFFFFF,
];

/// Quick folders on the Folders panel (Windows shell targets).
const List<List<String>> kFolders = [
  ['Desktop', 'shell:Desktop'],
  ['Downloads', 'shell:Downloads'],
  ['Documents', 'shell:Personal'],
  ['Pictures', 'shell:My Pictures'],
  ['Music', 'shell:My Music'],
  ['Videos', 'shell:My Video'],
  ['This PC', 'shell:MyComputerFolder'],
  ['Recycle Bin', 'shell:RecycleBinFolder'],
  ['Startup', 'shell:Startup'],
];

/// Cities offered by the world clock.
const List<String> kZones = [
  'UTC',
  'Europe/London',
  'Europe/Paris',
  'Europe/Berlin',
  'Europe/Istanbul',
  'Europe/Moscow',
  'Asia/Tehran',
  'Asia/Dubai',
  'Asia/Karachi',
  'Asia/Kolkata',
  'Asia/Bangkok',
  'Asia/Shanghai',
  'Asia/Tokyo',
  'Asia/Seoul',
  'Australia/Sydney',
  'Pacific/Auckland',
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'America/Toronto',
  'America/Sao_Paulo',
  'America/Mexico_City',
  'Africa/Cairo',
  'Africa/Lagos',
];
