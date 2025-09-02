import form
import gleam/option
import gleeunit/should
import pre_login.{Login, Signup, UserSetPreLoginMode}

pub fn update_toggle_mode_test() {
  let m0 = pre_login.init()
  let #(m1, _) = pre_login.update(m0, UserSetPreLoginMode(Signup))
  let #(m2, _) = pre_login.update(m1, UserSetPreLoginMode(Login))

  m1.mode |> should.equal(Signup)
  m2.mode |> should.equal(Login)
}

pub fn equality_test() {
  should.equal(form.StringField("abc"), form.StringField("abc"))

  let a = fn() { "hello world!" }
  let b = fn() { "hello world!" }
  should.not_equal(a, b)
}

fn mk_field(value: String, touch: form.FormFieldTouch) -> form.FormField(b) {
  form.FormField(form.StringField(value), touch, [], option.None, option.None)
}

fn mk_field_with_custom_error(
  value: String,
  touch: form.FormFieldTouch,
  err: a,
) -> form.FormField(a) {
  form.FormField(
    form.StringField(value),
    touch,
    [],
    option.None,
    option.Some(err),
  )
}

pub fn passwords_matching_test() {
  let in =
    pre_login.SignupFormData(
      username: mk_field("joe", form.Dirty),
      email: mk_field("joe@example.com", form.Dirty),
      password: mk_field("hunter2", form.Dirty),
      password_confirm: mk_field("hunter3", form.Dirty),
    )

  let pre_login.SignupFormData(
    password: password,
    password_confirm: password_confirm,
    ..,
  ) = pre_login.evaluate_matching_passwords(in)

  let expectation = option.Some(pre_login.PasswordMissmatch)
  password.custom_error |> should.equal(expectation)
  password_confirm.custom_error |> should.equal(expectation)
}

pub fn passwords_matching_test_skipped() {
  let in =
    pre_login.SignupFormData(
      username: mk_field("joe", form.Dirty),
      email: mk_field("joe@example.com", form.Dirty),
      password: mk_field("hunter2", form.Dirty),
      password_confirm: mk_field("", form.Pure),
    )

  let pre_login.SignupFormData(
    password: password,
    password_confirm: password_confirm,
    ..,
  ) = pre_login.evaluate_matching_passwords(in)

  let expectation = option.None
  password.custom_error |> should.equal(expectation)
  password_confirm.custom_error |> should.equal(expectation)
}

pub fn passwords_matching_cleared_test() {
  let model =
    pre_login.SignupFormData(
      username: mk_field("joe", form.Dirty),
      email: mk_field("joe@example.com", form.Dirty),
      password: mk_field_with_custom_error(
        "secret",
        form.Dirty,
        pre_login.PasswordMissmatch,
      ),
      password_confirm: mk_field_with_custom_error(
        "secret",
        form.Dirty,
        pre_login.PasswordMissmatch,
      ),
    )

  let pre_login.SignupFormData(
    password: password,
    password_confirm: password_confirm,
    ..,
  ) = pre_login.evaluate_matching_passwords(model)

  let expectation = option.None
  password.custom_error |> should.equal(expectation)
  password_confirm.custom_error |> should.equal(expectation)
}
