# Email (Brevo)

The server can send email through [Brevo](https://www.brevo.com)'s
transactional email service. The module is `le_email.pl`; it posts each
message to Brevo's `POST /v3/smtp/email` endpoint
([reference](https://developers.brevo.com/reference/sendtransacemail)).

Email is **off unless the server's environment configures it**, which only
the deployed server's does (fly secrets, §3). With no variable set,
`email_configured/0` fails and nothing is sent.

Today one part of the system sends email: the Contract Assistant (lpsPlus
`contract_assistant/ca_email.pl`). Its setup page has an optional field
**Send the results by email**. When the field holds a valid address:

- a run that finishes sends a message with a zip file: `results/` (the
  program, or each program of a set, and the ledger) and `inputs/` (the
  documents as text, and the additional instructions);
- a run that stops with an error sends a message with the reason, and the
  error goes to Sentry ([telemetry.md](telemetry.md)), with the tag
  `operation: contract_assistant`;
- a run that the user cancels sends nothing.

The address is kept only in the browser (`localStorage`, slot
`le-ca-notify-email`). The server holds it in the job's memory until the
message has gone, then forgets it. It never writes the address to disk or to
the run's log. A zip larger than 10 MB is not attached: the message gives the
link to the run instead.

## 1. The variables

| Variable | Needed | What it is |
|---|---|---|
| `LE_BREVO_API_KEY` | yes | the Brevo account's API key (`xkeysib-…`), from *SMTP & API ▸ API Keys* |
| `LE_EMAIL_SENDER` | yes | the sender's address, for example `noreply@logicalcontracts.com` |
| `LE_EMAIL_SENDER_NAME` | no | the sender's name; default `Logical English` |
| `LE_BREVO_SANDBOX` | no | `true`: Brevo checks each message and delivers none (for tests) |

Both the key and the sender are necessary. Brevo sends only from an address,
or from a domain, that the account has verified.

## 2. Setting up the Brevo account

1. **Sender.** In Brevo, open *Senders, Domains & Dedicated IPs*. Add the
   sender's address and confirm the email that Brevo sends to it. Better:
   add and authenticate the whole domain (the DKIM and DMARC records that
   Brevo shows go into the domain's DNS). Messages from an authenticated
   domain do not go to spam folders as often.
2. **API key.** In *SMTP & API ▸ API Keys*, make a key for the server. Use a
   different key for local tests, so that you can revoke one without the
   other.
3. **Authorised IP addresses.** By default, Brevo refuses a key that is used
   from an IP address that it does not know. It answers `401 unauthorized`,
   "We have detected you are using an unrecognised IP address". A fly.io
   machine has no fixed outgoing address: its address can change when the
   machine is moved or made again. Thus, in *Security ▸ Authorised IPs*,
   **deactivate the blocking of unknown IP addresses** for the account. If
   the account must keep the blocking, give the app a static egress address
   (`fly ips allocate-egress -a logicalenglish2`), and authorise that address.

## 3. Setting the variables on fly.io

The app is `logicalenglish2` (`fly.toml`). The key is a secret: keep it out
of `fly.toml` and out of the image.

```sh
fly secrets set -a logicalenglish2 \
    LE_BREVO_API_KEY='xkeysib-…' \
    LE_EMAIL_SENDER='noreply@logicalcontracts.com' \
    LE_EMAIL_SENDER_NAME='Logical English'
fly secrets list -a logicalenglish2        # names and digests, to check
```

`fly secrets set` restarts the machine with the new values. Add `--stage` to
apply them at the next `fly deploy` instead. **The restart stops every
Contract Assistant run that is in progress**, so set the secrets when no run
is in progress, or use `--stage`. To turn email off:
`fly secrets unset -a logicalenglish2 LE_BREVO_API_KEY`.

For a local test, export the variables in the shell that starts the server.
Add `LE_BREVO_SANDBOX=true` to check the messages without delivering them.

## 4. Checking it works

- **The page.** Open the Contract Assistant. When the server cannot send
  email, a note under **Send the results by email** says so. (The page asks
  the server through the `contract_cost_estimate` operation, whose reply has
  `email: true` or `email: false`.)
- **A message.** From a shell with the variables set:

  ```sh
  swipl -g "use_module(le_email), \
            send_email('you@example.com', \"Test\", \"A test.\", [], R), \
            print(R), nl, halt."
  ```

  `sent("<…@smtp-relay.mailin.fr>")` means that Brevo accepted the message.
  `error("Brevo answered 401: …")` gives Brevo's reason: a wrong key, an
  unknown IP address (§2, step 3), or a sender that is not verified.
- **A run.** Each run's log says what became of its message: "Email with the
  results sent", "The email … could not be sent: …" (also reported to
  Sentry), or "No email sent: …".

## 5. Limits

- A run that the server loses (the server stopped or restarted during the
  run) sends no message: nothing runs to send it.
- Brevo's plan sets how many messages a day the account can send.
- The message texts are in English (`ca_email.pl`), like the rest of the
  Contract Assistant's page.
