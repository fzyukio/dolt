#!/usr/bin/env bats
load $BATS_TEST_DIRNAME/helper/common.bash

setup() {
    setup_common
    TMPDIRS=$(pwd)/tmpdirs
    mkdir -p $TMPDIRS/{rem1,repo1}

    # repo1 -> rem1 -> repo2
    cd $TMPDIRS/repo1
    dolt init
    dolt remote add origin file://../rem1
    dolt remote add test-remote file://../rem1
    dolt push origin main

    cd $TMPDIRS
    dolt clone file://rem1 repo2
    cd $TMPDIRS/repo2
    dolt branch feature
    dolt remote add test-remote file://../rem1

    # table and commits only present on repo1, rem1 at start
    cd $TMPDIRS/repo1
    dolt sql -q "create table t1 (a int primary key, b int)"
    dolt add .
    dolt commit -am "First commit"
    dolt sql -q "insert into t1 values (0,0)"
    dolt commit -am "Second commit"
    dolt branch feature
    dolt push origin main
    cd $TMPDIRS
}

teardown() {
    teardown_common
    rm -rf $TMPDIRS
    cd $BATS_TMPDIR
}

@test "fetch: basic fetch" {
    cd repo2
    dolt fetch

    run dolt diff main origin/main
    [ "$status" -eq 0 ]
    [[ "$output" =~ "added table" ]] || false

    run dolt sql -q "show tables as of hashof('origin/main')" -r csv
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" =~ "Table" ]] || false
    [[ "$output" =~ "t1" ]] || false
}

@test "fetch: fetch origin" {
    cd repo2
    dolt fetch origin

    run dolt diff main origin/main
    [ "$status" -eq 0 ]
    [[ "$output" =~ "added table" ]] || false

    run dolt sql -q "show tables as of hashof('origin/main')" -r csv
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" =~ "Table" ]] || false
    [[ "$output" =~ "t1" ]] || false
}

@test "fetch: fetch main" {
    cd repo2
    dolt fetch origin main

    run dolt diff main origin/main
    [ "$status" -eq 0 ]
    [[ "$output" =~ "added table" ]] || false

    run dolt sql -q "show tables as of hashof('origin/main')" -r csv
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" =~ "Table" ]] || false
    [[ "$output" =~ "t1" ]] || false
}

@test "fetch: fetch custom remote" {
    cd repo2
    dolt fetch test-remote

   run dolt diff main test-remote/main
    [ "$status" -eq 0 ]
    [[ "$output" =~ "added table" ]] || false

    run dolt sql -q "show tables as of hashof('test-remote/main')" -r csv
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" =~ "Table" ]] || false
    [[ "$output" =~ "t1" ]] || false
}

@test "fetch: fetch specific ref" {
    cd repo2
    dolt fetch test-remote refs/heads/main:refs/remotes/test-remote/main

    run dolt diff main test-remote/main
    [ "$status" -eq 0 ]
    [[ "$output" =~ "added table" ]] || false

    run dolt sql -q "show tables as of hashof('test-remote/main')" -r csv
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" =~ "Table" ]] || false
    [[ "$output" =~ "t1" ]] || false
}

@test "fetch: fetch feature branch" {
    cd repo1
    dolt push origin feature

    cd ../repo2
    dolt fetch origin feature

    run dolt diff main origin/feature
    [ "$status" -eq 0 ]
    [[ "$output" =~ "added table" ]] || false

    run dolt sql -q "show tables as of hashof('origin/feature')" -r csv
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" =~ "Table" ]] || false
    [[ "$output" =~ "t1" ]] || false
}

@test "fetch: fetch tag" {
    cd repo1
    dolt tag v1
    dolt push origin v1

    cd ../repo2
    dolt fetch origin main

    run dolt diff main v1
    [ "$status" -eq 0 ]
    [[ "$output" =~ "added table" ]] || false

    run dolt sql -q "show tables as of hashof('v1')" -r csv
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" =~ "Table" ]] || false
    [[ "$output" =~ "t1" ]] || false
}

@test "fetch: fetch only tag" {
    skip "todo tag refspec support, and/or --tags option"
    cd repo1
    dolt tag v1
    dolt push origin v1

    cd ../repo2
    dolt fetch origin refs/tags/v1:refs/tags/v1

    run dolt diff main origin/v1
    [ "$status" -eq 0 ]
    [[ "$output" =~ "added table" ]] || false

    run dolt sql -q "show tables as of hashof('v1')" -r csv
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" =~ "Table" ]] || false
    [[ "$output" =~ "t1" ]] || false
}

@test "fetch: fetch rename ref" {
    cd repo2
    dolt fetch test-remote refs/heads/main:refs/remotes/test-remote/other

    run dolt diff main test-remote/other
    [ "$status" -eq 0 ]
    [[ "$output" =~ "added table" ]] || false

    run dolt sql -q "show tables as of hashof('test-remote/other')" -r csv
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" =~ "Table" ]] || false
    [[ "$output" =~ "t1" ]] || false
}

