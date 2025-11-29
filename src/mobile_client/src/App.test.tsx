import React from "react";
import { render } from "@testing-library/react";
import { vi } from "vitest";
import App from "./App";
import * as Json from "@shared/gleam_json/gleam/json.mjs";
import * as SharedUser from "@shared/shared/shared_user.mjs";
import * as Prelude from "@shared/prelude.mjs";
import * as Result from "./util/result";

globalThis.fetch = vi.fn(() =>
  Promise.resolve({
    ok: false,
    json: () => Promise.resolve({}),
  } as Response),
);

test("renders without crashing", () => {
  const { baseElement } = render(<App />);
  expect(baseElement).toBeDefined();
});

test("decodes data utilizing @shared (gleam built)", () => {
  const user = new SharedUser.UserDto(
    new SharedUser.UserId("id"),
    new SharedUser.Username("username"),
    "email@email.com",
    true,
  );

  const json = SharedUser.to_json(user);

  expect(json).toEqual({
    id: "id",
    username: "username",
    email: "email@email.com",
    email_verified: true,
  });

  const result: Prelude.Result<SharedUser.UserDto, Json.DecodeError$> =
    Json.parse(Json.to_string(json), SharedUser.decode_user_dto());

  if (Result.isOk(result)) {
    const actual = result[0];
    expect(actual).toEqual(user);
  } else {
    throw new Error("aint ok");
  }
});

test("withFields updates immutablely (gleam stdlib)", () => {
  const user = new SharedUser.UserDto(
    new SharedUser.UserId("user-123"),
    new SharedUser.Username("alice"),
    "old@email.com",
    false,
  );

  const updatedUser = user.withFields({
    email: "new@email.com",
    email_verified: true,
  });

  expect(user.email).toBe("old@email.com");
  expect(user.email_verified).toBe(false);

  expect(updatedUser.email).toBe("new@email.com");
  expect(updatedUser.email_verified).toBe(true);

  expect(updatedUser.id.v).toBe("user-123");
  expect(updatedUser.username.v).toBe("alice");
});
