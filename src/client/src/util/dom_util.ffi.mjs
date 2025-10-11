export function scrollToBottom(root) {
  const anchor = root.querySelector("#scroll-anchor");

  if (anchor) {
    anchor.scrollIntoView({ behavior: "smooth" });
  } else {
    console.warn("could not find '#scroll-anchor'");
  }
}
