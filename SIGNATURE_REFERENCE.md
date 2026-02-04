# Family Signature Visual Reference

## The Core Problem (SOLVED)

**Query: "coke"** returns these three items that are the SAME PRODUCT:

```
Before Fix:
┌─────────────────────────┬────────────┬────────────────┐
│ Name                    │ Brand      │ Signature      │
├─────────────────────────┼────────────┼────────────────┤
│ Coca Cola Coke Brand    │ Coca-Cola  │ sig_A ❌       │
│ Coca cola Goût Original │ coke       │ sig_B ❌       │
│ Original Taste Coke     │ (null)     │ sig_C ❌       │
└─────────────────────────┴────────────┴────────────────┘

sig_A ≠ sig_B ≠ sig_C → THREE SEPARATE ROWS! 😞

After Fix:
┌─────────────────────────┬────────────┬─────────────────────────────┐
│ Name                    │ Brand      │ Signature                   │
├─────────────────────────┼────────────┼─────────────────────────────┤
│ Coca Cola Coke Brand    │ Coca-Cola  │ coca-cola│cola│regular│none │
│ Coca cola Goût Original │ coke       │ coca-cola│cola│regular│none │
│ Original Taste Coke     │ (null)     │ coca-cola│cola│regular│none │
└─────────────────────────┴────────────┴─────────────────────────────┘

sig_A = sig_B = sig_C → MERGED INTO ONE ROW! ✓
```

---

## Step-by-Step Signature Generation

### Item 1: "Coca Cola Coke Brand" (brand: "Coca-Cola")

```
Input:
  name = "Coca Cola Coke Brand"
  brand = "Coca-Cola"
  query = "coke"

Step 1: Normalize name
  nameNorm = normalize("Coca Cola Coke Brand")
           = "coca cola coke brand"

Step 2: Normalize brand
  brandNorm = normalizeBrand("Coca-Cola", nameNorm)
            = "coca-cola"                    ← Key fix: normalize to hyphenated form

Step 3: Extract diet type
  dietType = extractDietType("coca cola coke brand")
           = "regular"                       ← No "diet", "zero", etc.

Step 4: Extract flavor
  flavor = extractFlavor("coca cola coke brand")
         = "none"                            ← NEW: not "original"!

Step 5: Infer core name
  coreNorm = inferCoreName(
    "coca cola coke brand",
    variants(diet=regular, flavor=none),
    brandNorm="coca-cola",
    queryNorm="coke"
  )
  
  Processing:
  - Remove brand tokens: "coca cola coke" → ""
  - Core so far: "" + "brand"
  - Remove stop tokens: "brand" → ""
  - Core is empty!
  - Fallback: brandNorm="coca-cola" → "cola"
  
  = "cola"                                  ← Key fix: infer from brand

Step 6: Build family signature
  sig = "$brandNorm|$coreNorm|$dietType|$flavor"
      = "coca-cola|cola|regular|none"       ✓

Output: coca-cola|cola|regular|none
```

### Item 2: "Coca cola Goût Original" (brand: "coke")

```
Input:
  name = "Coca cola Goût Original"
  brand = "coke"
  query = "coke"

Step 1: Normalize name
  nameNorm = normalize("Coca cola Goût Original")
           = "coca cola gout original"       ← "ô" becomes "o"

Step 2: Normalize brand
  brandNorm = normalizeBrand("coke", nameNorm)
            = "coca-cola"                    ← Key fix: "coke" → "coca-cola"

Step 3: Extract diet type
  dietType = extractDietType("coca cola gout original")
           = "regular"

Step 4: Extract flavor
  flavor = extractFlavor("coca cola gout original")
         = "none"                            ← NEW: not "original"!

Step 5: Infer core name
  coreNorm = inferCoreName(
    "coca cola gout original",
    variants(diet=regular, flavor=none),
    brandNorm="coca-cola",
    queryNorm="coke"
  )
  
  Processing:
  - Remove brand tokens: "coca cola" → "gout original"
  - Remove stop tokens: "gout original" → ""    ← NEW: complete phrase removal!
  - Core is empty!
  - Fallback: brandNorm="coca-cola" → "cola"
  
  = "cola"                                  ← Key fix: infer from brand

Step 6: Build family signature
  sig = "$brandNorm|$coreNorm|$dietType|$flavor"
      = "coca-cola|cola|regular|none"       ✓

Output: coca-cola|cola|regular|none ✓ SAME AS ITEM 1!
```

### Item 3: "Original Taste Coke" (brand: null)