@test "fetch: fetch override local branch" {
    skip "todo more flexible refspec support"
    cd repo2
    dolt fetch origin main:refs/heads/main

    dolt diff main origin/main
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "removed table" ]] || false

    run dolt sql -q "show tables as of hashof('main')" -r csv
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" =~ "Table" ]] || false
    [[ "$output" =~ "t1" ]] || false
}

@test "fetch: fetch with forced commit" {
    # reverse information flow for force fetch repo1->rem1->repo2
    cd repo2
    dolt sql -q "create table t2 (a int)"
    dolt add .
    dolt commit -am "forced commit"
    dolt push --force origin main
    cd ../repo1

    run dolt fetch origin main
    [ "$status" -eq 0 ]

    run dolt diff main origin/main
    [ "$status" -eq 0 ]
    [[ "$output" =~ "deleted table" ]] || false

    run dolt sql -q "show tables as of hashof('origin/main')" -r csv
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" =~ "Table" ]] || false
    [[ "$output" =~ "t2" ]] || false
}

@test "fetch: fetch --prune deletes remote refs not on remote" {
    mkdir firstRepo
    mkdir secondRepo

    cd firstRepo
    dolt init
    dolt remote add origin file://../remote1
    dolt remote add remote2 file://../remote2
    dolt branch b1
    dolt branch b2
    dolt push origin main
    dolt push remote2 main
    dolt push origin b1
    dolt push remote2 b2

    cd ..
    dolt clone file://./remote1 secondRepo

    cd secondRepo
    run dolt branch -va
    [[ "$output" =~ "main" ]] || false

    dolt remote add remote2 file://../remote2
    dolt fetch
    dolt fetch remote2

    run dolt branch -r
    [ "$status" -eq 0 ]
    [[ "$output" =~ "origin/b1" ]] || false
    [[ "$output" =~ "remote2/b2" ]] || false

    # delete the branches on the remote
    cd ../firstRepo
    dolt push origin :b1
    dolt push remote2 :b2

    cd ../secondRepo
    dolt fetch --prune

    # prune should have deleted the origin/b1 branch, but not the one on the other remote
    run dolt branch -r
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "origin/b1" ]] || false
    [[ "$output" =~ "remote2/b2" ]] || false

    # now the other remote
    dolt fetch --prune remote2

    run dolt branch -r
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "origin/b1" ]] || false
    [[ ! "$output" =~ "remote2/b2" ]] || false

    run dolt fetch --prune remote2 refs/heads/main:refs/remotes/remote2/othermain
    [ "$status" -ne 0 ]
    [[ "$output" =~ "--prune option cannot be provided with a ref spec" ]] || false
}

@test "fetch: fetch unknown remote fails" {
    cd repo2
    dolt remote remove origin
    run dolt fetch unknown
    [ "$status" -eq 1 ]
    [[ "$output" =~ "unknown remote" ]] || false
}

@test "fetch: fetch unknown remote with fetchspec fails" {
    cd repo2
    dolt remote remove origin
    run dolt fetch unknown main
    [ "$status" -eq 1 ]
    [[ "$output" =~ "unknown remote" ]] || false
}

@test "fetch: fetch unknown ref fails" {
    cd repo2
    run dolt fetch origin unknown
    [ "$status" -eq 1 ]
    [[ "$output" =~ "invalid ref spec: 'unknown'" ]] || false
}

@test "fetch: fetch empty remote fails" {
    cd repo2
    dolt remote remove origin
    run dolt fetch
    [ "$status" -eq 1 ]
    [[ "$output" =~ "unknown remote" ]] || false
}

@test "fetch: fetch empty ref fails" {
    cd repo2
    run dolt fetch origin ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "invalid fetch spec: ''" ]] || false
}

@test "fetch: fetch from remote host fails" {
    run dolt --host hostedHost --port 3306 --user root --password password fetch origin
    [ "$status" -eq 1 ]
    [[ "${lines[0]}" =~ "This command is not supported against a remote host yet." ]] || false
    [[ "${lines[1]}" =~ "If you're interested in running this command against a remote host, hit us up on discord (https://discord.gg/gqr7K4VNKe)." ]] || false

    dolt profile add --host hostedHost --port 3306 --user root --password password hostedProfile
    run dolt --profile hostedProfile fetch origin
    [ "$status" -eq 1 ]
    [[ "${lines[0]}" =~ "This command is not supported against a remote host yet." ]] || false
    [[ "${lines[1]}" =~ "If you're interested in running this command against a remote host, hit us up on discord (https://discord.gg/gqr7K4VNKe)." ]] || false
}
