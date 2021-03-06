pid_guard() {
  local pidfile=$1
  local name=$2
  local logall=${3:-true}

  if [ "${logall}" == "true" ]; then
    echo "------------ STARTING `basename $0` at `date` --------------" | tee /dev/stderr
  fi

  if [ -f "$pidfile" ]; then
    pid=$(head -1 "$pidfile")

    if [ -n "$pid" ] && [ -e /proc/$pid ]; then
      echo "$name is already running with pid $pid. Exiting."
      exit 1
    fi

    echo "Removing $name stale pidfile"
    rm $pidfile
  fi
}

wait_pidfile() {
  pidfile=$1
  try_kill=$2
  timeout=${3:-0}
  force=${4:-0}
  countdown=$(( $timeout * 10 ))

  if [ -f "$pidfile" ]; then
    pid=$(head -1 "$pidfile")

    if [ -z "$pid" ]; then
      echo "Unable to get pid from $pidfile"
      exit 1
    fi

    if [ -e /proc/$pid ]; then
      if [ "$try_kill" = "1" ]; then
        echo "Killing $pidfile: $pid "
        kill $pid
      fi
      while [ -e /proc/$pid ]; do
        sleep 0.1
        [ "$countdown" != '0' -a $(( $countdown % 10 )) = '0' ] && echo -n .
        if [ $timeout -gt 0 ]; then
          if [ $countdown -eq 0 ]; then
            if [ "$force" = "1" ]; then
              echo -ne "\nKill timed out, using kill -9 on $pid... "
              kill -9 $pid
              sleep 0.5
            fi
            break
          else
            countdown=$(( $countdown - 1 ))
          fi
        fi
      done
      if [ -e /proc/$pid ]; then
        echo "Timed Out"
      else
        echo "Stopped"
      fi
    else
      echo "Process $pid is not running"
    fi

    rm -f $pidfile
  else
    echo "Pidfile $pidfile doesn't exist"
  fi
}

kill_and_wait() {
  pidfile=$1
  # Monit default timeout for start/stop is 30s
  # Append 'with timeout {n} seconds' to monit start/stop program configs
  timeout=${2:-25}
  force=${3:-1}

  wait_pidfile $pidfile 1 $timeout $force
}

check_pidfile() {
  pidfile=$1
  timeout=${2:-0}
  countdown=$timeout

  if [ -f "$pidfile" ]; then
    pid=$(head -1 "$pidfile")

    if [ -z "$pid" ]; then
      echo "Unable to get pid from $pidfile"
    elif [ -e /proc/$pid ]; then
      while [ -e /proc/$pid ]; do
        sleep 1
        [ "$countdown" != '0' -a $(( $countdown % 10 )) = '0' ] && echo -n .
        if [ $timeout -gt 0 ]; then
          if [ $countdown -eq 0 ]; then
            break
          else
            countdown=$(( $countdown - 1 ))
          fi
        fi
      done
      if [ -e /proc/$pid ]; then
        echo "Timed Out"
        exit 1
      else
        echo "Stopped"
      fi
    else
      echo "Process $pid is not running"
    fi
  else
    echo "Pidfile $pidfile doesn't exist"
  fi
}
running_in_container() {
  grep -q -E '/instance|/docker/' /proc/self/cgroup
}
