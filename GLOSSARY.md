# BPGP glossary

The words BPGP uses for its own concepts. Text players see uses the **bold** term; code and ledger fields may use the name in `code`.

## Points

**BP (Boomer Points)**:
Effort points earned by raiding. Code, ledger fields and internal docs call them EP (`ep`, `UI.COLOR.EP`).
_Avoid in player-facing text_: EP, DKP, effort points

**GP (Gear Points)**:
Points charged for an item won in an auction.

**PR (Priority)**:
BP ÷ max(GP, *Minimum GP*). Higher PR wins within the same bid type.
_Avoid_: ratio, priority ratio

**Minimum standing**:
The BP a player needs before they may bid.
_Avoid_: min EP, minimum points

**On-time bonus**:
BP given to every raid member when a raid starts; the only automatic award.

**Decay**:
A manual percentage cut of BP, GP or both, for selected players, the raid or the roster.

## People and data

**Roster**:
The one list of guild members who have standings. Created with *Set up BPGP*; raids never add to it.
_Avoid_: team, list, rosters (there is only one)

**Officer**:
A guild member whose rank has "Is Officer". Officers can change data; everyone else is read-only.
_Avoid_: manager, assistant (CLM's old levels)

**Raider**:
Any non-officer guild member.
_Avoid_: pleb (the code's `PLEBS` level)

**Auctioneer**:
The officer running auctions: raid leader/assistant, or the officer with *Need on everything* on.
_Avoid_: master looter, loot master

**Ledger**:
The append-only list of entries that every client replays into standings, raids and settings, and that sync keeps the same everywhere.
_Avoid_: database, history (History is a tab)

**Entry**:
One change in the ledger (award, charge, decay, setting). Undo is another entry.
_Avoid_: event, transaction

## Auctions

**Tier**:
A main-spec bid level with its own GP: **BiS**, **Major** or **Minor**. In code they are the slot-value keys Medium, Small and Base.
_Avoid_: Max, Large, Medium, Small, Base in player-facing text

**OS (Off-spec)**:
A 0 GP bid that ranks below every tier, ordered by PR.

**Transmog**:
A 0 GP bid that ranks below OS; the highest roll wins, PR doesn't count.

**Trade list**:
Awarded items still to be traded to their winners, shown in the Trade tab.

**Pass on loot**:
A personal setting that passes on group loot rolls in our own raids, so one officer loots everything.

**Need on everything**:
An officer setting that rolls Need on boss loot, so that officer collects the items to auction.

## Development

**Test mode**:
A per-session mode with its own ledger (`ledger_test`) and comm prefix (`BPGPT`), so tests never reach the guild's data.
_Avoid_: sandbox (CLM's removed feature)
