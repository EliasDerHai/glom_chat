import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

pub fn default_disabled_class(in: String) -> String {
  "disabled:bg-gray-300" |> add_class(in, _)
}

pub fn default_hovered_class(in: String) -> String {
  "hover:bg-blue-700" |> add_class(in, _)
}

pub fn add_class(in: String, add: String) -> String {
  in <> " " <> add
}

pub fn view_default_button(
  text: String,
  disabled: Bool,
  msg: msg,
  additional_class: String,
) -> element.Element(msg) {
  html.button(
    [
      attribute.class(
        "bg-blue-600 text-white font-semibold py-2 px-4 transition-colors"
        |> default_disabled_class
        |> default_hovered_class
        |> add_class(additional_class),
      ),
      attribute.disabled(disabled),
      event.on_click(msg),
    ],
    [html.text(text)],
  )
}
