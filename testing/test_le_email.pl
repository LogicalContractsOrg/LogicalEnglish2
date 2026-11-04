/* test_le_email.pl — le_email.pl: the addresses it accepts, the message it
   would post to Brevo, and how it reads Brevo's answers. No message is
   sent: email_send_hook/1 replaces the call to Brevo.
*/

:- use_module(library(plunit)).
:- use_module('../le_email').

:- dynamic email_test_payload/1.

email_test_hook(Payload, sent("<test@brevo>")) :-
    assertz(email_test_payload(Payload)).

email_test_setup :-
    retractall(email_test_payload(_)),
    retractall(le_email:email_send_hook(_)),
    assertz(le_email:email_send_hook(user:email_test_hook)).

email_test_cleanup :-
    retractall(le_email:email_send_hook(_)).

:- begin_tests(le_email, [setup(email_test_setup), cleanup(email_test_cleanup)]).

test(valid_addresses) :-
    forall(member(A, ["ann@example.com", 'bob.smith+le@mail.example.co.uk', "x_y@a-b.io"]),
           assertion(valid_email_address(A))),
    forall(member(A, ["", "ann", "ann@example", "ann @example.com", "a@b.com, c@d.com",
                      "Ann <ann@example.com>", "ann@-example.com", 42]),
           assertion(\+ valid_email_address(A))).

test(payload_with_attachment) :-
    tmp_file(email, F),
    setup_call_cleanup(open(F, write, O, [type(binary)]), format(O, "PKzip", []), close(O)),
    send_email("ann@example.com", "Subject", "Body", [attachments([attachment('r.zip', F)])], R),
    assertion(R == sent("<test@brevo>")),
    email_test_payload(P),
    P.to = [To], assertion(To.email == "ann@example.com"),
    assertion(P.subject == "Subject"),
    assertion(P.textContent == "Body"),
    assertion(get_dict(email, P.sender, _)),
    P.attachment = [A],
    assertion(A.name == "r.zip"),
    base64(Decoded, A.content),
    assertion(Decoded == 'PKzip').

test(invalid_address_not_sent) :-
    retractall(email_test_payload(_)),
    send_email("not an address", "S", "B", [], R),
    assertion(R == invalid_address),
    assertion(\+ email_test_payload(_)).

test(not_configured_without_key) :-
    retractall(le_email:email_send_hook(_)),
    unsetenv('LE_BREVO_API_KEY'),
    send_email("ann@example.com", "S", "B", [], R),
    assertz(le_email:email_send_hook(user:email_test_hook)),
    assertion(R == not_configured).

test(brevo_answers) :-
    le_email:brevo_result(201, "{\"messageId\":\"<m1@smtp-relay>\"}", R1),
    assertion(R1 == sent("<m1@smtp-relay>")),
    le_email:brevo_result(401, "{\"code\":\"unauthorized\",\"message\":\"Key not found\"}", R2),
    assertion(R2 == error("Brevo answered 401: Key not found")),
    le_email:brevo_result(500, "oops", R3),
    assertion(R3 == error("Brevo answered 500")).

:- end_tests(le_email).
