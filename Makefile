lista%: FORCE
	#if [ -d "244985/$@" ] ; then
		mv -f 244985/$@ 244985/.old_$@ || true
	#fi
	cp -r main 244985/$@

container: FORCE
	ssh -p 9001 s244985@156.17.7.13

FORCE:
