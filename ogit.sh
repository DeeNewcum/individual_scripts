
# OGit stands for "one-file git".
#
# Version-control just ONE file within a directory...
# This allows you to have different repos for different files within a directory.
#
# See more at:
#       http://paperlined.org/apps/git/onegit.html
function ogit() {
    if [ "$1" = "use" ]; then
        if [ -z "$2" ]; then
            unset ONEGIT ONEGIT_GITDIR ONEGIT_DIR
            echo "OneGit settings cleared."
        elif [ -f "$2" ]; then
            export ONEGIT=$(readlink -f "$2")
            export ONEGIT_DIR=$(dirname "$ONEGIT")
            export ONEGIT_GITDIR=$ONEGIT_DIR/.git.$(basename "$ONEGIT")
            if [ ! -d "$ONEGIT_GITDIR" ]; then
                ogit init
                echo -e "*\n!"$(basename "$ONEGIT") > "$ONEGIT_GITDIR/info/exclude"
            fi
            echo "OneGit is now using:  $2"
        else
            echo "File '$2' does not exist.\n";
        fi
    else
        if [ -z "$ONEGIT" ]; then
            echo "You must first set a OneGit repository first, using 'ogit use <filename>'"
            return
        fi
        if [ -z "$1" ]; then
            echo "OneGit is now using:  $ONEGIT"
            return
        fi
        (cd "$ONEGIT_DIR"; git --work-tree=. --git-dir="$ONEGIT_GITDIR" "$@")
    fi
    #echo -e "\n======== DEBUG ========"; set | grep ^ONEGIT
}
