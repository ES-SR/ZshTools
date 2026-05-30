function @read:sporadic { 
    emulate -L zsh; setopt extendedglob typesetsilent
    if ! [[ -p /dev/stdin ]] { return 1 } 
 
    @args:parse '<->,<->':DelayIdx DelayPool:1 MaxEmptyReads:1 Timeout:1 OutDelimiter:+ InDelimiter:+ '-[abcCDfilmnNoOPRrsSuXxz](*|)':PrintOptsIdxs
 
    local -a PrintOpts=("${(@)PrintOptsIdxs//(#m)*/${(P)MATCH}}")
    local -a DelayRange=( ${(s.,.)${argv[$DelayIdx]}:-0,10} )
    local -a Delays=($(@numbers:random:range ${(j.,.)DelayRange} ${${DelayPool[1]}:-25}))
    Delays=(${Delays//(#m)*/$((MATCH / 10.))})
    local -i DelaysIdx=1
 
    set -- "${(@)ParsedArgv}"
 
    local -i MaxEmptyReads=${${MaxEmptyReads[1]}:-4}
    local -F Timeout=${${Timeout[1]}:-0.2}
    local InDelim="${${InDelimiter:+"(${(j.|.)InDelimiter})"}:-${(Q):-"($'\ '|$'\n'|$'\t')"}}"
    local OutDelim="${:-"${OutDelimiter:-"{{}}"}"}"
 
    local -a Buffer=() 
 
    local -i ReadAttempts=${MaxEmptyReads}
    while (( ReadAttempts )) { 
        sleep ${${Delays[$((DelaysIdx++))]}:-${Delays[$((DelaysIdx = 1))]}}
        #sleep $(( $(@numbers:random:range ${(j.,.)DelayRange}) / 10. ))
        local Char
        IFS= read -u 0 -t ${Timeout} -k 1 -rs Char
 
        [[ -z $Char ]] && {
            ((ReadAttempts--))
            continue
        }
 
        Buffer+=("${Char}")
        ((ReadAttempts=MaxEmptyReads))
        local BuffStr="${(j..)Buffer}"
        local FirstDelim=""
 
        while [[ -n "${FirstDelim::="${(M)BuffStr#*${~InDelim}}"}" ]] {
            BuffStr="${BuffStr#*${~InDelim}}"
            print ${(z)=PrintOpts} -- "${FirstDelim/(#m)${~InDelim}/"${OutDelim//\{\{*\}\}/${MATCH}}"}"
        }
        Buffer=(${(s..)BuffStr})
    }
 
    (( ${#Buffer} )) && {
        print ${(z)PrintOpts} -- "${(j..)Buffer}"
    }
}
 
: <<"Examples.@read:sporadic"
    () {
        {
            #set -x
            #functions -T @read:sporadic 
            print -- {a..z} {A..Z}      | @read:sporadic 1,2 -n
#return
            print '#######'
            print -- {a..f}         | @read:sporadic 1,5
            print '#######'
            print -- {a..f}         | @read:sporadic 1,5 -n -od '-'
            print $'\n''#######'
            print -- {a..f}         | @read:sporadic 1,5 -n -ID '[aeiou]' -OD '-'
            print '#######'
            print -- {a..f}         | @read:sporadic 1,5 -n -ID '[aeiou]' ' ' -OD '-'
            print '#######'
            print -- {} hello {} world  | @read:sporadic 1,5 -l -P indelimiter '[[:graph:][:space:]]' outdelimiter '%F{green}<%f{{}}%F{green}>%f' 
            print '#######'
            print -- {} hello {} world  | @read:sporadic 1,5 -l -P indelimiter '[[:graph:][:space:]]' outdelimiter '%F{green}<%f${(Vq+):-{{}}}%F{green}>%f'
        } always {
            set +x
        }
    }
