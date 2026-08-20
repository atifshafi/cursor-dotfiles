# Live Validator Subagent

**Cursor Subagent Type:** `live-validator`
**Shared Agent Reference:** `~/.cursor/agents/live-validator.md`

Navigate to Fleet Virt and RBAC pages on a live ACM cluster and capture the
actual DOM state for comparison against source code and test expectations.

## Context

You are a `live-validator` specialist running in **drift detection mode**. Your
standard capabilities (browser MCP: navigate, snapshot, click, screenshot; oc CLI:
resource checks, cluster health) are all available. This template specifies which
pages to visit and what DOM attributes to extract for drift comparison.

You are validating the LIVE UI to catch runtime rendering differences that
source code analysis alone cannot detect (conditional rendering, feature gates,
dynamic plugin loading, PatternFly version mismatches).

**Cluster Console URL:** {CLUSTER_URL}
**Cluster Password:** {CLUSTER_PASSWORD}

## Cluster Source

The cluster URL and password come from `~/Documents/work/notes/notes.md` (lines 1-3),
maintained by the user as a standing reference. If authentication is required during
navigation (login page detected), use `kubeadmin` / `{CLUSTER_PASSWORD}` to log in.

## Instructions

Use the `playwright` MCP server for all browser interactions.

### Tab Detection Protocol (applies to every page visit)

After navigating to any page and waiting for it to load, run this protocol:

1. **Take initial snapshot:**
   ```
   CallMcpTool: playwright -> browser_snapshot()
   ```

2. **Detect tabs:** In the snapshot output, search for elements with `role="tab"`.
   Tabs appear as `tab "Name" [selected]` or `tab "Name"` in the accessibility tree.

3. **If tabs are found:**
   a. Record the default (currently selected) tab name
   b. Record all tab names as a list
   c. For the DEFAULT tab: extract page elements and `data-test`/`data-testid`
      attributes as described in the page-specific step below
   d. For EACH non-default tab:
      - Click the tab:
        ```
        CallMcpTool: playwright -> browser_click(element="<tab name> tab", target="[role='tab']:has-text('<tab name>')")
        ```
      - Wait for content to render:
        ```
        CallMcpTool: playwright -> browser_wait_for(time=2)
        ```
      - Take a new snapshot:
        ```
        CallMcpTool: playwright -> browser_snapshot()
        ```
      - Extract elements and `data-test`/`data-testid` attributes for this tab
   e. Navigate back to the default tab when done (click it again)

4. **If no tabs found:** Set `tabStructure: null` and proceed with normal extraction.

5. **Build `tabStructure` output** (see Output Format section).

---

### Step 1: Navigate to Fleet Virtualization

```
CallMcpTool: playwright -> browser_navigate(url="{CLUSTER_URL}/fleet-virtualization/kubevirt.io~v1~VirtualMachine/all-clusters/all-namespaces")
```

Wait for the page to load (Fleet Virt uses the OCP dynamic plugin, which may
take a few seconds after initial navigation).

```
CallMcpTool: playwright -> browser_wait_for(time=5)
CallMcpTool: playwright -> browser_wait_for(textGone="Loading")
```

### Step 2: Snapshot Fleet Virt Page (with Tab Detection)

Run the **Tab Detection Protocol** above. The Fleet Virt page typically has
two tabs: "Overview" (default) and "Virtual machines".

For **each tab snapshot**, extract:
- Page heading text
- Toolbar elements (search input, buttons, filters)
- Table headers (column names)
- Any empty state messages
- Sidebar tree view structure (if visible)
- PatternFly version from CSS classes
- All `data-test` and `data-testid` attribute values visible in the snapshot
- **Perspective switcher** (`data-test-id="perspective-switcher-toggle"`) — confirm
  the 3-perspective architecture: Core platform, Fleet management, Fleet virtualization
- **Fleet Virt nav list** (`data-test-id="fleet-virtualization-perspective-perspective-nav"`)
  — record all nav items and their data-test-id values

Take a screenshot on each tab:
```
CallMcpTool: playwright -> browser_take_screenshot()
```

### Step 3: Navigate to User Management

```
CallMcpTool: playwright -> browser_navigate(url="{CLUSTER_URL}/multicloud/user-management/identities/users")
CallMcpTool: playwright -> browser_wait_for(time=5)
```

### Step 4: Snapshot User Management Page (with Tab Detection)

Run the **Tab Detection Protocol**. User Management has tabs:
"Users" (default), "Groups", and "Service accounts" (added in ACM 5.1;
may not be present on ACM 5.0 clusters — `ServiceAccounts.tsx` exists
in stolostron/console source at
`frontend/src/routes/UserManagement/Identities/ServiceAccounts/`).

For **each tab snapshot**, extract:
- Tab labels
- Table column headers
- Toolbar buttons ("Create role assignment")
- Filter options
- All `data-test` and `data-testid` attribute values
- Any list entries visible

### Step 5: Open the Role Assignment Wizard (if possible)

**Navigate to a user's Role Assignments tab** (not a group) to match the test
code's expected wizard flow. The generic wizard title is "Create role assignment"
— the group-context wizard shows "Create role assignment for {group-name}" which
is a different title. If no users exist (IDP not configured, empty state visible),
skip this step and log: "Wizard capture skipped — no users available (IDP not configured)."

