#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

@test "It should archive files to the ARCHIVE_DIRECTORY" {
  versions-only ge '9.4'

  mkdir -p ${DATA_DIRECTORY}/tmp
  touch ${DATA_DIRECTORY}/tmp/test.file
  archive.sh "tmp/test.file" "test.file"
  [ -f ${ARCHIVE_DIRECTORY}/test.file ]
}

@test "It should not overwrite existing archived files" {
  versions-only ge '9.4'

  mkdir -p ${DATA_DIRECTORY}/tmp
  touch ${DATA_DIRECTORY}/tmp/test.file
  touch ${ARCHIVE_DIRECTORY}/test.file
  run archive.sh "tmp/test.file" "test.file"
  [ ! "$status" -eq "0" ]
}

@test "It should clean up archived files that more than 2 days old" {
  versions-only ge '9.4'

  THREE_DAYS_AGO=$(date --date="3 days ago" +"%Y%m%d%H%M")
  touch ${ARCHIVE_DIRECTORY}/old.file -t ${THREE_DAYS_AGO}
  archive-cleanup.sh
  [ ! -f ${ARCHIVE_DIRECTORY}/old.file ]
}

@test "It should retain archived files less than 2 days old" {
  versions-only ge '9.4'

  YESTERDAY=$(date --date="1 day ago" +"%Y%m%d%H%M")
  touch ${ARCHIVE_DIRECTORY}/old.file -t ${YESTERDAY}
  archive-cleanup.sh
  [ -f ${ARCHIVE_DIRECTORY}/old.file ]
}

@test "It should have an archive command set" {
  versions-only ge '9.4'

  initialize_and_start_pg
  sudo -u postgres psql db -c'SHOW archive_command;' | grep "archive.sh"
}

@test "It should have have archive_mode turned on" {
  versions-only ge '9.4'

  initialize_and_start_pg
  sudo -u postgres psql db -c'SHOW archive_mode;' | grep "on"
}

@test "It should not be able to read pagerduty-notify.sh as the postgres user" {
  run sudo -u postgres cat /usr/bin/pagerduty-notify.sh
  [ "$status" -eq "1" ]
}
