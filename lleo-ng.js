var database = [];
var databaseIdx = {};
var accentsJson = 'accents.json';
var accents = {};
var poem = [];

var httpStats = {};

const fs = require('fs');
const readline = require('readline');

if (process.argv.length < 4) {
	console.log(
		"Для запуска используйте:\n\n",
		"node " + process.argv[1] + " b databasefile.json source.txt\n",
		" - создать(дополнить) ассоциативную базу databasename.json, прочтя текст source.txt\n\n",
		"node " + process.argv[1] + " a accents.json $$$$SLOG.BSY\n",
		" - конвертировать базу данных ударений из старого (бинарного) формата в новый\n\n",
		"node " + process.argv[1] + " w databasefile.json\n",
		" - использовать веб-сервис rifmus.net для расстановки ударений в базе databasefile.json\n\n",
		"node " + process.argv[1] + " v databasefile.json\n",
		" - аналогично w, но только для тех слов из базы, в которых ударения не были расставлены ранее\n\n",
		"node " + process.argv[1] + " e databasefile.json\n",
		" - вручную расставить ударения в тех словах из базы databasefile.json, где ударения не были расставлены ранее\n\n",
		"node " + process.argv[1] + " m databasefile1.json databasefile2.json\n",
		" - создать(дополнить) ассоциативную базу databasename1.json элементами базы database2.json\n\n",
		"node " + process.argv[1] + " c databasefile.json stih.rtm\n",
		" - сочинить стих, используя databasefile.json и файл ритма stih.rtm, например:\n",
		"                      +--+--+--+  A\n",
		"                      +--+--+     B\n",
		"                      +--+--+--+  A\n",
		"                      +--+--+     B\n",
		" В этом примере куплеты будут состоять из 4 строк, '-' - безударный слог,\n",
		" '+' - ударный слог, 'A' - код рифмы (заглавная латинская буква).");

	process.exit();
}

switch (process.argv[2]) {
	case 'b': createDb(); break;
	case 'a': convertAccentsDb(); break;
	case 'w': enrichDbUsingWebService(); break;
	case 'v': enrichDbUsingWebService(true); break;
	case 'e': editAccents(); break;
	case 'm': mergeDb(); break;
	case 'c': composePoem(); break;
}

/********************************** Entry points **********************************/

function createDb() {
	var databasefile = process.argv[3];
	var sourcefile = process.argv[4];

	try {
		loadDbFromJsonFile(databasefile);
	} catch (err) {
		console.log("Can't read " + databasefile + ". Starting with empty database.");
	}

	try {
		loadAccentsFromJsonFile(accentsJson);
	} catch (err) {
		console.log("Can't read accents.json. Starting with empty accents database.");
	}

	parseSourceText(sourcefile);
	saveDbToJsonFile(databasefile);
}

function convertAccentsDb() {
	var binary = process.argv[3];
	var json = process.argv[4];	

	loadAccentsFromBinaryFile(binary);
	saveAccentsToJsonFile(json);
}

function enrichDbUsingWebService(skipVerified) {
	var databasefile = process.argv[3];

	loadDbFromJsonFile(databasefile);

	try {
		loadAccentsFromJsonFile(accentsJson);
	} catch (err) {
		console.log("Can't read accents.json. Starting with empty accents database.");
	}
	
	console.log("Requesting the web service. Please, be patient...");

	var timer = setInterval(function() {
		console.log("HTTP requests done: ", httpStats);
	}, 5000);

	Promise.all(database.map((entry) => queryRifmus(entry, skipVerified)))
		.then((accents) => {
			clearInterval(timer);
			var succeeded = 0;

			accents.forEach((a, i) => {
				if (a != -1) {
					console.log(database[i].asString, a);

					succeeded += 1;
					setAccent(database[i], a);
				}
			});

			console.log(succeeded + " requests succeeded");

			saveDbToJsonFile(databasefile);
			saveAccentsToJsonFile(accentsJson);
		});
}

function nextUnverifiedWord(startFrom) {
	if (startFrom == null) {
		startFrom = -1;
	}
	for (var i = startFrom + 1; i < database.length; ++i) {
		if (!database[i].accentVerified) {
			return i;
		}
	}
	return null;
}

function printEditorHelp() {
	console.log(
		"\n\nДля расстановки ударений используйте команды:\n\n",
		"y            - согласиться с предложенным вариантом ударения, перейти к следующему слову\n",
		"s            - перейти к следующему слову\n",
		"<число>      - задать номер ударного слога (начиная с 0), перейти к следующему слову\n",
		"<слог>       - задать ударный слог, перейти к следующему слову\n",
		"e <слово>    - перейти к ввденному слову\n",
		"d            - показать запись в базе\n",
		"wq           - сохранить базу и выйти\n",
		"q или Ctrl-c - выйти без сохранения\n\n");
};

