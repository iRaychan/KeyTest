(() => {
  "use strict";

  const VERSION = "0.5.0";
  const BUTTON_ID = "keyaiDraftInboxButton";
  const DIALOG_ID = "keyaiDraftInboxDialog";
  const QUOTES_KEY = "ks_quotes";
  const PENDING_KEY = "ks_keyai_pending_imports_v050";
  let drafts = [];
  let busy = false;

  const esc = (value) => String(value ?? "")
    .replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;").replaceAll("'", "&#039;");

  const readJson = (key, fallback) => {
    try { const raw = localStorage.getItem(key); return raw ? JSON.parse(raw) : fallback; }
    catch { return fallback; }
  };
  const writeJson = (key, value) => localStorage.setItem(key, JSON.stringify(value));
  const uuid = () => globalThis.crypto?.randomUUID?.() ?? `keyai-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const today = () => {
    const date = new Date();
    return new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
  };
  const client = () => window.KeySuiteAuth?.getClient?.() ?? null;

  async function session() {
    const direct = window.KeySuiteAuth?.getSession?.();
    const resolved = direct && typeof direct.then === "function" ? await direct : direct;
    if (resolved?.access_token) return resolved;
    if (resolved?.data?.session?.access_token) return resolved.data.session;
    return (await client()?.auth?.getSession?.())?.data?.session ?? null;
  }

  function functionUrl(action) {
    if (window.KEYAI_FUNCTION_URL) {
      return `${String(window.KEYAI_FUNCTION_URL).replace(/\/$/, "")}?action=${encodeURIComponent(action)}`;
    }
    const supabase = client();
    const base = supabase?.supabaseUrl || window.KEYSUITE_SUPABASE_URL ||
      window.KEYSUITE_CONFIG?.supabaseUrl || window.SUPABASE_URL || "";
    if (!base) throw new Error("Supabase project URL could not be detected.");
    return `${String(base).replace(/\/$/, "")}/functions/v1/telegram-webhook?action=${encodeURIComponent(action)}`;
  }

  async function rpc(name, args = {}) {
    const supabase = client();
    if (!supabase) throw new Error("Sign in to KeySuite before opening KeyAI Drafts.");
    const { data, error } = await supabase.rpc(name, args);
    if (error) throw new Error(error.message || String(error));
    return data;
  }

  function customers() { return window.KeySuiteApp?.getCustomers?.() ?? []; }
  async function refreshCustomers() {
    try { await window.KeySuiteCustomerStore?.load?.(); }
    catch (error) { console.warn("KeyAI customer refresh failed", error); }
    return customers();
  }

  async function loadDrafts() {
    const data = await rpc("keyai_list_review_drafts_v05");
    drafts = Array.isArray(data) ? data : [];
    updateButton();
    return drafts;
  }

  function actionable(draft) {
    return !["rejected", "imported"].includes(draft.review_status) &&
      !["cancelled", "imported"].includes(draft.draft_status);
  }

  function updateButton() {
    const button = document.getElementById(BUTTON_ID);
    if (!button) return;
    const count = drafts.filter(actionable).length;
    button.textContent = count ? `KeyAI Drafts (${count})` : "KeyAI Drafts";
    button.title = count ? `${count} KeyAI draft${count === 1 ? "" : "s"} requiring attention` : "Open KeyAI Draft Review";
  }

  function installStyles() {
    if (document.getElementById("keyaiDraftInboxStyles")) return;
    const style = document.createElement("style");
    style.id = "keyaiDraftInboxStyles";
    style.textContent = `
      #${BUTTON_ID}{position:fixed;right:18px;bottom:18px;z-index:9998;border:0;border-radius:999px;padding:12px 18px;background:#d5bd50;color:#1f2937;font-weight:800;box-shadow:0 8px 24px rgba(0,0,0,.22);cursor:pointer}
      #${DIALOG_ID}{width:min(1180px,calc(100vw - 24px));max-height:92vh;border:0;border-radius:16px;padding:0;box-shadow:0 24px 80px rgba(0,0,0,.34)}
      #${DIALOG_ID}::backdrop{background:rgba(15,23,42,.58)}
      .kai-head{display:flex;align-items:center;justify-content:space-between;padding:18px 20px;background:#111827;color:#fff}.kai-head h2{margin:0;font-size:20px}.kai-head button{border:0;background:transparent;color:#fff;font-size:25px;cursor:pointer}
      .kai-body{padding:18px;background:#f8fafc;overflow:auto;max-height:calc(92vh - 68px)}
      .kai-note{padding:12px 14px;border-radius:10px;background:#fff7d6;border:1px solid #ead98d;margin-bottom:14px;line-height:1.45}
      .kai-card{background:#fff;border:1px solid #dbe2ea;border-radius:13px;padding:16px;margin:0 0 16px;box-shadow:0 3px 10px rgba(15,23,42,.05)}.kai-card.closed{opacity:.78}
      .kai-card-top{display:flex;gap:12px;align-items:flex-start;justify-content:space-between}.kai-card h3{margin:0 0 4px;font-size:17px}.kai-muted{color:#64748b;font-size:13px}
      .kai-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin:12px 0}.kai-span2{grid-column:span 2}.kai-span4{grid-column:1/-1}
      .kai-field{display:flex;flex-direction:column;gap:5px}.kai-field label{color:#64748b;font-size:11px;text-transform:uppercase;font-weight:800}.kai-field input,.kai-field select,.kai-field textarea{width:100%;box-sizing:border-box;border:1px solid #cbd5e1;border-radius:8px;padding:9px 10px;background:#fff;color:#0f172a}.kai-field textarea{min-height:86px;resize:vertical}.kai-field input:disabled,.kai-field select:disabled,.kai-field textarea:disabled{background:#f1f5f9;color:#64748b}
      .kai-actions{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin-top:12px}.kai-actions select,.kai-actions input,.kai-actions textarea{min-width:220px;flex:1;border:1px solid #cbd5e1;border-radius:8px;padding:9px 10px}.kai-actions button{border:0;border-radius:8px;padding:9px 13px;font-weight:800;cursor:pointer}.kai-actions button:disabled{opacity:.45;cursor:not-allowed}
      .kai-primary{background:#16803c;color:#fff}.kai-secondary{background:#e2e8f0;color:#0f172a}.kai-blue{background:#dbeafe;color:#1e40af}.kai-danger{background:#fee2e2;color:#991b1b}.kai-approve{background:#14532d;color:#fff}.kai-request{background:#fef3c7;color:#92400e}
      .kai-badge{display:inline-flex;padding:4px 8px;border-radius:999px;font-size:11px;font-weight:800;margin-left:4px}.kai-good{background:#dcfce7;color:#166534}.kai-warn{background:#fef3c7;color:#92400e}.kai-info{background:#dbeafe;color:#1e40af}.kai-bad{background:#fee2e2;color:#991b1b}.kai-grey{background:#e2e8f0;color:#475569}
      .kai-empty{padding:30px;text-align:center;color:#64748b;background:#fff;border:1px dashed #cbd5e1;border-radius:12px}.kai-error{padding:12px;background:#fee2e2;color:#991b1b;border-radius:9px;margin-bottom:12px;white-space:pre-wrap}
      .kai-customer{padding:10px;border:1px solid #e2e8f0;border-radius:10px;background:#f8fafc;margin:12px 0}.kai-review-actions{border-top:1px solid #e2e8f0;padding-top:12px;margin-top:14px}
      .kai-audit{margin-top:12px;padding:10px;border-radius:9px;background:#f8fafc;border:1px solid #e2e8f0}.kai-audit-row{padding:7px 0;border-bottom:1px solid #e2e8f0;font-size:12px}.kai-audit-row:last-child{border-bottom:0}
      @media(max-width:900px){.kai-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.kai-span4{grid-column:1/-1}}@media(max-width:620px){.kai-grid{grid-template-columns:1fr}.kai-span2,.kai-span4{grid-column:1}.kai-card-top{display:block}.kai-actions select,.kai-actions input,.kai-actions textarea{min-width:100%}}
    `;
    document.head.appendChild(style);
  }

  function installDialog() {
    if (document.getElementById(DIALOG_ID)) return;
    const dialog = document.createElement("dialog");
    dialog.id = DIALOG_ID;
    dialog.innerHTML = `<div class="kai-head"><h2>KeyAI Draft Review <small style="font-size:11px;opacity:.7">V${VERSION}</small></h2><button type="button" data-kai-close aria-label="Close">×</button></div><div class="kai-body" data-kai-body></div>`;
    dialog.querySelector("[data-kai-close]").addEventListener("click", () => dialog.close());
    document.body.appendChild(dialog);
  }

  function installButton() {
    if (document.getElementById(BUTTON_ID)) return;
    const button = document.createElement("button"); button.id = BUTTON_ID; button.type = "button"; button.textContent = "KeyAI Drafts";
    button.addEventListener("click", openInbox); document.body.appendChild(button);
  }

  function badge(value) {
    const key = String(value || "unknown");
    const cls = ["approved", "ready_for_approval", "exact", "manual", "imported"].includes(key) ? "kai-good" :
      ["rejected", "error", "cancelled"].includes(key) ? "kai-bad" :
      key === "more_information_required" ? "kai-warn" : "kai-info";
    return `<span class="kai-badge ${cls}">${esc(key.replaceAll("_", " "))}</span>`;
  }

  function customerOptions(selectedId) {
    return customers().map((customer) => {
      const name = customer.company || customer.companyName || customer.name || customer.id;
      const pricing = customer.pricingCategoryId ? "" : " — no pricing category";
      return `<option value="${esc(customer.id)}" ${String(customer.id) === String(selectedId || "") ? "selected" : ""}>${esc(name + pricing)}</option>`;
    }).join("");
  }

  const options = (values, selected) => values.map(([value, label]) => `<option value="${esc(value)}" ${String(value) === String(selected ?? "") ? "selected" : ""}>${esc(label)}</option>`).join("");

  function reviewValue(draft, key, fallback = "") {
    const review = draft.review_payload || {};
    return review[key] ?? fallback;
  }

  function render(errorMessage = "") {
    const body = document.querySelector(`#${DIALOG_ID} [data-kai-body]`);
    if (!body) return;
    const note = `Review and approve every KeyAI draft before import. Imports remain <b>unpriced</b>; KeySuite allocates the official quotation number and applies its existing pricing rules. Nothing is sent to the customer automatically.`;
    if (!drafts.length) {
      body.innerHTML = `${errorMessage ? `<div class="kai-error">${esc(errorMessage)}</div>` : ""}<div class="kai-note">${note}</div><div class="kai-empty">No KeyAI drafts are waiting for this KeySuite user.</div>`;
      return;
    }

    body.innerHTML = `${errorMessage ? `<div class="kai-error">${esc(errorMessage)}</div>` : ""}<div class="kai-note">${note}</div>` + drafts.map((draft) => {
      const r = draft.review_payload || {};
      const closed = ["rejected", "imported"].includes(draft.review_status) || ["cancelled", "imported"].includes(draft.draft_status);
      const candidate = r.customer_company || draft.customer_candidate?.company_name || draft.draft_payload?.customer?.company_name || "";
      const approved = draft.review_status === "approved";
      const ready = draft.review_status === "ready_for_approval";
      const canEdit = !closed;
      return `
        <section class="kai-card ${closed ? "closed" : ""}" data-draft-card="${esc(draft.draft_id)}">
          <div class="kai-card-top"><div><h3>${esc(draft.draft_no)}</h3><div class="kai-muted">Enquiry ${esc(draft.enquiry_no)} · Updated ${esc(new Date(draft.updated_at || draft.created_at).toLocaleString())}</div></div><div>${badge(draft.review_status)} ${badge(draft.product_match_status)}</div></div>
          ${draft.information_question && draft.review_status === "more_information_required" ? `<div class="kai-note"><b>Waiting for customer:</b> ${esc(draft.information_question)}</div>` : ""}
          ${draft.rejection_reason ? `<div class="kai-error"><b>Rejected:</b> ${esc(draft.rejection_reason)}</div>` : ""}

          <div class="kai-customer">
            <b>Customer confirmation</b>
            <div class="kai-actions"><select data-kai-customer ${canEdit ? "" : "disabled"}><option value="">Select existing customer…</option>${customerOptions(draft.customer_id)}</select><button class="kai-secondary" data-kai-assign ${canEdit ? "" : "disabled"}>Use customer</button></div>
            <div class="kai-actions"><input data-kai-new-customer value="${esc(candidate)}" placeholder="New customer company name" ${canEdit ? "" : "disabled"}><button class="kai-secondary" data-kai-create ${canEdit ? "" : "disabled"}>Create customer</button></div>
          </div>

          <div class="kai-grid">
            <div class="kai-field"><label>Product family</label><select data-field="product_family" ${canEdit ? "" : "disabled"}>${options([["CHC","CHC"],["ES","ES"],["GWS","GWS"],["KeyPLC","KeyPLC"],["Manifold","Manifold"],["Motor","Motor"],["Other","Other"]], r.product_family)}</select></div>
            <div class="kai-field"><label>Model / item</label><input data-field="model" value="${esc(r.model || "")}" ${canEdit ? "" : "disabled"}></div>
            <div class="kai-field"><label>Quantity</label><input data-field="quantity" type="number" min="0.01" step="0.01" value="${esc(r.quantity ?? 1)}" ${canEdit ? "" : "disabled"}></div>
            <div class="kai-field"><label>Matched product ID</label><input data-field="product_id" value="${esc(r.product_id || "")}" placeholder="Optional" ${canEdit ? "" : "disabled"}></div>
            <div class="kai-field kai-span2"><label>KeySuite product search</label><div class="kai-actions" style="margin:0"><input data-kai-product-query value="${esc(r.model || "")}" placeholder="Search model"><button class="kai-blue" data-kai-product-search ${canEdit ? "" : "disabled"}>Search</button><select data-kai-product-results ${canEdit ? "" : "disabled"}><option value="">Select search result…</option></select></div></div>
            <div class="kai-field"><label>Flow</label><input data-field="flow_value" type="number" step="any" value="${esc(r.flow_value ?? "")}" ${canEdit ? "" : "disabled"}></div>
            <div class="kai-field"><label>Flow unit</label><select data-field="flow_unit" ${canEdit ? "" : "disabled"}>${options([["L/s","L/s"],["m3/h","m³/h"],["m3/s","m³/s"],["L/min","L/min"],["gpm","gpm"],["unknown","Unknown"]], r.flow_unit)}</select></div>
            <div class="kai-field"><label>Head</label><input data-field="head_value" type="number" step="any" value="${esc(r.head_value ?? "")}" ${canEdit ? "" : "disabled"}></div>
            <div class="kai-field"><label>Head unit</label><select data-field="head_unit" ${canEdit ? "" : "disabled"}>${options([["m","m"],["bar","bar"],["kPa","kPa"],["psi","psi"],["unknown","Unknown"]], r.head_unit)}</select></div>
            <div class="kai-field"><label>Supply scope</label><select data-field="supply_scope" ${canEdit ? "" : "disabled"}>${options([["bare_shaft_pump","Bare shaft pump"],["pump_with_motor","Pump with motor"],["pumpset","Pumpset"],["complete_system","Complete system"],["spares","Spares"],["unknown","Unknown"]], r.supply_scope)}</select></div>
            <div class="kai-field"><label>Motor efficiency</label><select data-field="efficiency_class" ${canEdit ? "" : "disabled"}>${options([["IE1","IE1"],["IE2","IE2"],["IE3","IE3"],["IE4","IE4"],["unknown","Unknown"]], r.efficiency_class)}</select></div>
            <div class="kai-field"><label>Motor poles</label><input data-field="pole" type="number" step="1" value="${esc(r.pole ?? "")}" ${canEdit ? "" : "disabled"}></div>
            <div class="kai-field"><label>Voltage</label><input data-field="voltage" type="number" step="1" value="${esc(r.voltage ?? "")}" ${canEdit ? "" : "disabled"}></div>
            <div class="kai-field"><label>Phase</label><select data-field="phase" ${canEdit ? "" : "disabled"}>${options([["1","1 phase"],["3","3 phase"],["unknown","Unknown"]], r.phase)}</select></div>
            <div class="kai-field"><label>Frequency Hz</label><input data-field="frequency_hz" type="number" step="1" value="${esc(r.frequency_hz ?? "")}" ${canEdit ? "" : "disabled"}></div>
            <div class="kai-field kai-span4"><label>Description</label><textarea data-field="description" ${canEdit ? "" : "disabled"}>${esc(r.description || "")}</textarea></div>
            <div class="kai-field kai-span4"><label>Internal remarks (not sent to customer)</label><textarea data-field="internal_remarks" ${canEdit ? "" : "disabled"}>${esc(r.internal_remarks || draft.internal_remarks || "")}</textarea></div>
          </div>

          ${canEdit ? `<div class="kai-actions"><button class="kai-primary" data-kai-save>Save changes</button><button class="kai-approve" data-kai-approve ${ready ? "" : "disabled"}>Approve draft</button></div>
          <div class="kai-review-actions"><div class="kai-actions"><textarea data-kai-question placeholder="Question to send to the Telegram customer"></textarea><button class="kai-request" data-kai-request>Request information</button></div><div class="kai-actions"><input data-kai-reason placeholder="Rejection reason"><button class="kai-danger" data-kai-reject>Reject draft</button></div></div>` : ""}
          <div class="kai-actions"><button class="kai-primary" data-kai-import ${approved ? "" : "disabled"}>Import approved draft into KeySuite</button><button class="kai-secondary" data-kai-messages>Show Telegram messages</button><button class="kai-secondary" data-kai-audit>Show audit history</button></div>
          <div data-kai-message-box></div><div data-kai-audit-box></div>
        </section>`;
    }).join("");

    body.querySelectorAll("[data-draft-card]").forEach((card) => {
      const id = card.dataset.draftCard;
      card.querySelector("[data-kai-assign]")?.addEventListener("click", () => assignCustomer(id, card));
      card.querySelector("[data-kai-create]")?.addEventListener("click", () => createCustomer(id, card));
      card.querySelector("[data-kai-save]")?.addEventListener("click", () => saveReview(id, card));
      card.querySelector("[data-kai-approve]")?.addEventListener("click", () => approveDraft(id));
      card.querySelector("[data-kai-request]")?.addEventListener("click", () => requestInformation(id, card));
      card.querySelector("[data-kai-reject]")?.addEventListener("click", () => rejectDraft(id, card));
      card.querySelector("[data-kai-import]")?.addEventListener("click", () => importDraft(id));
      card.querySelector("[data-kai-messages]")?.addEventListener("click", () => showMessages(id, card));
      card.querySelector("[data-kai-audit]")?.addEventListener("click", () => showAudit(id, card));
      card.querySelector("[data-kai-product-search]")?.addEventListener("click", () => searchProducts(card));
      card.querySelector("[data-kai-product-results]")?.addEventListener("change", (event) => {
        const option = event.target.selectedOptions?.[0]; if (!option?.value) return;
        card.querySelector('[data-field="product_id"]').value = option.value;
        card.querySelector('[data-field="model"]').value = option.dataset.model || option.textContent;
      });
    });
  }

  async function openInbox() {
    if (busy) return; busy = true;
    const dialog = document.getElementById(DIALOG_ID); dialog.showModal(); render();
    try { if (!customers().length) await refreshCustomers(); await loadDrafts(); render(); }
    catch (error) { console.error(error); render(error.message || String(error)); }
    finally { busy = false; }
  }

  async function assignCustomer(draftId, card) {
    const customerId = card.querySelector("[data-kai-customer]").value;
    if (!customerId) return alert("Select a customer first.");
    try { await rpc("keyai_assign_draft_customer_v05", { p_draft_id: draftId, p_customer_id: customerId }); await loadDrafts(); render(); }
    catch (error) { alert(error.message || error); }
  }

  async function createCustomer(draftId, card) {
    const companyName = String(card.querySelector("[data-kai-new-customer]").value || "").trim();
    if (!companyName) return alert("Enter the customer company name.");
    if (!confirm(`Create “${companyName}” as a minimal KeySuite customer?\n\nComplete its details and pricing category before issuing the quotation.`)) return;
    try { await rpc("keyai_create_customer_for_draft_v05", { p_draft_id: draftId, p_company_name: companyName }); await refreshCustomers(); await loadDrafts(); render(); }
    catch (error) { alert(error.message || error); }
  }

  function collectPatch(card) {
    const patch = {};
    card.querySelectorAll("[data-field]").forEach((field) => {
      const key = field.dataset.field; const value = typeof field.value === "string" ? field.value.trim() : field.value;
      patch[key] = ["quantity","flow_value","head_value","pole","voltage","frequency_hz"].includes(key)
        ? (value === "" ? null : Number(value)) : value;
    });
    return patch;
  }

  async function saveReview(draftId, card) {
    try { await rpc("keyai_update_draft_review_v05", { p_draft_id: draftId, p_patch: collectPatch(card) }); await loadDrafts(); render(); alert("Draft review saved. Re-approve after every edit."); }
    catch (error) { alert(error.message || error); }
  }

  async function searchProducts(card) {
    const family = card.querySelector('[data-field="product_family"]').value;
    const query = card.querySelector("[data-kai-product-query]").value.trim();
    const select = card.querySelector("[data-kai-product-results]");
    select.innerHTML = '<option value="">Searching…</option>';
    try {
      const rows = await rpc("keyai_search_products_v05", { p_family: family, p_query: query, p_limit: 50 });
      select.innerHTML = '<option value="">Select search result…</option>' + (rows || []).map((row) => `<option value="${esc(row.product_id)}" data-model="${esc(row.product_model)}">${esc(row.product_model)}</option>`).join("");
      if (!(rows || []).length) alert("No matching KeySuite models were found. You may enter the model manually.");
    } catch (error) { select.innerHTML = '<option value="">Search failed</option>'; alert(error.message || error); }
  }

  async function approveDraft(draftId) {
    if (!confirm("Approve this reviewed draft for unpriced KeySuite import?")) return;
    try { await rpc("keyai_approve_draft_v05", { p_draft_id: draftId }); await loadDrafts(); render(); }
    catch (error) { alert(error.message || error); }
  }

  async function rejectDraft(draftId, card) {
    const reason = card.querySelector("[data-kai-reason]").value.trim();
    if (!reason) return alert("Enter a rejection reason.");
    if (!confirm("Reject this draft? It will remain in the audit history and cannot be imported.")) return;
    try { await rpc("keyai_reject_draft_v05", { p_draft_id: draftId, p_reason: reason }); await loadDrafts(); render(); }
    catch (error) { alert(error.message || error); }
  }

  async function requestInformation(draftId, card) {
    const question = card.querySelector("[data-kai-question]").value.trim();
    if (!question) return alert("Enter the question to send to the customer.");
    if (!confirm(`Send this question through Telegram?\n\n${question}`)) return;
    try {
      const currentSession = await session(); if (!currentSession?.access_token) throw new Error("Your KeySuite session has expired. Sign in again.");
      const response = await fetch(functionUrl("keysuite-review"), { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${currentSession.access_token}` }, body: JSON.stringify({ action: "request_information", draft_id: draftId, question }) });
      const result = await response.json().catch(() => ({}));
      if (!response.ok || !result.ok) throw new Error(result.error || `Request failed (${response.status}).`);
      await loadDrafts(); render(); alert("The information request was sent to the Telegram customer.");
    } catch (error) { alert(error.message || error); }
  }

  async function showMessages(draftId, card) {
    const box = card.querySelector("[data-kai-message-box]");
    if (box.innerHTML) { box.innerHTML = ""; return; }
    box.innerHTML = '<div class="kai-audit">Loading Telegram messages…</div>';
    try {
      const rows = await rpc("keyai_list_draft_messages_v05", { p_draft_id: draftId });
      box.innerHTML = `<div class="kai-audit"><b>Telegram enquiry transcript</b>${(rows || []).map((row) => `<div class="kai-audit-row"><b>${esc(row.direction === "inbound" ? "Customer" : row.direction === "outbound" ? "KeyAI" : "Internal")}</b> · ${esc(new Date(row.created_at).toLocaleString())}<br>${esc(row.message_text || `[${row.message_type || "message"}]`)}</div>`).join("") || '<div class="kai-audit-row">No Telegram messages found.</div>'}</div>`;
    } catch (error) { box.innerHTML = `<div class="kai-error">${esc(error.message || error)}</div>`; }
  }

  async function showAudit(draftId, card) {
    const box = card.querySelector("[data-kai-audit-box]");
    if (box.innerHTML) { box.innerHTML = ""; return; }
    box.innerHTML = '<div class="kai-audit">Loading…</div>';
    try {
      const rows = await rpc("keyai_list_draft_audit_v05", { p_draft_id: draftId });
      box.innerHTML = `<div class="kai-audit"><b>Audit history</b>${(rows || []).map((row) => `<div class="kai-audit-row"><b>${esc(String(row.action || "").replaceAll("_", " "))}</b> · ${esc(new Date(row.created_at).toLocaleString())}${row.actor_email ? ` · ${esc(row.actor_email)}` : ""}<br>${esc(row.note || "")}</div>`).join("") || '<div class="kai-audit-row">No audit records yet.</div>'}</div>`;
    } catch (error) { box.innerHTML = `<div class="kai-error">${esc(error.message || error)}</div>`; }
  }

  function existingQuoteForDraft(draftId) { return readJson(QUOTES_KEY, []).find((quote) => String(quote.keyaiDraftId || "") === String(draftId)); }

  function buildQuote(draft, reference, localQuoteId) {
    const payload = draft.draft_payload || {}; const review = draft.review_payload || {};
    const customer = window.KeySuiteApp?.getCustomerById?.(draft.customer_id) || customers().find((row) => String(row.id) === String(draft.customer_id));
    if (!customer) throw new Error("The confirmed customer is not loaded in KeySuite. Refresh Customers and try again.");
    const profile = window.KEYSUITE_PROFILE || {};
    const sourceItems = Array.isArray(payload.items) ? payload.items : [];
    const items = sourceItems.map((item, index) => ({
      id: item.id || uuid(), model: String(index === 0 ? (review.model || item.model || "KEYAI - SELECT MODEL") : item.model || ""),
      description: String(index === 0 ? (review.description || item.description || "") : item.description || ""),
      qty: Math.max(0.01, Number(index === 0 ? (review.quantity || item.qty || 1) : item.qty || 1)), unit: String(item.unit || "unit").toLowerCase() === "set" ? "set" : "unit",
      unitPrice: 0, pricingSource: { ...(item.pricingSource || {}), source: "keyai-v0.5", product_id: review.product_id || item.product_id || null, note: "Apply existing KeySuite pricing during review." },
      pumpData: item.pumpData || null, remark: "Imported from approved KeyAI draft; review pricing before sealing.",
    }));
    if (!items.length) throw new Error("The KeyAI draft contains no quotation items.");
    return {
      id: localQuoteId, no: reference, date: today(), revisionDate: "", showRevision: false, documentType: payload.document_type || "Quotation",
      customerId: customer.id, contactIndex: "", printedCompany: customer.company || customer.companyName || "", printedContact: "", pricingCustomerId: customer.id,
      pricingCustomerSnapshot: JSON.parse(JSON.stringify(customer)), status: "saved", revisionOf: "", revisionRootId: "", revisionNumber: 0,
      audit: [{ action: "keyai_import", at: new Date().toISOString(), by: profile.email || profile.display_name || "KeySuite user", draftNo: draft.draft_no, enquiryNo: draft.enquiry_no, approvedBy: draft.approved_by_email || "" }],
      quotationTemplateId: "", quotationTemplateSnapshot: null, assemblySessionId: `keyai:${draft.draft_id}`, preparedBy: profile.display_name || "", preparedByDesignation: profile.designation || "", signatoryName: profile.signatory_name || profile.display_name || "", signatureImage: profile.signature_image || "",
      items, project: payload.project || "", project2: "", customerReference: payload.customer_reference || draft.enquiry_no || "", delivery: "", delivery2: "", validity: "", priceBasis: "", payment: "",
      remarks: payload.remarks || "Imported from approved KeyAI draft. Review before sealing.", internalRemarks: review.internal_remarks || draft.internal_remarks || "", total: 0,
      keyaiDraftId: draft.draft_id, keyaiDraftNo: draft.draft_no, keyaiEnquiryNo: draft.enquiry_no, keyaiImportedAt: new Date().toISOString(), keyaiApprovedBy: draft.approved_by_email || "", keyaiApprovedAt: draft.approved_at || "",
    };
  }

  async function registerImport(draft, quote) {
    const currentSession = await session(); if (!currentSession?.access_token) throw new Error("Your KeySuite session has expired. Sign in again.");
    const response = await fetch(functionUrl("keysuite-import"), { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${currentSession.access_token}` }, body: JSON.stringify({ draft_id: draft.draft_id, quotation_reference: quote.no, local_quote_id: quote.id }) });
    const result = await response.json().catch(() => ({})); if (!response.ok || !result.ok) throw new Error(result.error || `Import registration failed (${response.status}).`); return result;
  }

  async function importDraft(draftId) {
    const draft = drafts.find((row) => String(row.draft_id) === String(draftId));
    if (!draft) return alert("Draft not found. Refresh the inbox.");
    if (draft.review_status !== "approved") return alert("Approve the draft before importing.");
    if (!draft.customer_id) return alert("Confirm the customer before importing.");
    const existing = existingQuoteForDraft(draftId);
    if (existing) { try { await registerImport(draft, existing); await loadDrafts(); render(); alert(`KeyAI draft synchronized.\nQuotation: ${existing.no}`); } catch (error) { alert(`The local quotation already exists as ${existing.no}, but synchronization is pending.\n\n${error.message || error}`); } return; }
    const referenceService = window.KeySuiteQuotationReferences;
    if (!referenceService?.allocateNext) return alert("KeySuite quotation-reference service is not ready. Refresh KeySuite and try again.");
    if (!confirm("Import this approved draft as an unpriced KeySuite quotation?")) return;
    let reference; try { reference = await referenceService.allocateNext(); if (!reference) throw new Error("No quotation reference was returned."); } catch (error) { return alert(`Quotation reference could not be allocated.\n\n${error.message || error}`); }
    const localQuoteId = uuid(); let quote;
    try { quote = buildQuote(draft, reference, localQuoteId); const allQuotes = readJson(QUOTES_KEY, []); if (allQuotes.some((row) => String(row.no || "").toUpperCase() === String(reference).toUpperCase())) throw new Error(`Quotation reference ${reference} already exists locally.`); allQuotes.unshift(quote); writeJson(QUOTES_KEY, allQuotes); await referenceService.registerUsed?.(reference); }
    catch (error) { return alert(`The draft could not be written to KeySuite.\n\n${error.message || error}`); }
    try { await registerImport(draft, quote); const pending = readJson(PENDING_KEY, {}); delete pending[draftId]; writeJson(PENDING_KEY, pending); await loadDrafts(); render(); alert(`KeyAI draft imported successfully.\n\nQuotation: ${reference}\nPrice: pending KeySuite review\nStatus: Awaiting internal approval`); window.KeySuiteApp?.showPage?.("quoteHistory"); }
    catch (error) { const pending = readJson(PENDING_KEY, {}); pending[draftId] = { quoteId: quote.id, reference: quote.no, error: error.message || String(error) }; writeJson(PENDING_KEY, pending); alert(`Quotation ${reference} was created locally, but KeyAI synchronization is pending.\n\nOpen KeyAI Drafts and click Import again to retry.\n\n${error.message || error}`); }
  }

  async function init() {
    installStyles(); installDialog(); installButton();
    try { if (window.KeySuiteAuth?.getSession?.()) await loadDrafts(); } catch (error) { console.warn("KeyAI Draft Review is waiting for sign-in", error); }
    window.addEventListener("keysuite-auth-changed", () => loadDrafts().catch(() => {}));
    window.addEventListener("keysuite-customers-changed", () => render());
  }

  window.KeyAIInbox = { version: VERSION, open: openInbox, refresh: loadDrafts };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => setTimeout(init, 0), { once: true }); else setTimeout(init, 0);
})();
