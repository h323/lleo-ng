                ideal
		p386
		model	flat,pascal
		codeseg

rndd = 777

;NN=15+1+1+20*2
dlin_BUF=1024
dlin_PUT=1024
dlin_word=100
dlin_slog=10
RAZMER=1024*300 ;1024*3
len_E_stack=32000 ;хватит наверно...
kolstrof	=	100
kolslof 	=	20

ATTR_FIELD = 01000000b
ATTR_RHYME = 10000000b

; -- startentry ------------------------------------------------
; Делать такую процедуру нужно для того, чтобы TASM не делал своего
; стартового кода. Это вредит.
proc		startentry
	jmp	@@skip		; Это...
	db	'WATCOM'        ; И это нужно для того, чтобы работало под DOS4GW
@@skip:
	cld
	mov	ax,ds
	mov	es,ax

        call slust
	cmp [REGIME],'C'
	je @@create
	cmp [REGIME],'U'
	je @@udara
        cmp [REGIME],'P'
	je @@prose
;═══════════════════════════════
        call stat
        call io
        db 13,10,13,10,0

        call automat
	jmp @@udara1
	;═══════════════════════════════
@@udara: call loadBASE
@@udara1:
        call stat
        call io
        db 13,10,13,10,0

	call set_UDAR_N
	call saveBASE
	jmp @@ret

        ;call test_RHYME
;═══════════════════════════════
@@prose:	call open_PUT
        call loadBASE
        cmp [word BASE],0
        je @@ret
 @@1:	call make_TEXT
	call key
	jmp @@1
;═══════════════════════════════
@@create:	call open_PUT
	call loadBASE
	cmp [word BASE],0
	je @@ret
	call CREATE
;═══════════════════════════════
@@ret:	jmp EXITT

endp	 startentry
;───────────────────────────────────────────────────
proc slust

;    mov ah,0
;    int 1ah
;    shl ecx,16  ; Освободили младшую половину ECX
;    mov cx,dx	 ; Запихнули туда стаpшую половину счетчика тиков
;    mov [randomcell],ecx    ; Положили куда нужно.
;Еще один метод:
;    mov eax,[dword 00046ch] ; Счетчик тиков лежит по этому адpесу.
;    mov [randomcell],ecx    ; Куда нужно. ;)

;PSP:80h. Опpеделить пpосто:
	mov ah,62h
	int 21h ; Текущий PSP

        mov [FSET_SLU],bx

;───────────────────────────────────────────────────────
	mov esi,0080h	     ; pointer at the first symbol of command
        call loadsl
        inc esi
	cmp al,3
	jna @@ErrComLine

@@get_symb:
	call loadsl
	je @@get_symb
	cmp al,0dh  ; 0DH - the end of command line
	je @@error

	mov [REGIME],al
        cmp al,'C'
        je @@create
	cmp al,'P'
	je @@prose
	cmp al,'B'
        je @@base
	cmp al,'U'
	je @@udara

@@error:
	call io
	db 13,10,'НЕВЕРНЫЙ ФОРМАТ СЛУЖЕБНОЙ СТРОКИ',0
	jmp EXITT

@@create:
	call io
	db 13,10,'НАПИСАНИЕ СТИХОТВОРЕНИЯ',13,10,' база: ',0
        mov edi,offset BASEname
	call get_namefile
	call io
	db 13,10,' ритм: ',0
	mov edi,offset NAME_SHABLON
        call get_namefile
	ret

@@prose:
	call io
	db 13,10,'НАПИСАНИЕ ПРОЗЫ',13,10,' база: ',0
        mov edi,offset BASEname
	call get_namefile
	ret

@@base:
	call io
	db 13,10,'ПОДГОТОВКА АССОЦИАТИВНОЙ БАЗЫ',13,10,' база: ',0
        mov edi,offset BASEname
	call get_namefile
	call io
	db 13,10,' файл: ',0
	mov edi,offset FileName
        call get_namefile
	ret

@@udara:
	call io
	db 13,10,'ПРОДОЛЖИТЬ РАССТАНОВКУ УДАРЕНИЙ',13,10,' база: ',0
        mov edi,offset BASEname
	call get_namefile
	ret

@@ErrComLine:
call io
db 13,10,'             \│/                             \│/'
db 13,10,'     ╒╗    ╔╗ ╒╦──═╗ ╓┬═══╗ ╔┐   ╗  \│/       ╔══──╖  ╓──═══'
db 13,10,' \│/ │╚═┐┌═╝║ │║     ║║     ││   ║            │    ║  ║       \│/'
db 13,10,'     ║┌╖└═║┐║ ║║     ││ \│/ └┴─══│     ═══    └──══╬──╬────╖'
db 13,10,'     │║╚╗╓┘│║ ││     │║          ║                 │  ║    │'
db 13,10,'     └╝ └╝ └┘ ╘╝ \│/ ╚╝     ╚═══─╝    \│/    ════──┘  └──══╝'
db 13,10
db 13,10,'          Московский Государственный Горный Университет'
db 13,10,'Факультет информатики и автоматизации. Кафедра вычислительных машин.'
db 13,10,'                         ДИПЛОМНЫЙ ПРОЕКТ'
db 13,10,'""Лингвистическое конструирование в системах искусственного интеллекта""'
db 13,10,'    LLEO_DIP.EXE - программа, сочиняющая стихи с заданным ритмом,'
db 13,10,'    используя ассоциативную базу, созданную при прочтении текста',0

call key

call io
db 13,10,'Для запуска используйте:'
db 13,10
db 13,10,'LLEO_DIP.EXE b basename.bsy some.txt'
db 13,10,' - создать(дополнить) ассоциативную базу basename.bsy, прочтя текст some.txt'
db 13,10,'   при расстановке ударений можно нажать ESC, и они будут проставлены сами'
db 13,10
db 13,10,'LLEO_DIP.EXE u basename.bsy'
db 13,10,' - продолжить ручную простановку ударений в базе basename.bsy'
db 13,10
db 13,10,'LLEO_DIP.EXE p basename.bsy'
db 13,10,' - сочинять предложения в прозе, используя basename.bsy'
db 13,10
db 13,10,'LLEO_DIP.EXE c basename.bsy stih.rtm'
db 13,10,' - сочинить стих, используя basename.bsy и файл ритма stih.rtm, например:'
db 13,10,'                      +--+--+--+  A'
db 13,10,'                      +--+--+     B'
db 13,10,'                      +--+--+--+  A'
db 13,10,'                      +--+--+     B'
db 13,10,' В этом примере куплеты будут состоять из 4 строк, ''-'' - безударный слог,'
db 13,10,' ''+'' - ударный слог, ''A'' - код рифмы (заглавная латинская буква).'
db 13,10
db 13,10,'! Все результаты записываются в файл RESULTAT.TXT',0

call key
call io
db 13,10,10,'        А сейчас, пользуясь случаем, хочу выразить благодарность:'
db 13,10,'Садретдинову Ринату, Зефирову Сергею и Лемехову Дмитрию за неоценимую помощь и',13,10,'постоянную консультацию;'
db 13,10,'Эльдарову Ильясу за то, что он великий программист и вообще хороший человек,',13,10,'несмотря на то, что любит такую попсу, как WIN95, а не профессиональные',13,10,'операционные системы как OS/2 WARP;'
db 13,10,'Дмитрию Антонову, Алексею Крылову и Сергею Лохову конечно же - что бы я без них делал?;'
db 13,10,'Матери, отцу, бабушке, сестре Маргарите, и всем кто за меня волновался;'
db 13,10,'Константину Петрову - за мудрые мысли о лингвистике;'
db 13,10,'Леониду Гриценко - за то, что не сломал мне компьютер;'
db 13,10,'Карине - за то, что она Карина;'
db 13,10,'Александру Недоспасову, Даниле Швецу, Шобанову Евгению, Кириллу и Катерине',13,10,'Сохатовым, Александру Аксельроду и Алексею Линецкому, чтоб он скорее к нам',13,10,'вернулся из своего мерзкого Нью-Йорка;'
db 13,10,'Ольге Лабузовой, Вадиму и Ольге Марковым, Мамаеву Сергею и сестре его Антонине,',13,10,'Вероничке Васильевой, Александре Тертель, Наташке Ярошенко, Ариадне с Костей и  Сороке за то, что они есть на свете;'
db 13,10,'Максу Иванову, Артему Полонскому и Борису Савину за материалы, использованные в',13,10,'пояснительной записке;'
db 13,10,'Антону Кротову, Денису Петрову и Jay Way - за мудрость философскую;',0
call key
call io
db 13,10,'Алексу Толоку и Леониду Николаеву - за СТЭМ матфака МГПИ;'
db 13,10,'Горбатову В.А. и Хомской Е.Д. за вклад в развитие науки;'
db 13,10,'Сергею Белоголовцеву, Василию Антонову, Андрею Бочарову,Александру Толоконниковуи Татьяне Лазаревой - за то, что они замечательные люди и не поперли меня с',13,10,'работы, пока я этот диплом писал. И конечно же Наталье Белоголовцевой;'
db 13,10,'Я.Андерсону за ""Jethro Tull"", Д.Моррисону за ""Doors"", И.С.Баху за второй',13,10,'бранденбургский концерт, и группе ""Барышня и хулиган"" за ""Водопад"", ибо без них я бы конечно ничего не написал;'
db 13,10,'Всем тем, кого я обязательно хотел включить в этот список, но в последний моментзабыл, а также всем, кого я в этот список включить не смог;'
db 13,10,'Всем участникам эхоконференции FIDO obec.pactet, а также ru.coffee.club,',13,10,'mo.sysoeff и ru.drugs;'
db 13,10,'Некоторым участникам ru.duel.rhyme, которые так или иначе убедили меня в том,',13,10,'что моя программа пишет просто замечательные стихи;'
db 13,10,'Моему боссу /313 Берковичу Сергею за то, что мой адрес все еще 2:5020/313.8,',13,10,'или, как говорят в Интернете, lleo@p8.f313.n5020.z2.gate.phantom.ru, куда',13,10,'всячески следует направлять отзывы о данной программе.'
db 13,10,'Всему прогрессивному человечеству;'
db 13,10,'                      Леонид Каганов, 6 июня 1996 6:30',0
jmp EXITT


endp slust
;─────────────────────────────────────────
proc get_namefile
	@@0:	call loadsl
		je @@0
		dec esi
	@@1:	call loadsl
		je @@2
		cmp al,0dh  ; 0DH - the end of command line
		je @@2
		stosb
		call i29
		jmp @@1
	@@2:	xor al,al
		stosb
		ret
endp get_namefile

proc loadsl
	push ds
	mov ax,[FSET_SLU]
	mov ds,ax
	lodsb
	pop ds

	cmp al,100o
	jc @@111
	and al,0ffh-32
 @@111: ;call i29
	cmp al,' '
        ret
endp loadsl