function editAccents() {
	var databasefile = process.argv[3];

	loadDbFromJsonFile(databasefile);

	try {
		loadAccentsFromJsonFile(accentsJson);
	} catch (err) {
		console.log("Can't read accents.json. Starting with empty accents database.");
	}

	var index = nextUnverifiedWord();

	if (index === null) {
		console.log("There are no unverified accents in database " + process.argv[3]);
		return;
	}

	printEditorHelp();

	const rl = readline.createInterface(process.stdin, process.stdout, (line) => {
		const hint = database[index].syllables
			.map(ss => ss.replace(/^\-*|\-*$/g, ''))
			.filter(ss => line === '' || ss.startsWith(line));
		return [hint, line];
	});
	rl.setPrompt(`${wordToString(database[index])} (${database[index].syllables.join()}) # `);
	rl.prompt();

	rl.on('line', (line) => {
		const word = index && database[index];

		if (line === '?') {
			printEditorHelp();
		} if (line === 'q') {
			rl.close();
		} else if (line === 'wq') {
			saveDbToJsonFile(databasefile);
			saveAccentsToJsonFile(accentsJson);
			rl.close();
		} else if (line === 'd') {
			console.log(word);
		} else if (line.startsWith('e ')) {
			index = databaseIdx[line.slice(2)] && databaseIdx[line.slice(2)].index;
		} else if (line === 's') {
			index = nextUnverifiedWord(index);
		} else if (index != null && line === 'y') {
			word.accentVerified = true;
			index = nextUnverifiedWord(index);
		} else if (index != null && line.match(/\d+/)) {
			const parsed = parseInt(line, 10);
			if (parsed >= 0 && parsed < word.syllables.length) {
				setAccent(word, parsed);
				index = nextUnverifiedWord(index);
			}
		} else if (index != null) {
			for (var s = 0; s < word.syllables.length; ++s) {
				if (line === word.syllables[s].replace(/^\-*|\-*$/g, '')) {
					setAccent(word, s);
					index = nextUnverifiedWord(index);
					break;
				}
			}
		}

		if (index == null) {
			rl.setPrompt('(слово не найдено) # ');
		} else {
			rl.setPrompt(`${wordToString(database[index])} (${database[index].syllables.join()}) # `);
		}
		rl.prompt();
	}).on('close', () => {
		process.exit(0);
	});
}

function mergeDb() {
	var target = process.argv[3];
	var source = process.argv[4];

	try {
		loadDbFromJsonFile(target);
	} catch (err) {
		console.log("Can't read " + target + ". Starting with empty database.");
	}

	var sourcedb = JSON.parse(fs.readFileSync(source, 'utf8'));

	sourcedb.forEach((newEntry) => {
		var existingEntry = databaseIdx[newEntry.asString];

		if (existingEntry) {
			// Existing word
			if (newEntry.accentVerified && !existingEntry.accentVerified) {
				setAccent(existingEntry, newEntry.accent);
			}

			existingEntry.links =
				existingEntry.links.concat(newEntry.links.filter((i) => existingEntry.links.indexOf(i) < 0 ));
		} else {
			// New word
			database.push(newEntry);
			databaseIdx[newEntry.asString] = database[database.length - 1];
		}
	});

	saveDbToJsonFile(target);
}

function composePoem() {
	var databasefile = process.argv[3];
	var patternfile = process.argv[4];

	loadDbFromJsonFile(databasefile);
	loadPattern(patternfile);

	while ((c = compose(
		getRandomWord(), getRandomWord(), getRandomWord(),
		getRandomWord(), getRandomWord(), getRandomWord(),
		getRandomWord(), getRandomWord(), getRandomWord())) == null);

	console.log(c);
}

/********************************** Utility functions **********************************/

function findLastIndex(array, predicate, fromIndex) {
	const length = array == null ? 0 : array.length;
	if (!length) {
		return -1
	}
	let index = length - 1;
	if (fromIndex !== undefined) {
		index = fromIndex < 0
		? Math.max(length + fromIndex, 0)
		: Math.min(fromIndex, length - 1);
	}
	do {
		if (predicate(array[index], index, array)) {
			return index
		}
	} while (index--);

	return -1
}

function decodeCp866(buffer) {
	var chars = "АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдежзийклмноп░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀рстуфхцчшщъыьэюяЁёЄєЇїЎў°∙·√№¤■ ";
	var s = "";

	for (const b of buffer) {
		if (b < 128) {
			s += String.fromCharCode(b);
		} else {
			s += chars[b - 128];
		}
	}
	return s;
}

function httpGet(url) {
	return new Promise((resolve, reject) => {
		// select http or https module, depending on reqested url
		const lib = url.startsWith('https') ? require('https') : require('http');
		lib.globalAgent.maxSockets = 45;

		const request = lib.request(url, (response) => {
			httpStats[response.statusCode] = (httpStats[response.statusCode] || 0) + 1;

			if (response.statusCode < 200 || response.statusCode > 299) {
				reject(new Error('Failed to get ' + url + ', status code: ' + response.statusCode));
			}

			const body = [];
			response.setEncoding('utf8');
			response.on('data', (chunk) => body.push(chunk));
			response.on('end', () => {
				return resolve(body.join(''))
			});
		});
		/*
		request.on('socket', function(socket) {
			socket.setTimeout(20 * 1000);  // 10 seconds
			socket.on('timeout', function() {
				console.log("Request timed out: " + url);
				request.abort();
			});
		});
		*/
		request.on('error', (err) => reject(err));
		request.end();
	})
}

