/** <module> The real spending policies turned into LE twins (Phase 1d)

    Each twin(Id, Options) cites where its policy is published: the
    document, its address, the text excerpt kept in sources/ (so the
    quotation is checked), and the quotation itself. The legends give the
    keys and hashes the names of their roles.
*/

:- module(ms_policies, [twin/2]).

:- use_module(library(lists)).
:- consult(core_wallet_policies).

sipa(source('the Miniscript page', "https://bitcoin.sipa.be/miniscript/", 'sources/sipa_miniscript.txt', Q), Q).

%   1. A 2-of-3 multisig, P2WSH — Bitcoin Core's descriptor documentation.
twin(core_2of3_multisig, [
    title("A 2-of-3 multisig (P2WSH)"),
    policy('wsh(multi(2,03a0434d9e47f3c86235477c7b1ae6ae5d3442d49b1943c2b752a68e2a47e247c7,03774ae7f858a9411e5ef4246b70c65aac5649980be5c17891bbec17895da008cb,03d01115d548e7561b15c38f004d734633687cf4419620095bc5b0f47070afe85a))'),
    legend(['03a0434d9e47f3c86235477c7b1ae6ae5d3442d49b1943c2b752a68e2a47e247c7'-'cosigner A',
            '03774ae7f858a9411e5ef4246b70c65aac5649980be5c17891bbec17895da008cb'-'cosigner B',
            '03d01115d548e7561b15c38f004d734633687cf4419620095bc5b0f47070afe85a'-'cosigner C']),
    paths([two_of_three]),
    source('the Bitcoin Core descriptor documentation', "https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md",
           'sources/core_descriptors.txt',
           "describes a P2WSH *2-of-3* multisig output with keys in the specified order")
]).

%   2. Liana's recovery descriptor: a primary key, or the recovery key after
%   a relative timelock — the real descriptor of Liana's RECOVER.md.
twin(liana_recovery, [
    title("A Liana wallet: a primary key, or a recovery key after a delay"),
    policy("wsh(or_d(pk([a5c6b76e/48'/1'/0'/2']tpubDF5861hj6vR3iJr3aPjGJz4rNbqDCRujQ21mczzKT5SiedaQqNVgHC8HT9ceyxvMFRoPMx4P6HAcL3NZrUPhRUbwCyj3TKSa64bAfnE3sLh/<0;1>/*),and_v(v:pkh([c477fd13/48'/1'/0'/2']tpubDFn7iPbFqGrTQ2aRACNsUK1MXQR4Z6dYfU2nD1WA9ifSaia642j3Wah4n5pBUEpERNWGJsyv3Dv5qwBabC9TLQrwSboKzukw9wmurGu7XVH/<0;1>/*),older(3))))#8ldsjayd"),
    legend(['a5c6b76e'-'the primary key', 'c477fd13'-'the recovery key']),
    paths([primary, recovery]),
    source('the Liana recovery guide', "https://github.com/wizardsardine/liana/blob/master/doc/RECOVER.md",
           'sources/liana_recover.txt',
           "Your Liana wallet descriptor is probably of the form")
]).

%   3. Liana's inheritance configuration, from the README's prose. The
%   policy is ours: the README states the delays in years and months.
twin(liana_inheritance, [
    title("A Liana inheritance wallet: the wallet manager, or two of the family after a year, or a third party after fifteen months"),
    policy("or(99@pk(manager),or(9@and(thresh(2,pk(spouse),pk(first_child),pk(second_child)),older(52560)),and(pk(third_party),older(65535))))"),
    legend([manager-'the wallet manager', spouse-'the spouse', first_child-'the elder child',
            second_child-'the younger child', third_party-'the third party']),
    paths([manager, family, third_party]),
    quotes([manager-"Wallet Manager's key (can always spend)",
            family-"Any 2 keys from the owner's spouse and two kids (after 1 year)",
            third_party-"A third party, in case [all else failed](https://wizardsardine.com/liana/plans#section-safety-net)"]),
    notes([family-"the README says: any 2 keys from the owner's spouse and two kids (after 1 year); the policy is our reading of that sentence, the year taken as 52560 blocks (144 a day)",
           third_party-"the README says: a third party (after 1 year and 3 months); taken as 65535 blocks, the longest relative lock BIP 68 allows (about 455 days: one day short of 1 year and 3 months at 144 blocks a day; 65664 blocks, the literal reading, is not a relative lock — consensus would read it as 128 blocks)",
           older(52560)-"1 year at 144 blocks a day: the network's average, not a calendar year",
           older(65535)-"the longest relative lock in blocks (BIP 68), about 455 days"]),
    source('the Liana README', "https://github.com/wizardsardine/liana#about",
           'sources/liana_readme.txt',
           "Any 2 keys from the owner's spouse and two kids (after 1 year)")
]).