If users are available, navigate to a user detail page's Role Assignments tab,
then try clicking the "Create role assignment" button:
```
CallMcpTool: playwright -> browser_click(element="Create role assignment button", target="button:has-text('Create role assignment')")
```

If the wizard opens:
```
CallMcpTool: playwright -> browser_snapshot()
CallMcpTool: playwright -> browser_take_screenshot()
```

Extract:
- Wizard step names (visible labels like "Scope", "Roles", "Review")
- Scope type dropdown options
- Form field labels
- Button labels (Next, Back, Submit, Cancel)

Close the wizard after capturing:
```
CallMcpTool: playwright -> browser_press_key(key="Escape")
```

### Step 6: Navigate to Roles Page

```
CallMcpTool: playwright -> browser_navigate(url="{CLUSTER_URL}/multicloud/user-management/roles")
CallMcpTool: playwright -> browser_wait_for(time=5)
CallMcpTool: playwright -> browser_snapshot()
CallMcpTool: playwright -> browser_take_screenshot()
```

Extract:
- Page heading and subtitle text
- Role names visible in the table
- Column headers (sortable or not)
- Any virt-specific roles (kubevirt.io:*, acm-vm-*)
- Toolbar elements (search, filter)
- **Fleet management nav list** (`data-test-id="acm-perspective-nav"`) — record
  all nav sections and items, especially User management sub-items

## Output Format

Return your findings as a single JSON structure:

```json
{
  "scanTimestamp": "<ISO 8601>",
  "clusterUrl": "{CLUSTER_URL}",

  "pages": [
    {
      "name": "Fleet Virt",
      "url": "<actual URL loaded>",
      "loaded": true,
      "tabStructure": {
        "defaultTab": "Overview",
        "tabs": [
          {
            "name": "Overview",
            "isDefault": true,
            "dataTestIds": ["cluster-status-widget", "vm-health-widget", "..."],
            "elements": {
              "heading": "<page heading text>",
              "toolbarButtons": ["<button text>", "..."],
              "tableHeaders": [],
              "emptyState": null
            }
          },
          {
            "name": "Virtual machines",
            "isDefault": false,
            "dataTestIds": ["vm-search-input", "vm-advanced-search-button", "..."],
            "elements": {
              "heading": "<page heading text>",
              "toolbarButtons": ["<button text>", "..."],
              "tableHeaders": ["<column>", "..."],
              "searchInput": { "present": true, "placeholder": "<text>" },
              "treeView": { "present": true, "nodes": ["<node text>", "..."] },
              "emptyState": "<message if no VMs>"
            }
          }
        ]
      },
      "pfClasses": ["pf-v6-c-*", "..."],
      "screenshotTaken": true
    },
    {
      "name": "User Management",
      "url": "<actual URL>",
      "loaded": true,
      "tabStructure": {
        "defaultTab": "Users",
        "tabs": [
          {
            "name": "Users",
            "isDefault": true,
            "dataTestIds": ["<id>", "..."],
            "elements": { "tableHeaders": ["<column>", "..."], "toolbarButtons": ["..."] }
          },
          {
            "name": "Groups",
            "isDefault": false,
            "dataTestIds": ["<id>", "..."],
            "elements": { "tableHeaders": ["<column>", "..."] }
          }
        ]
      }
    },
    {
      "name": "Role Assignment Wizard",
      "url": "<same page, modal open>",
      "loaded": true,
      "tabStructure": null,
      "elements": {
        "wizardSteps": ["<step name>", "..."],
        "scopeTypes": ["<option>", "..."],
        "formFields": ["<label>", "..."],
        "buttons": ["<button text>", "..."]
      }
    },
    {
      "name": "Roles Page",
      "url": "<actual URL>",
      "loaded": true,
      "tabStructure": null,
      "elements": {
        "heading": "<page heading>",
        "subtitle": "<subtitle text>",
        "roles": ["<role name>", "..."],
        "tableHeaders": ["<column>", "..."],
        "toolbar": ["<element>", "..."]
      }
    }
  ],

  "perspectives": {
    "switcherPresent": true,
    "switcherId": "perspective-switcher-toggle",
    "perspectives": ["Core platform", "Fleet management", "Fleet virtualization"],
    "fleetVirtNavId": "fleet-virtualization-perspective-perspective-nav",
    "fleetMgmtNavId": "acm-perspective-nav"
  },

  "errors": [
    { "page": "<page name>", "error": "<what went wrong>" }
  ]
}
```

## Important

- If a page fails to load (404, timeout, plugin not available), log the error
  in the `errors` array and continue with the next page. Do NOT stop.
- If the cluster requires login, report "Authentication required" and stop.
  The orchestrator will handle re-authentication.
- Extract element text EXACTLY as rendered. Do not normalize capitalization
  or whitespace.
- The PatternFly version is critical -- check CSS class prefixes on multiple
  elements to confirm consistency (e.g., `pf-v6-c-button`, `pf-v6-c-table`).
- For the wizard, only attempt to open it if there is a user in the table.
  On an empty user list, the button may be disabled.