```
Input:
  name = "Original Taste Coke"
  brand = null
  query = "coke"

Step 1: Normalize name
  nameNorm = normalize("Original Taste Coke")
           = "original taste coke"

Step 2: Normalize brand
  brandNorm = normalizeBrand(null, nameNorm)
  
  Since brand is null:
  - Check if nameNorm contains "coke"? → YES!
  - Return "coca-cola"                       ← Key fix: infer from name!
  
            = "coca-cola"

Step 3: Extract diet type
  dietType = extractDietType("original taste coke")
           = "regular"

Step 4: Extract flavor
  flavor = extractFlavor("original taste coke")
         = "none"                            ← NEW: not "original"!

Step 5: Infer core name
  coreNorm = inferCoreName(
    "original taste coke",
    variants(diet=regular, flavor=none),
    brandNorm="coca-cola",
    queryNorm="coke"
  )
  
  Processing:
  - Remove brand tokens: "coke" → "original taste"
  - Remove stop tokens: "original taste" → ""   ← NEW: complete phrase removal!
  - Core is empty!
  - Fallback: brandNorm="coca-cola" → "cola"
  
  = "cola"                                  ← Key fix: infer from brand

Step 6: Build family signature
  sig = "$brandNorm|$coreNorm|$dietType|$flavor"
      = "coca-cola|cola|regular|none"       ✓

Output: coca-cola|cola|regular|none ✓ SAME AS ITEMS 1 & 2!
```

---

## Signature Comparison: Before vs After

### BEFORE (Broken)

```
Item 1: Coca Cola Coke Brand
  nameNorm = "coca cola coke brand"
  brandNorm = "cocacola" (no hyphen - inconsistent!)
  coreNorm = ??? (unpredictable)
  flavor = ??? (might be "original")
  → sig = cocacola|cola coke|regular|original (NOT CONSISTENT!)

Item 2: Coca cola Goût Original  
  nameNorm = "coca cola gout original"
  brandNorm = "cocacola" (from "coke", no hyphen)
  coreNorm = ??? (unpredictable)
  flavor = "original" (BUG!)
  → sig = cocacola|cola|regular|original (DIFFERENT!)

Item 3: Original Taste Coke
  nameNorm = "original taste coke"
  brandNorm = "generic" (BUG: null brand not inferred!)
  coreNorm = ??? (unpredictable)
  flavor = "original" (BUG!)
  → sig = generic|coke|regular|original (TOTALLY DIFFERENT!)

Result: sig1 ≠ sig2 ≠ sig3 → THREE SEPARATE ROWS 😞
```

### AFTER (Fixed)

```
Item 1: Coca Cola Coke Brand
  nameNorm = "coca cola coke brand"
  brandNorm = "coca-cola" ✓ (hyphenated, consistent!)
  coreNorm = "cola" ✓ (inferred from brand)
  flavor = "none" ✓ (not "original"!)
  → sig = coca-cola|cola|regular|none

Item 2: Coca cola Goût Original
  nameNorm = "coca cola gout original"
  brandNorm = "coca-cola" ✓ (from "coke", normalized!)
  coreNorm = "cola" ✓ (inferred from brand)
  flavor = "none" ✓ (not "original"!)
  → sig = coca-cola|cola|regular|none ✓ SAME!

Item 3: Original Taste Coke
  nameNorm = "original taste coke"
  brandNorm = "coca-cola" ✓ (inferred from "coke" in name!)
  coreNorm = "cola" ✓ (inferred from brand)
  flavor = "none" ✓ (not "original"!)
  → sig = coca-cola|cola|regular|none ✓ SAME!

Result: sig1 = sig2 = sig3 → ONE MERGED ROW ✓
```

---

## Key Differences in Processing

### Issue #1: Brand Inconsistency

| Item | Brand Input | OLD | NEW |
|------|-------------|-----|-----|
| 1 | "Coca-Cola" | "cocacola" | "coca-cola" ✓ |
| 2 | "coke" | "cocacola" | "coca-cola" ✓ |
| 3 | null | "generic" ❌ | "coca-cola" ✓ |

### Issue #2: Flavor Detection

| Item | Flavor Input | OLD | NEW |
|------|--------------|-----|-----|
| 1 | "coca cola coke brand" | "original" ❌ | "none" ✓ |
| 2 | "coca cola gout original" | "original" ❌ | "none" ✓ |
| 3 | "original taste coke" | "original" ❌ | "none" ✓ |

**Why?** In OLD system, `extractFlavor()` returned "original" if no known flavor found. In NEW system, it returns "none".

### Issue #3: Core Name Inference

| Item | Core Input | OLD | NEW |
|------|-----------|-----|-----|
| 1 | "coca cola coke brand" | ??? | "cola" ✓ |
| 2 | "coca cola gout original" | ??? | "cola" ✓ |
| 3 | "original taste coke" | ??? | "cola" ✓ |

**Why?** NEW system:
1. Removes "gout original" as COMPLETE token (not individual words)
2. Falls back to brand inference when core is empty
3. Returns consistent "cola" for all three

---

## Stop Tokens Removed (NEW)

