WITH candidates AS (
  SELECT id, username
  FROM users
  WHERE lower(username) % lower($1)
     OR lower(username) LIKE lower($1) || '%'
  ORDER BY similarity(lower(username), lower($1)) DESC
  LIMIT 500
)
SELECT *
FROM candidates
ORDER BY
  (lower(username) = lower($1)) DESC,
  levenshtein(lower(username), lower($1)) ASC,
  length(username) ASC,
  username ASC
LIMIT $2;