udataseg
FSET_SLU	dw	?
REGIME		db	?
BASEname	db	50	dup(?)	;'$$$$$$$$.bsy',0
NAME_SHABLON	db	50	dup(?)	;'shablon.mmm',0
FileName	db	50	dup(?)	;'0000.txt',0
codeseg

;───────────────────────────────────────────────────
proc GET_RND_FIELD_WORD

	;call io
	;db 13,10,'GET_RND_FIELD_WORD:',0

        cmp [F_LEVEL],0
	je @@all_base
@@zano: movzx cx,[N_FIELD]
        or cx,cx
	je @@nooot

	;call io
	;db ' [N_FIELD]=',0
	;movzx eax,cx
	;call pr_dec

	dec cx
	xor edx,edx
        call Get_RND
        dec [N_FIELD]
        movzx ecx,[N_FIELD]
        sub ecx,edx

        mov edi,edx
	shl edi,1
	add edi,offset FIELD
	mov dx,[word edi]
	or cx,cx
	je @@reto

	mov esi,edi
	lodsw
	rep movsw

 @@reto:
	cmp [nomer_LEVEL],0
	jne @@ret

	movzx edx,dx
	mov esi,[dword edx+edx*2+BASE]
	and esi,0FFFFFFh
	add esi,offset BASE+30000h
	test [byte esi],ATTR_RHYME
	jnz  @@zano		  ;использован как рифма

@@ret:	mov [current_N],dx
	clc
	ret
 @@nooot:
	stc
	ret

 @@all_base:
	mov cx,[word BASE]
	dec cx
	xor edx,edx
	call Get_RND
        inc dx
	mov [po_krugu],dx	;с чего начался поиск
 @@5:	mov esi,[dword edx+edx*2+BASE]
	and esi,0FFFFFFh
	add esi,offset BASE+30000h
	test [byte esi],ATTR_FIELD
	jnz  @@44		;рассматривался уже
	cmp [nomer_LEVEL],0
	jne @@608
	test [byte esi],ATTR_RHYME
        jnz  @@44               ;рассматривался уже
 @@608:
	or [byte esi],ATTR_FIELD  ;* и флаговые поля базы,
	jmp @@ret

 @@44:	inc dx
 @@55:	cmp dx,[word BASE]	;не вышли за границы базы?
	jna @@555
        mov dx,1
 @@555: cmp dx,[po_krugu]	;уже по второму кругу пошли?
	jne @@5
	;call io
	;db 13,10,' #ПЕРЕВАЛ# ',0
	jmp @@nooot
udataseg
F_LEVEL 	db	?
N_FIELD 	db	?
FIELD		dw 255	dup(?)
po_krugu	dw	?
codeseg

endp GET_RND_FIELD_WORD

;─────────────────────────────────────────────
proc make_RND_FIELD_TEMA   ;заносит слова из таблицы

	;call io
	;db 13,10,'make_RND_FIELD_TEMA:',0

        mov esi,offset TEMA
	lodsb
        mov [N_FIELD],al

	;call io
	;db 'N_FIELD=',0
	;movzx eax,al
	;call pr_dec

        movzx ecx,al
	mov edi,offset FIELD
	rep movsw
        mov [F_LEVEL],1
	ret

TEMA:	db 1	;9
	dw 1	;,2,3,4,5,6,7,8,9
	;dw 21,22,23,24,25,26,27,28
endp make_RND_FIELD_TEMA
;

proc make_SHABLON
	mov edx,offset NAME_SHABLON
	call LOADFILE  ;--> ecx-dlina, esi-adr
	push ecx
	mov edi,offset RITM
	mov ecx,RITM_len
	xor al,al
	rep stosb
	pop ecx
	mov [kol_STROK],0
@@000:	movzx eax,[kol_STROK]
		mov ebx,dlin_word
		mul ebx
		add eax,offset RITM
		mov edi,eax
        mov ebx,esi
 @@00:	call getchar
	jc @@1
        cmp al,13
	jne @@00
 @@2:	push esi
	dec esi
        dec esi
 @@22:	std
	lodsb
        cld
        cmp al,13
        je @@23
	cmp al,10
        je @@23
        cmp al,' '
	je @@23
	cmp al,9
	je @@23
        stosb
 @@23:	cmp esi,ebx
	jne @@22
	pop esi
	inc [kol_STROK]
	jmp @@000
  @@1:	ret

udataseg
kol_STROK	db	?
RITM	db	kolstrof*dlin_word	dup(?)
RITM_len	=	$-RITM
codeseg
endp make_SHABLON

proc getchar
	jmp @@0
  @@1:	dec ecx
	lodsb
        cmp al,' '
	je @@0
	cmp al,9
	je @@0
	clc
	ret
  @@0:	inc ecx
	loop @@1
	stc
	ret
endp getchar
;────────────────────────────────────────────────────────────────────────────
proc LOADFILE
		;edx - name
	mov	ax,3d00h
        int     21h
	jc	@@error
	mov	bx,ax
	;---load-----------
	mov edx,offset FILE_BUFFER
	mov ecx,FILE_BUFFER_len
	mov ah,3Fh	  ;function read
	int 21h
        jc @@error
	mov	ecx,eax
	mov ah,3eh  ;close
	int 21h
	mov esi,offset FILE_BUFFER
	ret
        ;--------------------
@@error: call io
	 db 13,10,'ошибка чтения файла',0
	 mov ah,3eh  ;close
	 int 21h
	 jmp EXITT
udataseg
FILE_BUFFER	db	30000	dup(?)
FILE_BUFFER_len =	$-FILE_BUFFER
codeseg
endp LOADFILE
;────────────────────────────────────────────────────────────────────────────


proc CREATE
        call make_SHABLON
        call clr_FLG_BASE       ;* и флаговые поля базы,
	mov [E_pointer],offset E_stack	;clr stack_E
        mov [nomer_LEVEL],0
;--------------------------------------------------------
@@000:	;call io
	;db 13,10,13,10,'┌───────пишем новое четверостишие──┐',0
	;movzx eax,[kol_STROK]
	;call pr_dec

	call clr_RHYMEBASE
	call clr_STROK

	;-----------------------
@@0:	call make_RND_FIELD_TEMA ;*3) установить ■сферу поиска■
        mov al,[kol_STROK]
	mov [current_STROK],al
	;-----------------------
@@2:	call done_li_STROK
	jne @@1

	call create_STRING
	jnc @@111
	call erase_STRING_with_RHYME ;стереть все строки с этой рифмой
	jmp @@0
@@111:
	;call io
	;db 13,10,'Строка * ',0
	;movzx eax,[current_STROK]
	;call pr_dec
	;call pr_STROKA
	;call key

@@1:	dec [current_STROK]
	cmp [current_STROK],0
	jne @@2
	;------------------------
        call io
	db 13,10,0
	call pr_STIH

	call keyli
	jmp @@000
endp CREATE
;───────────────────────────────────────────────────────────────
proc pr_STIH
	mov cl,[current_STROK]
	push cx
	mov [current_STROK],1
 @@0:	call io
	db 13,10,0
	call pr_STROKA
        inc [current_STROK]
	mov al,[kol_STROK]
	cmp [current_STROK],al
	jna @@0
	pop cx
	mov [current_STROK],cl
	ret
endp pr_STIH
;───────────────────────────────────────────────────────────────
proc erase_STRING_with_RHYME ;стереть все строки с этой рифмой
        movzx eax,[current_RHYME]       ;стереть такую рифму
	mov [word eax*2+RHYMEBASE-'A'*2],0

	movzx ecx,[kol_STROK]

@@0:	cmp cl,[current_STROK]
	je @@1
	xchg cl,[current_STROK]
	push ecx
        ;--------
	call set_ukaza
	lodsb
	cmp al,[current_RHYME]
	jne @@11

	;call io
	;db 13,10,'Clear STROK: ',0
	;call pr_STROKA

	movzx ecx,[current_STROK]
	dec ecx
	mov eax,kolslof*2
	mul ecx
	mov [byte eax+STROKI],0
	;--------
@@11:	pop ecx
	xchg cl,[current_STROK]
	loop @@0
@@1:	ret
endp erase_STRING_with_RHYME ;стереть все строки с этой рифмой
;───────────────────────────────────────────────────────────────
proc clr_STROK
	movzx ecx,[kol_STROK]
 @@0:   push ecx
        dec ecx
        mov eax,kolslof*2
        mul ecx
        mov [byte eax+STROKI],0
        pop ecx
        loop @@0
        ret
endp clr_STROK

proc done_li_STROK
	movzx ecx,[current_STROK]
	dec ecx
	mov eax,kolslof*2
	mul ecx
	cmp [byte eax+STROKI],0
	ret
endp done_li_STROK
;───────────────────────────────────────────────────────────────
proc create_STRING

@@punkt3:
        call set_ukaza

	mov esi,[ukaza]
	inc [ukaza]
	xor eax,eax
	lodsb
	mov [ukaza],esi
	mov [current_RHYME],al

	;call io
	;db 13,10,'рифма -- ',0
	;call i29

	call search_RHYME  ;*3.1) Если в базе рифм нет указанной для этого типа
			   ;строки рифмы, то установить флаг ■свободная рифма■

@@punkt4:			;;Работа со словами

        call GET_RND_FIELD_WORD ;*4) Найти случайное слово из сферы поиска,
	jc @@punkt13		;если не найдено ■ к пункту 13

;	 cmp [F_LEVEL],2
;	 jne @@1818
;	 call io
;	 db 13,10,0
;	 call pr_wOOrd
;	 mov esi,[ukaza]	 ;Установить указатель
;	 call io
;	 db '  ■',0
;  @@131:
;	 lodsb
;	 call i29
;	 or al,al
;	 jne @@131
;	 @@1818:

        call RITM_li         ;*6) Проверить совпадение ритма (такт и максимальное
        jc @@punkt4          ;количество слогов), если не совпадает ■ к 4.

	cmp [FREE_RHYME],0   ;5) Если флаг ■свободная рифма■,
	je @@punkt6	     ;то не проверять совпадение рифмы,
	cmp [nomer_LEVEL],0
	jne @@punkt6
		call RHYME_li	     ;*
		jc @@punkt4	     ;если не совпадает ■ к 4.
@@punkt6:

	call push_E_LEVEL ;*7) Погрузить в стек Е найденное слово,

	movzx eax,[kolslog]
	;inc eax
	add [ukaza],eax        ;сферу поиска,курсор строки

	call make_RND_FIELD_ASSO ;*8) Ассоциации найденного слова
				 ;занести в сферу поиска
	mov esi,[ukaza]
	cmp [byte esi],0 ;9)  Если строка не заполнена полностью ■ к 4
	jne @@punkt4

	;;Строка заполнена

	call pop_E_LEVEL_ALL   ;*9) Вынуть из стека Е все этапы, запоминая
                               ; слова в буфере готовых строк
	call change_RHYMEBASE  ;*11) Записать оконечное слово в базу рифм,
				;заместо предыдущего (если оно было)
	clc
	ret
;-------------------------------------------
;12) Установить указатель на предыдущую строку ■ если
;она существует, то к 3.1.
;12.1) Проверить с конца ■ есть ли ненаписанные строки,
;если да ■ то установить на них указатель и перейти к 3.1
;ИНАЧЕ ■ КОНЕЦ
;
;      &&&
;; Если слово не найдено
;
@@punkt13:
	;call io
	;db 13,10,'{{F_LEVEL}}=',0
	;movzx eax,[F_LEVEL]
	;call pr_dec

	cmp [nomer_LEVEL],0   ;13) Если слово не оконечное ■ к 16
	jne @@punkt16

	;call io
	;db 13,10,'ОШИБКА ПОИСКА РИФМЫ',0
	;call key
	
	cmp [F_LEVEL],0 ;13.0) если ■сфера поиска■ = вся база
	jne @@punkt14
	cmp [FREE_RHYME],0	;13.1) Если и рифма была свободная, то
	je @@error_twor 	;■ТВОРЧЕСКИЙ КРИЗИС■, конец
	stc
	ret	;вернуться с неудачей

@@punkt14:
	cmp [F_LEVEL],1 ;14) ;Если ■сфера поиска■ =  ■заданная тематика■, то
	je @@565656
	;call io
	;db 13,10,'поиск шел в АССОЦИАЦИЯХ, теперь будет в теме',0
        call make_RND_FIELD_TEMA ;*3) установить ■сферу поиска■
	jmp @@punkt4 ;15)	(■сфера поиска■ = группе ассоциаций) ■	перейти к пункту 3.
@@565656:
	;call io
	;db 13,10,'поиск шел в ТЕМЕ, теперь будет глобальный',0
	call F_LEVEL_0	    ;■сфера поиска■ = ■вся база■,
	jmp @@punkt4	     ;вернуться к 4

@@punkt16:
	;call io
	;db 13,10,'ОШИБКА ПОИСКА  С Л О В А - после /',0
        call pop_E_LEVEL ;*16) Извлечь из стека Е предыдущий шаг,
			 ;слово отбросить, а все остальное установить
			 ;как было, в т.ч. прежнюю группу поиска.
	;call pr_wOOrdd
	;call key
	jmp @@punkt4	;Вернуться к 4.

@@error_twor:	      ;■ТВОРЧЕСКИЙ КРИЗИС■, конец
	;call io
	;db 13,10,'Творческий кризис',0
	jmp EXITT

udataseg
nomer_LEVEL	db	?
FREE_RHYME	db	?	;флаг ■свободная рифма■,
ukaza		dd	?	;поинтер шаблона
codeseg
endp create_STRING
;;───────────────────────────────────────────────────
proc clr_RHYMEBASE
	mov edi,offset RHYMEBASE
        mov ecx,RHYMEBASE_len   ;** 2) Очистить буфер рифм
        xor ax,ax               ;
        rep stosw               ;
        ret
endp clr_RHYMEBASE


proc set_ukaza
	movzx eax,[current_STROK] ;1) Установить указатель
	dec eax 		  ;на последнее слово последней
	mov ebx,dlin_word	  ;строки шаблона ритма
	mul ebx
	add eax,offset RITM
	mov [ukaza],eax
	mov esi,eax
	ret
endp set_ukaza


proc clr_RHYME_BUF	;2) Очистить буфер рифм
	mov edi,offset RHYME_BUF
	mov ecx,RHYME_BUF_len
	xor al,al
	rep stosb
	ret
udataseg
RHYME_BUF db dlin_word*50 dup(?)
RHYME_BUF_len = $-RHYME_BUF
codeseg
endp clr_RHYME_BUF	;2) Очистить буфер рифм
;────────────────────
proc clr_FLG_BASE	;* и флаговые поля базы,
	movzx ecx,[word BASE]
  @@1:	mov ebx,[dword ecx+ecx*2+offset BASE]
	and ebx,0FFFFFFh
	and [byte ebx+BASE+30000h],not((ATTR_FIELD)or(ATTR_RHYME))
	loop @@1
	ret
endp clr_FLG_BASE       ;* и флаговые поля базы,
;────────────────────
proc clr_FLG_ATTR_FIELD_BASE	;* и флаговые поля базы,
	movzx ecx,[word BASE]
  @@1:	mov ebx,[dword ecx+ecx*2+offset BASE]
	and ebx,0FFFFFFh
	and [byte ebx+BASE+30000h],not(ATTR_FIELD)
	loop @@1
	ret
endp clr_FLG_ATTR_FIELD_BASE	;* и флаговые поля базы,
;────────────────────
proc RITM_li ;6) Проверить совпадение ритма (такт и максимальное
      ;  call io
      ;  db 13,10,'RITM:',0

	movzx esi,[current_N]
	mov esi,[dword esi*2+esi+BASE]
	and esi,0FFFFFFh
	add esi,offset BASE+30000h
	mov [current_ADR],esi
	add esi,2
        xor eax,eax
	lodsb	;количество слогов

	mov bl,al
	add bl,[kolslog_last1]	 ;предыдущий записанный слог
	;add bl,[kolslog_last2]   ;пред-предыдущий записанный слог
        mov [kolslog],al    ;количество слогов
	cmp bl,2
	jna @@no

	or al,al
	je @@yes

	mov edi,[ukaza] 	;Установить указатель
	cmp [byte edi+eax-1],0	  ;А влезает ли в строку?
	je @@no
	cmp al,1
	je @@yes
	;call io
	;db ' │в строку влезло│',0
	;call key

	xchg dl,al
        lodsb
        xchg dl,al
	sub al,dl
	inc al

	cmp [byte edi+eax-1],'+'
	jne @@no

 ;	 mov esi,[ukaza]	 ;Установить указатель
 ;	 call io
 ;	 db '■',0
 ; @@131:
 ;	 lodsb
 ;	 call i29
 ;	 or al,al
 ;	 jne @@131

       ; call io
       ; db '■ слогов:',0
       ; mov eax,ebp
       ; call pr_dec

@@yes:	clc
	ret
@@no:	stc
	ret

kolslog_last1 db 1
kolslog_last2 db 2

endp RITM_li ;6) Проверить совпадение ритма (такт и максимальное
;────────────────────
proc RHYME_li
	movzx esi,[current_N]
	mov esi,[dword esi*2+esi+BASE]
	and esi,0FFFFFFh
	add esi,offset BASE+30000h
	mov [current_ADR],esi
	add esi,2
	lodsb
        mov ah,al
	lodsb
	sub ah,al
	movzx ebp,ah
        cmp ah,[type_of_rhyme]
	jne @@1

	lodsb
	movzx eax,al
	add esi,eax

	mov edi,[end_rhyme1]
  @@2:
        dec esi
	dec edi
	mov ah,[esi]
	;--------------
	push esi
	call parglas_li
	pop esi
	;--------------
	cmp ah,[edi]
	jne @@1
	cmp [rhyme1_glas_ADR],edi
	jc @@2	 ;<
	jne @@88 ;<>

	or bp,bp
	je @@2

@@88:	clc
	ret
@@1:	stc
	ret
udataseg
kolslog db ?
codeseg

endp RHYME_li
;──────────────────────────────────────────────────────────
proc make_RND_FIELD_ASSO ;8) Ассоциации найденного слова
	movzx esi,[current_N]	;найти слово
	mov esi,[dword esi+esi*2+BASE]
	and esi,0FFFFFFh
	add esi,offset BASE+30000h+1
	lodsb			;количество ассоциаций
	or al,al
	jne @@333
        call make_RND_FIELD_TEMA ;*3) установить ■сферу поиска■
	;call F_LEVEL_0
	ret

@@333:	mov [N_FIELD],al
	movzx ecx,al
	lodsw
        xor eax,eax
	lodsb
	add esi,eax		;найти поле ассоциаций
	mov edi,offset FIELD
	rep movsw		;перенести их все
	mov [F_LEVEL],2
        ret
endp make_RND_FIELD_ASSO ;8) Ассоциации найденного слова
;───────────────────────────────────────────┐
proc F_LEVEL_0
        call clr_FLG_ATTR_FIELD_BASE    ;* и флаговые поля базы,
        mov [F_LEVEL],0
	ret
endp F_LEVEL_0
;───────────────────────────────────────────┐
proc change_RHYMEBASE  ;*11) Записать оконечное слово в базу рифм,
	movzx eax,[current_RHYME]
        movzx ecx,[current_N]
	mov [word eax*2+RHYMEBASE-'A'*2],cx
			  ;10) Установить флаг ■использовано■
        mov esi,[dword ecx+ecx*2+BASE]
	and esi,0FFFFFFh
	add esi,offset BASE+30000h
        or [byte esi],ATTR_RHYME  ;для оконечного слова в базе.
	ret
udataseg
current_STROK	db	?
current_RHYME	db	?
codeseg
endp change_RHYMEBASE  ;*11) Записать оконечное слово в базу рифм,


proc search_RHYME  ;eax - код рифмы, устанавливает все поля

        mov [FREE_RHYME],0
        sub al,'A'
	mov ax,[word eax*2+RHYMEBASE]
	or ax,ax
	je @@1
        mov [current_N],ax

	movzx esi,ax
	mov esi,[dword esi*2+esi+BASE]
	and esi,0FFFFFFh
	add esi,offset BASE+30000h
	mov [current_ADR],esi
	call copy_WORD_rhyme1
	inc [FREE_RHYME]
 @@1:	ret

udataseg
RHYMEBASE	dw	25	dup(?)
RHYMEBASE_len	=	$-RHYMEBASE
codeseg
endp search_RHYME  ;3.1) Если в базе рифм нет указанной для этого типа
;───────────────────────────────────────────┘

;;───────────────────────────────────────────────────
proc pop_E_LEVEL_ALL   ;*9) Вынуть из стека Е все этапы, запоминая
	movzx edi,[current_STROK]
	dec edi
	mov eax,kolslof*2
	mul edi
	mov edi,eax
	add edi,offset STROKI

        mov al,[nomer_LEVEL]

	;call io
	;db 13,10,'--- nomer?_LEVEL= ',0
	;movzx eax,al
	;call pr_dec

        stosb                   ;записать количество

@@0:    cmp [nomer_LEVEL],0
	je @@1
	  push edi
          call pop_E_LEVEL
	  pop edi
	mov ax,[current_N]
	stosw
	jmp @@0

  @@1:	ret

udataseg
STROKI		db	kolstrof*kolslof*2	dup(?)
codeseg

