# Selector Mapping -- Upstream to Test Code

Maps each upstream UI element to the exact test code file and constant that
references it. Used by the diff analyzer to determine which files need updating
when an upstream element changes.

> **Note:** This file is a static reference snapshot. At runtime, the
> `test-code-analyzer` subagent builds this mapping dynamically by reading
> constants, page objects, and components from `stolostron/console-e2e@main`
> via the GitHub MCP. It also builds a full dependency graph
> (constant → page object → spec → Polarion ID) that the `diff-analyzer`
> uses for impact chain tracing. This static file serves as a seed/reference
> and is NOT the source of truth during a live skill run.

---

## Fleet Virt Selectors (kubevirt-plugin)

### Constants: `src/constants/fleet-virt.ts`

| Upstream Element | Constant Path | Selector Value | Used By |
|------------------|---------------|----------------|---------|
| VM search input | `FLEET_VIRT_SEARCH.searchInput` | `[data-test="vm-search-input"] input` | `FleetVirtPage`, `advanced-search.spec.ts` |
| Search results dropdown | `FLEET_VIRT_SEARCH.searchResults` | `[data-test="search-results"]` | `FleetVirtPage` |
| Search reset button | `FLEET_VIRT_SEARCH.resetButton` | `button[aria-label="Reset"]` | `FleetVirtPage` |
| Advanced search button | `FLEET_VIRT_ADVANCED_SEARCH.openButton` | `[data-test="vm-advanced-search-button"]` | `AdvancedSearchModal` |
| Adv search details | `FLEET_VIRT_ADVANCED_SEARCH.detailsContainer` | `[data-test="adv-search-details"]` | `AdvancedSearchModal` |
| Adv search VM name | `FLEET_VIRT_ADVANCED_SEARCH.nameInput` | `[data-test="adv-search-vm-name"]` | `AdvancedSearchModal` |
| Adv search cluster wrapper | `FLEET_VIRT_ADVANCED_SEARCH.cluster.wrapper` | `[data-test="adv-search-vm-cluster"]` | `AdvancedSearchModal` |
| Adv search project wrapper | `FLEET_VIRT_ADVANCED_SEARCH.project.wrapper` | `[data-test="adv-search-vm-project"]` | `AdvancedSearchModal` |
| Perspective switcher | `FLEET_VIRT_PAGE.perspectiveSwitcher` | `[data-test-id="perspective-switcher-toggle"]` | `FleetVirtPage` |
| Save search modal name | `FLEET_VIRT_SAVED_SEARCH.modal.nameInput` | `[data-test-id="save-search-name"]` | `SavedSearches` |
| Save search modal desc | `FLEET_VIRT_SAVED_SEARCH.modal.descriptionInput` | `[data-test-id="save-search-description"]` | `SavedSearches` |
| Save button | `FLEET_VIRT_SAVED_SEARCH.modal.submitButton` | `[data-test="save-button"]` | `SavedSearches` |
| Cancel button | `FLEET_VIRT_SAVED_SEARCH.modal.cancelButton` | `[data-test="cancel-button"]` | `SavedSearches` |
| Saved search list | `FLEET_VIRT_SAVED_SEARCH.dropdown.list` | `[data-test="saved-searches"]` | `SavedSearches` |
| VM actions dropdown | `FLEET_VIRT_VM_ACTIONS.dropdown` | `[data-test="actions-dropdown"]` | `VmDetailsPage` |
| VM start button | `FLEET_VIRT_VM_ACTIONS.startButton` | `[data-test-id="vm-action-start-button"]` | `VmDetailsPage` |
| VM stop button | `FLEET_VIRT_VM_ACTIONS.stopButton` | `[data-test-id="vm-action-stop-button"]` | `VmDetailsPage` |
| VM pause button | `FLEET_VIRT_VM_ACTIONS.pauseButton` | `[data-test-id="vm-action-pause-button"]` | `VmDetailsPage` |
| VM restart button | `FLEET_VIRT_VM_ACTIONS.restartButton` | `[data-test-id="vm-action-restart-button"]` | `VmDetailsPage` |
| VM status label | `FLEET_VIRT_VM_ACTIONS.statusLabel` | `[data-test-id="virtual-machine-overview-details-status"]` | `VmDetailsPage` |
| Confirm action button | `FLEET_VIRT_VM_ACTIONS.confirmAction` | `[data-test="confirm-action"]` | `VmDetailsPage`, `VmCloneModal` |
| Clone modal container | `FLEET_VIRT_CLONE_MODAL.container` | `[data-test="dialog-modal"]` | `VmCloneModal` |
| Clone name input | `FLEET_VIRT_CLONE_MODAL.nameInput` | `#name` | `VmCloneModal` |
| Clone start checkbox | `FLEET_VIRT_CLONE_MODAL.startOnCloneCheckbox` | `#start-clone` | `VmCloneModal` |
| Clone save button | `FLEET_VIRT_CLONE_MODAL.saveButton` | `[data-test="save-button"]` | `VmCloneModal` |
| Clone cancel button | `FLEET_VIRT_CLONE_MODAL.cancelButton` | `[data-test="cancel-button"]` | `VmCloneModal` |
| Tree view node toggle | `FLEET_VIRT_TREE_VIEW.nodeToggle` | `button.pf-v6-c-tree-view__node-toggle` | `TreeView` |
| Tree view node text | `FLEET_VIRT_TREE_VIEW.nodeText` | `button.pf-v6-c-tree-view__node-text` | `TreeView` |

