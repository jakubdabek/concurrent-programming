lista%: FORCE
	#if [ -d "244985/$@" ] ; then
		mv -f 244985/$@ 244985/.old_$@ || true
	#fi
	cp -r $@/ 244985/$@

FORCE:
