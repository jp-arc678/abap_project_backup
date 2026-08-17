# ITZone ERP — SAP ABAP Cloud (RAP) Capstone Project

## What this repository is

ABAP source for a university capstone project: a simulated multi-branch IT retail ERP
built on **SAP BTP ABAP Environment (ABAP Cloud)** using the **RAP** programming model.
Source is synced to/from the ABAP system via **abapGit**.

**Deadline: end of October 2026.** Speed matters, but a broken activation costs more
time than it saves — correctness first.

---

## ⚠️ Critical workflow rules

### Never invent metadata XML
abapGit stores each object as a **source file** plus an **`.xml` metadata file**.
- **DO** write and edit source files: `.asddls`, `.asddlxml`, `.asbdef`, `.abap`, `.srvdsrv`
- **DO NOT** hand-write or guess `.xml` metadata for objects that don't exist yet
- **New objects must be created as empty shells in ADT (Eclipse) first**, pushed to git,
  and only then filled in from here. Ask the user to create the shell if it's missing.

### Activation order matters
When suggesting what to activate in ADT after a change, always list the order:
child interface view → root interface view → projections → metadata extensions →
behavior class → BDEF → projection BDEF → service definition → service binding.

### The user runs Eclipse, not you
You cannot activate objects, run classes, or test in Fiori. End every substantive change
with a short "what to activate / what to test" list.

---

## Naming conventions

| Prefix | Meaning | Example |
|---|---|---|
| `ZBR_` | database table | `ZBR_STOCK` |
| `ZI_` | interface CDS view (data model) | `ZI_ITS_PRODUCT` |
| `ZC_` | projection CDS view (consumption) | `ZC_ITS_PRODUCT` |
| `ZBP_` | behavior implementation class | `ZBP_I_ITS_PRODUCT` |
| `ZUI_` | service definition / binding | `ZUI_ITS_PRODUCT`, `..._O4` |

Package: `ZTHESIS_ITSHOP` (under `ZLOCAL` — no transport requests, this is expected).

---

## 🔥 Hard-won rules — these caused real failures, do not repeat them

### 1. Draft-enabled entities reject calculated fields in the interface view
Adding a path expression (`_Product.ProductName as ProductName`) or a `CASE` to a
**draft-enabled** interface view causes:
`"ZBR_X_D" is not a suitable draft persistency for "ZI_X" (there is no "FIELD")`

**Fix:** put calculated/associated fields in the **projection view**, or compute them in a
separate plain `define view entity` and reach them through an association.

### 2. `field ( readonly )` in the base BDEF also blocks EML
Marking a field readonly in the **base** behavior definition prevents cross-BO EML writes,
not just UI edits. Stock quantity must stay writable in the base BDEF so Sales/Purchase
orders can update it.

**Fix:** declare `field ( readonly )` in the **projection BDEF** instead — blocks the UI,
allows EML.

### 3. A determination must never trigger on a field it writes
Trigger on `Amount` while the determination writes `Amount` → determinations call each
other in a loop → runtime short dump:
`Canceled due to stack of on-modify determinations being too deep`

**Fix:** trigger only on fields the *user* edits (`ProductID`, `Quantity`), and do all
derived calculation inside one determination. Prefer **one determination that does
everything** over several that chain.

### 4. `strict ( 2 )` requires every exposed field to be accounted for
Any field in the CDS view that is not in the `mapping for` block must be declared
`field ( readonly )`, or activation fails with
`"ZI_X" does not have a component "FIELD"`.

### 5. OData V4 UI services need draft for Create/Edit buttons
Non-draft business objects render without Create and Edit in Fiori Elements on OData V4.
Every BO the user edits through the UI must have `with draft;`.

### 6. Backslash association syntax uses the *association name*
`READ ENTITIES ... ENTITY SalesOrder BY \_Item` — `_Item` is the composition name declared
in CDS, **not** the entity or alias name. Same for `BY \_SalesOrder` going to the parent.

### 7. Amount fields (`CURR`) cannot go directly into `sum()`
Cast first, at the innermost level:
`sum( case entry_type when 'I' then cast( amount as abap.dec(15,2) ) else cast( 0 as abap.dec(15,2) ) end )`

---

## Style preferences

- Prefer plain `LOOP AT ... ENDLOOP` over `REDUCE` — the user must be able to explain
  every line in a thesis defence.
- Use `cl_abap_context_info=>get_user_technical_name( )` and `get_system_date( )`
  (ABAP Cloud compliant), never `sy-uname` or `sy-datum`.
- Compare user names case-insensitively: `WHERE upper( user_name ) = @to_upper( current_user )`.
- Comment business rules in English; the user reads Thai but the thesis code listing is English.
- Keep validation messages short and user-facing.

---

## Architecture (new multi-branch scope)

```
Company → Region → Branch (Plant) → Stock (per branch × product)
```

**Master data:** Company, Region, Branch, Cost Center, Product, Stock, Business Partner,
Employee, GL Account

**Transaction documents:**
- Sales Order (header + items) — Order-to-Cash
- Purchase Order (header + items) — Procure-to-Pay
- Stock Transport Order (header + items) — branch-to-branch transfer
- Material Document — append-only record of every stock movement
  (movement types: `101` goods receipt, `601` goods issue, `301`/`302` transfer out/in)
- Journal Entry (header + line items) — **double-entry**, total debit must equal total credit

**Key principle:** every stock movement and every money movement produces an immutable
document. Documents are never edited or deleted — corrections are reversing entries.

---

## When asked to build a new business object

Produce the full set in one response, in this order:
1. Interface view(s) — root + child if composition
2. Projection view(s)
3. Metadata extension(s)
4. Behavior definition (one file covers header and items)
5. Behavior implementation class (Local Types content)
6. Projection behavior definition
7. Service definition + binding notes

Then list the activation order and a short test checklist.
