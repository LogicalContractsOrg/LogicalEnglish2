/** <module> Email, sent through Brevo's transactional email service

    Off unless the server's environment configures it, which only the
    deployed server's does (fly secrets). docs/dev/email.md says how to set
    it up.

        LE_BREVO_API_KEY        the key of the Brevo account (xkeysib-...)
        LE_EMAIL_SENDER         the sender's address; Brevo sends only from
                                an address or a domain verified in the account
        LE_EMAIL_SENDER_NAME    default `Logical English`
        LE_BREVO_SANDBOX        `true`: Brevo checks each message and sends
                                none of them (for tests)

    The message goes to https://api.brevo.com/v3/smtp/email as JSON, with a
    30-second timeout. send_email/5 never throws: what happened is its
    result. Nothing here logs an address or a message's text.

    For tests, email_send_hook/1 replaces the call to Brevo: a closure
    called as call(Closure, Payload, Result), where Payload is the JSON dict
    that would have been posted.
*/

:- module(le_email, [
    email_configured/0,
    valid_email_address/1,      % +Text
    send_email/5                % +To, +Subject, +Text, +Options, -Result
]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(base64)).
:- use_module(library(readutil)).
:- use_module(library(pcre)).
:- use_module(library(http/http_open)).
:- ( catch(use_module(library(http/http_ssl_plugin)), _, true) -> true ; true ).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.

:- dynamic email_send_hook/1.

brevo_url('https://api.brevo.com/v3/smtp/email').

		 /*******************************
		 *         CONFIGURATION        *
		 *******************************/

setting(Name, Value) :-
    atom_concat('LE_', Name, Var),
    getenv(Var, V0),
    normalize_space(atom(Value), V0),
    Value \== ''.

%!  email_configured is semidet.
%
%   True when this server can send email: a key and a sender, or a test
%   hook.
email_configured :-
    email_send_hook(_), !.
email_configured :-
    setting('BREVO_API_KEY', _),
    setting('EMAIL_SENDER', Sender),
    valid_email_address(Sender).

sender(_{email: Email, name: Name}) :-
    ( setting('EMAIL_SENDER', Email) -> true ; Email = 'noreply@example.com' ),
    ( setting('EMAIL_SENDER_NAME', Name) -> true ; Name = 'Logical English' ).

sandbox :-
    setting('BREVO_SANDBOX', V),
    downcase_atom(V, true).

%!  valid_email_address(+Text) is semidet.
%
%   One address, of the shape name@domain.tld, with no spaces, no commas and
%   no angle brackets, at most 254 characters: a field that holds anything
%   else is not sent to.
valid_email_address(Text) :-
    ( string(Text) ; atom(Text) ), !,
    atom_string(Text, S),
    string_length(S, L), L =< 254,
    re_match("^[^@\\s,;<>\"()\\[\\]]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*\\.[A-Za-z]{2,}$", S).

		 /*******************************
		 *            SENDING           *
		 *******************************/

%!  send_email(+To, +Subject, +Text, +Options, -Result) is det.
%
%   Sends a plain-text message to one address. Options:
%
%     - attachments(List): attachment(Name, File) terms, each file sent as
%       it is (Brevo accepts only some extensions; `.zip` is one);
%     - html(Html): an HTML version of the text.
%
%   Result is sent(MessageId), not_configured, invalid_address or
%   error(Message).
send_email(To, Subject, Text, Options, Result) :-
    catch(send_email_(To, Subject, Text, Options, Result0), E,
          ( message_to_string(E, M), Result0 = error(M) )),
    !,
    Result = Result0.
send_email(_, _, _, _, error("the message could not be built")).

send_email_(To, _, _, _, invalid_address) :-
    \+ valid_email_address(To), !.
send_email_(_, _, _, _, not_configured) :-
    \+ email_configured, !.
send_email_(To, Subject, Text, Options, Result) :-
    sender(Sender),
    atom_string(To, ToS),
    P0 = _{sender: Sender, to: [_{email: ToS}], subject: Subject, textContent: Text},
    ( memberchk(html(Html), Options) -> P1 = P0.put(htmlContent, Html) ; P1 = P0 ),
    ( memberchk(attachments(As), Options) -> true ; As = [] ),
    maplist(attachment_json, As, Js),
    ( Js == [] -> P2 = P1 ; P2 = P1.put(attachment, Js) ),
    ( sandbox -> Payload = P2.put(headers, _{'X-Sib-Sandbox': drop}) ; Payload = P2 ),
    (   email_send_hook(Hook)
    ->  call(Hook, Payload, Result)
    ;   post_to_brevo(Payload, Result)
    ).

attachment_json(attachment(Name, File), _{name: NameS, content: B64}) :-
    atom_string(Name, NameS),
    read_file_to_codes(File, Codes, [type(binary)]),
    phrase(base64(Codes), B64Codes),
    string_codes(B64, B64Codes).

message_to_string(E, M) :-
    catch(message_to_codes(E, _, Codes), _, fail), !,
    string_codes(M, Codes).
message_to_string(E, M) :-
    format(string(M), '~W', [E, [max_depth(6), quoted(true)]]).

message_to_codes(E, _, Codes) :-
    '$messages':translate_message(E, Lines, []),
    with_output_to(codes(Codes), print_message_lines(current_output, '', Lines)).

post_to_brevo(Payload, Result) :-
    setting('BREVO_API_KEY', Key),
    brevo_url(Url),
    with_output_to(string(Body), json_write_dict(current_output, Payload, [width(0)])),
    setup_call_cleanup(
        http_open(Url, In,
                  [ method(post),
                    post(string('application/json', Body)),
                    request_header('api-key'=Key),
                    request_header(accept='application/json'),
                    timeout(30), status_code(Code) ]),
        read_string(In, _, Reply),
        close(In)),
    brevo_result(Code, Reply, Result).

%   201 (sent) or 202 (scheduled): the message id. Otherwise Brevo's own
%   message, which says what it refused (the sender, the key, the address).
brevo_result(Code, Reply, sent(Id)) :-
    between(200, 299, Code), !,
    (   catch(atom_json_dict(Reply, D, []), _, fail),
        ( get_dict(messageId, D, Id) -> true
        ; get_dict(messageIds, D, [Id|_]) )
    ->  true
    ;   Id = ""
    ).
brevo_result(Code, Reply, error(Msg)) :-
    (   catch(atom_json_dict(Reply, D, []), _, fail),
        get_dict(message, D, M)
    ->  format(string(Msg), "Brevo answered ~w: ~w", [Code, M])
    ;   format(string(Msg), "Brevo answered ~w", [Code])
    ).
