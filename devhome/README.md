# Handy scripts and files to have on a host running LOCKSS service containers

bin/cid <string> - prints the container ID of the first container whose
		   'docker ps' line contains <string>.  E.g.,
		   docker exec `cid repo` jcmd 1 Thread.print

bin/lnlogs - makes short name symlinks in /lockss to daemon.log and
	     stdout.log files in log subdirs

.emacs