endp pop_E_LEVEL_ALL   ;*9) Вынуть из стека Е все этапы, запоминая
;──────────────────────────────────────
proc push_E_LEVEL		;В стек Е погружается шаг:

        mov al,[kolslog_last1]
        call push_E
        mov al,[kolslog_last2]
        call push_E
	  mov al,[kolslog_last1]
	  mov [kolslog_last2],al
	  mov al,[kolslog]
	  mov [kolslog_last1],al

        mov al,[FREE_RHYME]     ;■ флаг FREE_RHYME
        call push_E

        mov al,[F_LEVEL]        ;■ флаг F_LEVEL (флаг уровня поиска)
        call push_E

	or al,al
	jne @@1
	mov [N_FIELD],0
   @@1:
	movzx ecx,[N_FIELD]
	or ecx,ecx
	je @@2
        mov esi,offset FIELD

   @@3: lodsw		;[N указателей на слова]
        call push_EE
	loop @@3

   @@2: mov al,[N_FIELD] ;байт количества
        call push_E

	mov eax,[ukaza]      ;■ ПОИНТЕР текущего слога в сочиняемой строке
	call push_EE
	call bswap_eax ;я же не виноват, блин, что у 386 процессора нет bswap!
	call push_EE

	mov ax,[current_N]
	call push_EE

        inc [nomer_LEVEL]

        ret

endp push_E_LEVEL		;В стек Е погружается шаг:
;──────────────────────────────────────
;──────────────────────────────────────
proc pop_E_LEVEL	       ;Из стека вынимается шаг:

	call pop_EE
	mov [current_N],ax

	call pop_EE   ;■ ПОИНТЕР текущего слога в сочиняемой строке
        call bswap_eax ;я же не виноват, блин, что у 386 процессора нет bswap!
	call pop_EE
	mov [ukaza],eax

	call pop_E
	mov [N_FIELD],al ;байт количества
	or al,al
	je @@1

	movzx ecx,al
	mov edi,offset FIELD
   @@3: call pop_EE ;[N указателей на слова]
	stosw
        loop @@3

   @@1:
	call pop_E
	mov [F_LEVEL],al	;■ флаг F_LEVEL (флаг уровня поиска)
	call pop_E
	mov [FREE_RHYME],al	;■ флаг FREE_RHYME

	call pop_E
	mov [kolslog_last2],al
	call pop_E
	mov [kolslog_last1],al

	dec [nomer_LEVEL]
	ret

endp pop_E_LEVEL	       ;Из стека вынимается шаг
;──────────────────────────────────────
proc bswap_eax ;я же не виноват, блин, что у 386 процессора нет bswap!
	mov [bswap_mes],eax ;приходится извращаться...
	xchg al,ah
	shl eax,16
	mov ax,[word bswap_mes+2]
        xchg al,ah
	ret
udataseg
bswap_mes dd ?
codeseg
endp bswap_eax ;я же не виноват, блин, что у 386 процессора нет bswap!
;──────────────────────────────────────
proc push_EE
        call push_E
        mov al,ah
        call push_E
	ret
endp push_EE
proc pop_EE
	call pop_E
	mov ah,al
	call pop_E
	ret
endp pop_EE


proc push_E
	push ebx
	mov ebx,[E_pointer]
	cmp ebx,offset E_stack+len_E_stack
	jnc @@error
	mov [byte ebx],al
	inc [E_pointer]
	pop ebx
	ret
@@error: call io
	db 13,10,'Ошибка PUSH_E',0
	jmp EXITT
endp push_E

proc pop_E
	push ebx
	mov ebx,[E_pointer]
	cmp ebx,offset E_stack
	je @@error
	dec [E_pointer]
	dec ebx
	mov al,[byte ebx]
	pop ebx
        ret
@@error: call io
	db 13,10,'Ошибка POP_E',0
	jmp EXITT
endp pop_E

udataseg
E_pointer	dd	?
E_stack 	db	len_E_stack	dup(?)
codeseg
;───────────────────────────────────────────────────
;proc test_RHYME
; @@0:
;	 mov cx,[word BASE]
;	 dec cx
;	 call Get_RND
;	 inc dx
;	 mov [current_N],dx
;
;	 movzx edx,dx
;	 mov esi,[dword edx*2+edx+BASE]
;	 and esi,0FFFFFFh
;	 add esi,offset BASE+30000h
;	 mov [current_ADR],esi
;
;	 call io
;	 db 13,10,13,10,0
;
;	 call copy_WORD_word
;	 call pr_m_word
;
;	 call copy_WORD_rhyme1
;	 call pr_rhyme1
;
;	 cmp [rhyme_slog],0
;	 je @@0
;
;	 call key
;	 ;─────────────────────────────
;	 movzx ecx,[word BASE]
;	 ;sub ecx,1
;	 ;je @@0
;	 mov ax,[current_N]
;	 mov [new_current_N],ax
;   @@e0:
;	 push ecx
;	 cmp cx,[new_current_N]
;	 je @@1
;		 mov [current_N],cx
;		 call RHYME_li
;		 jc @@1
;	 call io
;	 db 13,10,0
;	 mov esi,[current_ADR]
;	 add esi,4
;	 lodsb
;	 movzx ecx,al
;  @@7:  lodsb
;	 call i29
;	 loop @@7
;
;   @@1: pop ecx
;	 loop @@e0
;	 ;─────────────────────────────
;	 jmp @@0
;	 ret
;
;udataseg
;new_current_N dw ?
;codeseg
;
;endp test_RHYME
;───────────────────────────────────────────────────
proc set_UDAR
        movzx edx,[current_N]
        mov esi,[dword edx+edx*2+BASE]
        and esi,0FFFFFFh
        add esi,offset BASE+30000h
        mov [current_ADR],esi

        call slog_word
	mov edi,[current_ADR]
	mov al,[byte edi]	;а проставлено ли там уже ударение?
	test al,1
	jnz @@ret2

	add edi,2
	mov al,[kol_slog]
	stosb			;установить количество слогов
	or al,al
	je @@9
	cmp al,1
	je @@9

	call io
	db 13,10,'═════════════════',13,10,0
        call pr_work_word
        call prognose_UDAR
        call pr_work_word
	call io
	db 13,10,0
	call input_UDAR
	call remember_SLOG_N
	mov al,[udar_slog]
	mov edi,[current_ADR]
	add edi,3
	stosb
	jmp @@ret

@@9:	stosb			;установить ударный слог
	call pr_work_word
	call io
	db 13,10,0
	call otto_UDAR

@@ret:
	mov edi,[current_ADR]
        mov al,[byte edi]
	or al,1
	mov [byte edi],al
	inc [wsego_slow_udar]
	inc [prawilno_slow_udar]
@@ret2: ret
endp set_UDAR
;──────────────────────────────────────────────────
proc set_automat_UDAR

        movzx edx,[current_N]
        mov esi,[dword edx+edx*2+BASE]
        and esi,0FFFFFFh
        add esi,offset BASE+30000h
        mov [current_ADR],esi

        call slog_word

		;call pr_work_word

        mov edi,[current_ADR]
	mov al,[byte edi]	;а проставлено ли там уже ударение?
	test al,1
	jnz @@ret2

	add edi,2
	mov al,[kol_slog]
	stosb			;установить количество слогов
	or al,al
	je @@9
	cmp al,1
	je @@9

        call prognose_UDAR
	mov al,[udar_slog]
	mov edi,[current_ADR]
	add edi,3
	stosb
	jmp @@ret

@@9:	stosb			;установить ударный слог

@@ret:
@@ret2: ret

endp set_automat_UDAR
;═══════════════════════════════════════════════════
proc remember_SLOG_N
	call io
	db 13,10,0

	mov esi,offset work_word
	xor bx,bx	;номер слога
   @@0: mov edi,offset new_SLOG
  @@00: lodsb
	;call i29
	or al,al
	je @@1
	stosb
	cmp edi,offset new_SLOG+1 ;первый '-' можно
	je @@00
	cmp al,'-'
	jne @@00
	dec esi
   @@1: inc bx		;номер слога
	mov ecx,edi
	sub ecx,offset new_SLOG
	mov [len_slog],cl
	push esi bx
	 call remember_SLOG
	pop bx esi
	cmp [byte esi-1],0
	jne @@0
	ret
endp remember_SLOG_N
   ;───────────
proc remember_SLOG
		;call pr_SLOG

		push bx
		call find_SLOG
		pop bx
		jnc @@2 	 ;если найден
		call create_SLOG
           @@2:
		cmp bl,[udar_slog]
		je @@4
		inc [word ebp+2]	; ───
		jmp @@3
		;------
	   @@4: inc [word ebp]		; ─┼─
	   @@3: ret
endp remember_SLOG
;──────────────────
proc pr_SLOG
	push esi ecx
	mov esi,offset new_SLOG
	movzx ecx,[len_slog]
@@0:	lodsb
	call i29
	loop @@0
	pop ecx esi
	ret
endp pr_SLOG
;───────────────────────────────────────────────────
proc create_SLOG
	mov edi,[adress_END_SLOG]
	mov al,[len_slog]	;длина слога
	movzx ecx,al
	add al,4		;с учетом поля статистики
	stosb			;длина слога
	mov esi,offset new_SLOG
	rep movsb
	mov ebp,edi		;записать нулевую статистику
		mov ax,1
		stosw
                stosw
	mov [adress_END_SLOG],edi
	inc [N_UDAR]
	mov eax,[N_UDAR]
	mov [current_SLOG],eax
        ret
endp create_SLOG
;───────────────────────────────────────────────────
        ; = = = = =
proc locate_END_SLOG
        mov ebx,[N_UDAR]
	call locate_SLOG
	mov [adress_END_SLOG],esi
        ret
endp locate_END_SLOG
        ; - - - - -
proc locate_SLOG       ;eax,ebx,ecx,esi
	mov esi,[BASE_SLOG]
	or ebx,ebx
        je @@3
	dec ebx
        xor eax,eax
	xor ecx,ecx
        jmp @@1
 @@0:   lodsb
        add esi,eax
	inc ecx
 @@1:	cmp ebx,ecx
        jne @@0
 @@3:	mov [current_ADR_SLOG],esi
        ret
endp locate_SLOG
;───────────────────────────────────────────────────
proc find_SLOG
	mov esi,[BASE_SLOG]
	mov ebx,1
@@0:
	cmp [N_UDAR],ebx
	jc @@2

	mov [current_ADR_SLOG],esi
	lodsb
	movzx ebp,al
	add ebp,esi  ;ebp - адрес след. элемента
	sub al,4
	movzx ecx,al ;количество букв элемента
	cmp cl,[len_slog]
	jne @@1

	mov edi,offset new_SLOG
        repe cmpsb
	jne @@1
	mov [current_SLOG],ebx	;вот он, найденый слог!
	sub ebp,4	;а вот его поле статистики
        clc
	ret

@@1:	inc ebx
	mov esi,ebp
        jmp @@0
@@2:	mov ebp,offset NULL_STAT
	stc
	ret

udataseg
current_SLOG dd ?
adress_END_SLOG dd ?
current_ADR_SLOG dd ?
codeseg
NULL_STAT dw 1,1
endp find_SLOG
;────────────────────────────────────────────────────────────────────────────
proc saveSLOG
        ;----create----------
        mov     ah,3ch
	mov	edx,offset SLOGname
	xor	cx,cx
        int     21h
        jc      @@error
	mov	bx,ax
        ;---write------------
	mov ecx,[adress_END_SLOG]
        mov [byte ecx],0
	inc ecx
	mov edx,[BASE_SLOG]
	sub ecx,edx
	mov ah,40h	  ;function save
	int 21h
        jc @@error
        ;----close-----------
        mov     ah,3eh
        int     21h
        jnc @@BYTERET
        ;--------------------
