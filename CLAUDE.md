# ITZone ERP — SAP ABAP Cloud (RAP) Capstone Project

## What this repository is

ABAP source for a university capstone: a simulated **multi-branch IT retail ERP** on
**SAP BTP ABAP Environment (ABAP Cloud)** using the **RAP** model.
Source syncs to/from the ABAP system via **abapGit**. Package: `ZTHESIS_ITSHOP`.

## 🚧 Current phase: MIGRATION v1 → v2

The repository currently contains a **working v1 system**: a single-shop model with sales
orders, purchase orders, a product master carrying one global stock number, and a simple
income/expense ledger.

We are migrating it to **v2: a multi-branch chain** — stock per branch, material documents,
double-entry accounting, stock transfers, and multi-level reporting.

**v1 code works. Do not break it while building v2.** Migrate in the order in §5 and keep
the system activatable at the end of every step.

**Deadline: end of October 2026.**

---

## 1. ⚠️ Naming — keep the existing prefix

All objects use the `ZITS_` family. **New v2 objects follow the same convention.**
Do NOT rename existing objects — renaming costs days and gains nothing.

| Kind | Pattern | Example |
|---|---|---|
| Database table | `ZITS_<NAME>` | `ZITS_BRANCH` |
| Interface CDS view | `ZI_ITS_<NAME>` | `ZI_ITS_BRANCH` |
| Projection CDS view | `ZC_ITS_<NAME>` | `ZC_ITS_BRANCH` |
| Metadata extension | `ZC_ITS_<NAME>` | (same name, different object type) |
| Behavior class | `ZBP_I_ITS_<NAME>` | `ZBP_I_ITS_BRANCH` |
| Service definition | `ZUI_ITS_<NAME>` | `ZUI_ITS_BRANCH` |
| Service binding | `ZUI_ITS_<NAME>_O4` | `ZUI_ITS_BRANCH_O4` |
| Value-help view | `ZI_ITS_VH_<NAME>` | `ZI_ITS_VH_SALESPERSON` |
| Computed base view | `ZI_ITS_<NAME>_BASE` | `ZI_ITS_SO_BASE` |

Table names stay ≤ 16 characters (draft tables append `_D`).

---

## 2. Object inventory and disposition

### v1 objects — KEEP AND EXTEND
| Object | Change needed |
|---|---|
| `ZITS_PRODUCT` | **Remove `stock_qty` and `reorder_level`** — both move to `ZITS_STOCK` |
| `ZITS_EMPLOYEE` | Add `branch_id` |
| `ZITS_SO` / `ZITS_SOITEM` | Add branch and sales fields (§6) |
| `ZITS_PO` / `ZITS_POITEM` | Add `branch_id`; replace free-text `supplier_name` with `supplier_id` → `ZITS_PARTNER` |
| Their CDS / BDEF / behavior classes | Follow the table changes |

### v1 objects — RETIRE only after the v2 replacement works
| Object | Replaced by |
|---|---|
| `ZITS_LEDGER` | `ZITS_JE` + `ZITS_JEITEM` (double-entry) |
| `ZI_ITS_SHOP_BALANCE` | New reporting views over `ZITS_JEITEM` |

Do not delete these until the replacement is proven. **Ask the user before deleting anything.**

### v2 objects — CREATE NEW
**Master data:** `ZITS_COMPANY`, `ZITS_REGION`, `ZITS_BRANCH`, `ZITS_COSTCENTER`,
`ZITS_GLACCT`, `ZITS_PARTNER`, `ZITS_STOCK`

**Transactions:** `ZITS_MATDOC`, `ZITS_JE` + `ZITS_JEITEM`, `ZITS_STO` + `ZITS_STOITEM`

---

## 3. Target architecture

```
Company → Region → Branch (Plant) → Stock (branch × product)
```

Demo org: 3 branches in 2 regions — Siam Paragon (BR01) and Central Ladprao (BR02) in the
Central region; Central Chiang Mai (BR03) in the North region.

**Document principle — the core rule of this system:** every stock movement and every money
movement creates an immutable document. Documents are never edited or deleted; corrections
are reversing entries.

- **Material Document** (`ZITS_MATDOC`) — append-only, one row per stock movement.
  Movement types: `101` goods receipt · `601` goods issue · `301` transfer out · `302` transfer in
- **Journal Entry** (`ZITS_JE` + `ZITS_JEITEM`) — double-entry; **total debit must equal
  total credit**, enforced by validation

**Processes:** Order-to-Cash · Procure-to-Pay · Stock Transfer
Approval is multi-level by amount: none → branch manager → regional manager.