/********************************** Data querying and saving **********************************/

function queryRifmus(databaseEntry, skipVerified) {
	if (databaseEntry.accentVerified && skipVerified) {
		return Promise.resolve(-1);
	}

	if (databaseEntry.syllables == null || databaseEntry.syllables.length < 2) {
		return Promise.resolve(0);
	}

	// Search for a string constructed from given word with an accent symbol (&#x301;) added after some vowel in it.
	// Calculate the number of the vowel (which is also a number of the syllable) where accent symbol is found.
	// Below is a fragment of the real data got from service:
	// <div class='grid-full' id='result' itemscope itemtype='http://schema.org/Question'>
    //    <h1 class='nocaps' itemprop='name text'>
    //      Рифма к слову
    //      &laquo;застре&#x301;лен&raquo;
    //    </h1>
    //    <div>

	return httpGet("https://rifmus.net/rifma/" + encodeURIComponent(databaseEntry.asString))
		.then((response) => response.match(new RegExp("&laquo;" + databaseEntry.asString.replace(/([аоэиуыеёюя])/g, "$1(&#x301;)?"))).indexOf("&#x301;") - 1)
		.catch((err) => -1);
}

function loadAccentsFromBinaryFile(binary) {
	var buffer = fs.readFileSync(binary);

	var offset = buffer.readInt8(0); // first chunk of the file looks garbaged, skip it
	var chunkSize = 0;

	while ((chunkSize = buffer.readInt8(offset)) && (offset + chunkSize) < buffer.length) {
		accents[decodeCp866(buffer.slice(offset + 1, offset + chunkSize - 3))] = {
			vyes: buffer.readUInt16LE(offset + chunkSize - 3),
			vno: buffer.readUInt16LE(offset + chunkSize - 1)
		}

		offset += chunkSize + 1;
	}
}

function loadAccentsFromJsonFile(json) {
	accents = JSON.parse(fs.readFileSync(json, 'utf8'));
}

function saveAccentsToJsonFile(json) {
	fs.writeFileSync(json, JSON.stringify(accents));
}

function saveDbToJsonFile(databasefile) {
	fs.writeFileSync(databasefile, JSON.stringify(database));
	console.log("Saved " + database.length + " records to " + databasefile + ".");
}

function loadDbFromJsonFile(databasefile) {
	database = JSON.parse(fs.readFileSync(databasefile, 'utf8'));

	database.forEach((entry) => {
		if (entry.accent < 0) {
			entry.accentVerified = false;
			console.log("WARN: entry.accent < 0 in " + entry.asString + ". Marked as unverified.");
		}
		databaseIdx[entry.asString] = entry;
	});

	console.log("Loaded " + database.length + " records from " + databasefile + ".");
}

function loadPattern(patternfile) {
	var rhymes = {};
	fs.readFileSync(patternfile, 'utf8').split(/\r?\n/).forEach((string, lineNum) => {
		try {
			const [ignore, pattern, rhyme] = string.match(/([а-яА-Я +-]+) +([A-Z])/);
			var line = {
				pattern: pattern.toLowerCase(),
				rhyme: rhyme,
				weakRhyme: false
			}

			// Check if any two lines should be rhymed but have different rhythm of their endings.
			// Mark them as having a weak rhyme.
			if (!rhymes[line.rhyme]) {
				rhymes[line.rhyme] = line;
			} else {
				line.weakRhyme = rhymes[line.rhyme].weakRhyme =
					(line.pattern.slice(-3) != rhymes[line.rhyme].pattern.slice(-3));
			}

			if (line.weakRhyme) {
				console.log("WARN: Weak rhyme on line", lineNum);
			}

			if (line.pattern.length && line.rhyme) {
				poem.push(line);
			}
		} catch (e) {}
	});

	console.log("Loaded pattern:\n", poem);
}

/********************************** Split to syllables **********************************/

//    Первым делом надо сказать об алгоритме разбивки на слоги. Количество слогов
// равно  количеству гласных букв.  Есть слова с нулевым количеством слогов - это
// предлоги "в",  "с",  "к" и т.д. Их можно вставлять в любую стихотворную строку
// по мере необходимости, не боясь нарушить ритм.
//    Алгоритм разбивки на слоги,  который я  сделал,  иногда  дает  ошибку.  Это
// связано  с тем,  что не имеется четких правил,  позволяющих определить границы
// слогов. Например почему: МОР-СКИ-Е , но МЕРЗ-КИ-Е ?
//    Границы слога зависят от корня.  Но в общем случае  слог  заканчивается  на
// гласной, если за ней идет тоже гласная ("ко-а-ла"), на гласную, если перед ней
// только одна  согласная  ("мо-ло-ко"),  и  на  согласную  после  гласной,  если
// согласных  подряд  две  или больше ("мор-ски-е").  В последнем случае алгоритм
// изредка будет давать сбой, раскладывая "пар-тком", "мер-зки-е" etc.
//    НО: Для  нашего  случая  это непринципиально,  поэтому заниматься серьезной
// доработкой я не стал.

