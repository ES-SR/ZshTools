#!/bin/zsh
##  ASCII.zsh


() {

unset ASCII; typeset -agHUhx ASCII=(
	NUL 
	SOH STX ETX EOT ENQ ACK BEL BS TAB LF VT FF CR SO SI 
	DLE DC1 DC2 DC3 DC4 
	NAK SYN ETB CAN EM SUB ESC 
	FS GS RS US 
	\  \! \" \# \$ \% \& \' \( \) \* \+ \, \- \. \/ 
	0 1 2 3 4 5 6 7 8 9 
	\: \; \< \> \? \@ 
	A B C D E F G H I J K L M N O P Q R S T U V W X Y Z 
	\[ \\ \] \^ \_ \` 
	a b c d e f g h i j k l m n o p q r s t u v w x y z 
	\{ \| \} \~ 
	DEL 
)

local DECIMAL=( {0..127} )

typeset -AgHxh AsciiDecimal=( ${DECIMAL:^ASCII} )
typeset -AgHxh DecimalAscii=( ${ASCII:^DECIMAL} )

typeset -fuUz @ascii:decimal:list 
function @ascii:decimal:list {
	print -c - "${(f)="$(print -aC2 ${(kv)AsciiDecimal} | sort -n)"}"
}

function @ascii:2decimal {
	for C ( ${(s..):-"Hello World\!"} ) {
		echo ${DecimalAscii[${DecimalAscii[(i)${~C}]}]}
	}
}


}
