function @history:save:last {
        emulate -L zsh; setopt extendedglob typesetsilent      
        
        local BaseName="${1}"         
        local -a SavePaths=("${(@)argv[2,-1]}")          
        local SP                                                
        for SP ( "${(@)SavePaths}" ) {
                if ! [[ -d "${SP:A}" ]] {      
                        SavePaths=(${SavePaths:#(#s)${SP}(#e)}) 
                }                     
        }       
        local Time=$(date +%s)
        local FileName="${BaseName}.${Time}.zsh"
        local HereDelim=$'\"'"EOF.save.${BaseName}"$'\"'
        local Cmd=${$(fc -ln -1)//(#m)($'\$\''*([^$'\\']$'\''|$'\\\\\''))/"${(q)MATCH}"}
        local SaveOutput=${SavePaths//(#m)(*)/" | tee ${MATCH}/${FileName}"}" > /dev/null"

        ## using tee instead of > in case the user does not have multios on 
         # and print -z means the functions scope doesnt help
        print -z -- "cat<<${HereDelim}${SaveOutput}"$'\n'$Cmd$'\n'${(Q)HereDelim}
}