### Fleet Virt Overview Widgets (live DOM `data-test` attributes)

| Upstream Element | data-test Value | Context |
|------------------|-----------------|---------|
| Cluster status widget | `cluster-status-widget` | Overview tab expandable section |
| VM health widget | `vm-health-widget` | Overview tab expandable section |
| Migration status section | `migration-status-section` | Overview tab: cross-cluster migration plans |
| Resource allocation section | `resource-allocation-section` | Overview tab expandable section |
| Tree view container | `vms-treeview` | Right panel cluster/project tree |
| OVirt status widget | `openshift-virtualization-widget` | Inside cluster status widget |
| Cluster resources card | `cluster-resources-card` | Clusters/Nodes/Projects/VMs counts |
| VM alerts widget | `vm-alerts-widget` | Inside VM health widget |
| Cross-cluster migrations widget | `cross-cluster-migration-plans-widget` | Inside migration status section |
| Overview tab | `overview-tab` | Tab switcher |
| VM list tab | `vm-list-tab` | Tab switcher |
| Fleet Virt nav list | `fleet-virtualization-perspective-perspective-nav` (data-test-id) | Sidebar navigation list |
| Fleet Mgmt nav list | `acm-perspective-nav` (data-test-id) | Sidebar navigation list |
| Perspective switcher | `perspective-switcher-toggle` (data-test-id) | Top-left perspective dropdown |

### Routes: `src/constants/fleet-virt.ts`

| Route Constant | Path | Used By |
|----------------|------|---------|
| `FLEET_VIRT_ROUTES.vmList` | `/fleet-virtualization/kubevirt.io~v1~VirtualMachine/all-clusters/all-namespaces` | `FleetVirtPage.goto()` |

---

## RBAC / User Management Selectors (stolostron/console)

### Constants: `src/constants/fg-rbac.ts`

| Upstream Element | Constant Path | Selector Value | Used By |
|------------------|---------------|----------------|---------|
| Create RA button (ID) | `RBAC_RA_TABLE.toolbar.createButtonId` | `create-role-assignment` | `RoleAssignmentsTable` |
| Create RA button (label) | `RBAC_RA_TABLE.toolbar.createButtonLabel` | `Create role assignment` | `RoleAssignmentsTable`, specs |
| Kebab actions (selector) | `RBAC_RA_TABLE.rowActions.kebabSelector` | `button.pf-v6-c-menu-toggle[aria-label="Actions"]` | `RoleAssignmentsTable` |
| Edit RA (ID) | `RBAC_RA_TABLE.rowActions.editId` | `edit-role-assignment` | `RoleAssignmentsTable` |
| Delete RA (ID) | `RBAC_RA_TABLE.rowActions.deleteId` | `delete-role-assignment` | `RoleAssignmentsTable` |
| Confirm input (ID) | `RBAC_RA_TABLE.rowActions.confirmInput` | `confirm` | `RoleAssignmentsTable` |
| Bulk delete button (ID) | `RBAC_RA_TABLE.toolbar.bulkDeleteButtonId` | `deleteRoleAssignments` | `RoleAssignmentsTable` |
| Scope selection step | `WIZARD_STEP_IDS.scopeSelection` | `scope-selection` | `RoleAssignmentWizardPage` |
| Identities step | `WIZARD_STEP_IDS.identities` | `identities` | `RoleAssignmentWizardPage` |
| Scope step | `WIZARD_STEP_IDS.scope` | `scope` | `RoleAssignmentWizardPage` |
| Role step | `WIZARD_STEP_IDS.role` | `role` | `RoleAssignmentWizardPage` |
| Review step | `WIZARD_STEP_IDS.review` | `review` | `RoleAssignmentWizardPage` |
| Cluster set granularity step | `WIZARD_STEP_IDS.clusterSetGranularity` | `scope-cluster-set-granularity` | `RoleAssignmentWizardPage` |
| Cluster granularity step | `WIZARD_STEP_IDS.clusterGranularity` | `scope-cluster-granularity` | `RoleAssignmentWizardPage` |
| Scope type select | `WIZARD_SELECT_IDS.scopeType` | `scope-type` | `RoleAssignmentWizardPage` |
| Clusters access level | `WIZARD_SELECT_IDS.clustersAccessLevel` | `clusters-access-level` | `RoleAssignmentWizardPage` |
| Cluster set access level | `WIZARD_SELECT_IDS.clusterSetAccessLevel` | `clusters-set-access-level` | `RoleAssignmentWizardPage` |
| Pre-auth save button | `RBAC_WIZARD.preAuthorizedUser.saveButton` | `Save pre-authorized user` | `RoleAssignmentWizardPage` |
| Create project button (ID) | `RBAC_WIZARD.projects.createButtonId` | `create-project` | `RoleAssignmentWizardPage` |
| Edit no-change alert | `RBAC_WIZARD.editMode.dangerAlertSelector` | `.pf-v6-c-alert.pf-m-danger` | `RoleAssignmentWizardPage` |

