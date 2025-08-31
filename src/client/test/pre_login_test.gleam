import gleeunit/should
import pre_login.{Login, Signup, UserSetPreLoginMode}

pub fn update_toggle_mode_test() {
  let m0 = pre_login.init()
  let #(m1, _) = pre_login.update(m0, UserSetPreLoginMode(Signup))
  let #(m2, _) = pre_login.update(m1, UserSetPreLoginMode(Login))

  m1.mode |> should.equal(Signup)
  m2.mode |> should.equal(Login)
}
