(lang dune 3.24)

(name hack)

(generate_opam_files true)

(source
 (github bbods16/doodle-constellation))

(authors "bbods16")

(maintainers "bbods16")

(documentation https://github.com/bbods16/doodle-constellation/blob/main/docs/PROOFS.md)

(package
 (name hack)
 (synopsis "Draw a shape, find it in the stars")
 (description "Doodle Constellation: an OCaml star-pattern matcher with a raylib front end, a from-scratch transformer recogniser, and Lean 4 proofs of the geometry.")
 (depends ocaml (ounit2 :with-test))
 (depopts raylib ctypes)
 (tags
  (astronomy ocaml raylib lean)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
