def --env mkcd [directory: path] {
  mkdir $directory
  cd $directory
}

def backup [filename: path] {
  cp $filename $"($filename).bak"
}

def restore [filename: path] {
  let destination = ($filename | into string | str replace --regex '\.bak$' '')

  if $destination == ($filename | into string) {
    error make { msg: $"'($filename)' is not a backup file" }
  }

  mv $filename $destination
}

def extract [archive: path] {
  let archive = ($archive | path expand)

  if not ($archive | path exists) {
    error make { msg: $"'($archive)' is not a valid file" }
  }

  let name = ($archive | path basename)

  if ($name | str ends-with '.tar.bz2') or ($name | str ends-with '.tbz2') {
    ^tar xjf $archive
  } else if ($name | str ends-with '.tar.gz') or ($name | str ends-with '.tgz') {
    ^tar xzf $archive
  } else if ($name | str ends-with '.tar.xz') or ($name | str ends-with '.tar.zst') or ($name | str ends-with '.tar') {
    ^tar xf $archive
  } else if ($name | str ends-with '.bz2') {
    ^bunzip2 $archive
  } else if ($name | str ends-with '.rar') {
    ^unrar x $archive
  } else if ($name | str ends-with '.gz') {
    ^gunzip $archive
  } else if ($name | str ends-with '.zip') {
    ^unar $archive
  } else if ($name | str ends-with '.Z') {
    ^uncompress $archive
  } else if ($name | str ends-with '.7z') {
    ^7z x $archive
  } else if ($name | str ends-with '.deb') {
    ^ar x $archive
  } else {
    error make { msg: $"'($archive)' cannot be extracted" }
  }
}

def start [service_name: string] {
  sudo systemctl start $service_name

  while (do { systemctl is-active --quiet $service_name } | complete).exit_code != 0 {
    print 'Waiting for service to start...'
    sleep 1sec
  }

  journalctl --unit $service_name --no-pager --lines 10
}

def --env gm [] {
  let main_exists = (do { git show-ref --verify --quiet refs/heads/main } | complete).exit_code == 0
  git checkout (if $main_exists { 'main' } else { 'master' })
}

def ggc [] {
  git reflog expire --expire-unreachable=now --all
  git gc --prune=now
}

def rr [] {
  let selections = (trash list | fzf --multi | lines)

  for selection in $selections {
    let path = ($selection | split row ' ' | last)
    trash restore --match=exact --force $path
  }
}

def re [] {
  let selections = (trash list | fzf --multi | lines)

  for selection in $selections {
    let path = ($selection | split row ' ' | last)
    trash empty --match=exact --force $path
  }
}