These are NOW removed as COMPLETE tokens (not individually!):

```
Language Variants (COMPLETE PHRASES):
  ✓ "original taste"      ← English
  ✓ "goût original"       ← French (with accent)
  ✓ "gout original"       ← French (without accent)
  ✓ "sabor original"      ← Spanish
  ✓ "gusto original"      ← Italian/Spanish
  ✓ "classique"           ← French
  ✓ "clasico", "clásico"  ← Spanish
  ✓ "tradicional"         ← Spanish/French/Portuguese
  
Generic Marketing:
  ✓ "brand"
  ✓ "product"
  ✓ "original"
  ✓ "classic"
  ✓ "traditional"
```

---

## Signature Components Breakdown

```
Signature Format: $brandNorm|$coreName|$dietType|$flavor

Example: "coca-cola|cola|regular|none"
         │           │   │       │
         │           │   │       └─ Flavor (none, cherry, lime, etc.)
         │           │   └─────── Diet type (regular, diet, zero)
         │           └─────────── Product core (cola, pepsi, sprite, etc.)
         └─────────────────────── Brand (coca-cola, pepsi, sprite, etc.)
```

### Component Details

**$brandNorm** (Brand):
- Canonical form: "coca-cola", "pepsi", "sprite", "fanta"
- With hyphens (not underscores or no hyphens)
- Normalized from variants: "Coke", "coca cola" → "coca-cola"

**$coreName** (Product Core):
- What the product fundamentally is: "cola", "coke", "pepsi", "sprite"
- Extracted after removing brand, marketing terms, packaging
- Inferred from brand when empty: "coca-cola" → "cola"

**$dietType** (Diet Type):
- "regular" (default)
- "diet" (diet/low-calorie)
- "zero" (zero sugar)

**$flavor** (Flavor):
- "none" (default)
- "cherry", "vanilla", "lime", "lemon", etc.
- Only actual flavors, not marketing terms

---

## Example Signatures for All Coke Products

```
Product                              Brand Input      → Family Signature
─────────────────────────────────────────────────────────────────────────
Coca Cola (regular)                  "Coca-Cola"     → coca-cola|cola|regular|none
Coca cola Goût Original              "coke"          → coca-cola|cola|regular|none ✓
Original Taste Coke                  null            → coca-cola|cola|regular|none ✓
Coca Cola Coke Brand                 "Coca-Cola"     → coca-cola|cola|regular|none ✓

Diet Coke                            "Coca-Cola"     → coca-cola|cola|diet|none (different!)
Coke Zero                            "Coca-Cola"     → coca-cola|cola|zero|none (different!)

Cherry Flavored Coke                 "????"          → coca-cola|cola|regular|cherry (different!)
Coke With Lime Flavor                "????"          → coca-cola|cola|regular|lime (different!)

Transformation (irrelevant)          "TRANSFORMATION" → generic|transformation|regular|none
```

---

## Summary

### The Fix In One Picture

```
BEFORE:
┌──────────────────┬───────────┬──────────────────────────┐
│ Item             │ Sig Parts │ Family Signature         │
├──────────────────┼───────────┼──────────────────────────┤
│ Coca Cola Brand  │ cocacola  │ cocacola|cola coke|...   │
│ Goût Original    │ cocacola  │ cocacola|cola|...        │  ❌ NOT MATCHING
│ Original Taste   │ generic   │ generic|coke|...         │
└──────────────────┴───────────┴──────────────────────────┘

AFTER:
┌──────────────────┬───────────┬──────────────────────────┐
│ Item             │ Sig Parts │ Family Signature         │
├──────────────────┼───────────┼──────────────────────────┤
│ Coca Cola Brand  │ coca-cola │ coca-cola|cola|regular|none│
│ Goût Original    │ coca-cola │ coca-cola|cola|regular|none│ ✓ MATCHING!
│ Original Taste   │ coca-cola │ coca-cola|cola|regular|none│
└──────────────────┴───────────┴──────────────────────────┘
```

---

## Testing This Yourself

### Run the unit test:
```bash
flutter test test/food_deduplication_test.dart
```

Should see:
```
✓ Coca Cola variants normalize to same brand (coca-cola)
✓ Coca Cola Coke Brand and Coca cola Goût Original share same family signature
✓ Language variants all collapse to same core (cola)
✓ Deduplication collapses all Coke variants into single canonical
```

### Run the app:
```bash
flutter run
```

Search "coke" in the app:
```
[1] Coca Cola Coke Brand (44 cal, regular) ← CANONICAL
    (also contains: Original Taste, Coca cola Goût Original)
[2] Diet Coke (0 cal, diet)
[3] Coke Zero (0 cal, zero)
[4] Cherry Flavored Coke (45 cal, cherry)
[5] Coke With Lime Flavor (42 cal, lime)
```

All three language variants merged into [1] ✓