---

## 4. Repository file map

Each ABAP object = one source file + one `.xml` metadata file.

| Object type | Edit this | Never edit |
|---|---|---|
| CDS view | `.ddls.asddls` | `.ddls.xml` |
| Metadata extension | `.ddlx.asddlxml` | `.ddlx.xml` |
| Behavior definition | `.bdef.asbdef` | `.bdef.xml` |
| Class implementation | `.clas.abap` | `.clas.xml` |
| **Behavior handler code** | **`.clas.locals_imp.abap`** | — |
| Service definition | `.srvd.srvdsrv` | `.srvd.xml` |
| Database table | — | `.tabl.xml` — **change tables in ADT only** |
| Service binding | — | `.srvb.xml` |

Files ending `.sia`, `.iamu`, `.devc.xml` are launchpad/package metadata — ignore them.

**Rule: only edit the "Edit this" column.** If a change needs XML or a table definition,
stop and tell the user to do it in ADT.

**Never invent metadata XML.** New objects must be created as empty shells in ADT first,
pushed to git, then filled in from here. If a shell is missing, say so and stop.

---

## 5. Migration order — follow this sequence

Each step must leave the system activatable.

**Step 1 — New master data** (no dependencies, safest first)
`ZITS_COMPANY` → `ZITS_REGION` → `ZITS_BRANCH` → `ZITS_COSTCENTER` → `ZITS_GLACCT` → `ZITS_PARTNER`
Each gets the full 7-object BO set. The pattern is identical to the existing Product BO.

**Step 2 — Stock per branch** (the risky one)
1. Create `ZITS_STOCK` (key: `branch_id` + `product_id`)
2. Remove `stock_qty` and `reorder_level` from `ZITS_PRODUCT`
3. **Every place that reads or writes product stock must be updated.** Search the whole repo
   for `StockQty` and `stock_qty` before calling this done. Known callers: Product BDEF
   mapping, Product projection + MDE, `validateStock` in SalesOrder, the `Complete` action in
   SalesOrder, the `Receive` action in PurchaseOrder.

**Step 3 — Branch awareness on existing documents**
Add `branch_id` to `ZITS_SO` and `ZITS_PO` plus the new sales fields (§6).
Stock checks and stock updates become **per branch**.

**Step 4 — Material Document**
Create `ZITS_MATDOC`. SalesOrder `Complete` and PurchaseOrder `Receive` must write a
material document **before** adjusting stock.

**Step 5 — Double-entry accounting**
Seed `ZITS_GLACCT`, create `ZITS_JE` + `ZITS_JEITEM`, switch SO/PO posting from `ZITS_LEDGER`
to journal entries. Retire the ledger only after this works end to end.

**Step 6 — Stock Transfer Order**
New BO `ZITS_STO` + `ZITS_STOITEM`. Reuses every pattern already built.

**Step 7 — Reporting views** · **Step 8 — Fiori apps and launchpad tiles**

---

## 6. New fields on Sales Order (v2)

```abap
branch_id         : abap.char(4)     " FK ZITS_BRANCH — required
customer_id       : abap.char(10)    " FK ZITS_PARTNER — blank allowed for walk-in
sales_channel     : abap.char(1)     " W=Walk-in, P=Phone, O=Online
delivery_mode     : abap.char(1)     " P=Pickup, D=Delivery
delivery_address  : abap.char(255)   " required when delivery_mode = 'D'
payment_method    : abap.char(1)     " C=Cash, R=Credit card, T=Transfer
```

Validations: delivery address required when `delivery_mode = 'D'`; customer required when
`sales_channel <> 'W'`.

Determination: the journal entry debit account depends on payment method —
`C` → cash account, `R`/`T` → bank account.

---

## 7. 🔥 Hard-won rules — these caused real failures, do not repeat them

### 1. Draft-enabled entities reject calculated fields in the interface view
A path expression (`_Product.ProductName as ProductName`) or a `CASE` in a **draft-enabled**
interface view fails activation:
`"ZITS_X_D" is not a suitable draft persistency for "ZI_ITS_X" (there is no "FIELD")`
**Fix:** put calculated/associated fields in the **projection view**, or compute them in a
separate plain `define view entity` (see `ZI_ITS_SO_BASE`) and reach it via association.

### 2. `field ( readonly )` in the base BDEF also blocks EML
Readonly in the **base** behavior definition blocks cross-BO EML writes, not just the UI.
Stock quantity must stay writable in the base BDEF so orders can update it.
**Fix:** declare `field ( readonly )` in the **projection BDEF** instead.

