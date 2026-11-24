#!/bin/sh
# The Catala corpus and toolchain for Phase 3c (corpus.pl), without root:
#   - catala-examples at the commit corpus.pl pins, in .cache/catala-examples;
#   - the Catala team's own nightly build (a pre-release; the twins were
#     built with 1.2.0+git20260822r08832f46b), unpacked in .cache/deb;
#   - OCaml 5.3 with zarith and findlib, and ninja, from Debian's packages,
#     unpacked in ~/ocamlroot (Catala compiles a module's external functions
#     to OCaml), with zig as the C compiler and assembler (the zig of
#     ../rulespec/fetch_oracle.sh) through two wrappers;
#   - each module of the programmes built and tested once (clerk test), so
#     the interpreter finds its compiled objects.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
C=$HERE/.cache
mkdir -p "$C"

# The corpus.
COMMIT=e67e42414c8bcd2dca450a6a21c94db593fc909b
[ -d "$C/catala-examples" ] || git clone -q https://github.com/CatalaLang/catala-examples.git "$C/catala-examples"
git -C "$C/catala-examples" checkout -q $COMMIT

# Catala.
if [ ! -x "$C/deb/usr/bin/catala" ]; then
  URL=$(curl -s https://api.github.com/repos/CatalaLang/catala/releases/tags/nightly \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["assets"][0]["browser_download_url"])')
  curl -sL -o "$C/catala.deb" "$URL"
  mkdir -p "$C/deb" && dpkg-deb -x "$C/catala.deb" "$C/deb"
fi
ln -sfn x86_64-linux-gnu/ocaml/5.3.0/catala "$C/deb/usr/lib/catala"

# OCaml 5.3.0, zarith, findlib and ninja, as a user. The Catala package above
# is built for OCaml 5.3.0, so the compiler and the libraries must be that
# version exactly: the packages are taken from Debian's pool by name and
# version, not from whatever the machine's own distribution happens to carry
# (Ubuntu 26.04 moved to OCaml 5.4 on 9 October 2026, which does not read
# Catala's compiled objects).
OCAMLVER=5.3.0
R=$HOME/ocamlroot
D=http://ftp.debian.org/debian/pool/main
DEBS="
$D/o/ocaml/ocaml_5.3.0-3_amd64.deb
$D/o/ocaml/ocaml-base_5.3.0-3_amd64.deb
$D/o/ocaml/ocaml-interp_5.3.0-3_amd64.deb
$D/o/ocaml/libstdlib-ocaml_5.3.0-3_amd64.deb
$D/o/ocaml/libstdlib-ocaml-dev_5.3.0-3_amd64.deb
$D/o/ocaml-zarith/libzarith-ocaml_1.14-1+b2_amd64.deb
$D/o/ocaml-zarith/libzarith-ocaml-dev_1.14-1+b2_amd64.deb
$D/f/findlib/ocaml-findlib_1.9.8-1+b1_amd64.deb
$D/f/findlib/libfindlib-ocaml_1.9.8-1+b1_amd64.deb
$D/f/findlib/libfindlib-ocaml-dev_1.9.8-1+b1_amd64.deb
"
if [ ! -d "$R/usr/lib/x86_64-linux-gnu/ocaml/$OCAMLVER" ]; then
  mkdir -p "$R/debs"
  for u in $DEBS; do
    f=$R/debs/$(basename "$u")
    [ -f "$f" ] || curl -sLo "$f" "$u"
  done
  for d in "$R"/debs/*.deb; do dpkg-deb -x "$d" "$R"; done
fi
# ninja and the C headers from the machine's own packages (no OCaml in them).
A=$HOME/apt
O="-o Dir::State::Lists=$A/lists -o Dir::Cache=$A/cache -o Debug::NoLocking=1"
if [ ! -x "$R/usr/bin/ninja" ]; then
  mkdir -p "$A/lists/partial" "$A/cache/archives/partial" "$R/debs2"
  apt-get $O update >/dev/null 2>&1 || true
  (cd "$R/debs2" && apt-get $O download libgmp-dev ninja-build >/dev/null 2>&1) || true
  for d in "$R"/debs2/*.deb; do dpkg-deb -x "$d" "$R"; done
fi
L=$R/usr/lib/x86_64-linux-gnu/ocaml/$OCAMLVER
ln -sfn "$L/zarith" "$C/deb/usr/lib/zarith"
# The C compiler and assembler OCaml calls. A machine with its own gcc uses
# it; one without (the build machine of 5 October 2026) uses zig through two
# wrappers. Either way the headers and libraries unpacked above are on the
# search path.
mkdir -p "$R/wrap"
# (the wrappers are put first on PATH under the names OCaml calls, so the
# real tools must be named by their absolute paths, or a wrapper would call
# itself)
if command -v gcc >/dev/null 2>&1; then
  CCMD="$(command -v gcc)"
  ASCMD="$(command -v as)"
else
  ZIG=$HOME/.local/zig/ziglang/zig
  [ -x "$ZIG" ] || { echo "no gcc and no zig at $ZIG" >&2; exit 1; }
  CCMD="$ZIG cc -target x86_64-linux-gnu.2.41"
  ASCMD="$ZIG cc -target x86_64-linux-gnu.2.41 -c -x assembler"
fi
cat > "$R/wrap/x86_64-linux-gnu-gcc" <<EOF
#!/bin/sh
exec $CCMD -L$R/usr/lib/x86_64-linux-gnu -I$R/usr/include -I$R/usr/include/x86_64-linux-gnu "\$@"
EOF
cat > "$R/wrap/x86_64-linux-gnu-as" <<EOF
#!/bin/sh
out=""; src=""
while [ \$# -gt 0 ]; do case "\$1" in -o) out="\$2"; shift 2;; -*) shift;; *) src="\$1"; shift;; esac; done
exec $ASCMD "\$src" -o "\$out"
EOF
chmod +x "$R/wrap/x86_64-linux-gnu-gcc" "$R/wrap/x86_64-linux-gnu-as"
ln -sf x86_64-linux-gnu-gcc "$R/wrap/gcc"; ln -sf x86_64-linux-gnu-gcc "$R/wrap/cc"; ln -sf x86_64-linux-gnu-as "$R/wrap/as"
cat > "$R/findlib.conf" <<EOF
destdir="$L"
path="$L"
ocamlc="ocamlc.opt"
ocamlopt="ocamlopt.opt"
ocamldep="ocamldep.opt"
ldconf="ignore"
EOF
cat > "$R/env.sh" <<EOF
export PATH=$R/wrap:$R/usr/bin:$C/deb/usr/bin:\$PATH
export OCAMLLIB=$L
export OCAMLFIND_CONF=$R/findlib.conf
export CAML_LD_LIBRARY_PATH=$L/stublibs
EOF

# Build and test the modules the programmes use. `clerk test` builds the
# objects of a folder that has test scopes; a module without them (Bmaf) is
# built by naming its compiled object, which the generated cases of
# corpus.pl need in order to run.
. "$R/env.sh"
cd "$C/catala-examples"
clerk start >/dev/null 2>&1 || true
clerk test us_tax_code smic prologue_france base_mensuelle_allocations_familiales prestations_familiales aides_logement 2>&1 | grep -E "files |tests " || true
for m in base_mensuelle_allocations_familiales/ocaml/Bmaf smic/ocaml/Smic prologue_france/ocaml/France; do
  clerk build "_build/$m.cmxs" >/dev/null 2>&1 || true
done