### Routes: `src/constants/fg-rbac.ts`

| Route Constant | Path | Used By |
|----------------|------|---------|
| `RBAC_ROUTES.identities` | `/multicloud/user-management/identities` | `UserDetailsPage` |
| `RBAC_ROUTES.roles` | `/multicloud/user-management/roles` | `RolesListPage` |
| `RBAC_ROUTES.users` | `/multicloud/user-management/identities/users` | `UserDetailsPage` |
| `RBAC_ROUTES.userDetails(id)` | `/multicloud/user-management/identities/users/{id}` | `UserDetailsPage.goto()` |
| `RBAC_ROUTES.roleDetails(id)` | `/multicloud/user-management/roles/{id}` | `RoleDetailsPage.goto()` |
| `RBAC_ROUTES.clusterSetDetails(n)` | `/multicloud/infrastructure/clusters/sets/details/{n}` | `ClusterSetDetailsPage` |
| `RBAC_ROUTES.groups` | `/multicloud/user-management/identities/groups` | `UserDetailsPage` (groups tab) |
| `RBAC_ROUTES.clusterDetails(ns, n)` | `/multicloud/infrastructure/clusters/details/{ns}/{n}` | `ClusterDetailsPage` |

### Text Labels (used in role-based locators)

| Label | Constant Path | Locator Pattern | Used By |
|-------|---------------|-----------------|---------|
| "Create role assignment" | `RBAC_RA_TABLE.toolbar.createButtonLabel` | `getByRole('button', { name: '...' })` | Wizard entry specs |
| "Role assignments" | `RBAC_USER_DETAIL.tabs.roleAssignments` | `getByRole('tab', { name: '...' })` | User/Role detail specs |
| "Details" | `RBAC_USER_DETAIL.tabs.details` | `getByRole('tab', { name: '...' })` | User detail specs |
| "Groups" | `RBAC_USER_DETAIL.tabs.groups` | `getByRole('tab', { name: '...' })` | User detail specs |
| "Global access" | `SCOPE_TYPES.global` | `getByText('...')` / select option | Wizard specs |
| "Select cluster sets" | `SCOPE_TYPES.clusterSets` | `getByText('...')` / select option | Wizard specs |
| "Select clusters" | `SCOPE_TYPES.clusters` | `getByText('...')` / select option | Wizard specs |

---

## PatternFly Selectors (cross-domain)

### Constants: `src/constants/selectors.ts`

| Upstream Element | Constant | Selector Value | Used By |
|------------------|----------|----------------|---------|
| PF version prefix | `PF` (local const) | `pf-v6-c` | All PF-based selectors |
| Spinner | `PF_SPINNER` | `.pf-v6-c-spinner` | `BasePage.waitForLoad()` |
| Skeleton | `PF_SKELETON` | `.pf-v6-c-skeleton` | `BasePage.waitForLoad()` |
| Modal box | `PF_MODAL` | `.pf-v6-c-modal-box` | Multiple page objects |
| Alert | `PF_ALERT` | `.pf-v6-c-alert` | `RoleAssignmentWizardPage` |
| Select | `PF_SELECT` | `.pf-v6-c-select` | Multiple page objects |
| Dropdown | `PF_DROPDOWN` | `.pf-v6-c-dropdown` | Multiple page objects |
| Table | `PF_TABLE` | `.pf-v6-c-table` | `AcmTable` component |

---

## Maintenance

This mapping is regenerated on each drift check by the test-code-analyzer
subagent. If you manually add a new selector to the constants files, it will
be picked up automatically on the next run.

When adding a new page object or component that introduces new selectors,
no changes are needed here -- the analyzer discovers them from the source.