### 3. A determination must never trigger on a field it writes
Triggering on `Amount` while writing `Amount` loops until:
`Canceled due to stack of on-modify determinations being too deep`
**Fix:** trigger only on fields the *user* edits (`ProductID`, `Quantity`) and do all derived
calculation inside **one** determination.

### 4. `strict ( 2 )` requires every exposed field to be accounted for
Any CDS field not in the `mapping for` block must be declared `field ( readonly )`.

### 5. OData V4 UI services need draft for Create/Edit buttons
Non-draft business objects render without Create and Edit in Fiori Elements on OData V4.
Every BO edited through the UI needs `with draft;`.

### 6. Backslash association syntax uses the *association name*
`ENTITY SalesOrder BY \_Item` — `_Item` is the composition name declared in CDS, not the
entity or alias name.

### 7. Amount fields (`CURR`) cannot go directly into `sum()`
Cast at the innermost level:
`sum( case ... then cast( amount as abap.dec(15,2) ) else cast( 0 as abap.dec(15,2) ) end )`

### 8. Fiori tiles in Work Zone must not append an intent hash
Standalone BSP apps show a blank page if Work Zone adds `#Semantic-action` to the URL.
Untick "Add intent and default SAP parameters to URL" on the tile configuration.

### 9. Changing a service definition after publishing leaves a stale descriptor
If the exposed entity alias changes (`expose X;` → `expose X as Y;`) after the service
binding was published, the preview app keeps the old entity set name and hangs with
`Unknown child <ViewName> of ...Container` and `Cannot read properties of undefined
(reading 'entityType')`.
**Fix:** Unpublish → Activate → Publish the binding, or delete and recreate the binding.

### 10. Unpublish/Publish a service binding invalidates the session's authorization
After re-publishing, the browser session still holds the old service-group authorization:
`No authorization to access service group '<binding>'` / `no start authorization for
R3TR G4BA <binding>, return code 4`.
**Fix:** full logout and fresh login (incognito). If it persists, the service needs an
IAM App (External App) published locally and added to a Business Catalog.
### 11. Value-help aliases must not collide with property names
Exposing a value-help view under the same alias as a field produces a 500 on $metadata:
`Property 'X' has the same EDM name as entity type 'X'`.
**Rule:** always suffix value-help aliases with `VH` in the service definition —
`expose ZI_ITS_VH_PARTNERTYPE as PartnerTypeVH;`
### 12. OData names entity types as `<EntitySetName>Type` — watch for collisions
The framework auto-generates an entity type named after the entity set plus `Type`.
A property with that exact name breaks $metadata with HTTP 500:
`Property 'X' has the same EDM name as entity type 'X'`
Example: `expose ZC_ITS_PARTNER as Partner;` generates entity type `PartnerType`,
which collides with the property `PartnerType`.
**Rule:** before exposing an entity, check that no property is named
`<alias>Type`. Rename the alias (cheapest) or the property.
### 13. `provider contract transactional_query` rejects expressions
A projection view with a transactional contract cannot contain `CASE` or arithmetic:
`Field X contains a not supported expression`
**Fix:** compute it one layer down — in the interface view if the entity has no draft,
otherwise in a separate plain `define view entity` reached through an association.
Always `cast(... as abap.int1)` for criticality fields, and declare every computed or
association-sourced field as `field ( readonly )` in the BDEF (strict(2) requires it).
---

## 8. Style preferences

- Prefer plain `LOOP AT ... ENDLOOP` over `REDUCE` — the user must be able to explain every
  line in a thesis defence.
- Use `cl_abap_context_info=>get_user_technical_name( )` and `get_system_date( )`
  (ABAP Cloud compliant). Never `sy-uname` or `sy-datum`.
- Compare user names case-insensitively:
  `WHERE upper( user_name ) = @to_upper( current_user )`.
- Code and comments in English. Keep validation messages short and user-facing.
- Prefer one determination doing several things over several chained determinations.

---

## 9. Working agreement

- **You cannot activate objects, run classes, or test in Fiori.** The user does that in
  Eclipse/ADT.
- End every substantive change with **what to activate (in order)** and **what to test**.
- When building a new business object, produce the full set in one response: interface
  view(s) → projection view(s) → metadata extension(s) → behavior definition → behavior class
  (Local Types) → projection BDEF → service definition/binding notes.
- Before finishing a step in §5, search the repo for anything still referencing what changed.
  Do not declare a migration step complete without that check.
