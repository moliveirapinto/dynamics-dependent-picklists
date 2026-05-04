# Dependent Picklists for Dynamics 365 / Dataverse

A lightweight, no-code-for-end-users solution that lets makers configure **dependent option-set (choice) fields** on any Dynamics 365 / Model-Driven App form — and *also* paints each option with a colored pill so users can spot the right value at a glance.

> Built and tested on Dynamics 365 Customer Service (Case form), but works on any model-driven entity with two choice fields.

---

## ✨ What it does

1. **Matrix admin UI** — pick an entity, a *controlling* choice field and a *dependent* choice field. A grid lets you tick which dependent values are allowed for each controlling value.
2. **Multi-form registration** — register / unregister the runtime script on any number of forms with one click.
3. **Runtime filtering** — at form load and on every change of the controlling field, the dependent field is filtered to the allowed values only.
4. **Colored option pills** — the runtime auto-fetches each choice field's `Color` metadata and paints both the open dropdown options *and* the selected display with a soft-tinted pill (left border + matching background). Hover highlight is included for free.
5. **Multi-document / portal-aware** — works even when the listbox renders in a portal layer attached to `window.top`.

## 📦 What's in the box

| Component | Logical Name | Purpose |
|-----------|--------------|---------|
| Custom table | `mau_dependentpicklistrule` | One row per controlling-value → allowed-dependent-values rule |
| Web resource (HTML) | `mau_DependentPicklistAdmin.html` | Admin matrix UI |
| Web resource (JS) | `mau_DependentPicklistRuntime.js` | Form runtime (v1) |
| Web resource (JS) | `mau_DependentPicklistRuntimeV2.js` | Form runtime (v2 — same code, different name to bust UCI cache) |

The runtime entry point is `MauDependentPicklist.onLoad` (registered as the form `OnLoad` handler).

---

## 🚀 Install (end users)

1. Download the latest **`DependentPicklists_managed.zip`** from the [Releases](../../releases) page.
2. In your target environment: **Power Apps** → **Solutions** → **Import solution** → pick the zip → **Next** → **Import**.
3. Open the solution and launch the **Dependent Picklist Admin** web resource (or surface it via a sitemap entry / bookmark).
4. Select an entity + controlling field + dependent field, tick the allowed combinations, hit **Save rules**.
5. In the **Forms** matrix, tick the form(s) you want the runtime registered on and click **Save**.
6. Hard-refresh the target form (`Ctrl+F5`) — done.

> Prefer the **unmanaged** zip if you want to keep the source editable in your dev environment.

---

## 🛠️ Develop / contribute

Prereqs: Windows PowerShell 5+, [Power Platform CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction) (`pac`), [GitHub CLI](https://cli.github.com/) (optional, for releases).

```powershell
# 1. Authenticate against your dev environment
pac auth create --environment https://<yourorg>.crm.dynamics.com

# 2. Edit files under .\webresources\

# 3. Push the changed web resources + publish
. .\scripts\dv.ps1
foreach ($n in @('mau_DependentPicklistRuntime.js','mau_DependentPicklistRuntimeV2.js','mau_DependentPicklistAdmin.html')) {
  $bytes = [IO.File]::ReadAllBytes("$PWD\webresources\$n")
  $b64 = [Convert]::ToBase64String($bytes)
  $id = (Invoke-Dv -Method GET -Path "/api/data/v9.2/webresourceset?`$select=webresourceid&`$filter=name eq '$n'").value[0].webresourceid
  Invoke-Dv -Method PATCH -Path "/api/data/v9.2/webresourceset($id)" -Body @{content=$b64} | Out-Null
}
Invoke-Dv -Method POST -Path "/api/data/v9.2/PublishAllXml" -Body @{} | Out-Null

# 4. Re-export the solution zip for a release
pac solution export --name DependentPicklists --path .\dist\DependentPicklists.zip --overwrite
pac solution export --name DependentPicklists --path .\dist\DependentPicklists_managed.zip --managed --overwrite
```

Numbered scripts in `scripts/` document the original bring-up of the solution (publisher, table, columns, web-resource upload, form patching). They're idempotent and can be re-run.

---

## 🧠 How it works

- **Rules table** stores one row per `(entity, controlling field, controlling option value, dependent field, allowed dependent values)`. Allowed values are a comma-separated list of option codes.
- **Runtime** uses `formContext.getAttribute(controllingField).addOnChange(...)` to react to changes. It removes disallowed dependent options via `control.removeOption(value)` and restores them later via `control.addOption({value, text}, index)` — so no metadata is mutated.
- **Color injection** queries `EntityDefinitions(LogicalName='X')/Attributes(LogicalName='Y')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?$select=LogicalName&$expand=OptionSet($select=Options)` once per field, builds a `byText` color map, then a MutationObserver + lightweight 100ms poll (only while a tracked combobox is expanded) keeps the pills painted across virtual-DOM rebuilds and portal layers.
- **No metadata changes, no plugins, no custom controls** — pure web resources + a single configuration table.

---

## ❓ Troubleshooting

| Symptom | Fix |
|---------|-----|
| Nothing happens on the form | Hard-refresh (`Ctrl+F5`). UCI caches scripts very aggressively. |
| Admin shows ✗ on a form you registered manually | Make sure the script library on the form is exactly `mau_DependentPicklistRuntime.js` *or* `mau_DependentPicklistRuntimeV2.js` and the handler is `MauDependentPicklist.onLoad`. The admin recognizes both filenames. |
| Pills disappear after re-picking the same value | Should be fixed in v1.0.0.6. If you see it again, capture the console — the runtime logs `Color observer attached for fields: [...]`. |

---

## 📄 License

MIT — see [LICENSE](LICENSE).
