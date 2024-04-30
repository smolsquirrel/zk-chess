# Cryptographic Dark Chess

The project presents two cryptographic protocols that allow two players
to play dark chess, an imperfect information variation of chess, without
the need for an active and trusted third party. In dark chess, the players
may only see their own pieces and the squares that they can move to.

The first protocol assumes that the players are semi-honest and focuses
mainly on how the players may learn information about the other’s position
without the opponent learning anything.

The second protocol assumes that the players are malicious and aims to
prevent all types of cheating using zero-knowledge proofs. This new protocol builds on top of the work done in the first.

Supervisor: Prof. Claude Crépeau, McGill University