function splitSyllables(word) {
	if (word == null || word == "") {
		throw "Assertion failed: Null word in splitSyllables()";
	}

	var vowels = word.match(/[аоэиуыеёюя]/g);
	
	var syllables = word.match(
		// <любое число согласных, мягких и твердых знаков>
		// <одна гласная>
		// <любое число согласных, мягких и твердых знаков до конца слова, если гласных в нем не осталось>
		// <одна согласная и, возможно, следующий за ней мягкий или твердый знак, если за ней следует еще одна согласная>
		/[бвгджзйклмнпрстфхцчшщьъ]*[аоэиуыеёюя]([бвгджзйклмнпрстфхцчшщьъ]+$)?([бвгджзйклмнпрстфхцчшщ][ьъ]?(?=[бвгджзйклмнпрстфхцчшщ]))?/g
	);	

	if (syllables != null && vowels != null && syllables.length != vowels.length) {
		throw "Assertion failed: Number of syllables differs from number of vowels in: " + word;
	}

	if (syllables != null && syllables.join('') != word) {
		throw "Assertion failed: Some letters was lost while splitting to syllables: " + word;
	}

	return syllables && syllables.map((each, i, syllables) => (i == 0 ? "" : "-") + each + ((i == syllables.length - 1) ? "" : "-"));
}

/********************************** Set accent **********************************/

//    Как оказывается, четких правил простановки ударений в словах русского языка
// не имеется. Более того, в одном и том же слове ударение может меняться. Ну как
// объяснить компьютеру,  почему в выражении "прижал к груди",  ударение в  слове
// "груди" падает на второй слог, а в выражении "женские груди" - не первый?
//    Тем не   менее   я   предположил   (а   в   дальнейшем   мое  предположение
// подтвердилось), что существует некоторое количество слогов, на которые никогда
// не падает ударение,  а также некоторое количество слогов,  на которые ударение
// падает всегда.
//    Мой алгоритм  позволяет  на  основании  некоторого   накопленного   "ручной
// простановкой"  опыта  прогнозировать наиболее вероятный ударный слог.  Процент
// попаданий при  этом  (не  считая  односложные  слова,  где  альтернативы  нет)
// составляет  50-60%,  что  конечно немного,  но значительно выше случайного 30%
// (средняя  длина  слова  =  3  слогам).  Вспомнив,  что  иные   поэты   нарочно
// пренебрегают   ударениями   ("глупый  пингвин  робко  прячет"),  можно  вполне
// допустить такой процент.
//    Вначале в некотором количестве слов  ударения  проставляются  вручную.  При
// этом  в  специальной  базе  записываются  все  встретившиеся  слоги,  а  также
// количество их ударных (Vyes) и  безударных  (Vno)  существований.  Вероятность
// получения     ударения     в    этом    слоге,    вычисленная    по    формуле
// A=(Vyes-Vno)*(Vyes+Vno) тем больше,  чем больший опыт накоплен для этого слога
// и чем  меньше противоречивого употребления этого слога было встречено.  Затем,
// используя эту базу,  программа готова  выполнять  автоматическое  проставление
// ударений.

//    NOTE: Тут следует привести контрпример с наречием "ничего́" в котором при-
// веденный алгоритм никогда не проставит ударение верно из-за огромного количес-
// тва прилагательных в родительном падеже с безударным окончанием "-го" (напр.
// ле́тнего). Этот контрпример показывает низкую ценность статистики по ударениям,
// накопленной без учета принадлежности слога части слова (морфеме). Классическая
// наука о языке вообще ставит под сомнение возможность определения ударения пу-
// тем анализа слогов, поскольку ударение в русском языке несет смысловую нагруз-
// ку, и в одном наборе слогов может быть расставлено по-разному, меняя тем самым
// смысл слова и состав морфем.

function setAccent(databaseEntry, syllableNo) {
//	if (syllableNo < 0) {
//		throw "Assertion failed: syllableNo " + syllableNo + " is invalid";
//	}

	if (syllableNo != 0 && databaseEntry.syllables == null) {
		throw "Assertion failed: syllableNo " + syllableNo + " is out of bounds: " + databaseEntry;
	}

	if (databaseEntry.syllables != null && syllableNo >= databaseEntry.syllables.length) {
		throw "Assertion failed: syllableNo " + syllableNo + " is out of bounds: " + databaseEntry;
	}

	if (databaseEntry.syllables != null && databaseEntry.syllables.length > 1) {
		databaseEntry.syllables.forEach((s, i) => {
			if (!accents[s]) {
				accents[s] = {
					vyes: 0,
					vno: 0
				}
			}
			accents[s].vyes += (syllableNo == i) * 1;
			accents[s].vno += (syllableNo != i) * 1;
		});
	}
	databaseEntry.accent = syllableNo;
	databaseEntry.accentVerified = true;
}

function getAccentProbability(syllable) {
	var a = accents[syllable];
	return  a ? (a.vyes - a.vno) * (a.vyes + a.vno) : 0;
}

function getAccentedSyllable(syllables) {
	if (syllables.length < 2) {
		return 0;
	}

	var p = syllables.map((s) => getAccentProbability(s));
	return p.indexOf(Math.max.apply(null, p));
}

