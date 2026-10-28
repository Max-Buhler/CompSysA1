#!/usr/bin/env bash

# Builds a directory tree full of awkward inputs for fauxgrep/fhistogram.
# Usage: setup_torture.sh DIR   (DIR must not exist yet)

set -u

root="$1"
[ -e "$root" ] && { echo "refusing to overwrite $root" >&2; exit 1; }
mkdir -p "$root" || exit 1
cd "$root" || exit 1

# Files whose last line has no '\n' glue onto the next printed line when
# several files are searched, which drowns out every other difference.
# They live in their own tree (ROOT.eol) and get a dedicated test section.
mkdir "$root.eol"
printf 'needle' > "$root.eol/one_line_no_newline"
printf 'first needle\nlast line needle' > "$root.eol/no_trailing_newline"
perl -e 'print "z" x 1_500_000, "needle"' > "$root.eol/long_line_no_nl"
for i in 1 2 3 4 5 6 7 8; do printf 'needle %d' "$i" > "$root.eol/f$i"; done

# --- empty things ---------------------------------------------------------
mkdir empty_dir
: > empty_file
mkdir -p nested_empty/a/b/c/d
mkdir wide
for i in $(seq 1 300); do mkdir "wide/d$i"; done
for i in $(seq 1 300 | awk 'NR%25==0'); do echo "needle in wide $i" > "wide/d$i/f"; done

# --- tiny / odd content ---------------------------------------------------
printf 'x' > one_byte
printf 'needle\r\nsecond\r\nneedle again\r\n' > crlf
perl -e 'print "\n" x 1000' > only_newlines
printf 'a\0needle\0b\nneedle after nul\nplain\n' > nul_bytes
perl -e 'for $i (1..40) { print chr($_) for 0..255 }' > all_bytes
perl -e 'print chr(0x80 + $_ % 128) for 1..5000' > high_bit_only
printf 'caf\xc3\xa9 needle \xe2\x9c\x93\n\xff\xfe invalid utf8 needle\n' > utf8_mix

# --- sizes around the 100000 byte merge boundary in fhistogram-mt ---------
for n in 99999 100000 100001 199999 200000 200001; do
  perl -e '$n=shift; print((chr(97+$_%26) . ($_%80==79 ? "\n" : "")) x 1) for 0..$n-1' "$n" \
    | head -c "$n" > "size_$n"
done
# one long line, needle at the very end, with and without newline
perl -e 'print "z" x 1_500_000, "needle\n"' > long_line_1_5MB
# several MB of ordinary lines
perl -e 'print "line $_ lorem ipsum needle? ", ($_%7==0 ? "needle" : "nope"), "\n" for 1..150000' > big_text

# --- lots of small files (more than the job queue capacity of 64) ---------
mkdir many
for i in $(seq 1 700); do
  printf 'file %d\nneedle %d\n' "$i" "$i" > "many/f$i"
done

# --- directory depth ------------------------------------------------------
mkdir deep
(
  cd deep || exit
  for i in $(seq 1 60); do mkdir "level$i" && cd "level$i" || exit; echo "needle depth $i" > f; done
)
# deeper than PATH_MAX: fopen on the full path fails, nothing may crash
mkdir too_deep
(
  cd too_deep || exit
  for i in $(seq 1 300); do mkdir abcdefgh && cd abcdefgh || exit; echo "needle" > f; done
)

# --- awkward file names ---------------------------------------------------
mkdir names
(
  cd names || exit
  echo "needle space" > "with space"
  echo "needle dash" > "-dash"
  echo "needle dashes" > "--"
  echo "needle n" > "-n"
  echo "needle squote" > "it's"
  echo "needle dquote" > 'say "hi"'
  echo "needle tab" > "$(printf 'a\tb')"
  echo "needle newline" > "$(printf 'new\nline')"
  echo "needle unicode" > "ünï©ødé"
  echo "needle glob" > '*glob*'
  echo "needle dollar" > '$HOME'
  echo "needle percent" > '%s%n%d'
  echo "needle colon" > 'a:1: b'
  echo "needle hidden" > .hidden
  echo "needle long" > "$(perl -e 'print "n" x 250')"
  mkdir -- "dir with space" "-dashdir" && echo "needle" > "dir with space/f" && echo "needle" > "./-dashdir/f"
)

# --- links, specials and permissions -------------------------------------
mkdir links
(
  cd links || exit
  echo "needle target" > target
  mkdir target_dir && echo "needle in target_dir" > target_dir/f
  ln -s target link_to_file
  ln -s target_dir link_to_dir
  ln -s link_to_file link_to_link
  ln -s does_not_exist broken
  ln -s self self
  ln -s a b; ln -s b a
  ln -s .. up_loop
  ln -s . dot_loop
  ln -s "$PWD/target" abs_link
  mkfifo fifo
  ln -s fifo link_to_fifo
)
mkdir dup && echo "needle dup" > dup/f && ln -s f dup/g && ln -s f dup/h

mkdir unreadable
echo "needle secret" > unreadable/no_read
chmod 000 unreadable/no_read
echo "needle fine" > unreadable/ok
mkdir unreadable_dir
echo "needle hidden away" > unreadable_dir/f
chmod 000 unreadable_dir

exit 0
