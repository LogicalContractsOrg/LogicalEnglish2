% The British Nationality Act 1981, section 1(1), much simplified.
% Demo B of the talk "Logical English with SWI-Prolog".
% Load with:  swipl bna_s1.pl   (or paste into https://swish.swi-prolog.org)

:- dynamic married/2.

% A person acquires British citizenship on a date
% if the person is born in the UK on the date,
% the date is after commencement,
% and a parent of the person is a British citizen
% or is settled in the UK on the date.
acquires_citizenship(Person, Date) :-
    born_in(Person, uk, Date),
    after_commencement(Date),
    parent(Parent, Person),
    ( british_citizen(Parent, Date) ; settled_in_uk(Parent, Date) ).

parent(Parent, Child) :- mother(Parent, Child).
parent(Parent, Child) :- father(Parent, Child), father_counts(Parent, Child).

% Section 50(9), as passed in 1981: a father counts
% only if he is married to the mother.
father_counts(Father, Child) :-
    mother(Mother, Child),
    married(Father, Mother).
% Section 50(9A), in force from 1 July 2006: for a child born
% on or after that date, an unmarried father counts too.
father_counts(_Father, Child) :-
    born_in(Child, _, Date),
    Date @>= date(2006, 7, 1).

after_commencement(Date) :- Date @>= date(1983, 1, 1).

% The facts of three cases: John's, Mary's and Tom's
born_in(john, uk, date(2021, 10, 9)).
born_in(mary, uk, date(2022, 3, 1)).
born_in(tom, uk, date(2000, 5, 1)).

mother(alice, john).
mother(beth, mary).
mother(carol, tom).
father(harry, mary).
father(harry, tom).

british_citizen(alice, date(2021, 10, 9)).
% Harry has been settled in the UK since 1995. He is not married.
settled_in_uk(harry, Date) :- Date @>= date(1995, 1, 1).
