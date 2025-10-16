// Email utility no longer used; Firebase handles emails directly.
export async function sendEmail() {
  throw new Error("Email sending is disabled; use Firebase Auth actions instead");
}
