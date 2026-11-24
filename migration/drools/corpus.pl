/** <module> The Drools rule bases the twins are built from

    Each case: a DRL file of corpus/drl/, the fact model it is written
    against (Java classes compiled into model/ from corpus/java/, or the
    DRL's own `declare`s), the initial working memory and the steps a Java
    driver takes between two runs (inserting and deleting facts) — the
    examples' own drivers, restated. Facts are written Type(Field, ...) in
    the type's field order, a reference to another object by its name.

    Sources: the drools-examples of Drools (Apache KIE (incubating);
    Apache License 2.0; unchanged, see corpus/NOTICE.txt): Fire
    (fire/simple), HonestPolitician; LPS2's own rule bases
    (examples/migration/drools/drl in LPS2), written out as valid DRL
    (quoted strings, `$` bindings, `;`) so that Drools can run them.
*/

:- module(drools_corpus, [case/2]).

kie('https://github.com/apache/incubator-kie-drools/tree/main/drools-examples/src/main/resources/org/drools/examples').

case(fire_alarm, [
    title("Fire alarm: sprinklers and an alarm (Drools examples, fire/simple)"),
    drl('drl/Fire.drl'),
    model(['org.drools.examples.fire.Room', 'org.drools.examples.fire.Sprinkler',
           'org.drools.examples.fire.Fire', 'org.drools.examples.fire.Alarm']),
    facts([room(kitchen), room(bedroom), room(office), room(livingroom),
           sprinkler(kitchen, false), sprinkler(bedroom, false),
           sprinkler(office, false), sprinkler(livingroom, false)]),
    steps([step([fire(kitchen), fire(office)], []),
           step([], [fire(kitchen), fire(office)])])
]).
case(honest_politician, [
    title("The honest politician (Drools examples, truth maintenance)"),
    drl('drl/HonestPolitician.drl'),
    model(['org.drools.examples.honestpolitician.Politician', 'org.drools.examples.honestpolitician.Hope']),
    facts([politician('President of Umpa Lumpa', true), politician('Prime Minster of Cheeseland', true),
           politician('Tsar of Pringapopaloo', true), politician('Omnipotence Om', true)])
]).
case(insurance, [
    title("Insurance eligibility (LPS2's rule base, as valid DRL)"),
    drl('drl/insurance.drl'),
    facts([driver(ann, young, clean), driver(bob, mature, clean), driver(cid, mature, claimed), policy(cid, low)])
]).
case(discount, [
    title("Discounts by customer tier (LPS2's rule base, as valid DRL; a decision service)"),
    drl('drl/discount.drl'),
    facts([order(acme, large), customer(acme, gold), order(zeta, large), customer(zeta, silver), order(tiny, small)])
]).
case(shipping, [
    title("Order shipping (LPS2's rule base, as valid DRL)"),
    drl('drl/shipping.drl'),
    facts([order(o1, placed), stock(widget, available)])
]).
