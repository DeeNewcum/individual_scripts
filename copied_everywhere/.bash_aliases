# this stands for "update copy_everywhere"
function upce {
	pushd ~/copied_everywhere/ >/dev/null
	scp -r -p -q newcum@rabbitmq-1.data.cc.uic.edu:will_be_copied_everywhere/. .
	./deedot
	popd >/dev/null
	echo "Updated!"
}
