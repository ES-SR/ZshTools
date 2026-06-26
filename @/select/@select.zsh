function @select {
        emulate -L zsh; setopt extendedglob

        @args:parse Prompt:1

        (( ${#Prompt} )) && {
                print -P -- %S ${Prompt[1]} %s
                set -- "${(@)Argv}"
        }

        (( ARGC )) || {
                print -u2 -- "No choices provided"
                return 1
        }

        local Choice
        select Choice in "${(@)argv}"; {
                (( ${#Choice} )) && {
                        print -- "${(P)REPLY}"
                        return 0
                } || {
                        print -u2 -- "Invalid choice"
                        return 1
                }
        }
}

: <<"Examples.@select"
        @select -P "This is the Example" hello world 3 four
Examples.@select