/********************************** Parse source text **********************************/

//    Разберем работу алгоритма на примере. Имеем текст: "Мама мыла раму. На раму
// села мама."
//    Получившаяся база имеет следующий вид:
//    1 мама 5
//    2 мыла 1
//    3 раму 2 4
//    4 на
//    5 села 3
//
//    Номера перед словом я проставил для наглядности - реально их нет. Мы видим,
// что в тексте перед словом "мама" употреблялось слово "села",  а перед "раму" -
// слова "мыла" и "на".
//    Вообще формат единичного элемента выглядит так:
//
//    байт - ФЛАГ
//    байт - количество ассоциаций в поле X
//    байт - количество слогов
//    байт - номер ударного слога
//    байт - количество букв в слове N
//    [N байт] - слово
//    {[X слов]} - номера слов-ассоциаций
//
//    Скобки {}  означают,  что  ассоциаций  может  не быть.  Например если слово
// начинает новое предложение. (Вспомним наше "на".)
//
//    В байте флага устанавливается:
//    - бит 1, если ударение для этого слова было проставлено вручную - нужен для
// того,  чтобы  блок  автоматической  расстановки  ударений не трогал это слово,
// обработанное когда-то вручную; [accentVerified]
//    - бит 7,  если это слово уже использовалось как окончание, и это не привело
// к успеху.  - Нужен для того,  чтобы функция,  случайно  выбирающая  слова,  не
// повторялась; [tried]
//    - бит 8,  если это слово использовалось как рифма в  этом  цикле  сочинения
// стиха  -  нужен для того,  чтобы при написании стиха не повторялись в качестве
// рифмы одни и те же слова. [used]
//
//    Количество слогов,  ударный слог и флаг вначале равны нулю - при дальнейшей
// обработке сформированной базы они будут играть свою роль.

function parseSourceText(sourcefile) {
	data = fs.readFileSync(sourcefile, 'utf8');

	// split source into sentences
	data.split(/[.;!?\n]/).forEach((sentence) => {
		if (sentence != "") {
			// split sentences into words, remove everything but cyrillic letters
			sentence.toLowerCase().replace(/[^а-я]/g, ' ').trim().split(/\s+/).forEach((word, i, words) => {
				if (word != "") {
					if (!databaseIdx[word]) {
						// new word to database
						var syllables = splitSyllables(word);
						database.push({
							index: database.length,
							asString: word, // слово
							syllables: syllables, // слоги
							accent: syllables && getAccentedSyllable(syllables), // номер ударного слога
							links: (i == 0) ? [] : [words[i - 1]] // номера слов-ассоциаций
						});
						databaseIdx[word] = database[database.length - 1];

					} else if (i > 0 && databaseIdx[word].links.indexOf(words[i - 1]) === -1) {
						// update links
						databaseIdx[word].links.push(words[i - 1]);
					}
				}
			})
		}
	});
}

/********************************** Rhyme checking **********************************/

//   Разберем правила рифмовки  на
// примере стиха И.Северянина - ну очень удачный пример.
//
//                             О вы - размеры старые,
//                             Захватанные многими,
//                             Банальные, дешевые,
//                             Готовые клише!
//
//                             Звучащие гитарою,
//                             И с рифмами убогими -
//                             Прекраснее, чем новые
//                             Простой моей душе.
//
//    1. "клише - душе" Ударные слоги должны быть созвучными  (или  одинаковыми).
// Собственно даже не весь слог, а только фонема, относящаяся к ударной гласной.
//
//    2. "мно-гими - у-бо-ги-ми" Если слог не последний,  то уже не столько важна
// ударная фонема,  сколько лишь сама гласная ("но" и  "бо"  -  малосозвучны),  а
// также всё, что следует за ней ("огими").
//
//    3. "ста-ры-е - гита-ро-ю" Количество слогов, стоящих после ударного, должно
// совпадать,  а сами они  должны  быть  если  не  одинаковы  (как  "огими"),  то
// созвучны.  Причем  критерии  созвучности  тут  сильно  занижены по сравнению с
// созвучностью,  необходимой ударному  слогу  -  ("рою"  -  "рые"  малосозвучны,
// рифмовать их отдельно нельзя).
//
//    Рассмотрим вопрос алгоритмизации "созвучности".  Тут  нам  поможет  понятие
// парных    гласных   и   согласных:   "Б-П,В-Ф,Г-К,Д-Т,Ж-Ш,Щ-Ш,З-С,М-Н,Ц-Ч"   и
// "Ы-И,Ю-У,Я-А,Э-Е,О-Ё".
//
//    Таким образом,  компьютер сможет определить,  что  слова  "стопа-пальба"  -
// рифмуются.  Возможно  даже рифмуются "стопа-себя" - если даже многие известные
// поэты допускают изредка нечеткие рифмы,  то почему надо  ограничивать  в  этом
// компьютер?  Это  можно  простить.  Простить нельзя другое - поначалу программа
// выдавала такие характерные для неопытных поэтов перлы,  как  "зима  -  пчела".
// После  чего я внес поправку (которую описал в пункте 2 - раньше я считал,  что
// важна только ударная гласная) -  если  ударным  является  последний  слог,  то
// необходима  созвучность не только ударной гласной,  но и одной буквы перед ней
// ("М" и "Л" несозвучны). Но если слог не последний - то заботиться о предыдущей
// букве  не надо:  "мНогими - уБогими" тоже неплохо звучит.  Главное - проверить
// созвучность последующих букв, и критерии парных гласных и согласных тут вполне
// применимы.  Честно говоря я только полез за образцами рифм,  почитал их, и мне
// не  очень  понравилось.  Например  попадались  такие:  "половым  -  неживым  -
// пингвин",  "всему  - одному - огню",  "исходила - объявила - филя".  Поэтому я
// только что подправил алгоритм,  и теперь в случае ударения на  последний  слог
// проверяются  не парные буквы,  а только их совпадение.  Таким образом,  отныне
// программа больше не рифмует "стопа-себя". Действительно, не хорошо это. Теперь
// в результате получаются только жесткие рифмы:
//
//    нефункциональный (нефункчиональний   -   так   преобразовывается  слово  во
// внутреннем формате по правилу парных гласных)  -  нахальный  -  театральный  -
// пасхальный - начальный - коммунальный - универсальный
//    дружить(дружить) - окружить - разложить - освежить - доложить - отложить  -
// положить - дожить - заложить
//
//    Надо отметить,  что, например, рифма "образование - причесывание" возникает
// из-за того,  что слово "причесывание" как  раз  попало  в  группу  неудач  при
// автоматическом  проставлении ударения.  Вспомним "глупого пингвина" и не будим
// судить строго.

