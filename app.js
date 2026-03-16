import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";

const SUPABASE_URL = "https://jlflfwjmtaxmnuzmupne.supabase.co";
const SUPABASE_PUBLISHABLE_KEY =
  "sb_publishable_O7FLqxVxwnsBqRMoNS-fjQ_h2jETQuO";
const EVENT_SLUG = "krvava-hodina-2026-03-23";
const CONTACT_URL = "https://www.facebook.com/ondra.d.ulrich/";
const CONTACT_LABEL = "https://www.facebook.com/ondra.d.ulrich/";
const FULL_PAGE_URL = new URL("full.html", window.location.href).toString();

const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
    detectSessionInUrl: false,
  },
});

const form = document.querySelector("#signup-form");
const submitButton = document.querySelector("#submit-button");
const statusElement = document.querySelector("#form-status");
const contactLink = document.querySelector("#contact-link");

if (contactLink) {
  contactLink.textContent = CONTACT_LABEL;

  if (CONTACT_URL && CONTACT_URL !== "#") {
    contactLink.href = CONTACT_URL;
    contactLink.target = "_blank";
  } else {
    contactLink.addEventListener("click", (event) => event.preventDefault());
  }
}

function setStatus(message, state = "") {
  statusElement.textContent = message;

  if (state) {
    statusElement.dataset.state = state;
  } else {
    delete statusElement.dataset.state;
  }
}

function setSubmitting(isSubmitting) {
  submitButton.disabled = isSubmitting;
  submitButton.textContent = isSubmitting
    ? "Ukládám přihlášku..."
    : "Přihlásit se na Krvavou hodinu";
}

function redirectToFullPage() {
  window.location.replace(FULL_PAGE_URL);
}

function isEventFullError(error) {
  return error?.code === "P0001" && error?.message === "EVENT_FULL";
}

async function refreshRegistrationStatus() {
  const { data, error } = await supabase.rpc("get_event_registration_status", {
    target_event_slug: EVENT_SLUG,
  });

  if (error) {
    console.error("Failed to fetch registration status:", error);
    return null;
  }

  if (data?.is_full) {
    redirectToFullPage();
  }

  return data;
}

function normalizeName(value) {
  return value.replace(/\s+/g, " ").trim();
}

function normalizeEmail(value) {
  return value.trim().toLowerCase();
}

function isValidEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

form?.addEventListener("submit", async (event) => {
  event.preventDefault();

  const formData = new FormData(form);
  const fullName = normalizeName(formData.get("fullName")?.toString() ?? "");
  const email = normalizeEmail(formData.get("email")?.toString() ?? "");
  const honeypot = formData.get("website")?.toString().trim() ?? "";

  if (honeypot) {
    setStatus("Formulář nebylo možné odeslat.", "error");
    return;
  }

  if (fullName.length < 2) {
    setStatus("Zadej prosím celé jméno.", "error");
    return;
  }

  if (!isValidEmail(email)) {
    setStatus("Zadej prosím platný e-mail.", "error");
    return;
  }

  setSubmitting(true);
  setStatus("Odesílám přihlášku...");

  try {
    const { error } = await supabase.from("event_registrations").insert({
      event_slug: EVENT_SLUG,
      full_name: fullName,
      email,
      source_url: `${window.location.origin}${window.location.pathname}`,
      user_agent: navigator.userAgent,
    });

    if (error) {
      if (error.code === "23505") {
        setStatus(
          "Tenhle e-mail už je na akci přihlášený. Kdybys potřeboval změnu, napiš pořadateli.",
          "error",
        );
        return;
      }

      if (isEventFullError(error)) {
        redirectToFullPage();
        return;
      }

      setStatus(
        "Přihlášku se nepodařilo uložit. Zkus to prosím za chvíli znovu.",
        "error",
      );
      console.error("Supabase insert failed:", error);
      return;
    }

    form.reset();
    setStatus(
      "Hotovo. Přihláška je uložená, těšíme se na tebe 23. 3. 2026 v 19:00.",
      "success",
    );
  } catch (error) {
    setStatus(
      "Spojení se nepodařilo navázat. Zkus to prosím za chvíli znovu.",
      "error",
    );
    console.error("Unexpected submit failure:", error);
  } finally {
    setSubmitting(false);
  }
});

refreshRegistrationStatus();
