(() => {
  "use strict";

  const VERSION = "0.4.0";
  const BUTTON_ID = "keyaiDraftInboxButton";
  const DIALOG_ID = "keyaiDraftInboxDialog";
  const QUOTES_KEY = "ks_quotes";
  const PENDING_KEY = "ks_keyai_pending_imports_v040";
  let drafts = [];
  let busy = false;

  const esc = (value) => String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");

  const readJson = (key, fallback) => {
    try {
      const raw = localStorage.getItem(key);
      return raw ? JSON.parse(raw) : fallback;
    } catch {
      return fallback;
    }
  };

  const writeJson = (key, value) => {
    localStorage.setItem(key, JSON.stringify(value));
  };

  const uuid = () => globalThis.crypto?.randomUUID?.() ??
    `keyai-${Date.now()}-${Math.random().toString(16).slice(2)}`;

  const today = () => {
    const date = new Date();
    const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
    return local.toISOString().slice(0, 10);
  };

  const client = () => window.KeySuiteAuth?.getClient?.() ?? null;

  async function session() {
    const direct = window.KeySuiteAuth?.getSession?.();
    const resolved = direct && typeof direct.then === "function" ? await direct : direct;
    if (resolved?.access_token) return resolved;
    if (resolved?.data?.session?.access_token) return resolved.data.session;
    const result = await client()?.auth?.getSession?.();
    return result?.data?.session ?? null;
  }

  function functionUrl() {
    if (window.KEYAI_FUNCTION_URL) {
      return `${String(window.KEYAI_FUNCTION_URL).replace(/\/$/, "")}?action=keysuite-import`;
    }
    const supabase = client();
    const base = supabase?.supabaseUrl || window.KEYSUITE_SUPABASE_URL ||
      window.KEYSUITE_CONFIG?.supabaseUrl || window.SUPABASE_URL || "";
    if (!base) throw new Error("Supabase project URL could not be detected.");
    return `${String(base).replace(/\/$/, "")}/functions/v1/telegram-webhook?action=keysuite-import`;
  }

  async function rpc(name, args = {}) {
    const supabase = client();
    if (!supabase) throw new Error("Sign in to KeySuite before opening KeyAI Drafts.");
    const { data, error } = await supabase.rpc(name, args);
    if (error) throw new Error(error.message || String(error));
    return data;
  }

  function customers() {
    return window.KeySuiteApp?.getCustomers?.() ?? [];
  }

  async function refreshCustomers() {
    try {
      await window.KeySuiteCustomerStore?.load?.();
    } catch (error) {
      console.warn("KeyAI customer refresh failed", error);
    }
    return customers();
  }

  async function loadDrafts() {
    const data = await rpc("keyai_list_pending_drafts_v04");
    drafts = Array.isArray(data) ? data : [];
    updateButton();
    return drafts;
  }

  function updateButton() {
    const button = document.getElementById(BUTTON_ID);
    if (!button) return;
    button.textContent = drafts.length ? `KeyAI Drafts (${drafts.length})` : "KeyAI Drafts";
    button.title = drafts.length
      ? `${drafts.length} KeyAI draft${drafts.length === 1 ? "" : "s"} waiting`
      : "Open KeyAI Draft Inbox";
  }

  function installStyles() {
    if (document.getElementById("keyaiDraftInboxStyles")) return;
    const style = document.createElement("style");
    style.id = "keyaiDraftInboxStyles";
    style.textContent = `
      #${BUTTON_ID}{position:fixed;right:18px;bottom:18px;z-index:9998;border:0;border-radius:999px;padding:12px 18px;background:#d5bd50;color:#1f2937;font-weight:800;box-shadow:0 8px 24px rgba(0,0,0,.22);cursor:pointer}
      #${BUTTON_ID}:hover{filter:brightness(.97)}
      #${DIALOG_ID}{width:min(920px,calc(100vw - 28px));max-height:86vh;border:0;border-radius:16px;padding:0;box-shadow:0 24px 80px rgba(0,0,0,.34)}
      #${DIALOG_ID}::backdrop{background:rgba(15,23,42,.58)}
      .kai-head{display:flex;align-items:center;justify-content:space-between;padding:18px 20px;background:#111827;color:#fff}
      .kai-head h2{margin:0;font-size:20px}.kai-head button{border:0;background:transparent;color:#fff;font-size:25px;cursor:pointer}
      .kai-body{padding:18px;background:#f8fafc;overflow:auto;max-height:calc(86vh - 68px)}
      .kai-note{padding:12px 14px;border-radius:10px;background:#fff7d6;border:1px solid #ead98d;margin-bottom:14px;line-height:1.45}
      .kai-card{background:#fff;border:1px solid #dbe2ea;border-radius:13px;padding:16px;margin:0 0 14px;box-shadow:0 3px 10px rgba(15,23,42,.05)}
      .kai-card-top{display:flex;gap:12px;align-items:flex-start;justify-content:space-between}.kai-card h3{margin:0 0 4px;font-size:17px}.kai-muted{color:#64748b;font-size:13px}
      .kai-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin:12px 0}.kai-field{padding:9px 10px;border-radius:9px;background:#f8fafc;border:1px solid #e2e8f0}.kai-label{display:block;color:#64748b;font-size:11px;text-transform:uppercase;font-weight:800;margin-bottom:3px}
      .kai-actions{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin-top:12px}.kai-actions select,.kai-actions input{min-width:220px;flex:1;border:1px solid #cbd5e1;border-radius:8px;padding:9px 10px}.kai-actions button{border:0;border-radius:8px;padding:9px 13px;font-weight:800;cursor:pointer}.kai-primary{background:#16803c;color:#fff}.kai-secondary{background:#e2e8f0;color:#0f172a}.kai-danger{background:#fee2e2;color:#991b1b}.kai-actions button:disabled{opacity:.5;cursor:not-allowed}
      .kai-badge{display:inline-flex;padding:4px 8px;border-radius:999px;font-size:11px;font-weight:800}.kai-good{background:#dcfce7;color:#166534}.kai-warn{background:#fef3c7;color:#92400e}.kai-info{background:#dbeafe;color:#1e40af}
      .kai-empty{padding:30px;text-align:center;color:#64748b;background:#fff;border:1px dashed #cbd5e1;border-radius:12px}
      .kai-error{padding:12px;background:#fee2e2;color:#991b1b;border-radius:9px;margin-bottom:12px;white-space:pre-wrap}
      @media(max-width:680px){.kai-grid{grid-template-columns:1fr}.kai-card-top{display:block}.kai-actions select,.kai-actions input{min-width:100%}}
    `;
    document.head.appendChild(style);
  }

  function installDialog() {
    if (document.getElementById(DIALOG_ID)) return;
    const dialog = document.createElement("dialog");
    dialog.id = DIALOG_ID;
    dialog.innerHTML = `
      <div class="kai-head"><h2>KeyAI Draft Inbox <small style="font-size:11px;opacity:.7">V${VERSION}</small></h2><button type="button" data-kai-close aria-label="Close">×</button></div>
      <div class="kai-body" data-kai-body></div>`;
    dialog.querySelector("[data-kai-close]").addEventListener("click", () => dialog.close());
    document.body.appendChild(dialog);
  }

  function installButton() {
    if (document.getElementById(BUTTON_ID)) return;
    const button = document.createElement("button");
    button.id = BUTTON_ID;
    button.type = "button";
    button.textContent = "KeyAI Drafts";
    button.addEventListener("click", openInbox);
    document.body.appendChild(button);
  }

  function statusBadge(value, goodValues = []) {
    const good = goodValues.includes(value);
    const cls = good ? "kai-good" : "kai-warn";
    return `<span class="kai-badge ${cls}">${esc(String(value || "unknown").replaceAll("_", " "))}</span>`;
  }

  function customerOptions(selectedId) {
    return customers().map((customer) => {
      const name = customer.company || customer.companyName || customer.name || customer.id;
      const pricing = customer.pricingCategoryId ? "" : " — no pricing category";
      return `<option value="${esc(customer.id)}" ${String(customer.id) === String(selectedId || "") ? "selected" : ""}>${esc(name + pricing)}</option>`;
    }).join("");
  }

  function render(errorMessage = "") {
    const body = document.querySelector(`#${DIALOG_ID} [data-kai-body]`);
    if (!body) return;
    const note = `KeyAI imports an <b>unpriced draft</b>. The official quotation number is allocated by KeySuite during import. Review the model, customer, description and apply KeySuite pricing before sealing. Nothing is sent to the customer automatically.`;
    if (!drafts.length) {
      body.innerHTML = `${errorMessage ? `<div class="kai-error">${esc(errorMessage)}</div>` : ""}<div class="kai-note">${note}</div><div class="kai-empty">No KeyAI drafts are waiting for this KeySuite user.</div>`;
      return;
    }

    body.innerHTML = `${errorMessage ? `<div class="kai-error">${esc(errorMessage)}</div>` : ""}<div class="kai-note">${note}</div>` + drafts.map((draft) => {
      const payload = draft.draft_payload || {};
      const item = Array.isArray(payload.items) ? payload.items[0] || {} : {};
      const candidate = draft.customer_candidate?.company_name || payload.customer?.company_name || "Not supplied";
      const customerResolved = Boolean(draft.customer_id);
      return `
        <section class="kai-card" data-draft-card="${esc(draft.draft_id)}">
          <div class="kai-card-top">
            <div><h3>${esc(draft.draft_no)}</h3><div class="kai-muted">Enquiry ${esc(draft.enquiry_no)} · ${esc(new Date(draft.created_at).toLocaleString())}</div></div>
            <div>${statusBadge(draft.draft_status,["ready_to_import"])} ${statusBadge(draft.product_match_status,["exact"])}</div>
          </div>
          <div class="kai-grid">
            <div class="kai-field"><span class="kai-label">Customer candidate</span>${esc(candidate)}</div>
            <div class="kai-field"><span class="kai-label">Model / Item</span>${esc(item.model || "Selection required")}</div>
            <div class="kai-field"><span class="kai-label">Quantity</span>${esc(item.qty || 1)}</div>
            <div class="kai-field"><span class="kai-label">Pricing</span>Pending KeySuite review</div>
          </div>
          ${customerResolved ? `<div class="kai-muted">Customer is linked. Change it below only when necessary.</div>` : `<div class="kai-muted">Confirm an existing customer or explicitly create a new minimal customer record.</div>`}
          <div class="kai-actions">
            <select data-kai-customer><option value="">Select existing customer…</option>${customerOptions(draft.customer_id)}</select>
            <button class="kai-secondary" data-kai-assign>Use customer</button>
          </div>
          <div class="kai-actions">
            <input data-kai-new-customer value="${esc(candidate === "Not supplied" ? "" : candidate)}" placeholder="New customer company name">
            <button class="kai-secondary" data-kai-create>Create customer</button>
          </div>
          <div class="kai-actions">
            <button class="kai-primary" data-kai-import ${customerResolved ? "" : "disabled"}>Import draft into KeySuite</button>
          </div>
        </section>`;
    }).join("");

    body.querySelectorAll("[data-draft-card]").forEach((card) => {
      const id = card.dataset.draftCard;
      card.querySelector("[data-kai-assign]").addEventListener("click", () => assignCustomer(id, card));
      card.querySelector("[data-kai-create]").addEventListener("click", () => createCustomer(id, card));
      card.querySelector("[data-kai-import]").addEventListener("click", () => importDraft(id));
    });
  }

  async function openInbox() {
    if (busy) return;
    busy = true;
    const dialog = document.getElementById(DIALOG_ID);
    dialog.showModal();
    render();
    try {
      if (!customers().length) await refreshCustomers();
      await loadDrafts();
      render();
    } catch (error) {
      console.error(error);
      render(error.message || String(error));
    } finally {
      busy = false;
    }
  }

  async function assignCustomer(draftId, card) {
    const select = card.querySelector("[data-kai-customer]");
    const customerId = select.value;
    if (!customerId) return alert("Select a customer first.");
    try {
      await rpc("keyai_assign_draft_customer_v04", {
        p_draft_id: draftId,
        p_customer_id: customerId,
      });
      await loadDrafts();
      render();
    } catch (error) {
      alert(error.message || error);
    }
  }

  async function createCustomer(draftId, card) {
    const input = card.querySelector("[data-kai-new-customer]");
    const companyName = String(input.value || "").trim();
    if (!companyName) return alert("Enter the customer company name.");
    if (!confirm(`Create “${companyName}” as a minimal KeySuite customer?\n\nComplete its address, contacts, terms and pricing category before issuing the quotation.`)) return;
    try {
      await rpc("keyai_create_customer_for_draft_v04", {
        p_draft_id: draftId,
        p_company_name: companyName,
      });
      await refreshCustomers();
      await loadDrafts();
      render();
    } catch (error) {
      alert(error.message || error);
    }
  }

  function existingQuoteForDraft(draftId) {
    return readJson(QUOTES_KEY, []).find((quote) => String(quote.keyaiDraftId || "") === String(draftId));
  }

  function buildQuote(draft, reference, localQuoteId) {
    const payload = draft.draft_payload || {};
    const customer = window.KeySuiteApp?.getCustomerById?.(draft.customer_id) ||
      customers().find((row) => String(row.id) === String(draft.customer_id));
    if (!customer) throw new Error("The confirmed customer is not loaded in KeySuite. Refresh Customers and try again.");

    const profile = window.KEYSUITE_PROFILE || {};
    const items = (Array.isArray(payload.items) ? payload.items : []).map((item) => ({
      id: item.id || uuid(),
      model: String(item.model || "KEYAI - SELECT MODEL IN KEYSUITE"),
      description: String(item.description || ""),
      qty: Math.max(1, Number(item.qty || 1)),
      unit: String(item.unit || "unit").toLowerCase() === "set" ? "set" : "unit",
      unitPrice: 0,
      pricingSource: item.pricingSource || {
        source: "keyai-v0.4",
        note: "Apply existing KeySuite pricing during review.",
      },
      pumpData: item.pumpData || null,
      remark: "Imported from KeyAI; review before sealing.",
    }));

    if (!items.length) throw new Error("The KeyAI draft contains no quotation items.");

    return {
      id: localQuoteId,
      no: reference,
      date: today(),
      revisionDate: "",
      showRevision: false,
      documentType: payload.document_type || "Quotation",
      customerId: customer.id,
      contactIndex: "",
      printedCompany: customer.company || customer.companyName || "",
      printedContact: "",
      pricingCustomerId: customer.id,
      pricingCustomerSnapshot: JSON.parse(JSON.stringify(customer)),
      status: "saved",
      revisionOf: "",
      revisionRootId: "",
      revisionNumber: 0,
      audit: [{
        action: "keyai_import",
        at: new Date().toISOString(),
        by: profile.email || profile.display_name || "KeySuite user",
        draftNo: draft.draft_no,
        enquiryNo: draft.enquiry_no,
      }],
      quotationTemplateId: "",
      quotationTemplateSnapshot: null,
      assemblySessionId: `keyai:${draft.draft_id}`,
      preparedBy: profile.display_name || "",
      preparedByDesignation: profile.designation || "",
      signatoryName: profile.signatory_name || profile.display_name || "",
      signatureImage: profile.signature_image || "",
      items,
      project: payload.project || "",
      project2: "",
      customerReference: payload.customer_reference || draft.enquiry_no || "",
      delivery: "",
      delivery2: "",
      validity: "",
      priceBasis: "",
      payment: "",
      remarks: payload.remarks || "Imported from KeyAI. Review before sealing.",
      total: 0,
      keyaiDraftId: draft.draft_id,
      keyaiDraftNo: draft.draft_no,
      keyaiEnquiryNo: draft.enquiry_no,
      keyaiImportedAt: new Date().toISOString(),
    };
  }

  async function registerImport(draft, quote) {
    const currentSession = await session();
    if (!currentSession?.access_token) throw new Error("Your KeySuite session has expired. Sign in again.");
    const response = await fetch(functionUrl(), {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "authorization": `Bearer ${currentSession.access_token}`,
      },
      body: JSON.stringify({
        draft_id: draft.draft_id,
        quotation_reference: quote.no,
        local_quote_id: quote.id,
      }),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok || !result.ok) throw new Error(result.error || `Import registration failed (${response.status}).`);
    return result;
  }

  async function importDraft(draftId) {
    const draft = drafts.find((row) => String(row.draft_id) === String(draftId));
    if (!draft) return alert("Draft not found. Refresh the inbox.");
    if (!draft.customer_id) return alert("Confirm the customer before importing.");

    const existing = existingQuoteForDraft(draftId);
    if (existing) {
      try {
        await registerImport(draft, existing);
        await loadDrafts();
        render();
        alert(`KeyAI draft synchronized.\nQuotation: ${existing.no}`);
      } catch (error) {
        alert(`The local quotation already exists as ${existing.no}, but server synchronization is still pending.\n\n${error.message || error}`);
      }
      return;
    }

    const referenceService = window.KeySuiteQuotationReferences;
    if (!referenceService?.allocateNext) {
      return alert("KeySuite quotation-reference service is not ready. Refresh KeySuite and try again.");
    }

    if (!confirm("Import this as an unpriced KeySuite draft?\n\nKeySuite will allocate the official quotation reference. Review and apply pricing before sealing.")) return;

    let reference;
    try {
      reference = await referenceService.allocateNext();
      if (!reference) throw new Error("No quotation reference was returned.");
    } catch (error) {
      return alert(`Quotation reference could not be allocated.\n\n${error.message || error}`);
    }

    const localQuoteId = uuid();
    let quote;
    try {
      quote = buildQuote(draft, reference, localQuoteId);
      const allQuotes = readJson(QUOTES_KEY, []);
      if (allQuotes.some((row) => String(row.no || "").toUpperCase() === String(reference).toUpperCase())) {
        throw new Error(`Quotation reference ${reference} already exists locally.`);
      }
      allQuotes.unshift(quote);
      writeJson(QUOTES_KEY, allQuotes);
      await referenceService.registerUsed?.(reference);
    } catch (error) {
      return alert(`The draft could not be written to KeySuite.\n\n${error.message || error}`);
    }

    try {
      await registerImport(draft, quote);
      const pending = readJson(PENDING_KEY, {});
      delete pending[draftId];
      writeJson(PENDING_KEY, pending);
      await loadDrafts();
      render();
      alert(`KeyAI draft imported successfully.\n\nQuotation: ${reference}\nPrice: pending KeySuite review\nStatus: Awaiting internal approval`);
      window.KeySuiteApp?.showPage?.("quoteHistory");
    } catch (error) {
      const pending = readJson(PENDING_KEY, {});
      pending[draftId] = { quoteId: quote.id, reference: quote.no, error: error.message || String(error) };
      writeJson(PENDING_KEY, pending);
      alert(`Quotation ${reference} was created locally, but KeyAI synchronization is pending.\n\nOpen KeyAI Drafts and click Import again to retry.\n\n${error.message || error}`);
    }
  }

  async function init() {
    installStyles();
    installDialog();
    installButton();
    try {
      if (window.KeySuiteAuth?.getSession?.()) await loadDrafts();
    } catch (error) {
      console.warn("KeyAI Draft Inbox is waiting for sign-in", error);
    }
    window.addEventListener("keysuite-auth-changed", () => loadDrafts().catch(() => {}));
    window.addEventListener("keysuite-customers-changed", () => render());
  }

  window.KeyAIInbox = {
    version: VERSION,
    open: openInbox,
    refresh: loadDrafts,
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => setTimeout(init, 0), { once: true });
  } else {
    setTimeout(init, 0);
  }
})();