@@error: call io
	 db 13,10,'ошибка записи СЛОГОВ',0
	 jmp EXITT
@@BYTERET: ret
endp saveSLOG
;────────────────────────────────────────────────────────────────────────────
proc loadSLOG
	movzx esi,[word BASE]	;вычислить место для базы
	mov esi,[dword esi+esi*2+BASE]
	and esi,0FFFFFFh
	add esi,offset BASE+30000h
	mov [BASE_SLOG],esi
	;----open----------
	mov	ax,3d00h
	mov	edx,offset SLOGname
        int     21h
	jc	@@no_base
	mov	bx,ax
	;---load-----------
	mov esi,[BASE_SLOG]

	mov edx,esi
	mov ecx,6*1024*1024

	mov ah,3Fh	  ;function read
	int 21h
        jc @@error

	mov ebp,eax
	add ebp,[BASE_SLOG]

	call io
	db 13,10,'Прочитано байт базы слогов: ',0
	call pr_dec

        mov     ah,3eh  ;close
        int     21h

	;------ ebp - last adr
	mov esi,[BASE_SLOG]
        xor eax,eax
	xor ecx,ecx ;количество элементов
 @@0:
	lodsb
	or al,al
	je @@8
        add esi,eax

        inc ecx

	cmp esi,ebp
	jc @@0
	jmp @@er_date

 @@8:	cmp esi,ebp
	jne @@er_date
	mov [N_UDAR],ecx
	dec esi
	mov [adress_END_SLOG],esi
@@BYTERET:
	call locate_END_SLOG
	ret
        ;--------------------
@@er_date: call io
	db 13,10,'Неверный формат базы слогов!',0
	jmp EXITT
        ;--------------------
@@no_base: call io
	   db 13,10,'База слогов не найдена - создана.',0
	   mov [N_UDAR],0
	   jmp @@BYTERET

@@error: call io
         db 13,10,'ошибка записи БАЗЫ СЛОГОВ',0
	 mov	 ah,3eh  ;close
	 int	 21h
	 jmp EXITT
endp loadSLOG
;────────────────────────────────────────────────────────────────────────────
		udataseg
len_slog	db	?
new_SLOG	db	dlin_slog dup(?)
BASE_SLOG	dd	?
                codeseg

N_UDAR          dd      0FFFFh
SLOGname        db      '$$$$slog.bsy',0
;────────────────────────────────────────────────────────────────────────────

;═══════════════════════════════════════════════════

;═══════════════════════════════════════════════════
proc prognose_UDAR
	mov esi,offset work_word
	xor bx,bx	;номер слога
   @@0: mov edi,offset new_SLOG

  @@00: lodsb
	or al,al
	je @@1
	stosb
	cmp edi,offset new_SLOG+1 ;первый '-' можно
	je @@00
	cmp al,'-'
	jne @@00
	dec esi
   @@1:
	inc bx		;номер слога
	mov ecx,edi
	sub ecx,offset new_SLOG
	mov [len_slog],cl
	push bx
	;─────////////////////──────────────

        push esi
	call find_SLOG
	pop esi

	mov ax,[word ebp]	;─┼─
	mov bx,[word ebp+2]	;───
	mov [stat_znak],0
	cmp bx,ax
	jne @@ne_ravnio
	xor ax,ax
	jmp @@oi1
@@ne_ravnio:
	jc @@op1

	xchg ax,bx
	not [stat_znak]

 @@op1:
	mov cx,[word ebp]
	add cx,[word ebp+2]
	mul cx
        xor dx,dx
	div bx
	cmp [stat_znak],0
	je @@oi1
	neg ax
 @@oi1:
	cmp [nadoli_print],0
	jne @@print_ne_nado

	push ax
		call io
		db 13,10,'│ё ',0
		mov al,[stat_znak]
		and al,1
		add al,' '
		call i29
		call io
		db ' │ +',0
		movzx eax,[word ebp]
		call pr_dec
		call io
		db ' │ -',0
		movzx eax,[word ebp+2]
		call pr_dec
		call io
		db ' │',0
	pop ax
	call io
	db ' >> ',0
        call pr_dec_z
@@print_ne_nado:
        ;─────////////////////──────────────
	pop bx
	mov [ebx*2+prognose_STRING-2],ax
        ;───────────────────
	cmp [byte esi-1],0
	jne @@0
;────────────────────────────────────────────────┐
	mov esi,offset prognose_STRING
	movzx ecx,[kol_slog]
        mov [udar_slog],1
	mov [best_prognose],8000h
	xor bl,bl
@@1010: inc bl
	lodsw
	cmp ax,[best_prognose]
	jl @@1011 ;<
	mov [best_prognose],ax
	mov [udar_slog],bl
@@1011:
        loop @@1010

	cmp [nadoli_print],0
	jne @@print_ne_nado2
        call io
        db 13,10,0
@@print_ne_nado2:
;────────────────────────────────────────────────┘
        ret

udataseg
nadoli_print db ?
udar_slog db ?
stat_znak db ?
best_prognose dw ?
prognose_STRING dw 30 dup(?)
codeseg

wsego_slow_udar dw 0
prawilno_slow_udar dw 0

endp prognose_UDAR
;═══════════════════════════════════════════════════

proc input_UDAR
	call otto_UDAR
	 mov bl,[udar_slog]
  @@0:  xor ax,ax
	int 16h
	cmp ah,1
	je @@exit
        cmp ah,77
	je @@1
	cmp ah,75
	je @@2
	cmp ah,28
	jne @@0
	 cmp bl,[udar_slog]
	 je @@ret
	 dec [prawilno_slow_udar]
 @@ret:  ret
  @@2:	mov al,[udar_slog]
	cmp al,1
	je @@0
	dec [udar_slog]
	jmp @@3
  @@1:  mov al,[udar_slog]
        cmp al,[kol_slog]
	je @@0
	inc [udar_slog]
  @@3:	call io
	db 8,' ',13,0
	call otto_UDAR
	jmp @@0


@@exit:
        call io
	db 13,10,'Всего слов обработано нынче:',0
        movzx eax,[wsego_slow_udar]
	call pr_dec
        call io
	db 13,10,'Из них правильно:',0
	movzx eax,[prawilno_slow_udar]
	call pr_dec

        call saveSLOG

        call set_automat_UDAR_N

        call saveBASE

	jmp EXITT
endp input_UDAR

proc otto_UDAR
	movzx ecx,[udar_slog]
	mov esi,offset work_word
   @@1: lodsb
	or al,al
	je @@9
                call io
                db ' ',0
	    push ecx
	    call glasn_li
	    pop ecx
	jne @@1
	loop @@1
	call io
	db 8,'│',0
@@9:	ret
endp otto_UDAR
;───────────────────────────────────────────────────
proc set_UDAR_N
	mov [nadoli_print],0
	mov [wsego_slow_udar],0
	mov [prawilno_slow_udar],0

	call loadSLOG

	mov [current_N],0

@@0:	mov ax,[word BASE]
        cmp [current_N],ax
	je @@1
	inc [current_N]

	call set_UDAR

	jmp @@0
  @@1:
	call saveSLOG
	ret

endp set_UDAR_N
;───────────────────────────────────────────────────
proc set_automat_UDAR_N
	mov [nadoli_print],1
	call io
	db 13,10,'осталось обработать слов:',13,10,0
	mov bx,[current_N]
	mov ax,[word BASE]
	sub ax,bx
	mov [done_word],ax

@@00:	call io
	db 13,0
	movzx eax,[done_word]
	call pr_dec
	call io
	db '  ',0
@@0:
	call set_automat_UDAR

	mov ax,[word BASE]
        cmp [current_N],ax
	je @@1
	inc [current_N]

	dec [done_word]
	mov ax,[done_word]
	and ax,0FFh
	je @@00

	jmp @@0
  @@1:
	ret

udataseg
done_word dw ?
codeseg

endp set_automat_UDAR_N
;───────────────────────────────────────────────────
;LCRNG: X[i]=(X[i-1]*A+B) mod C;

;C - 2**что-то там, а вообще, лучше всего пpостое;
;B - B mod 4 должно быть = 1, подойдут 1,5,9,13,17,... Обычно беpется 1;
;A - нечетное, достаточно большое (3*С/4<A<7*C/8).

; Hиже - пpоцедуpа вычисления следующего случайного числа по модулю 65536.
;        Результат - в AX.

proc Get_RND  ;Выдает pавномеpно pаспpеделенное число в диапазоне 0..CX-1:
    push ax cx
    mov ax,8401h  ; pезультат - в DX
    mul [curr_rnd]
    inc ax
    mov [curr_rnd],ax
    inc cx
    mul cx
    pop cx ax
    ret
endp Get_RND

;udataseg
curr_rnd dw rndd ;?
;codeseg

;proc Init_RND	; А вот как инициализить RND
;    push ax cx dx
;    mov ah,0
;    int 1ah ; DX-младшее слово тиков таймеpа. Оно кpуче изменяется, быстpее.
;    mov [curr_rnd],dx
;    pop dx cx ax
;    ret
;endp Init_RND
;───────────────────────────────────────────────────
proc make_TEXT
	;большая буква
        call io
        db 13,10,0

	mov cx,[word BASE]
	dec cx
        call Get_RND
	inc dx
	mov [current_N],dx   ;начальное слово
	xor bp,bp	   ;счетчик нашаренных слов

@@0:	;call pr_WORD
	push [current_N]
	inc bp
	cmp bp,30
	je @@net_slov

	movzx esi,[current_N]
	mov esi,[dword esi+esi*2+BASE]
	and esi,0FFFFFFh
        add esi,offset BASE+30000h+1
	lodsb
	or al,al
	je @@net_slov
	movzx cx,al
	inc esi
        inc esi
	xor eax,eax
	lodsb
	add esi,eax

	sub cl,1
	je @@odno

        call Get_RND

        movzx eax,dx
	shl eax,1
        add esi,eax

@@odno: lodsw
	mov [current_N],ax
        jmp @@0

@@net_slov:
	movzx ecx,bp

  @@11: pop si
	movzx esi,si
	mov esi,[dword esi*2+esi+BASE]
        and esi,0FFFFFFh
	add esi,offset BASE+30000h+4
	lodsb
	   push ecx
	   movzx ecx,al
	   cmp ecx,100
	   jnc @@8
    @@111: lodsb
	   call i29
	   loop @@111
    @@8:   pop ecx
        call io
	db ' ',0
	loop @@11
	call io
	db '.',13,10,0
	ret
endp make_TEXT
;───────────────────────────────────────────────────
proc pr_STROKA

	;call io
	;db 13,10,'┌─────────────────────────────────',13,10,'│',0

	movzx ecx,[current_STROK]
	or ecx,ecx
	je @@x

	dec ecx
	mov eax,kolslof*2
	mul ecx
	mov esi,eax
	add esi,offset STROKI
	lodsb
	or al,al
	je @@x
	movzx ecx,al

  @@11: lodsw
	mov [current_N],ax
	 call pr_wOOrd
        call io
	db ' ',0
	loop @@11
   @@x:
	;call io
	;db 13,10,'└─────────────────────────────────',0
	ret

