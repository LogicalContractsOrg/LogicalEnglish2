# Published ontologies, as Logical English templates

An ontology is a published table of words and of the links between them, for example "a loafer is a kind of shoe". The programs of this folder let a Logical English program use one. The first is WordNet (Open English WordNet 2025, a dictionary of English, licence CC-BY 4.0). The repository does not keep WordNet: the first query that needs it downloads it once (10 MB) and keeps it as Prolog facts.

**Start here**
- [`wordnet.le`](wordnet.le): the WordNet templates. Include it as a resource.
- [`shop_words.le`](shop_words.le): a shop puts each product on a shelf. Its own words come first, and WordNet reads the other names.

**Try this**
1. Open [`shop_words.le`](shop_words.le?scenario=delivery&query=shelves) on the scenario `delivery` and the query `shelves`.
2. Run the query. The first run downloads WordNet (about 15 seconds). Product 1 ("pumps") goes on the shelf shoes, by a word of the shop.
3. Product 2 ("loafers") also goes on the shelf shoes. WordNet says that a loafer is a kind of shoe, and "shoe" is a word of the shop.
4. Product 4 ("chest bag") goes on the shelf bags. WordNet does not have the phrase, so the system reads its ending, "bag".
5. Product 5 ("teapot") gets no shelf. In WordNet a teapot is a kind of container, but no word of the shop ("shoe", "bag", "pumps", "trainers") is above it.
6. Open [`wordnet.le`](wordnet.le?scenario=slippers&query=definition) and run `definition`: the definition of the sense that the answers cite.

**More**
- The language reference, §14.6 Published ontologies ([`docs/user/reference/language.md`](../../docs/user/reference/language.md)).
- The module that downloads and reads WordNet: [`le_ontology.pl`](../../le_ontology.pl).
- A large use: the customs model reads the sellers' words for footwear, clothing and jewellery with WordNet when no cited text has the word ([`../regulatory/customs/background/footwear.le`](../regulatory/customs/background/footwear.le)).
- Open English WordNet: https://en-word.net.
