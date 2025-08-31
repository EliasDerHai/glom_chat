import gleam/dict
import gleam/list
import gleam/option
import gleam/string

// TYPES -----------------------------------------------------------------------
pub type FormGroup(custom_error) {
  FromGroup(chilren: dict.Dict(String, FromGroupChild(custom_error)))
}

pub type FormArray(custom_error) {
  FormArray(chilren: List(FromGroupChild(custom_error)))
}

pub type FromGroupChild(custom_error) {
  FG(form_group: FormGroup(custom_error))
  FF(form_field: FormField(custom_error))
  FA(form_array: FormArray(custom_error))
}

pub type FormField(custom_error) {
  FormField(
    value: FormFieldValue,
    touch: FormFieldTouch,
    validators: List(
      fn(FormFieldValue) -> option.Option(PredefinedFormFieldError),
    ),
    error: option.Option(PredefinedFormFieldError),
    custom_error: option.Option(custom_error),
  )
}

pub type FormFieldValue {
  StringField(String)
  // TODO: others
}

pub type FormFieldError(custom_error) {
  Predefined(PredefinedFormFieldError)
  Custom(custom_error)
}

pub type PredefinedFormFieldError {
  Empty
  MinLength(is: Int, min: Int)
}

// TODO: consider removing
pub type FormFieldTouch {
  /// user hasn't touched input yet
  Pure
  /// user has touched and unfocused input (blur-event)
  Dirty
}

type Validator =
  fn(FormFieldValue) -> option.Option(PredefinedFormFieldError)

// FUNCTIONS -----------------------------------------------------------------------

/// order of validators matters (first error short-circuits)
pub fn form_field(validators: List(Validator)) -> FormField(custom_error) {
  FormField(
    value: StringField(""),
    touch: Pure,
    validators: validators,
    error: option.None,
    custom_error: option.None,
  )
}

/// set explicit error 
pub fn set_custom_error(
  form_field: FormField(custom_error),
  custom_error: custom_error,
) -> FormField(custom_error) {
  FormField(..form_field, custom_error: option.Some(custom_error))
}

pub fn clear_custom_error(
  form_field: FormField(custom_error),
) -> FormField(custom_error) {
  FormField(..form_field, error: option.None)
}

/// set new value for the form-field (runs valdiators)
pub fn set_string_value(
  field: FormField(custom_error),
  v: String,
) -> FormField(custom_error) {
  set_value(field, StringField(v))
}

/// set new value for the form-field (runs valdiators)
pub fn set_value(
  field: FormField(custom_error),
  v: FormFieldValue,
) -> FormField(custom_error) {
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
pub fn group_is_valid(group: FormGroup(custom_error)) {
  group.chilren
  |> dict.values()
  |> list.map(fn(c) {
    case c {
      FA(form_array:) -> array_is_valid(form_array)
      FF(form_field:) -> field_is_valid(form_field)
      FG(form_group:) -> group_is_valid(form_group)
    }
  })
  |> list.all(fn(valid) { valid })
}

pub fn array_is_valid(group: FormArray(custom_error)) {
  group.chilren
  |> list.map(fn(c) {
    case c {
      FA(form_array:) -> array_is_valid(form_array)
      FF(form_field:) -> field_is_valid(form_field)
      FG(form_group:) -> group_is_valid(form_group)
    }
  })
  |> list.all(fn(valid) { valid })
}

/// FormField can be invalid and have no errors 
/// - errors are set upon change (`set_value`) 
/// - valid represents if all validators are passed 
/// this allows to set submit button's disabled state from validity without rendering errors before the field was touched
pub fn field_is_valid(field: FormField(custom_error)) {
  list.fold(field.validators, option.None, fn(acc, validator) {
    case acc {
      option.None -> validator(field.value)
      some -> some
    }
  })
  |> option.is_none
}

pub fn get_error(
  field: FormField(custom_error),
) -> option.Option(FormFieldError(custom_error)) {
  option.or(
    option.map(field.error, fn(e) { Predefined(e) }),
    option.map(field.custom_error, fn(e) { Custom(e) }),
  )
}

// VALIDATORS -----------------------------------------------------------------------

pub fn validator_nonempty() -> Validator {
  fn(value: FormFieldValue) {
    case value {
      StringField("") -> option.Some(Empty)
      _ -> option.None
    }
  }
}

pub fn validator_min_length(min: Int) -> Validator {
  fn(value: FormFieldValue) {
    case value {
      StringField(value) -> {
        let is = string.length(value)
        case is >= min {
          True -> option.None
          False -> option.Some(MinLength(is, min))
        }
      }
    }
  }
}
