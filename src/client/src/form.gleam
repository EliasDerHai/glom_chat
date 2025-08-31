import gleam/list
import gleam/option
import gleam/string

// TYPES -----------------------------------------------------------------------
pub type FormField(value, custom_error) {
  FormField(
    value: value,
    touch: FormFieldTouch,
    validators: List(fn(value) -> option.Option(PredefinedFormFieldError)),
    error: option.Option(PredefinedFormFieldError),
    custom_error: option.Option(custom_error),
  )
}

pub type FormFieldError(custom_error) {
  Predefined(PredefinedFormFieldError)
  Custom(custom_error)
}

pub type PredefinedFormFieldError {
  Empty
  MinLength(is: Int, min: Int)
}

// TODO: remove?
pub type FormFieldTouch {
  /// user hasn't touched input yet
  Pure
  /// user has touched and unfocused input (blur-event)
  Dirty
}

// FUNCTIONS -----------------------------------------------------------------------

/// order of validators matters (first error short-circuits)
pub fn form_field(
  validators: List(fn(String) -> option.Option(PredefinedFormFieldError)),
) -> FormField(String, custom_error) {
  FormField(
    value: "",
    touch: Pure,
    validators: validators,
    error: option.None,
    custom_error: option.None,
  )
}

/// set explicit error 
pub fn set_custom_error(
  form_field: FormField(value, custom_error),
  custom_error: custom_error,
) -> FormField(value, custom_error) {
  FormField(..form_field, custom_error: option.Some(custom_error))
}

pub fn clear_custom_error(
  form_field: FormField(value, custom_error),
) -> FormField(value, custom_error) {
  FormField(..form_field, error: option.None)
}

/// set new value for the form-field (runs valdiators)
pub fn set_value(
  field: FormField(value, custom_error),
  v: value,
) -> FormField(value, custom_error) {
  let error =
    list.fold(field.validators, option.None, fn(acc, validator) {
      case acc {
        option.None -> validator(v)
        some -> some
      }
    })

  FormField(..field, value: v, touch: Dirty, error: error)
}

// GETTERS -----------------------------------------------------------------------
pub fn get_value(field: FormField(value, custom_error)) -> value {
  field.value
}

pub fn get_error(
  field: FormField(value, custom_error),
) -> option.Option(FormFieldError(custom_error)) {
  option.or(
    option.map(field.error, fn(e) { Predefined(e) }),
    option.map(field.custom_error, fn(e) { Custom(e) }),
  )
}

/// FormField can be invalid and have no errors 
/// - errors are set upon change (`set_value`) 
/// - valid represents if all validators are passed 
/// this allows to set submit button's disabled state from validity without rendering errors before the field was touched
pub fn is_valid(field: FormField(value, custom_error)) {
  list.fold(field.validators, option.None, fn(acc, validator) {
    case acc {
      option.None -> validator(field.value)
      some -> some
    }
  })
  |> option.is_none
}

// VALIDATORS -----------------------------------------------------------------------

pub fn validator_nonempty() -> fn(String) ->
  option.Option(PredefinedFormFieldError) {
  fn(value: String) {
    case value {
      "" -> option.Some(Empty)
      _ -> option.None
    }
  }
}

pub fn validator_min_length(
  min: Int,
) -> fn(String) -> option.Option(PredefinedFormFieldError) {
  fn(value: String) {
    let is = string.length(value)
    case is >= min {
      True -> option.None
      False -> option.Some(MinLength(is, min))
    }
  }
}