%   4. A user and a co-signing (2FA) service, the user alone after 90 days
%   — the custody pattern of co-signing services.
twin(cosigning_service, [
    title("A user and a co-signing service, the user alone after 90 days"),
    policy("and(pk(key_user),or(99@pk(key_service),older(12960)))"),
    legend([key_user-'the user', key_service-'the cosigning service']),
    paths([user_and_service]),
    source(D, U, F, Q)
]) :- sipa(source(D, U, F, Q), "A user and a 2FA service need to sign off, but after 90 days the user alone is enough").

%   5. A decaying multisig: 3-of-3 that turns into 2-of-3 after 90 days.
twin(decaying_multisig, [
    title("A 3-of-3 multisig that turns into a 2-of-3 after 90 days"),
    policy("thresh(3,pk(key_1),pk(key_2),pk(key_3),older(12960))"),
    legend([key_1-'key 1', key_2-'key 2', key_3-'key 3']),
    paths([decaying_threshold]),
    source(D, U, F, Q)
]) :- sipa(source(D, U, F, Q), "A 3-of-3 that turns into a 2-of-3 after 90 days").

%   6. A 4-of-4 decaying at each halving height — Bitcoin Core's descriptor
%   documentation (absolute lock times).
twin(halving_decay, [
    title("A 4-of-4 that decays to 3, 2 and 1 of 4 at each of the next halvings"),
    policy("wsh(thresh(4,pk([7258e4f9/44h/1h/0h]tpubDCZrkQoEU3845aFKUu9VQBYWZtrTwxMzcxnBwKFCYXHD6gEXvtFcxddCCLFsEwmxQaG15izcHxj48SXg1QS5FQGMBx5Ak6deXKPAL7wauBU/<0;1>/*),s:pk([c80b1469/44h/1h/0h]tpubDD3UwwHoNUF4F3Vi5PiUVTc3ji1uThuRfFyBexTSHoAcHuWW2z8qEE2YujegcLtgthr3wMp3ZauvNG9eT9xfJyxXCfNty8h6rDBYU8UU1qq/<0;1>/*),s:pk([4e5024fe/44h/1h/0h]tpubDDLrpPymPLSCJyCMLQdmcWxrAWwsqqssm5NdxT2WSdEBPSXNXxwbeKtsHAyXPpLkhUyKovtZgCi47QxVpw9iVkg95UUgeevyAqtJ9dqBqa1/<0;1>/*),s:pk([3b1d1ee9/44h/1h/0h]tpubDCmDTANBWPzf6d8Ap1J5Ku7J1Ay92MpHMrEV7M5muWxCrTBN1g5f1NPcjMEL6dJHxbvEKNZtYCdowaSTN81DAyLsmv6w6xjJHCQNkxrsrfu/<0;1>/*),sln:after(840000),sln:after(1050000),sln:after(1260000)))"),
    legend(['7258e4f9'-'key 1', 'c80b1469'-'key 2', '4e5024fe'-'key 3', '3b1d1ee9'-'key 4']),
    paths([decaying_threshold]),
    source('the Bitcoin Core descriptor documentation', "https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md",
           'sources/core_descriptors.txt',
           "and finally 1-of-4 at each future halvening block height")
]).

