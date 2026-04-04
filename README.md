# LabTrack

> Mobile inventory management app for laboratory supplies. Tracks stock levels, expiration dates, and consumption with barcode scanning, offline support, and automatic Google Sheets synchronization. Designed as a standalone solution or integrated with external systems via REST API.

---

## Overview

```
         Scan or manual entry
                 │
         ┌───────▼────────┐
         │   LabTrack App  │  Flutter · iOS & Android
         │                 │
         │  ┌───────────┐  │
         │  │  Offline  │  │  SQLite local storage
         │  │  Storage  │  │  auto-sync on reconnect
         │  └─────┬─────┘  │
         └────────┼────────┘
                  │
         ┌────────▼────────┐
         │    Supabase     │  PostgreSQL · Auth · Realtime
         │                 │
         │  Multi-tenant   │  One instance, multiple labs
         │  Row Level Sec  │
         └────────┬────────┘
                  │
       ┌──────────┴──────────┐
       │                     │
┌──────▼──────┐     ┌────────▼────────┐
│Google Sheets│     │   REST API      │
│  Auto-sync  │     │  External apps  │
└─────────────┘     └─────────────────┘
```

---

## Key Features

- **Barcode scanning** — scan existing barcodes or generate internal codes for lab-produced reagents
- **Expiration tracking** — per-lot expiration dates with configurable advance alerts (30 / 60 / 90 days)
- **Smart alerts** — reorder point, critical stock, and expiry push notifications
- **Offline first** — full functionality without internet, auto-sync when connection is restored
- **Weekly physical count** — guided flow to compare expected vs counted stock and approve adjustments
- **Google Sheets sync** — inventory updates reflected automatically in a connected spreadsheet
- **Multi-tenant** — supports multiple independent laboratories in a single deployment
- **REST API** — consume or integrate inventory data from external systems

---

## Stock Level Logic

```
                    ┌─────────────────────────────────┐
  Stock level       │                                 │
                    │  ██████████████████████  Full   │
                    │                                 │
  Reorder point ──► │  ░░░░░░░░░░░░░░          🟡    │  "Place order now"
                    │                                 │
  Minimum stock ──► │  ░░░░░░                   🔴    │  "Critical — urgent order"
                    │                                 │
  Zero ──────────►  │                           ☠️    │  "Out of stock"
                    └─────────────────────────────────┘
```

Each product has:
- **Reorder point** — trigger to request purchase
- **Minimum stock** — critical threshold before operations are at risk
- **Estimated delivery time** — used to calculate how many days of stock remain before crisis

---

## Expiration Management (FEFO)

```
  Product: Sodium Chloride NaCl

  Lot A  ──  Qty: 200g  ──  Expires: 2026-06-15  ◄── consumed first
  Lot B  ──  Qty: 500g  ──  Expires: 2027-01-20
  Lot C  ──  Qty: 500g  ──  Expires: 2027-08-05

  Total stock: 1200g
  ⚠️  Lot A expires in 73 days
```

FEFO (First Expired, First Out) — the app always suggests consuming the lot closest to expiration.

---

## Weekly Inventory Flow

```
  1. Start count session
          │
  2. Scan or enter each product quantity
          │
  3. System compares: recorded vs counted
          │
          ├── Match ──────────────────► ✅ Confirmed
          │
          └── Difference detected ──► Show discrepancy
                      │
              4. Approve adjustment
                      │
              5. Movement logged with reason
                      │
              6. Google Sheet updated automatically
```

---

## Google Sheets Structure

| Sheet | Content |
|---|---|
| **Stock** | Current inventory — product, quantity, unit, location, status |
| **Expiring Soon** | Lots expiring in the next 90 days |
| **Movements** | All entries, exits, and adjustments with user and timestamp |
| **Restock Needed** | Products at or below reorder point, ready to share |

---

## Data Model

```
laboratories
  └── users (roles per lab)
  └── categories
  └── storage_conditions       (temperature range, humidity, light)
  └── locations                (rooms, fridges, shelves)
  └── suppliers
  └── products
        └── lots               (lot number, expiration, quantity)
              └── stock_by_location
  └── movements                (entry | exit | adjustment | return)
        └── area / project     (optional)
  └── restock_requests         (with external reference for ERP integration)
  └── alert_config             (thresholds, advance days, recipients)
  └── webhooks                 (outbound events to external systems)
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter (iOS & Android) |
| Barcode scanning | mobile_scanner |
| Barcode generation | barcode_widget |
| Local storage | Drift (SQLite) |
| Backend | Supabase (PostgreSQL + Auth + Realtime) |
| Push notifications | Firebase Cloud Messaging |
| Spreadsheet sync | Google Sheets API |
| API | Supabase Edge Functions |

---

## App Screens

```
LabTrack
  ├── Login
  ├── Dashboard          ← alerts summary + stock overview
  ├── Inventory
  │     ├── Product list (with stock status indicators)
  │     ├── Product detail (lots, expiration, history)
  │     └── Search by name or barcode scan
  ├── Movements
  │     ├── Register entry
  │     ├── Register exit
  │     └── History log
  ├── Weekly Count       ← guided physical inventory flow
  ├── Products
  │     ├── Add / edit
  │     └── Generate internal barcode
  ├── Reports
  │     ├── Visual dashboard
  │     └── Share restock report (WhatsApp / email)
  └── Settings
        ├── Alert thresholds
        └── Suppliers
```

---

## REST API

The system exposes endpoints for integration with external applications:

```
GET  /api/inventario/{lab_id}           current stock
GET  /api/productos/{barcode}           find product by barcode
POST /api/movimientos                   register entry or exit
GET  /api/alertas/{lab_id}             active alerts
GET  /api/lotes/por-vencer/{lab_id}    lots expiring soon
```

Each request requires an API key scoped to the laboratory.

---

## Outbound Webhooks

LabTrack can notify external systems when inventory events occur:

| Event | Payload |
|---|---|
| `stock_critico` | product, current quantity, reorder point |
| `vencimiento_proximo` | lot, product, expiration date, days remaining |
| `lote_vencido` | lot, product |
| `entrada_registrada` | product, quantity, lot, user |
| `ajuste_aprobado` | product, expected, counted, difference, user |

---

## License

MIT
