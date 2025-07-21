#!/bin/zsh


() {

autoload -Uz @term:cursor:getPosition
function @term:cursor:getPosition {
	tput u7 > $TTY
	local CPos
	IFS='[;' read -rsd R -A CPos
	local -a CursorPosition=( ${CPos[2,3]} )
	: ${(A)CLine::=${(j:,:)CursorPosition[1]}}
	: ${(A)CCol::=${(j:,:)CursorPosition[2]}}
	local -a Output=( ${${(s..)${@//-/}}// /} )
	
	(( $#Output )) && {
		(( ${Output[(I)l]} )) && { Output[${Output[(i)l]}]=$CLine }
		(( ${Output[(I)c]} )) && { Output[${Output[(i)c]}]=$CCol }
		print ${(j.,.)Output}
	}
}

}

:<<-"EXAMPLES"
		** Line numbers are skewed from deleting my prompt lines when adding the examples **
	~/ @term:cursor:getPosition
	
	~/ @term:cursor:getPosition l
	21
	~/ @term:cursor:getPosition c
	1
	~/ @term:cursor:getPosition cl
	1,27
	~/ @term:cursor:getPosition lc
	30,1
	~/ @term:cursor:getPosition -lc
	33,1
	~/ @term:cursor:getPosition -l -c
	36,1
	~/ @term:cursor:getPosition -l   
	37
	~/ clear; print -P - "%B%S${(%l:((COLUMNS/2))::-:: :r:((COLUMNS/2))::-:: :):-$(@term:cursor:getPosition l)}%s%b"
	------------------------------------------------ 1,1 -----------------------------------------------
	~/ print -P - "%B%S${(%l:((COLUMNS/2))::-:: :r:((COLUMNS/2))::-:: :):-$(@term:cursor:getPosition lc)}%s%b"       
	------------------------------------------------ 5,1 -----------------------------------------------
	~/ print -P - "%B%S${(%l:((COLUMNS/2))::-:: :r:((COLUMNS/2))::-:: :):-$(@term:cursor:getPosition l)}%s%b" 
	------------------------------------------------- 9 ------------------------------------------------
	~/ print -P - "%B%S${(%l:((COLUMNS/2))::-:: :r:((COLUMNS/2))::-:: :):-$(@term:cursor:getPosition l)}%s%b"
	------------------------------------------------ 13 ------------------------------------------------
EXAMPLES
