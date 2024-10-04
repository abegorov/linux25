#!/bin/bash

# Если день недели суббота и пользователь не член группы admin,
# то запрещаем вход:
if (($(date +%u) > 5)) && \
  ! id --name --groups "${PAM_USER}" | grep --quiet --word-regexp admin
then
  echo You are not allowed to login on this day of the week!
  exit 1
fi

# Если день не выходной, то подключиться может любой пользователь
exit 0
