# LabTrack — User Manual

> Version 1.0 · May 2026

---

## Table of Contents

1. [What is LabTrack?](#1-what-is-labtrack)
2. [Getting Started](#2-getting-started)
3. [Dashboard](#3-dashboard)
4. [Inventory](#4-inventory)
5. [Products](#5-products)
6. [Movements](#6-movements)
7. [Inventory Count](#7-inventory-count)
8. [Reports](#8-reports)
9. [Settings](#9-settings)
10. [Barcode Scanning](#10-barcode-scanning)
11. [Sync and Offline Use](#11-sync-and-offline-use)
12. [Two Lab Workflows](#12-two-lab-workflows)

---

## 1. What is LabTrack?

LabTrack is a mobile application for laboratory inventory management. It allows you to:

- Register products with or without lot numbers
- Track entries, exits, returns, and stock adjustments
- Perform periodic physical inventory counts (weekly, monthly, etc.)
- View consumption reports, historical trends, and discrepancy analyses
- Work offline — data syncs automatically when a connection is available
- Manage multiple laboratories from a single account

---

## 2. Getting Started

### 2.1 Sign In

When you open the app for the first time you will see the **Login** screen.

- Enter your email address and password.
- If you do not yet have an account, tap the **Sign up** link to register.
- Once authenticated, the app takes you to the laboratory selector.

### 2.2 Select or Create a Laboratory

On the **Lab Picker** screen:

- If you already belong to a laboratory, it will appear in the list — tap it to enter.
- To create a new one, tap **Create new lab**, enter a name, and confirm.
- If you have been invited to an existing laboratory, an administrator must add you from Settings.

> You can switch laboratories at any time from **Settings → Switch laboratory**.

---

## 3. Dashboard

The Dashboard is the home screen. It displays a summary of the current inventory status.

### Key Performance Indicators (KPIs)

| Indicator | Description |
|-----------|-------------|
| **Products** | Total number of active registered products |
| **Alerts** | Number of products with critical or zero stock |
| **Reorder** | Products that have fallen below their reorder point |

### Alert Sections

- **Critical Stock** — products below the configured minimum level. Tap any card to go to the product detail.
- **Reorder Needed** — products that dropped below the reorder point but are not yet critical.
- **Expiring Soon (≤ 30 days)** — lots with an upcoming expiry date. Shows the specific lot and its date.
- **All clear** — appears when no active alerts exist.

### Quick Actions

- **Settings** (gear icon, top-right corner) → opens the Settings screen.
- **Sign out** (exit icon) → logs out of the app.

---

## 4. Inventory

The **Inventory** tab shows all active products with their current stock quantity.

### Search and Filter

- **Search bar** — filters by product name or barcode. A clear button (×) appears when text is entered.
- **Scan barcode** (scanner icon, AppBar) — opens the camera to search by barcode.
- **Status chips** — filter the list by stock status:
  - `All` — all products
  - `OK` — stock within normal levels
  - `Reorder` — below the reorder point
  - `Critical` — below the minimum stock level
  - `Out` — zero stock

### Product Card

Each card shows:
- Product name and unit of measure
- Barcode (if assigned)
- Whether the product uses lots or direct quantity
- **Stock badge** with color indicator:
  - Green → OK
  - Amber → reorder
  - Red → critical or out of stock

Tap a card to view the **product detail** (lots, quantity per lot, expiry dates).

### Add a Product

Tap the **+ Add product** button (bottom-right corner) to open the product creation form.

---

## 5. Products

The **Products** screen (accessible from Inventory → Add product, or from the general catalog) lists all registered products.

### Adding a New Product

Tap the **+** icon in the AppBar. The form asks for:

| Field | Required | Description |
|-------|----------|-------------|
| Name | Yes | Descriptive product name |
| Unit | Yes | Unit of measure (mL, g, L, units, etc.) |
| Barcode | No | Can be scanned with the camera |
| Category | No | Select from configured categories |
| Supplier | No | Select from the supplier catalog |
| Location | No | Storage location |
| Storage Condition | No | Temperature, humidity, light sensitivity |
| Minimum Stock | No | Critical level — triggers an alert when reached |
| Reorder Point | No | Preventive reorder level — triggers a preventive alert |
| **Tracks lots** | No | Enable if this product is controlled by lot number and expiry date |

> **Tracks lots?** — When enabled, stock is calculated by summing the quantities of all active lots. When disabled, stock is a direct value updated by movements.

### Editing a Product

From the product list, tap the product and then the edit icon, or tap the row directly on the Inventory screen.

---

## 6. Movements

The **Movements** tab records all transactions that affect stock. Each movement is saved to the history log.

### Movement Types

| Type | When to Use |
|------|-------------|
| **Entry** | Receiving new stock or restocking |
| **Exit** | Consumption or dispensing of a product |
| **Return** | Returning a product to inventory (e.g. leftover from an experiment) |

### Registering a Movement

1. Tap the corresponding button on the Movements screen:
   - **Entry** (primary green button)
   - **Exit** (primary button, top row)
   - **Return** (secondary button, bottom row)
2. Select the product (search by name or scan).
3. If the product uses lots, select a lot or create a new one (for entries).
4. Enter the quantity.
5. Optionally add a reason, area, or project.
6. Tap **Save** to confirm.

Stock is updated immediately.

### Scan Count

From the Movements screen, tap the **Scan Count** button to start an individual item-by-item count by scanning:

1. Scan or select a product.
2. Enter the physically counted quantity.
3. Repeat for each product.
4. When finished, tap **Save count result** (if everything matches) or **Approve N adjustments** (if there are differences — this applies the adjustments to the inventory).

The count session is saved to the history.

### Movement History

The main list on the Movements tab shows the last 50 movements for the laboratory, ordered from most recent to oldest, with type, product, quantity, and date.

---

## 7. Inventory Count

The **Count** tab (Weekly Count) is used to perform a complete physical inventory count.

### How It Works

1. Tap **Start Count Session**.
2. The app loads all active products with their current system quantities.
3. For each product, enter the quantity you physically found.
4. When finished, the app compares expected vs. counted quantities and displays discrepancies.
5. Tap **Approve adjustments** to apply the differences to the inventory, or **Save without adjusting** to save the count without modifying stock.

### Count Session Results

Each count session saves:
- Date and time of the count
- Total number of products counted
- Number of discrepancies found
- Per-product detail: expected quantity, counted quantity, and difference

You can review count history from **Reports → History**.

> **Recommended frequency:** For labs that do not record individual movements, weekly or monthly counts are recommended to keep the inventory up to date.

---

## 8. Reports

The **Reports** tab has two levels: the current status report and three historical analysis reports.

### Status Report (Main Screen)

Shows a snapshot of the inventory at the current moment:

- **KPIs:** total products, active alerts, products on reorder
- **Out of Stock** — products with zero stock
- **Critical Stock** — products below their minimum level
- **Reorder Needed** — products below their reorder point
- **Expiring Soon** — lots approaching their expiry date
- **Full Inventory** — complete list with quantity and status for each product

Available actions:
- **Sync to Google Sheets** (table icon) — exports the current inventory to a Google Sheets spreadsheet.
- **Share via email** — generates a text report and opens it in the mail client for sharing.

### Analysis Reports (Quick-Access Cards)

Tap any of the three cards below the header:

---

#### Consumption

Shows how much of each product has been consumed over a selected period, **based on registered exit movements**.

- Select the period using the chips: **Last 7 days**, **Last 30 days**, **Last 90 days**.
- Products are listed from highest to lowest consumption.
- Each row shows the total consumed, the unit, and how many individual movements make it up (badge `×N`).
- The progress bar is proportional to the most-consumed product.

> If the laboratory does not record individual exits, this screen will be empty with a guide to start doing so.

---

#### Trend (Inventory Trend)

Shows how the physical inventory has evolved across the most recent counts, **based on saved count sessions**.

- The table has one column per count session (max. 4 recent sessions, from oldest to newest).
- The **Change** column shows the difference between the first and last recorded count for each product:
  - Red with `−` → consumption (quantity decreased)
  - Green with `+` → increase (quantity increased)
- Products not counted in a session appear as `—`.

> This report is useful for both movement-tracking labs and count-only labs. The "Change" column lets you infer consumption between periods.

---

#### History (Count History)

Lists all saved count sessions, from most recent to oldest.

- Tap any session to expand it and see the per-product detail.
- The expanded view shows: product, expected quantity, counted quantity, and a difference badge (green = no discrepancy, red = shortage, amber = surplus).

---

## 9. Settings

Access from the gear icon on the Dashboard (top-right corner).

### Laboratory

Shows the name of the active laboratory and your role (Admin / Member).

- **Switch laboratory** — returns to the lab selector to switch to another laboratory in your account.

### Categories

Groups products by type (e.g. Reagents, Equipment, Cleaning Materials).

- Tap **+ Add category** to create one.
- Tap the edit icon (pencil) to rename it.
- Tap the delete icon (trash) to remove it.

> Deleted categories do not affect products that already had them assigned.

### Locations

Defines storage locations within the laboratory (e.g. Refrigerator 1, Cabinet A, Storage Room).

- Same operations as Categories.

### Suppliers

Supplier catalog with name, contact email, and phone number.

- Tap **+ Add supplier** to create one.
- Fill in the name (required), email, and phone (optional).
- Edit and delete work the same way as in other sections.

### Storage Conditions

Defines specific storage conditions that can be assigned to products.

- **Name** — descriptive label (e.g. "Refrigeration 2–8 °C")
- **Temp min / Temp max** — temperature range in °C (optional)
- **Humidity max** — maximum humidity in % (optional)
- **Light sensitive** — enable this toggle if the product must be protected from light

### Alerts

Configure when you want to receive notifications:

- **Expiry alert days** — how many days before expiry you want an alert (you can add multiple values, e.g. 30, 60, 90 days)
- **Reorder notifications** — enable/disable alerts when a product reaches its reorder point
- **Critical stock notifications** — enable/disable alerts when a product reaches its critical level

Tap **Save** to confirm changes.

---

## 10. Barcode Scanning

LabTrack can read barcodes and QR codes in several parts of the app:

| Where | Purpose |
|-------|---------|
| Inventory (AppBar) | Search for a product by code |
| Product form | Assign a barcode to the product |
| Movement registration | Select the product being moved |
| Scan Count | Count products by scanning them one by one |

When tapping the scanner icon, the app will request camera permission on the first use. Point the camera at the code and it is read automatically.

---

## 11. Sync and Offline Use

LabTrack works fully offline. All data is stored locally on your device.

When a connection is available, the app syncs automatically:

- When opening the Inventory tab
- After registering a movement
- After saving a count session

Sync is bidirectional: changes made on one device appear on other devices in the same laboratory once both are online.

> **Tip:** If you work in a team, it is good practice for each member to sync at the start and end of their shift to avoid data conflicts.

---

## 12. Two Lab Workflows

LabTrack adapts to two distinct working styles:

### Movement-Tracking Lab

The team records every entry, exit, and return in real time.

**Benefits:**
- Inventory always reflects the current state without frequent counts.
- The **Consumption** report shows exactly how much of each product was used.
- Periodic counts serve as **audits**: comparing what the system says vs. what is physically present (discrepancies).

**Recommended workflow:**
1. Register entries when stock arrives.
2. Register exits every time a product is consumed.
3. Perform a monthly count to detect discrepancies.
4. Review the Consumption report to analyze usage trends.

---

### Count-Only Lab

The team does not record individual movements; instead, it performs regular complete inventory counts.

**Benefits:**
- Requires less day-to-day discipline.
- Useful when consumption is very frequent and recording individually would be impractical.

**Recommended workflow:**
1. Perform a weekly or monthly count from the **Count** tab.
2. Approve adjustments at the end of the count so the system reflects reality.
3. Review the **Trend** report to see how inventory evolved between counts and infer consumption for the period.

---

## Glossary

| Term | Meaning |
|------|---------|
| **Lot** | A batch of a product identified by lot number and expiry date |
| **FEFO** | First Expired, First Out — the system orders lots from earliest to latest expiry |
| **Minimum Stock** | Level below which stock is considered critical |
| **Reorder Point** | Preventive level that signals it is time to reorder |
| **Tracks lots** | Product property indicating whether its stock is controlled by individual lots |
| **Direct quantity** | Direct stock value for a product that does not use lots |
| **Discrepancy** | Difference between the expected quantity (system) and the physically counted quantity |
| **Sync** | Process of synchronising between the device's local database and the cloud server |

---

*LabTrack is built with Flutter + Supabase.*