TAB_BOL_GLAS db 'аА','оО','еЕ','иИ','уУ','яЯ','ыЫ','эЭ','юЮ',0
endp pr_STROKA
;───────────────────────────────────────────────────
proc pr_wOOrd
        push esi eax
        ;────────────────
	movzx esi,[current_N]
        mov esi,[dword esi*2+esi+BASE]
        and esi,0FFFFFFh
        add esi,offset BASE+30000h+3

        lodsb
        mov bl,al

        lodsb
           push ecx
           movzx ecx,al
           cmp ecx,100
           jnc @@8
    @@111: lodsb
           push ecx ax edi
	   call glasn_li
           pop edi ax ecx
           jne @@7
           dec bl
           or bl,bl
           jne @@7
        ;---------------
        push esi
        mov ah,al
        mov esi,offset TAB_BOL_GLAS
  @@2:  lodsb
        or al,al
        je @@1
        inc esi
        cmp ah,al
        jne @@2
        mov ah,[esi-1]
  @@1:  mov al,ah
        pop esi
        ;---------------
    @@7:   call i29
           loop @@111
    @@8:   pop ecx
        ;────────────────
        pop eax esi
        ret
endp pr_wOOrd

;proc pr_wOOrdd
;	 push esi eax ecx
;	 ;────────────────
;	 movzx esi,[current_N]
;	 mov esi,[dword esi*2+esi+BASE]
;	 and esi,0FFFFFFh
;	 add esi,offset BASE+30000h+1
;
;	 lodsb
;	 movzx ecx,al
;	 lodsb
;
;	 lodsb
;	 mov bl,al
;
;	 lodsb
;	    push ecx
;	    movzx ecx,al
;	    cmp ecx,100
;	    jnc @@8
;    @@111: lodsb
;	    push ecx ax edi
;	    call glasn_li
;	    pop edi ax ecx
;	    jne @@7
;	    dec bl
;	    or bl,bl
;	    jne @@7
;	 ;---------------
;	 push esi
;	 mov ah,al
;	 mov esi,offset TAB_BOL_GLAS
;  @@2:  lodsb
;	 or al,al
;	 je @@1
;	 inc esi
;	 cmp ah,al
;	 jne @@2
;	 mov ah,[esi-1]
;  @@1:  mov al,ah
;	 pop esi
;	 ;---------------
;    @@7:   call i29
;	    loop @@111
;    @@8:   pop ecx
;	 ;────────────────
;
;	 push [current_N]
;	 call io
;	 db ' #',0
;
;	 or ecx,ecx
;	 je @@101
;@@313:
;	 call io
;	 db ',',0
;	 movzx eax,[current_N]
;	 call pr_dec
;	 call io
;	 db '│',0
;
;	 lodsw
;	 mov [current_N],ax
;	 call pr_wOOrd
;	 loop @@313
;
; @@101: pop [current_N]
;
;	 pop ecx eax esi
;	 ret
;endp pr_wOOrdd
;───────────────────────────────────────────────────
proc stat
        mov [kol_ASSO],0
	movzx eax,[word BASE]
        call io
        db 13,10,'База интеллекта содержит ассоциативных понятий: ',0
        call pr_dec
        ;------
	xor ebx,ebx
	cmp [word BASE],bx
        je @@9
 @@0:	;------
	inc bx
	  mov esi,ebx
	  shl esi,1
	  add esi,ebx
	  mov esi,[dword esi+BASE]
	  and esi,0ffffffh
	  add esi,offset BASE+30000h
	movzx eax,[byte esi+1]
	add [kol_ASSO],eax
	cmp bx,[word BASE]
	jne @@0
        ;------
	mov eax,[kol_ASSO]
	movzx ebx,[word BASE]
        xor edx,edx
        div ebx
        call io
        db 13,10,'На каждое слово в среднем ассоциаций ',0
        call pr_dec
@@9:	ret
udataseg
kol_ASSO dd ?
codeseg
endp stat
;───────────────────────────────────────────────────
proc insert_ASSO
	mov ax,[last_ASSO]
	cmp ax,[current_N]
	je @@9			 ;запретить саму на себя

        mov esi,[current_ADR]
	inc esi
	lodsb
	movzx ecx,al ;ecx - кол-во ассоциаций
	add esi,2
	lodsb
	movzx eax,al
	add esi,eax  ;вычислить начало поля ассоциаций

	or cl,cl  ;а есть ли вообще ассоциации?
	je @@insert

	mov ebp,esi
	mov edi,ecx
   @@1: lodsw       ;поиск
        cmp ax,[last_ASSO]
        je @@9
        loop @@1
	mov ecx,edi
	mov esi,ebp

	cmp cl,255 ;а не много ли их?
	je @@zamena
	;--- такой нет - будем раздвигать
;═════════════════════════════════════════════════════════════════
;═════════════════════════════════════════════════════════════════
@@insert:
	movzx edi,[word BASE]
	inc edi
	mov eax,edi
	shl edi,1
	mov edi,[edi+eax+offset BASE] ;адрес конца
	and edi,0FFFFFFh
	add edi,offset BASE+30000h

        mov ecx,edi
	sub ecx,esi	     ;ecx - сколько переность
        or ecx,ecx
        je @@3
	js @@3

	dec edi
	mov esi,edi
	add edi,2

	 inc ecx	      ;так для чего-то нужно!!!
         std
	 rep movsb
         cld
 @@3:   mov ax,[last_ASSO]
	  stosw
	mov esi,[current_ADR]
	inc [byte esi+1]
;═════════════════════════════════════════════════════════════════
;═════════════════════════════════════════════════════════════════
        ;------------   ;передвинуть все последующие указатели
	movzx ecx,[word BASE]
	inc ecx
        inc ecx
        mov eax,ecx
	shl ecx,1
	add ecx,eax
	add ecx,offset BASE ;ecx - адр. END

	movzx edi,[current_N]
	mov eax,edi
	shl edi,1
	add edi,eax
	add edi,offset BASE
	add edi,3

  @@00: cmp edi,ecx
	jnc @@9
	mov eax,[dword edi]
	add eax,2
	stosw
        shld eax,eax,16
	stosb
	jmp @@00
        ;----        Затереть случайную
@@zamena:
	  dec cx ;ecx=254
	  xor edx,edx
	  call Get_RND
	  mov ax,[last_ASSO]
	  mov [esi+edx*2],ax
   @@9: ret


;@@key:  call io
;	 db 13,10,'Fatal ERROR',0
;	 call io
;	 db 13,10,'edi=',0
;	 mov eax,edi
;	 call pr_hex
;	 call io
;	 db 13,10,'esi=',0
;	 mov eax,esi
;	 call pr_hex
;	 jmp EXIT
;
endp insert_ASSO

;────────────────────────────────────────────────────────────────────────────
proc automat
	call io
	db 13,10,'Идет закачивание файла',13,10,0
        mov [last_ASSO],0
	call open_BUF ;а закроется автоматически в конце файла

@@0:	call get_word
	jc @@1
		call find_WORD
		jc @@create	;если не найден
		;------ вставить новую ассоциацию
		push [current_N]
                cmp [last_ASSO],0
		je @@33
		call insert_ASSO
	  @@33: pop [last_ASSO]
                jmp @@3
		;------
      @@create: call create_WORD
		mov ax,[current_N]
		mov [last_ASSO],ax
@@3:	;call pr_WORD
	cmp [new_ASSO],1
	je @@0
	mov [last_ASSO],0
	jmp @@0
@@1:	ret
endp automat
;───────────────────────────────────────────────────
proc create_WORD
        ;------------------------ get edi
	movzx ebx,[word BASE]
	cmp bx,0FFFFh
        je @@error_kol
	inc ebx 	;номер следующего
	mov [current_N],bx

	mov edi,[dword ebx*2+ebx+BASE]
	and edi,0FFFFFFh
	add edi,offset BASE+30000h
	mov [current_ADR],edi
	;------------------------
        xor ax,ax
        stosb   ;*Flag
	mov ebp,edi
        stosb   ;*Asso
	stosw	;*k_slog,*u_slog
	mov al,[byte new_WORD_len]
        stosb   ;*len
	movzx ecx,al  ;*************"word"
	mov esi,offset new_WORD
	rep movsb

 @@1:	mov ax,[last_ASSO]	 ;если не нулевая ассоциация
	or ax,ax
	je @@2
		stosw			 ;то создать ее
		inc [byte ebp]
 @@2:	inc [word BASE]
	sub edi,offset BASE+30000h
	mov [dword ebx*2+ebx+BASE+3],edi
        ret

@@error_kol: call io
	     db 13,10,'Слишком много слов',0
	     jmp EXITT

endp create_WORD
;───────────────────────────────────────────────────
proc find_WORD
	movzx ecx,[word BASE]	     ;а не нулевая ли база?
	or cx,cx
	je @@9

 @@0:	mov ebx,ecx		;вычислить адрес элемента
	shl ebx,1
	add ebx,ecx
	mov esi,[dword ebx+BASE]
	and esi,0FFFFFFh
	add esi,offset BASE+30000h
	mov [current_ADR],esi

        add esi,4               ;пропустить флаг,ассо,слог,удар
	lodsb

	cmp al,[byte new_WORD_len]   ;совпадают ли их длины?
        jne @@1

	push ecx
	movzx ecx,al
	mov edi,offset new_WORD
	repe cmpsb
        pop ecx
	je @@2
@@1:	loop @@0
@@9:    stc
        ret

@@2:	mov [current_N],cx  ;вот оно, найденное слово!
        clc
	ret

udataseg
por_ASSO db ?
new_ASSO db ?
last_ASSO dw ?
current_N dw ?
current_ADR dd ?
codeseg

endp find_WORD
;────────────────────────────────────────────────────────────────────────────
;proc pr_BASE
;	 call io
;	 db 13,10,' ┌─┬─┬───┬────────────────────┐',0
;	 push [current_N]
;	 push [current_ADR]
;	 push ecx bx
;
;	 movzx ecx,[word BASE]
;	 or cx,cx
;	 je @@9
;	 mov [current_N],1
;
;   @@1: call io
;	 db 13,10,0
;	 call pr_wOOrdd  ;WORD
;	 inc [current_N]
;	 loop @@1
;
;   @@9: pop bx ecx
;	 pop [current_ADR]
;	 pop [current_N]
;	 call io
;	 db 13,10,'   └─┴─┴───┴────────────────────┘',0
;	 ret
;endp pr_BASE
;─────────────────────────────────

