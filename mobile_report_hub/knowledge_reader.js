"use strict";

(function (global) {
  const SCHEMA = "ea-lab-second-brain-reader/1";
  const EN_TOKEN = /[A-Za-z0-9]+(?:[-_][A-Za-z0-9]+)*/g;
  const INTAKE_FIELDS = ["ea", "variant", "build", "config", "symbol", "timeframe", "window", "data_source"];

  function text(value, fallback = "UNKNOWN") {
    return value === undefined || value === null || value === "" ? fallback : String(value);
  }

  function safeHttp(value) {
    if (typeof value !== "string") return null;
    try {
      const url = new URL(value);
      return url.protocol === "https:" || url.protocol === "http:" ? url.href : null;
    } catch { return null; }
  }

  function englishTokens(value) {
    return (String(value).match(EN_TOKEN) || []).map(item => item.toLocaleLowerCase("en-US"));
  }

  function thaiTokens(value) {
    return String(value).match(/[\u0E00-\u0E7F]+/g) || [];
  }

  function matches(document, query, topic, scope) {
    if (scope === "CANONICAL" && document.authority_class === "DRAFT_NOT_IMPORTED") return false;
    if (scope === "DRAFT" && document.authority_class !== "DRAFT_NOT_IMPORTED") return false;
    if (topic && !(document.topics || []).includes(topic)) return false;
    if (!query.trim()) return true;
    const haystack = [document.title, document.body, ...(document.topics || []), ...(document.source_ids || [])].join("\n");
    const hayEnglish = new Set(englishTokens(haystack));
    return englishTokens(query).every(token => hayEnglish.has(token)) && thaiTokens(query).every(token => haystack.includes(token));
  }

  function el(name, options = {}, children = []) {
    const node = document.createElement(name);
    Object.entries(options).forEach(([key, value]) => {
      if (key === "className") node.className = value;
      else if (key === "text") node.textContent = value;
      else if (key.startsWith("data-")) node.setAttribute(key, value);
      else if (key in node) node[key] = value;
      else node.setAttribute(key, value);
    });
    for (const child of (Array.isArray(children) ? children : [children])) if (child) node.append(child);
    return node;
  }

  function renderInline(container, raw) {
    const pattern = /\[([^\]]+)\]\(([^)]+)\)|`([^`]+)`|(https?:\/\/[^\s<]+)/g;
    let cursor = 0; let match;
    while ((match = pattern.exec(raw))) {
      container.append(document.createTextNode(raw.slice(cursor, match.index)));
      if (match[3]) container.append(el("code", {text: match[3]}));
      else {
        const label = match[1] || match[4];
        const href = safeHttp(match[2] || match[4]);
        if (href) container.append(el("a", {text: label, href, target: "_blank", rel: "noopener noreferrer"}));
        else container.append(document.createTextNode(label));
      }
      cursor = pattern.lastIndex;
    }
    container.append(document.createTextNode(raw.slice(cursor)));
  }

  function markdown(body) {
    const host = el("article", {className: "kr-document-body"});
    let paragraph = []; let list = null; let code = null;
    const flushParagraph = () => {
      if (!paragraph.length) return;
      const p = el("p"); renderInline(p, paragraph.join(" ")); host.append(p); paragraph = [];
    };
    const flushList = () => { if (list) host.append(list); list = null; };
    for (const raw of String(body || "").split(/\r?\n/)) {
      if (raw.startsWith("```")) {
        flushParagraph(); flushList();
        if (code) { host.append(el("pre", {}, el("code", {text: code.join("\n")}))); code = null; } else code = [];
        continue;
      }
      if (code) { code.push(raw); continue; }
      const heading = raw.match(/^(#{1,6})\s+(.+)$/);
      const item = raw.match(/^\s*[-*]\s+(.+)$/);
      if (heading) {
        flushParagraph(); flushList(); const h = el(`h${Math.min(heading[1].length + 1, 6)}`); renderInline(h, heading[2]); host.append(h);
      } else if (item) {
        flushParagraph(); if (!list) list = el("ul"); const li = el("li"); renderInline(li, item[1]); list.append(li);
      } else if (!raw.trim() || raw === "---") { flushParagraph(); flushList(); }
      else paragraph.push(raw.trim());
    }
    flushParagraph(); flushList(); if (code) host.append(el("pre", {}, el("code", {text: code.join("\n")})));
    return host;
  }

  function excerpt(doc, query) {
    const plain = String(doc.body || "").replace(/\s+/g, " ").trim();
    const terms = [...englishTokens(query), ...thaiTokens(query)];
    const folded = plain.toLocaleLowerCase("en-US");
    const positions = terms.map(term => folded.indexOf(term.toLocaleLowerCase("en-US"))).filter(value => value >= 0);
    const start = Math.max(0, (positions.length ? Math.min(...positions) : 0) - 90);
    return `${start ? "…" : ""}${plain.slice(start, start + 360)}${start + 360 < plain.length ? "…" : ""}`;
  }

  function packet(data, question, docs, intake) {
    const negative = data.documents.filter(doc => doc.document_type === "NEGATIVE_KNOWLEDGE" && matches(doc, question, "", "ALL"));
    const caveats = ["Keyword NO_MATCH does not prove no historical equivalent; read current PROJECT_STATE and exact family/experiment owners before proposing action.", "Snapshot documents can contain historical plans; document content is not current execution authority."];
    if (!docs.length) caveats.push("NO_MATCH: no title/body/topic/source match at the pinned export");
    if (docs.some(doc => doc.authority_class === "BROKEN_PROVENANCE")) caveats.push("BROKEN_PROVENANCE present in matched material");
    (data.health.problems || []).slice(0, 10).forEach(problem => caveats.push(`Library health: ${problem.kind}`));
    return {
      schema_version: "ea-lab-knowledge-query-packet/1", authority: data.authority, question,
      canonical: data.canonical,
      problem_intake: Object.fromEntries(INTAKE_FIELDS.map(field => [field, intake[field] || null])),
      matches: docs.map(doc => ({id: doc.id, title: doc.title, authority_class: doc.authority_class, path: doc.path || null, sha256: doc.sha256, source_ids: doc.source_ids, line_refs: doc.line_refs || [], excerpt: excerpt(doc, question)})),
      negative_memory: negative.length ? {status: "MATCH", sources: negative.map(doc => ({id: doc.id, path: doc.path, sha256: doc.sha256, excerpt: excerpt(doc, question)}))} : {status: "NO_MATCH", sources: []},
      unresolved_evidence_caveats: caveats,
      draft_separation: {draft_matches: docs.filter(doc => doc.authority_class === "DRAFT_NOT_IMPORTED").length, notice: "DRAFT_NOT_IMPORTED is not canonical, accepted, or strategy authority."},
      automatic_actions: [], test_verdict: null, confidence_grade: null, performance_grade: null
    };
  }

  function validate(data) {
    if (!data || data.schema_version !== SCHEMA || !data.canonical || !/^[0-9a-f]{40}$/.test(data.canonical.sha || "") || !Array.isArray(data.documents) || !data.health) throw new Error("Malformed or pinless Second Brain index");
    if (data.canonical.ref !== data.canonical.sha || !data.documents.length || !Array.isArray(data.registry) || !Array.isArray(data.health.problems)) throw new Error("Malformed knowledge metadata");
    const classes = new Set(["REGISTERED_RESEARCH", "OTHER_CANONICAL_DOCUMENT", "DRAFT_NOT_IMPORTED", "BROKEN_PROVENANCE"]);
    for (const field of ["canonical_documents", "draft_documents", "source_notes", "research_cards", "registry_records", "missing_or_unsafe_link_count", "registry_binding_problem_count"]) if (!Number.isInteger(data.health[field]) || data.health[field] < 0) throw new Error("Malformed library count");
    if (data.health.canonical_documents + data.health.draft_documents !== data.documents.length || data.health.draft_documents !== data.documents.filter(d => d.authority_class === "DRAFT_NOT_IMPORTED").length || data.health.registry_records !== data.registry.length) throw new Error("Library count mismatch");
    const seen = new Set();
    data.documents.forEach(doc => {
      if (!doc || typeof doc.id !== "string" || typeof doc.title !== "string" || typeof doc.body !== "string" || !/^[0-9a-f]{64}$/.test(doc.sha256 || "")) throw new Error("Malformed Second Brain document row");
      if (!classes.has(doc.authority_class) || typeof doc.portable_id !== "string" || !Array.isArray(doc.source_ids) || !Array.isArray(doc.topics) || !Array.isArray(doc.line_refs)) throw new Error("Malformed source metadata");
      const key = `${doc.authority_class}:${doc.id}`; if (seen.has(key)) throw new Error(`Duplicate document identity: ${key}`); seen.add(key);
    });
    return data;
  }

  async function loadData(options) {
    if (options.data) return validate(options.data);
    const response = await fetch(options.url || "./knowledge_index.json", {cache: "no-store"});
    if (!response.ok) throw new Error(`Second Brain index unavailable (${response.status})`);
    return validate(await response.json());
  }

  async function copyOrDownload(value, status) {
    const serialized = `${JSON.stringify(value, null, 2)}\n`;
    try {
      await navigator.clipboard.writeText(serialized); status.textContent = "คัดลอก context packet แล้ว · copied";
    } catch {
      const blob = new Blob([serialized], {type: "application/json"}); const url = URL.createObjectURL(blob);
      const link = el("a", {href: url, download: "EA_LAB_KNOWLEDGE_PACKET.json"}); link.click(); URL.revokeObjectURL(url);
      status.textContent = "ดาวน์โหลด context packet แล้ว · downloaded";
    }
  }

  function renderApp(root, data, options) {
    root.replaceChildren(); root.classList.add("kr-root");
    const state = {query: "", topic: "", scope: "ALL", selected: null};
    const title = el("h1", {text: "Second Brain Reader"});
    const notice = el("p", {className: "kr-notice", text: "คลังอ่านแบบตรึงตาม Git · DRAFT_NOT_IMPORTED ยังไม่ใช่ความรู้ canonical ที่ยอมรับแล้ว และไม่มีอำนาจแก้ EA/สั่งทดสอบ"});
    const health = el("section", {className: "kr-health", ariaLabel: "Library health"});
    const counts = [`Pin ${data.canonical.sha.slice(0, 12)}`, `Source notes ${data.health.source_notes}`, `Cards ${data.health.research_cards}`, `Draft ${data.health.draft_documents}`, `Registered sources ${data.health.registry_records}`, `Git hash matches ${data.health.git_hash_matches ?? "UNKNOWN"}`, `External not revalidated ${data.health.external_not_verified ?? "UNKNOWN"}`, `Problems ${(data.health.problems || []).length}`, `Missing links ${data.health.missing_or_unsafe_link_count}`];
    health.append(el("h2", {text: "Library health · สุขภาพคลัง"}), el("p", {text: `ส่งออก ${data.canonical.generated_at_utc || "UNKNOWN"} | source commit ${data.canonical.build_timestamp} · ไม่ใช่สถานะสด`}), el("div", {className: "kr-health-grid"}, counts.map(item => el("span", {text: item}))));
    if ((data.health.problems || []).length) health.append(el("details", {}, [el("summary", {text: "ดูปัญหา provenance / links"}), el("pre", {text: JSON.stringify(data.health.problems, null, 2)})]));

    const query = el("input", {type: "search", id: "kr-query", placeholder: "ค้นหา Order Flow, Demon Beam, BWD, risk หรือภาษาไทย", ariaLabel: "ค้นหาความรู้"});
    const scope = el("select", {id: "kr-scope", ariaLabel: "กรอง Canonical หรือ Draft"}, [el("option", {value: "ALL", text: "Canonical + Draft"}), el("option", {value: "CANONICAL", text: "Canonical เท่านั้น"}), el("option", {value: "DRAFT", text: "Draft เท่านั้น"})]);
    const topic = el("select", {id: "kr-topic", ariaLabel: "กรองหัวข้อ"}, [el("option", {value: "", text: "ทุกหัวข้อ"}), ...[...new Set(data.documents.flatMap(doc => doc.topics || []))].sort().map(value => el("option", {value, text: value}))]);
    const controls = el("section", {className: "kr-controls"}, [el("label", {text: "ค้นหา · Search"}, query), el("label", {text: "สถานะ · Scope"}, scope), el("label", {text: "หัวข้อ · Topic"}, topic)]);
    const resultCount = el("p", {className: "kr-result-count", ariaLive: "polite"});
    const list = el("div", {className: "kr-list", role: "list", ariaLabel: "ผลการค้นหา"});
    const reading = el("section", {className: "kr-reading", tabIndex: -1});
    const intake = Object.fromEntries(INTAKE_FIELDS.map(field => [field, ""]));
    const packetForm = el("details", {className: "kr-packet"});
    const packetFields = INTAKE_FIELDS.map(field => {
      const input = el("input", {type: "text", id: `kr-intake-${field}`, placeholder: "UNKNOWN / เว้นว่างได้"});
      input.addEventListener("input", () => { intake[field] = input.value.trim(); });
      return el("label", {text: field.replace("_", " ")}, input);
    });
    const packetButton = el("button", {type: "button", text: "คัดลอก / ดาวน์โหลด context packet"});
    const packetStatus = el("p", {className: "kr-packet-status", role: "status"});
    packetForm.append(el("summary", {text: "ปัญหา EA → evidence packet (read-only)"}), el("p", {text: "ช่องที่ไม่ทราบให้เว้นว่าง; จะคงค่า null ไม่ตีความเป็นศูนย์"}), el("div", {className: "kr-intake"}, packetFields), packetButton, packetStatus);

    function filtered() {
      return data.documents.filter(doc => matches(doc, state.query, state.topic, state.scope)).sort((a, b) => (a.authority_class === "DRAFT_NOT_IMPORTED") - (b.authority_class === "DRAFT_NOT_IMPORTED") || a.title.localeCompare(b.title, "th") || a.id.localeCompare(b.id));
    }
    function open(doc, focus = true) {
      state.selected = doc; reading.replaceChildren();
      const permanent = `#knowledge/${encodeURIComponent(doc.portable_id)}`;
      if (focus) history.replaceState(null, "", permanent);
      const heading = el("h2", {text: doc.title, tabIndex: -1});
      const idLink = el("a", {href: permanent, className: "kr-doc-link", text: `ID ${doc.id}`});
      reading.append(heading, el("p", {className: `kr-authority kr-${doc.authority_class.toLowerCase()}`, text: doc.authority_class}), idLink,
        el("p", {className: "kr-meta", text: `${doc.document_type} · SHA256 ${doc.sha256} · ${doc.path || "portable draft identity (local path withheld)"}` }));
      if (doc.authority_class === "DRAFT_NOT_IMPORTED") reading.append(el("p", {className: "kr-draft-warning", text: "ฉบับรอ review: ไม่ใช่ canonical import และไม่ใช่คำสั่งหรือ strategy verdict"}));
      if (safeHttp(doc.source_url)) reading.append(el("a", {href: safeHttp(doc.source_url), target: "_blank", rel: "noopener noreferrer", className: "kr-source", text: "เปิดแหล่งที่มา (เว็บไซต์ภายนอก)"}));
      reading.append(markdown(doc.body)); if (focus) heading.focus();
    }
    function draw() {
      const rows = filtered(); resultCount.textContent = `พบ ${rows.length} เอกสาร · ${state.scope} · การค้นหาเป็น exact token สำหรับอังกฤษ`;
      list.replaceChildren();
      if (!rows.length) list.append(el("p", {className: "kr-empty", text: "ไม่พบผลลัพธ์ที่ pin นี้ · NO_MATCH (ไม่ใช่หลักฐานว่าไม่มีความรู้ในโลกภายนอก)"}));
      rows.forEach(doc => {
        const button = el("button", {type: "button", className: "kr-result", "data-document-id": doc.id});
        button.append(el("strong", {text: doc.title}), el("span", {text: `${doc.authority_class} · ${doc.document_type}`}), el("small", {text: excerpt(doc, state.query)}));
        button.addEventListener("click", () => open(doc)); list.append(el("div", {role: "listitem"}, button));
      });
      if ((!state.selected || !rows.includes(state.selected)) && rows.length) open(rows[0], false);
      if (!rows.length) { state.selected = null; reading.replaceChildren(el("p", {text:"ไม่พบเอกสารตรงกับตัวกรองนี้"})); }
    }
    query.addEventListener("input", () => { state.query = query.value; draw(); });
    scope.addEventListener("change", () => { state.scope = scope.value; draw(); });
    topic.addEventListener("change", () => { state.topic = topic.value; draw(); });
    packetButton.addEventListener("click", () => copyOrDownload(packet(data, state.query, filtered(), intake), packetStatus));
    root.append(el("header", {className: "kr-header"}, [title, notice]), health, controls, resultCount, el("div", {className: "kr-layout"}, [el("aside", {className: "kr-master"}, list), reading]), packetForm);
    const requested = decodeURIComponent((location.hash.match(/^#knowledge\/(.+)$/) || [])[1] || "");
    const selected = requested && data.documents.find(doc => doc.portable_id === requested || doc.id === requested);
    if (selected) state.selected = selected;
    draw(); if (selected) open(selected, false);
    return {data, search(value) { query.value = value; state.query = value; draw(); }, packet: () => packet(data, state.query, filtered(), intake)};
  }

  async function mount(root, options = {}) {
    if (!root) throw new Error("Second Brain mount target missing");
    root.replaceChildren(el("p", {className: "kr-loading", text: "กำลังเปิดคลังความรู้…"}));
    try {
      const data = await loadData(options);
      const expected = typeof options.getExpectedSha === "function" ? options.getExpectedSha() : options.expectedSha;
      if (expected && expected !== data.canonical.sha) throw new Error("Knowledge / Monitor canonical pin mismatch");
      if (typeof options.isCurrent === "function" && !options.isCurrent()) return null;
      return renderApp(root, data, options);
    }
    catch (error) {
      if (typeof options.isCurrent === "function" && !options.isCurrent()) return null;
      root.replaceChildren(el("section", {className: "kr-failure", role: "alert"}, [el("h1", {text: "Second Brain unavailable"}), el("p", {text: error.message}), el("p", {text: "ไม่แสดง empty-success และไม่กระทบ Monitor views อื่น"})]));
      throw error;
    }
  }

  global.EALabKnowledgeReader = {mount, matches, validate, packet, safeHttp};
})(window);
