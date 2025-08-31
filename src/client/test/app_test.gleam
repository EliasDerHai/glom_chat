import app.{PreLogin, PreLoginState, UserSetPreLoginMode, init, update}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn update_toggle_mode_test() {
  let #(m0, _) = init(Nil)
  let #(m1, _) = update(m0, UserSetPreLoginMode(app.Signup))
  let #(m2, _) = update(m1, UserSetPreLoginMode(app.Login))

  case m1 {
    PreLogin(PreLoginState(mode1, _, _)) -> mode1 |> should.equal(app.Signup)
    _ -> panic as "Expected Signup"
  }

  case m2 {
    PreLogin(PreLoginState(mode2, _, _)) -> mode2 |> should.equal(app.Login)
    _ -> panic as "Expected Login"
  }
}
