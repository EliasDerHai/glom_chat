import app.{
  Login, PreLogin, PreLoginState, Register, UserChangeEmail, UserChangePassword,
  UserChangePasswordConfirm, UserChangeUserName, UserSetPreLoginMode, init,
  update,
}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn init_test() {
  let #(model, _eff) = init(Nil)

  case model {
    PreLogin(PreLoginState(mode, username, email, password, password_confirm)) -> {
      mode |> should.equal(Login)
      username |> should.equal("")
      email |> should.equal("")
      password |> should.equal("")
      password_confirm |> should.equal("")
    }
    _ -> panic as "Expected PreLogin"
  }
}

pub fn update_fields_test() {
  let #(m0, _) = init(Nil)
  let #(m1, _) = update(m0, UserChangeUserName("user_name"))
  let #(m2, _) = update(m1, UserChangeEmail("some@example.com"))
  let #(m3, _) = update(m2, UserChangePassword("secret"))
  let #(m4, _) = update(m3, UserChangePasswordConfirm("secret"))

  case m4 {
    PreLogin(PreLoginState(_, user_name, email, password, password_confirm)) -> {
      user_name |> should.equal("user_name")
      email |> should.equal("some@example.com")
      password |> should.equal("secret")
      password_confirm |> should.equal("secret")
    }
    _ -> panic as "Expected PreLogin"
  }
}

pub fn update_toggle_mode_test() {
  let #(m0, _) = init(Nil)
  let #(m1, _) = update(m0, UserSetPreLoginMode(Register))
  let #(m2, _) = update(m1, UserSetPreLoginMode(Login))

  case m1 {
    PreLogin(PreLoginState(mode1, _, _, _, _)) ->
      mode1 |> should.equal(Register)
    _ -> panic as "Expected PreLogin"
  }

  case m2 {
    PreLogin(PreLoginState(mode2, _, _, _, _)) -> mode2 |> should.equal(Login)
    _ -> panic as "Expected PreLogin"
  }
}
