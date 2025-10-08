#!/usr/bin/zsh
##  @read:delimited.1

() {

	function @read:delimited {
		if ! [[ -p /dev/stdin ]] { return 1 }
		local Delimiter="${1:-$'\n'}"
		local OutDelim=${2}
		local -i ChunkSize=${3:-64}
		local -F Timeout=${4:-0.5}
		local -i MaxEmptyReads=${5:-3}
		local Buffer=""
		local -i EmptyReads=0
		local -i BuffSize
		while [[ $EmptyReads -le $MaxEmptyReads ]] {
			(( BuffSize = $#Buffer ))
			Buffer+=$(IFS= read -u0 -t${Timeout} -k${ChunkSize} -rE)
			(( BuffSize - $#Buffer )) || {
				(( EmptyReads++ ))
				continue
			}
			EmptyReads=0
			local Tokens=(${(0)=${Buffer//${Delimiter}/$'\0'${Delimiter}$'\0'}})
			local OutputTokens=(${Tokens[1,-2]})
			print -n - "${OutputTokens:^^OutDelim}"
			Buffer="${Tokens[-1]}"
		}
		print -r -- "$Buffer"
	}

	:<<-"Example"
		TestInput="$(cat<<-"TESTINPUT"
		helo there is this some
		 random words eof with some key EOF words
		M
		a in cluded  for testing? ' it is ! ' and typosj
		EOF EOF w @OF  wOE Eeof EOF
		O
		Done with the test input
		TESTINPUT
		)"
		#functions -T @read:delimited
		echo $TestInput | @read:delimited EOF '\n<:>\n'
	Example

}