;proc pr_WORD
;	 push eax ecx esi edx
;
;	 call io
;	 db 13,10,0
;	 movzx eax,[current_N]
;	 call pr_hex
;
;	 mov edx,eax
;	 shl edx,1
;	 add edx,eax
;	 mov esi,[dword edx+BASE]
;	 and esi,0FFFFFFh
;	 add esi,offset BASE+30000h
;	 call io	 ;flg
;	 db '',0
;	 xor eax,eax
;	 lodsb
;	 call pr_hex
;
;	 call io	 ;asso
;	 db '│',0
;	 lodsb
;	 movzx edx,al
;	 call pr_hex
;
;	 call io	 ;k_slog
;	 db '│',0
;	 lodsb
;	 call pr_hex
;	 call io
;	 db ',',0        ;u_slog
;	 lodsb
;	 call pr_hex
;
;	 call io	 ;asso
;	 db '│',0
;	 lodsb
;
;	 movzx ecx,al
;	 or al,al
;	 je @@1
;
;	 push ecx
; @@2:	 lodsb
;	 call i29
;	 loop @@2
;	 pop ecx
;	 neg ecx
;	 add ecx,20
;
; ;	  mov al,' '
; ;  @@7: call i29
; ;	  loop @@7
;
;	 call io	 ;asso
;	 db '│',0
;
;	 mov ecx,edx
;	 or ecx,ecx
;	 je @@1
;
;  @@3:  lodsw
;	 call pr_hex
;	 call io	 ;asso
;	 db '|',0
;	 loop @@3
;
;@@1:
;	 pop edx esi ecx eax
;	 ret
;
;endp pr_WORD
;
;proc pr_WORD_esi
;	 push eax ecx esi edx
;
;	 call io
;	 db 13,10,0
;
;	 call io	 ;flg
;	 db '│',0
;	 xor eax,eax
;	 lodsb
;	 call pr_hex
;
;	 call io	 ;asso
;	 db '│',0
;	 lodsb
;	 movzx edx,al
;	 call pr_hex
;
;	 call io	 ;k_slog
;	 db '│',0
;	 lodsb
;	 call pr_hex
;	 call io
;	 db ',',0        ;u_slog
;	 lodsb
;	 call pr_hex
;
;	 call io	 ;asso
;	 db '│',0
;	 lodsb
;
;	 movzx ecx,al
;	 or al,al
;	 je @@1
;
;	 push ecx
; @@2:	 lodsb
;	 call i29
;	 loop @@2
;	 pop ecx
;	 neg ecx
;	 add ecx,20
;
;	 mov al,' '
;   @@7: call i29
;	 loop @@7
;
;	 call io	 ;asso
;	 db '│',0
;
;	 mov ecx,edx
;	 or ecx,ecx
;	 je @@1
;
;  @@3:  lodsw
;	 call pr_hex
;	 call io	 ;asso
;	 db '|',0
;	 loop @@3
;
;@@1:
;	 pop edx esi ecx eax
;	 ret
;
;endp pr_WORD_esi
;───────────────────────────────────────────────────
proc saveBASE
	cmp [word BASE],0
	je @@ret
        ;----create----------
        mov     ah,3ch
	mov	edx,offset BASEname
	xor	cx,cx
        int     21h
        jc      @@error
	mov	bx,ax
	;─────────── записать таблицу расположения
        movzx ecx,[word BASE]
	inc ecx
        inc ecx ;чтобы и END записался
	mov eax,ecx
	shl ecx,1
	add ecx,eax ;*3
	mov edx,offset BASE
	mov ah,40h
	int 21h
        jc @@error
	;─────────── записать базу слов
	movzx ecx,[word BASE]
        inc ecx
	mov eax,ecx
	shl ecx,1
        add ecx,eax ;*3
	mov ecx,[dword ecx+BASE] ;END адрес
	and ecx,0FFFFFFh
	mov eax,[dword BASE+3]	 ;адрес 1-го элемента
	and eax,0FFFFFFh
	sub ecx,eax
	mov edx,offset BASE+30000h
	mov ah,40h
	int 21h
        jc @@error
	;--close--
        mov     ah,3eh
	int	21h
 @@ret: ret
	;---------
@@error: call io
	 db 13,10,'ошибка записи БАЗЫ',0
	 mov ah,3eh
	 int 21h
	 jmp EXITT
	 ret
endp saveBASE
;────────────────────────────────────────────────────────────────────────────
proc loadBASE
	;----open----------
	mov	ax,3d00h
        mov     edx,offset BASEname
        int     21h
	jc	@@no_base
	mov	bx,ax
	;---load-----------
	mov edx,offset BASE	;прочитать количество элементов
	mov ecx,3
	mov ah,3Fh
	int 21h
        jc @@error

	mov eax,[dword BASE]	      ;прочитать таблицу размещений
	and eax,0FFFFFFh
	inc eax
	mov ecx,eax
	shl ecx,1
	add ecx,eax
	mov edx,offset BASE+3

	mov ah,3Fh	  ;function read
	int 21h
        jc @@error

	mov ecx,RAZMER		;прочитать массив слов
	mov edx,offset BASE+30000h
	mov ah,3Fh	  ;function read
	int 21h
        jc @@error

	mov ebx,[dword BASE]
	inc ebx
	mov ecx,ebx
	shl ecx,1
	add ecx,ebx

	mov ecx,[dword ecx+BASE] ;END адрес
	and ecx,0FFFFFFh
	mov ebx,[dword BASE+3]	 ;адрес 1-го элемента
	and ebx,0FFFFFFh
	sub ecx,ebx

        cmp ecx,eax
	jne @@err_format

        mov ah,3eh  ;close
	int 21h
	ret

        ;--------------------
@@no_base: call io
	   db 13,10,'База не найдена - создана нулевая база.',0
	   mov [dword BASE],0
	   mov [dword BASE+3],0
	   ret

@@err_format: call io
	      db 13,10,'НЕВЕРНЫЙ ФОРМАТ БАЗЫ',0
	      mov ah,3eh  ;close
	      int 21h
	      jmp EXITT
	      ret

@@error: call io
	 db 13,10,'ошибка чтения БАЗЫ',0
	 mov ah,3eh  ;close
	 int 21h
	 jmp EXITT
endp loadBASE
;────────────────────────────────────────────────────────────────────────────

proc get_word
	mov [new_ASSO],1	;не убивать появившихся ассоциаций
	mov edi,offset new_WORD
	mov ecx,dlin_word
	mov [por_ASSO],1	;если спецзнак - то убить старую [last_ASSO]
   @@0: call get
	jc @@1
	call slus  ;пока идет мусор
	jc @@0
	mov [por_ASSO],2	;если теперь спецзнак - то убить народившуются
  @@2:	stosb
	call get
	jc @@1
	cmp al,'-'
	jne @@900
		call get
		jc @@1
		cmp al,0Dh
		je @@0
		mov [nimbl],al
		jmp @@3
@@900:	call slus
	jc @@3
	loop @@2  ;пока нет мусора
  @@3:	xor al,al
	stosb
	mov [new_WORD_len],edi
	sub [new_WORD_len],offset new_WORD+1

	sub edi,2
	cmp edi,offset new_WORD
	jne @@000

	mov al,[edi]
	cmp al,'о'
	je @@000
        cmp al,'а'
        je @@000
        cmp al,'у'
        je @@000
        cmp al,'и'
        je @@000
        cmp al,'я'
        je @@000
        cmp al,'к'
        je @@000
        cmp al,'с'
        je @@000
        cmp al,'в'
        je @@000
	cmp al,'ж'
        je @@000
	;call io
	;db 13,10,'Найдена левая буква ',0
	;call i29
        jmp get_word

 @@000: clc
	ret
  @@1:	stc
	ret

proc slus
	push esi ebx

	cmp al,'.'
	je @@1100
	cmp al,'?'
	je @@1100
	cmp al,'!'
	je @@1100
	cmp al,'('
	je @@1100
	cmp al,')'
	jne @@1111
@@1100: cmp [por_ASSO],1 ;если =1, то убить предыдущую ассоциацию
	jne @@1101
	mov [last_ASSO],0
	jmp @@1111
@@1101: mov [new_ASSO],0 ;если =2, то убить народившуюся
@@1111:
	mov bl,al
	mov esi,offset tabperedel
  @@0:	lodsb
	or al,al
	je @@2
	cmp al,bl
	je @@3
	inc esi
	jmp @@0
  @@3:	lodsb
	jmp @@22
  @@2:	mov al,bl
  @@22: pop ebx esi
	cmp al,080h
	jc @@1
	cmp al,0B0h
	jc @@8
	cmp al,0E0h
	jc @@1
	cmp al,0F0h
	jnc @@1
@@8:	clc
	ret
@@1:	stc
	ret

tabperedel:
	db 'A','а'
	db 'B','в'
	db 'E','е'
	db 'K','к'
	db 'M','м'
	db 'H','н'
	db 'O','о'
	db 'P','р'
	db 'C','с'
	db 'T','т'
	db 'X','х'

	db 'А','а'
	db 'Б','б'
	db 'В','в'
	db 'Г','г'
	db 'Д','д'
	db 'Е','е'
	db 'Ж','ж'
	db 'З','з'
	db 'И','и'
	db 'Й','й'
	db 'К','к'
	db 'Л','л'
	db 'М','м'
	db 'Н','н'
	db 'О','о'
	db 'П','п'
	db 'Р','р'
	db 'С','с'
	db 'Т','т'
	db 'У','у'
	db 'Ф','ф'
	db 'Х','х'
	db 'Ц','ц'
	db 'Ч','ч'
	db 'Ш','ш'
	db 'Щ','щ'
	db 'Э','э'
	db 'Ю','ю'
	db 'Я','я'
	db 'Ы','ы'
	db 'Ь','ь'
	db 'Ъ','ъ'

;	 db 'a','а'
;	 db 'e','е'
;	 db 'o','о'
	db 'p','р'
;	 db 'c','с'
;	 db 'x','х'
;	 db 'y','у'
        db 0
endp slus
endp get_word

;proc pr_word
;	 mov esi,offset new_WORD
; @@0:	 lodsb
;	 or al,al
;	 je @@1
;	 call i29
;	 jmp @@0
; @@1:	 ret
;endp pr_word
;
;proc pr_m_word
;	 mov esi,offset m_word
; @@0:	 lodsb
;	 or al,al
;	 je @@1
;	 call i29
;	 jmp @@0
; @@1:	 ret
;endp pr_m_word

proc get
        xor al,al
	cmp [nimbl],al
	je @@11
	xchg al,[nimbl]
	ret
@@11:
        push esi
	mov esi,[point_BUF]
	cmp esi,[last_byte_BUF]
	jc @@1

	call load_BUF
	jc @@ret

@@1:	lodsb
	mov [point_BUF],esi
        clc
@@ret:	pop esi
        ret
endp get

proc load_BUF
	push eax ebx ecx edx
	mov bx,[bx_BUF]
	mov ecx,dlin_BUF
	mov edx,offset BUF
	mov ah,3Fh	  ;function read
	int 21h
        jc @@error
	or eax,eax
	jne @@1
        ;----close-----------
	 call close_BUF
        ;----close-----------
	stc
	jmp @@ret

 @@1:	add [real_read_BUF],eax

	push eax
	mov eax,[real_read_BUF]
        call pr_dec
	call io
	db '  ',13,0
	pop eax

	add eax,offset BUF
	mov [last_byte_BUF],eax
	mov [point_BUF],offset BUF
	mov esi,offset BUF
	clc
