# Build the image:
#   docker build -t le2 .
#
# Run locally:
#   docker run -p 3050:3050 le2
#
# Push to Docker Hub:
#   docker tag le2 logicalcontracts/le2:latest
#   docker push logicalcontracts/le2:latest
#
# Pull and run as a server:
#   docker pull logicalcontracts/le2:latest
#   docker run -d -p 8084:3050 --name le2_server logicalcontracts/le2:latest
#

# Use the official SWI-Prolog image as the base
FROM swipl:latest

# Install Node.js, git, opencode, and make. `make` is needed by the s(CASP)
# pack's build step below (its Makefile drives SWI-Prolog itself — it compiles a
# scasp CLI/qlf, no C toolchain — but pack_install fails outright if make is
# absent). poppler-utils is pdftotext, with which the Contract Assistant reads a
# wording that comes as a PDF (lpsPlus contract_assistant/le_contract_assistant.pl,
# ensure_text_file/5, vendored by vendor_lpsplus.sh). python3 runs the Rune
# reader (lpsPlus migration/rune/parser/rosetta2json.py, standard library only)
# when a .rosetta file is opened.
RUN apt-get update && apt-get install -y curl git gnupg make poppler-utils python3 && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g opencode-ai mcp-remote && \
    rm -rf /var/lib/apt/lists/*

# Install the s(CASP) pack so the second execution engine (le_scasp.pl) is
# available on the server. Without this, "See s(CASP)" / the s(CASP) engine
# report "The s(CASP) engine is not installed on this server." Fail the build
# (rather than the running server) if the install or a smoke check does not work.
RUN swipl -q -g "pack_install(scasp, [interactive(false)])" -t halt && \
    swipl -q -g "( exists_source(library(scasp)) -> halt(0) ; halt(1) )"

# Set the working directory in the container
WORKDIR /app

# Copy the Prolog source files and examples into the container
COPY *.pl ./
# The parts of the private lpsPlus repository this server uses — signing in
# and the licences table (accounts/), the translators (migration/) — copied
# there by vendor_lpsplus.sh, which buildPush.sh runs. Without them the image
# still works: every visitor is anonymous and only Logical English's own
# formats are offered (le_plus.pl).
COPY vendor/ ./vendor/
ENV LPS_PLUS_DIR=/app/vendor/lpsplus
# Where LE2 is, for the translators that run in a child process (lpsPlus
# migration/le2_paths.pl looks beside lpsPlus or at /work, neither of which
# exists in this image).
ENV LE2_DIR=/app
# The Solidity door (File ▸ Open of a `.sol`) runs solcjs against
# OpenZeppelin's sources: npm packages, gitignored in lpsPlus and so not
# vendored, installed here for this image's platform. Without them a `.sol`
# opens as a TODO comment (9 October 2026), so the build checks they load.
RUN if [ -f vendor/lpsplus/migration/solidity/package.json ]; then \
      cd vendor/lpsplus/migration/solidity && \
      npm ci --omit=dev --no-audit --no-fund && \
      node -e "require('solc'); require.resolve('@openzeppelin/contracts/package.json')" ; \
    fi
# The Rune door (File ▸ Open of a .rosetta, or a zip of them) translates over
# DRR 7.14.0, whose Rune files and test pack vendor_lpsplus.sh copies from
# lpsPlus's gitignored download: without them a .rosetta opened as a TODO
# comment (18 October 2026), so the build checks they are here; and Export ▸
# Rune loads the model as JSON (.cache/json), without which the export was
# refused for a missing folder (19 October 2026).
RUN if [ -d vendor/lpsplus/migration/rune ]; then \
      ls vendor/lpsplus/migration/rune/.cache/drr/drr/rosetta/*.rosetta > /dev/null && \
      ls vendor/lpsplus/migration/rune/.cache/json/*.json > /dev/null && \
      python3 --version ; \
    fi
# The sheet engine (services/sheet): Formualizer, an Excel formula engine
# compiled to WebAssembly, run by Node. It answers the sheet: services
# address (language.md §17.6) and evaluates workbooks for the spreadsheet
# importer; its npm packages are gitignored, so installed here, and the build
# checks they load. Formualizer imports its .wasm file as a module, which Node
# 20 refuses (ERR_UNKNOWN_FILE_EXTENSION) and Node 22 accepts: hence setup_22.x.
COPY services/ ./services/
RUN cd services/sheet && npm ci --omit=dev --no-audit --no-fund && \
    node --no-warnings -e "import('./sheet_engine.mjs').then(m => m.init())"
# i18n CSV dictionaries: read by le_i18n.pl at load time AND by the editor
# build below (scripts/gen-i18n.cjs generates the TS tables from them)
COPY i18n/ ./i18n/
COPY examples/ ./examples/
COPY llm/ ./llm/
COPY editor/ ./editor/
COPY web_extras/ ./web_extras/
COPY docs/ ./docs/
COPY AGENTS_LE_template.md AGENTS_LE_template.pt.md ./
COPY opencode.json ./

# Set environment variables for opencode
ENV OPENCODE_DANGEROUSLY_SKIP_PERMISSIONS=true

# Build the editor
RUN cd editor && npm install --legacy-peer-deps && npm run build

# The examples' search index (le_examples_search.pl), written now so that the
# first search on the server reads it in milliseconds instead of building it.
RUN swipl -q -g "use_module(le_api), le_examples_search:write_index" -t halt

ARG BUILD_INFO="unknown"
RUN echo "${BUILD_INFO}" > build_info.txt

# Expose the port the server runs on
EXPOSE 3050

# Command to run the plain web server
# We use -g to start the server and -t halt to ensure it stays in the foreground.
# The server runs in its own threads, so we just need to prevent the main thread from exiting.
CMD ["swipl", "-g", "use_module(classic_web_api), start_api_server(3050)", "-t", "repeat, sleep(1000), fail"]