function generalize(string) {
	var t = {'б': 'п','в': 'ф','г': 'к','д': 'т','ж': 'ш','щ': 'ш','з': 'с','м': 'н','ц': 'ч','ы': 'и','ю': 'у','я': 'а','э': 'е','о': 'ё', '-': ''};

	return string.replace(/\S/g, (w) => t[w] != null ? t[w] : w);
}

function checkRhyme(firstWord, secondWord, weakRhyme) {
	if (!firstWord.syllables || !secondWord.syllables) {
		// слова без гласных не рифмуются
		return false;
	}

	if (weakRhyme) {
		var sliceLen = Math.min(firstWord.syllables.length - firstWord.accent, secondWord.syllables.length - secondWord.accent);

		var a = firstWord.syllables.slice(-sliceLen);
		var b = secondWord.syllables.slice(-sliceLen);
	} else {
		var a = firstWord.syllables.slice(firstWord.accent);
		var b = secondWord.syllables.slice(secondWord.accent);
	}

	// 3. "ста-ры-е - гита-ро-ю" Количество слогов, стоящих после ударного, должно совпадать
	if (a.length != b.length) {
		return false;
	}

	// в случае ударения на  последний  слог проверяются  не парные буквы,  а только их совпадение
	if (a.length == 1) {
		return a[0].replace('-', '') == b[0].replace('-', '');
	}

	// 2. "мно-гими - у-бо-ги-ми" Если слог не последний,  то уже не столько важна
	// ударная фонема,  сколько лишь сама гласная
	if (a[0].match(new RegExp("[аоэиуыеёюя].*"))[0] != b[0].match(new RegExp("[аоэиуыеёюя].*"))[0]) {
		return false;
	}

	// слоги, стоящих после ударного, должны  быть  если  не  одинаковы  (как  "огими"),  то созвучны
	for (var i = 1; i < a.length; ++i) {
		if (generalize(a[i]) != generalize(b[i])) {
			return false;
		}
	}
	return true;
}

/********************************** Composition **********************************/

