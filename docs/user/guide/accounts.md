# Signing in, and what a licence adds

*Kind: guide · Audience: everyone who uses the hosted editor · Status: current (2026-10-04)*

You do not need an account to use Logical English. All the functions in this
documentation operate without a sign-in. The only exceptions are the few functions
that the section *The two licences* gives below.

## One sign-in for Logical English and LPS

The hosted Logical English editor (`le2.logicalcontracts.com`) and the hosted LPS
editor (`lps2.logicalcontracts.com`) use one sign-in together. LPS is short for Logic
Production Systems. LPS is the sister language for programs that act over time. When
you sign in on one site, you are also signed in on the other site. When you sign out
on one site, you are signed out on the two sites.

To sign in, do one of these steps:

1. Click **Login** at the top right of the start page or of the executive view.
2. Alternatively, open the page `/login`.

You can sign in in three ways:

- **Sign in with Google**, with any Google account.
- **Sign in with GitHub**, with any GitHub account.
- **An email address and a password** that Logical Contracts made for you. You
  cannot make an email address and password of this type yourself. Use Google or
  GitHub instead.

Google and GitHub tell us your email address and nothing more. We do not see your
password for Google or for GitHub.

A sign-in stays valid for 14 days, or until you click **Logout**.

## The two licences

When you sign in, the site can find the licences for your email address. Each
licence has an expiry date.

| Licence | What it adds |
|---|---|
| **Logical English Translators** | The translators of other systems. With these translators, **File ▸ Open** opens a file for another rules system (for example Oracle Intelligent Advisor, Socotra, Blawx or Drools). **File ▸ Export** writes a program for such a system. The licence also adds the **LE Contract Assistant**. The Contract Assistant writes the first draft of a program from a contract, its schedules and its cases ([the assistants](assistants.md#the-contract-assistant)). The licence also adds the private example programs. These include the programs that the translators wrote from sources that we possibly cannot publish. In the LPS editor, the licence also adds **Deploy as Solidity** and the Drools reader. |
| **InsurLE** | The InsurLE language extensions. These extensions are: a *which* in the conclusion of a rule, conditions that start with *unless*, groups of conditions below *either*, *any of* or *all of*, and conditions with the numbers 1., 2., 3. The licence also adds the example programs of InsurLE. |

A person can have one licence, the other licence, or the two licences. To obtain a
licence, speak to logicalcontracts.com.

## What you see without a licence

- **File ▸ Open** accepts only Logical English files. **File ▸ Export** does not
  give other systems.
- The page of the Contract Assistant tells you the licence that it is part of. The
  page also lets you sign in.
- The private examples are not in the list. A link to a private example sends you to
  the sign-in page. If your account has the licence, the site then sends you back to
  the example.
- A program can give numbers to its conditions (`if:` followed by `1.`, `2.`, ...).
  Such a program shows an error on each rule of this type. The error tells you that
  numbered conditions are part of the InsurLE licence. Without the licence, LE reads
  each such rule as never true. Thus the program never gives an incorrect answer
  because of a construct that LE could not read. You can write the same conditions
  one after the other, with *and* and *or* between them. Then the rule operates for
  all persons.
- LE does not recognise the other InsurLE constructs, for example a *which* in a
  conclusion. The editor reports such a sentence as a sentence that it cannot match
  to a template. A template is a sentence pattern. You declare the templates at the
  start of a program, and each sentence of the program must agree with a template.

## What the sites keep about you

- In your browser: a small file with the name `lc_session`. This type of file is a
  cookie. The cookie holds your email address and the method that you used to sign
  in, for 14 days. With this cookie, the two sites can recognise you. While you sign
  in with Google or GitHub, a second cookie, `lc_oauth`, stays for a maximum of ten
  minutes.
- On the sites: nothing, if you do not have a licence. If you have a licence, the
  licences table holds your email address, the licence, and its expiry date.

The site does not keep the programs that you write with your account.

The [privacy notice](../privacy.md) gives the same information in full. It tells you
who is responsible, which other companies use the data, and how to have your data
removed.