@@ret:	pop edx ecx ebx eax
	ret
@@error: pop edx ecx ebx eax
	 call io
	 db 13,10,'Ошибка чтения файла',0
	 jmp EXITT
endp load_BUF

proc open_BUF
	mov [nimbl],0
	mov [real_read_BUF],0
        push eax edx
	mov	ax,3d00h
	mov	edx,offset FileName
        int     21h
	jc	@@not_found
	mov	[bx_BUF],ax
	pop edx eax
	ret
@@not_found:
        pop edx eax
	call io
	db 13,10,'Нет такого файла!',0
	jmp EXITT
endp open_BUF

bx_BUF dw 12345

udataseg
point_BUF dd ?
real_read_BUF dd ?
last_byte_BUF dd ?
BUF db dlin_BUF dup(?)
nimbl db ?
codeseg
;────────────────────────────────────────────────────
proc open_PUT
        push eax edx
	mov	ah,3ch
	xor	cx,cx
	mov	edx,offset FilePut
        int     21h
	jc	@@not_found
	mov	[bx_PUT],ax
	pop edx eax
	ret
@@not_found:
        pop edx eax
	call io
	db 13,10,'Нет такого файла!',0
	jmp EXITT
endp open_PUT

bx_PUT dw 12345
point_PUT dd PUT

FilePut db 'resultat.txt',0

udataseg
PUT db dlin_PUT dup(?)
codeseg


proc put
	push edi
	mov edi,[point_PUT]
	cmp edi,offset PUT+dlin_PUT
        jc @@1

	call save_PUT
	jc @@ret

@@1:	stosb
	mov [point_PUT],edi
        clc
@@ret:	pop edi
        ret
endp put

proc save_PUT
	push eax ebx ecx edx
	mov bx,[bx_PUT]
	mov edx,offset PUT
	mov ecx,[point_PUT]
	sub ecx,edx
	mov ah,40h	  ;function read
	int 21h
        jc @@error
        mov edi,offset PUT
	mov [point_PUT],edi
	clc
@@ret:	pop edx ecx ebx eax
	ret
@@error: pop edx ecx ebx eax
	 call io
	 db 13,10,'Ошибка записи файла',0
	 jmp EXITT
endp save_PUT
;────────────────────────────────────────────────────
proc close_PUT
	mov bx,[bx_PUT]
	cmp bx,12345
	je @@1
	 call save_PUT
         mov     ah,3eh
         int     21h
        mov [bx_PUT],12345
	mov [point_PUT],offset PUT
         jc @@error
@@1:	ret
@@error: call io
	db 13,10,'Ошибка закрытия PUT',0
	ret
endp close_PUT

proc close_BUF
	mov bx,[bx_BUF]
	cmp bx,12345
	je @@1
         mov     ah,3eh
         int     21h
	 mov [bx_BUF],12345
         jc @@error
@@1:	ret
@@error: call io
	 db 13,10,'Ошибка закрытия BUF',0
	ret
endp close_BUF
;────────────────────────────────────────────────────

proc i29
	cmp [bx_PUT],12345
	je @@7
	call put
@@7:
	int 29h
	call keyli
	ret
endp i29

proc key
	push ax
	xor ax,ax
	int 16h
	cmp ah,1
	jne @@1
	jmp EXITT
 @@1:	pop ax
	ret
endp key

proc keyli
	push ax
	mov ah,1
	int 16h
	jne @@key_pressed
 @@1:	pop ax
	ret

 @@key_pressed:
	xor ax,ax
	int 16h
        cmp ah,1
        jne @@1
	jmp EXITT
endp keyli

include 'inc32\io.i32'
;include 'inc32\pr_hex.i32'
include 'inc32\pr_dec.i32'

proc pr_dec_z
		push eax
		or ax,ax
		je @@null
		jns @@9998
		neg ax
		call io
		db ' ─── ',0
		jmp @@9999
		@@9998:
		call io
		db ' ─┼─ ',0
		@@9999:
		call pr_dec
	  @@0:	pop eax
		ret
	@@null: call io
		db '     0',0
		jmp @@0
endp pr_dec_z

proc EXITT
	call close_PUT
	call close_BUF

        mov     ax,4c00h
        int     21h
endp EXITT
;────────────────────────────────────────────────────
proc pr_work_word
	push esi eax
	call io
	db 13,10,0
	mov esi,offset work_word
 @@0:	lodsb
	or al,al
	je @@1
	call i29
	jmp @@0
 @@1:	pop eax esi
	ret
endp pr_work_word
;
;proc pr_rhyme1
;	 push esi eax
;	 call io
;	 db 13,10,0
;	 mov esi,offset rhyme1
; @@0:	 cmp esi,[rhyme1_glas_ADR]
;	 jne @@2
;	 call io
;	 db '│',0
;	 @@2:
;	 cmp esi,[end_rhyme1]
;	 je @@3
;	 lodsb
;	 call i29
;	 jna @@0
; @@3:	 pop eax esi
;	 ret
;endp pr_rhyme1

proc copy_WORD_word
	push esi edi ecx
        mov esi,[current_ADR]
        mov edi,offset m_word
	add esi,4
        lodsb
	movzx ecx,al
        rep movsb
        xor al,al
        stosb
	pop ecx edi esi
	ret
endp copy_WORD_word


proc copy_WORD_rhyme1
	push esi edi ecx
        mov esi,[current_ADR]
	add esi,2
	lodsb
	mov [rhyme_slog],al
	mov ah,al
        lodsb
	sub ah,al

	mov [nado_parglas],0
	or ah,ah
	jne @@890
        mov [nado_parglas],1
 @@890:
	mov [type_of_rhyme],ah

        lodsb
	movzx ecx,al
	mov ebx,esi
        mov edi,offset rhyme1

        call par_glas

	movzx ecx,[type_of_rhyme]
	inc ecx
	mov esi,edi
   @@0: dec edi
	mov al,[edi]
	push cx
	call glasn_li
	pop cx
	jne @@0
	loop @@0
	mov [rhyme1_glas_ADR],edi
	sub esi,edi
	mov [ecx_type_of_rhyme],esi

	pop ecx edi esi
	ret
udataseg
rhyme_slog		db	?
type_of_rhyme		db	?
ecx_type_of_rhyme	dd	?
rhyme1_glas_ADR 	dd	?
end_rhyme1		dd	?
rhyme1			db	dlin_word dup(?)
codeseg

endp copy_WORD_rhyme1

proc slog_word
	push esi edi ecx
	call copy_WORD_word
	;---------	коррекция, а то что-то иногда сбой
	mov esi,offset m_word
	mov [slogi_gi_gi_gi],0
   @@korr_0: lodsb
        or al,al
	je @@korr_9
	call glasn_li
	jne @@korr_0
	inc [slogi_gi_gi_gi]
	jmp @@korr_0
  @@korr_9:
	mov al,[slogi_gi_gi_gi]
	mov [kol_slog],al
	or al,al
	je @@korr_10
	dec [slogi_gi_gi_gi]
  @@korr_10:
        ;---------
	mov esi,offset m_word
	mov edi,offset work_word
  @@0:  lodsb
        or al,al
        je @@exit
        stosb

         call glasn_li
        jne @@0
        ;--- была гласная
@@glas: mov al,[esi]
        or al,al
        je @@ohexit
         call glasn_li   ;следующая гласная?
         je @@222

	mov al,[esi+1]
         or al,al
         je @@ohexit
        cmp al,'ь'              ;за согласной стоит 'Ь'
        je @@osobij_sluchaj
        cmp al,'Ь'
        je @@osobij_sluchaj

         call glasn_li   ;следующая согласная, а за ней - гласная?
         je @@222
	cmp [byte esi+2],0
        je @@ohexit

 @@2201: movsb

  @@222: cmp [slogi_gi_gi_gi],0
	 je @@0
	 dec [slogi_gi_gi_gi]

	 mov al,'-'
         stosb
         jmp @@0
        ;---
@@osobij_sluchaj:
	mov al,[esi+2]
         or al,al
         je @@ohexit
         call glasn_li   ;ну а хоть 3-я - гласная?
         je @@222
         movsb
         jmp @@2201
        ;---
@@ohexit: lodsb
          or al,al
          je @@exit
          stosb
          jmp @@ohexit
@@exit: stosb
	pop ecx edi esi
        ret

;абвгдежзиклмнопрстуфхцчшщэюяыъь
;АБВГДЕЖЗИКЛМНОПРСТУФХЦЧШЩЭЮЯЫЪЬ
udataseg
nado_parglas	db	?
slogi_gi_gi_gi db ?
kol_slog db ?
codeseg
endp slog_word

proc glasn_li
	push edi
	mov edi,offset TAB_GLASN
	mov ecx,TAB_GLASN_len
	repne scasb
	pop edi
	je @@1
	mov al,'*'
 @@1:	ret

TAB_GLASN db 'аеиоуяэюяы','АЕИОУЯЭЮЯЫ'
TAB_GLASN_len = $-TAB_GLASN
endp glasn_li
;───────────────────┤
proc par_glas		;ebx - исходное слово
	push esi	;edi - конечное слово
  @@0:	mov ah,[ebx]	;ecx - цикл
        inc ebx
        ;-------
	call parglas_li
        ;-------
	mov al,ah
	stosb
	loop @@0
        mov [end_rhyme1],edi
	pop esi
        ret

TAB_PAR_GLAS	db 'бп','вф','гк','дт','жш','щш','зс','мн','цч'
		db 'ыи','юу','яа','эе','ёо',0     ;л р х   ь ъ

endp par_glas
;--------------------
proc parglas_li
        cmp [nado_parglas],0
	jne @@1

        mov esi,offset TAB_PAR_GLAS
  @@2:  lodsb
        or al,al
        je @@1
        inc esi
        cmp ah,al
        jne @@2
        mov ah,[esi-1]
  @@1:  ret
endp parglas_li
;--------------------
;───────────┬┬────────────┬───────────────┬─────┬─────────────────┐
;───────────┼┴┬─────┬─────┼─────┬─────────┼─────┼──┬───┬──────────┤
;───────────┼─┴─┬───┴─┬───┼─────┼───────┬─┼─────┴──┼───┼──────┬───┤
;───────────┴───┴─────┼───┼─────┼───────┼─┴────────┴───┼──────┼───┤
;─────────────────────┴───┴─────┴───────┴──────────────┴──────┴───┘

;────────────────────────────────────────────────────
		udataseg
new_WORD_len	dd ?
new_WORD	db dlin_word dup(?)
work_word	db dlin_word dup(?)
m_word		db dlin_word dup(?)
BASE db RAZMER dup(?)
                stack   65536
		;codeseg
		end	startentry