//    Для создания  стиха  необходимо:  Выбрать  последнее  слово и проверить его
// соответствие рифме и ритму,  по его ассоциациям найти  слово,  соответствующее
// ритму,  и так до тех пор, пока не будет заполнена строка, в случае затруднений
// возвращаться на шаг назад  -  менять  предыдущее  слово,  а  то  и  предыдущие
// рифмозадающие строки.
//    В виду большой сложности этого алгоритма,  изобразить его в виде блок-схемы
// представляется проблематичным, поэтому он будет описан в текстовом виде.
//
//    1) Установить указатель на последнее слово последней строки шаблона ритма
//    2) Очистить буфер рифм и флаговые поля базы,
//    3) установить "сферу поиска" = "заданная тематика"
//                    ; Работа со строками
//    3.1) Если  в  базе  рифм  нет  указанной  для  этого типа строки рифмы,  то
// установить флаг "свободная рифма"
//                    ;Работа со словами
//    4) Найти случайное слово из сферы поиска, если не найдено - к пункту 13
//    5) Если флаг "свободная рифма" сброшен, то проверить совпадение рифмы, если
// нет - к 4.
//    6) Проверить совпадение ритма (такт и максимальное количество слогов), если
// не совпадает - к 4.
//    7) Погрузить в стек Е найденное слово, сферу поиска, курсор строки
//    8) Ассоциации найденного слова занести в сферу поиска
//    9) Если строка не заполнена полностью - к 4
//                    ;Строка заполнена
//    9) Вынуть из стека Е все этапы,  запоминая слова в буфере готовых строк для
// этого номера строки
//    10) Установить флаг "использовано" для оконечного слова в базе.
//    11) Записать  оконечное  слово  в базу рифм,  заместо предыдущего (если оно
// было)
//    12) Установить указатель на предыдущую строку - если она существует,  то  к
// 3.1.
//    12.1) Проверить  с  конца  -  есть  ли  ненаписанные  строки,  если да - то
// установить на них указатель и перейти к 3.1 ИНАЧЕ - КОНЕЦ
//                     ; Если слово не найдено
//    13) Если слово не оконечное - к 16
//    13.0) если "сфера поиска" = вся база
//             13.1) Если и рифма была свободная, то "ТВОРЧЕСКИЙ КРИЗИС", конец
//             13.2) Если рифма не свободная,  то стереть из буфера готовых строк
// все строки с этой рифмой, если есть (мы их потом допишем), перейти к пункту 3
//    14) Если "сфера поиска" = "заданная тематика",  то "сфера  поиска"  =  "вся
// база", вернуться к 4
//    15) ("сфера поиска" = группе ассоциаций) - перейти к пункту 3.
//    16) Извлечь из стека Е предыдущий шаг,  слово отбросить,  а  все  остальное
// установить как было, в т.ч. прежнюю группу поиска. Вернуться к 4.
//
//    В стек Е погружается новый шаг:
//    - флаг F_LEVEL (флаг уровня поиска) 0 - вся база,1 - заданная тематика, 2 -
// набор ассоциаций
//    - флаг FREE_RHYME "свободная рифма" = 0, "заданная" = 1
//    - флаг FIRST_WORD Для оконечного слова = 1, для всех остальных в строке = 0
//    - СФЕРА ПОИСКА: байт количества + [N указателей на слова]
//    - УКАЗАТЕЛЬ на слово
//    - ПОИНТЕР текущего слога в сочиняемой строке

function getRandomWord(context) {
	if (context) {
		if (context.links.length) {
			return databaseIdx[context.links[context.links.length * Math.random() << 0]];
		} else {
			return null;
		}
	} else {
		return database[database.length * Math.random() << 0];
	}
}

// Программу можно попытаться заставить использовать определенные слова или слоги,
// указывая их в файле ритма. Поведение программы при этом следующее:
//
//    --+--+    - Строфа в 6 слогов. Длина слов - на усмотрение программы. Также
//                программа может вставить между словами безударный предлог.
//                Например: "ледянАя водА", "вдалекЕ в облакАх".
//
//    --+ --+   - Два слова, строго по три слога в каждом. Программа может вставить
//                между словами предлог по своему усмотрению.
//
//    --+ и -+  - Два слова, соединенные союзом "И". Например: "человЕк И закОн"
//
//    -но       - Слово из двух слогов, оканчивающееся на ударный слог "но".
//                Например: "винО", "кинО", но НЕ "днО".
//
//    +но       - Слово из двух слогов, оканчивающееся на безударный слог "но".
//                Например: "стрАнно".

function checkPattern(word, pattern) {
	//console.log(`CHECK PATTERN: "${word.asString}" vs "${pattern}"`);
	if (pattern.length == 0) {
		throw "Assertion failed: Zero length pattern";
	}

	var p = pattern.length - 1;

	const strictMatch = function(sequence) {
		var ss = sequence.length - 1;

		while (pattern[p] === sequence[ss] && p >= 0 && ss >= 0) {
			ss -= 1;
			p -= 1;
		}

		if (ss >= 0) {
			return false;
		} else {
			return true;
		}
	}

	if (word.syllables == null) {
		if (pattern[p] === ' ') {
			return 1;
		} else if (pattern[p] !== '+' && pattern[p] !== '-') {
			if (!strictMatch(word.asString)) {
				return -1;
			}
		} else {
			return 0;
		}
	} else {
		var s = word.syllables.length - 1;

		while (p >= 0 && s >= 0) {
			if (pattern[p] === '+') {
				// Ударный слог
				if (s != word.accent) {
					return -1;
				}
				p -= 1;
				s -= 1;
			} else if (pattern[p] === '-') {
				// Безударный слог
				if (s == word.accent) {
					return -1;
				}
				p -= 1;
				s -= 1;
			} else if (pattern[p] === ' ') {
				// Конец слова
				return -1;
			} else {
				// Конкретный слог
				if (strictMatch(word.syllables[s].replace(/^\-*|\-*$/g, ''))) {
					s -= 1;
				} else {
					return -1;
				}
			}
		}

		if (s >= 0) {
			return -1;
		}
	}

	while (pattern[p] == ' ') {
		p -= 1;
	}
	return pattern.length - (p + 1);
}

function wordToString(word) {
	if (!word.accentVerified) {
		console.log("WARN: Accent is not verified in:", word.asString);
	}

	var i = 0;
	return word.asString.replace(/[аоэиуыеёюя]/g, (v) => (word.accent === i++) ? v.toUpperCase() : v);
}

