import * as Prelude from "@shared/prelude.mjs";

export const isOk = <T, E>(
  result: Prelude.Result<T, E>,
): result is Prelude.Ok<T, E> => result instanceof Prelude.Ok;
