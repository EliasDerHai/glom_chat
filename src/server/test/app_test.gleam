import app/util/mailing
import dot_env/env
import gleam/dict
import gleam/io
import gleam/set
import gleeunit
import gleeunit/should
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

// needs env vars:
// - EMAIL (must be gmail)
// - EMAIL_NAME
// - EMAIL_APP_KEY
// - INTEGRATION_TEST_EMAIL_RECEIVER
pub fn mailing_test() {
  fn() {
    mailing.send_confirmation_mail(
      env.get_string_or("INTEGRATION_TEST_EMAIL_RECEIVER", "some@gmail.com"),
      uuid.v4() |> uuid.to_string,
    )
  }
  |> integration_test
}

const integration_test_flag = "RUN_INTEGRATION_TESTS"

fn integration_test(test_fn: fn() -> a) {
  case env.get_bool(integration_test_flag) {
    Error(_) -> {
      { "Skipping integration test (" <> integration_test_flag <> " not set)" }
      |> io.println
    }
    Ok(False) -> {
      {
        "Skipping integration test ("
        <> integration_test_flag
        <> " set to FALSE)"
      }
      |> io.println
    }
    Ok(True) -> {
      "integration test started ..."
      |> io.println
      test_fn()
      "integration test ended"
      |> io.println
      Nil
    }
  }
}

pub fn collection_equality_test() {
  let a = uuid.v7()
  let b = uuid.v7()

  [a, b] |> set.from_list |> should.equal([b, a] |> set.from_list)
  [a, b] |> should.not_equal([b, a])
  [a, b] |> should.equal([a, b])
  dict.from_list([#("a", a), #("b", b)])
  |> should.equal(dict.from_list([#("b", b), #("a", a)]))
}