function compose(args) {
	const seed = arguments.length && { links: arguments };

	var lineId = poem.length - 1; // 1. Установить указатель на последнее слово последней строки шаблона ритма
	var rhymes = {}; // 2. Очистить буфер рифм и флаговые поля базы,
	var usedRhymes = {};

	var context = seed; // 3. установить "сферу поиска" = "заданная тематика"

	poem.forEach((line) => { delete line.composed; });

	while (lineId >= 0) {
		// Работа со строками
		const line = poem[lineId];

		// console.log("LINE ID:", lineId);
		// console.log("LINE:", line);
		// console.log("CONTEXT:", context && context.links);

		// 3.1 флаг "свободная рифма" = !rhymes[line.rhyme]
		var E = [];
		var triedWords = {};
		var lineCursor = line.pattern.length;

		while (lineCursor > 0) {
			// Работа со словами

			var word = getRandomWord(context); // 4. Найти случайное слово из сферы поиска
			var ending = !E.length;

			// Повторять поиск: 
			// 1. пока не найдется слово, которое не использовалось ранее
			// 2. если слово оконечное, то пока не найдется слово с хотя бы одной гласной, которое ранее не использовалось для рифмы
			// 3. пока не исчерпан набор слов в "сфере поиска"
			while (word && (triedWords[word.asString] || ending && (!word.syllables || !word.accentVerified || usedRhymes[word.asString]))) {
				var anotherWord = getRandomWord(context);
				if (anotherWord === word) {
					// Пошли по кругу
					word = null;
				} else {
					word = anotherWord;
				}
			}

			//console.log("RND WORD:", word && word.asString);

			if (!word) {
				// Если слово не найдено
				if (!ending) {
					// 13. Если слово не оконечное
					// 16. Извлечь из стека Е предыдущий шаг,  слово отбросить,  а  все  остальное
					// установить как было, в т.ч. прежнюю группу поиска. Вернуться к 4.
					var { word, context, lineCursor } = E.shift();

					// console.log("STEP BACK TO:", context);
				} else {
					// Если слово оконечное
					if (!context) {
						// 13.0. если "сфера поиска" = вся база
						if (!rhymes[line.rhyme]) {
							// 13.1. Если и рифма была свободная, то "ТВОРЧЕСКИЙ КРИЗИС", конец
							return null;
						} else {
							// 13.2. Если рифма не свободная,  то стереть из буфера готовых строк
							// все строки с этой рифмой, если есть (мы их потом допишем), перейти к пункту 3
							poem.forEach((i) => {
								if (i.rhyme == line.rhyme) {
									delete i.composed;
								}
							});
							delete rhymes[line.rhyme];
							context = seed;
						}
					} else if (context === seed) {
						// 14. Если "сфера поиска" = "заданная тематика",  то "сфера  поиска"  =  "вся база", вернуться к 4
						context = null;
						triedWords = {};
					} else {
						// 15. ("сфера поиска" = группе ассоциаций) - перейти к пункту 3.
						context = seed;
					}
				}
			} else {
				// Если слово найдено
				triedWords[word.asString] = true;

				// 6. Проверить совпадение ритма (такт и максимальное количество слогов), если не совпадает - к 4.
				const match = checkPattern(word, line.pattern.slice(0, lineCursor));
				if (match >= 0) {
					// 5. Если флаг "свободная рифма", то не проверять совпадение рифмы. Иначе если не совпадает - к 4.
					if (!ending || !rhymes[line.rhyme] || checkRhyme(word, rhymes[line.rhyme], line.weakRhyme)) {
						// 7. Погрузить в стек Е найденное слово, сферу поиска, курсор строки
						E.unshift({ word: word, context: context, lineCursor: lineCursor });

						// 8. Ассоциации найденного слова занести в сферу поиска
						context = word;

						lineCursor -= match;

						// console.log("ACCEPTED!, lineCursor = ", lineCursor);
					}
				}
			}
			// 9. Если строка не заполнена полностью - к 4
		}

		if (lineCursor != 0) {
			throw "Assertion failed: Composed line doesn't match the given pattern: " + line;
		}

		if (E.length == 0) {
			throw "Assertion failed: Empty string composed: " + line;
		}

		line.composed = E; // 9. Вынуть из стека Е все этапы, запоминая слова в буфере готовых строк для этого номера строки
		usedRhymes[E[E.length - 1].word.asString] = true; // 10. Установить флаг "использовано" для оконечного слова в базе.
		rhymes[line.rhyme] = E[E.length - 1].word; // 11. Записать оконечное слово в базу рифм,  заместо предыдущего (если оно было)

		// 12. Установить указатель на предыдущую строку - если она существует,  то  к 3.1.
		// 12.1 Проверить  с  конца  -  есть  ли  ненаписанные  строки,  если да - то установить на них указатель и перейти к 3.1 ИНАЧЕ - КОНЕЦ
		if ((lineId > 0) && !poem[lineId - 1].composed) {
			lineId -= 1;
		} else {
			lineId = findLastIndex(poem, (i) => !i.composed);
		}
	}

	return poem.map((line) => line.composed.map((composed) => wordToString(composed.word)).join(' ')).join('\n');
}