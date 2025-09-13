export function get_document_cookie() {
  console.log("get_document_cookie called");
  console.log("current location:", window.location.href);
  console.log("current port:", window.location.port);
  console.log("typeof document:", typeof document);
  console.log("document.cookie:", document.cookie);
  const result = document.cookie || "";
  console.log("returning:", result);
  return result;
}