%   7-9. Lightning (BOLT #3) outputs, as the Miniscript page writes them.
twin(bolt3_to_local, [
    title("A Lightning to_local output (BOLT #3)"),
    policy("or(pk(key_revocation),and(pk(key_local),older(1008)))"),
    legend([key_revocation-'the revocation key', key_local-'the local node']),
    paths([revocation, local_after_delay]),
    source(D, U, F, Q)
]) :- sipa(source(D, U, F, Q), "The BOLT #3 to_local policy: or(pk(key_revocation),and(pk(key_local),older(1008)))").

twin(bolt3_offered_htlc, [
    title("A Lightning offered HTLC (BOLT #3)"),
    policy("or(pk(key_revocation),and(pk(key_remote),or(pk(key_local),hash160(H))))"),
    legend([key_revocation-'the revocation key', key_remote-'the remote node', key_local-'the local node',
            'H'-'the payment hash']),
    paths([revocation, remote_with_local_or_preimage]),
    source(D, U, F, Q)
]) :- sipa(source(D, U, F, Q), "The BOLT #3 offered HTLC policy: or(pk(key_revocation),and(pk(key_remote),or(pk(key_local),hash160(H))))").

twin(bolt3_received_htlc, [
    title("A Lightning received HTLC (BOLT #3)"),
    policy("or(pk(key_revocation),and(pk(key_remote),or(and(pk(key_local),hash160(H)),older(1008))))"),
    legend([key_revocation-'the revocation key', key_remote-'the remote node', key_local-'the local node',
            'H'-'the payment hash']),
    paths([revocation, remote_with_preimage_or_timeout]),
    source(D, U, F, Q)
]) :- sipa(source(D, U, F, Q), "The BOLT #3 received HTLC policy: or(pk(key_revocation),and(pk(key_remote),or(and(pk(key_local),hash160(H)),older(1008))))").

%   10. Hash locks in a threshold: two of a signature and two preimages —
%   Bitcoin Core's Miniscript test vectors.
twin(hash_threshold, [
    title("Two of a signature, a SHA-256 preimage and a HASH160 preimage"),
    policy("thresh(2,c:pk_h(025cbdf0646e5db4eaa398f365f2ea7a0e3d419b7e0330e39ce92bddedcac4f9bc),s:sha256(e38990d0c7fc009880a9c07c23842e886c6bbdc964ce6bdd5817ad357335ee6f),a:hash160(dd69735817e0e3f6f826a9238dc2e291184f0131))"),
    legend(['025cbdf0646e5db4eaa398f365f2ea7a0e3d419b7e0330e39ce92bddedcac4f9bc'-'the key holder',
            e38990d0c7fc009880a9c07c23842e886c6bbdc964ce6bdd5817ad357335ee6f-'the payment secret',
            dd69735817e0e3f6f826a9238dc2e291184f0131-'the release secret']),
    paths([two_of_three]),
    source('the Bitcoin Core Miniscript tests', "https://github.com/bitcoin/bitcoin/blob/master/src/test/miniscript_tests.cpp",
           'sources/core_miniscript_tests.txt',
           "thresh(2,c:pk_h(025cbdf0646e5db4eaa398f365f2ea7a0e3d419b7e0330e39ce92bddedcac4f9bc),s:sha256(e38990d0c7fc009880a9c07c23842e886c6bbdc964ce6bdd5817ad357335ee6f),a:hash160(dd69735817e0e3f6f826a9238dc2e291184f0131))")
]).

%   11. A Liquid-like federation: five functionaries, or two of three
%   emergency keys after about 90 days (a TIME-based relative lock).
twin(liquid_federation, [
    title("A Liquid-like federated peg-in: five functionaries, or two of three emergency keys after about 90 days"),
    policy(P),
    legend(L),
    paths([federation, emergency]),
    source('the Bitcoin Core wallet Miniscript tests', "https://github.com/bitcoin/bitcoin/blob/master/test/functional/wallet_miniscript.py",
           'sources/core_wallet_miniscript.txt',
           "Liquid-like federated pegin with emergency recovery keys")
]) :- liquid_policy(P), liquid_legend(L).

%   12. A Revault unvault policy (andor, multi, thresh, an absolute lock).
twin(revault_unvault, [
    title("A Revault unvault output: the managers with the cosigning servers after a lock time, or all four stakeholders"),
    policy(P),
    legend(L),
    paths([managers, stakeholders]),
    source('the Bitcoin Core wallet Miniscript tests', "https://github.com/bitcoin/bitcoin/blob/master/test/functional/wallet_miniscript.py",
           'sources/core_wallet_miniscript.txt',
           "A Revault Unvault policy with the older() replaced by an after()")
]) :- revault_policy(P), revault_legend(L).
