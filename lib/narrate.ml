(* Narration layer. See narrate.mli for the public contract. *)

type request = { shape : string; stars : string list; neighbour : string }

let fiction_label = "This story is invented."
let model = "claude-haiku-5-5"
let endpoint = "https://api.anthropic.com/v1/messages"

(**
   [prompt r] builds the model prompt from the facts only.
   Requires: nothing
   Returns: prompt text
   Raises: nothing
   Example: prompt { shape = "Bolt"; stars = ["Vega"]; neighbour = "Lyra" }
            contains "Bolt", "Vega" and "Lyra"
   Complexity: O(L) time and space
   Pseudocode:
     lines <- [ "Write a short invented sky myth (about 70 words)."
                "Use only these facts; add no numbers, dates or real legends."
                "Shape: " ^ shape
                "Stars: " ^ join ", " stars ]
     if neighbour <> "" then add "Nearest constellation: " ^ neighbour
     return join "\n" lines
*)
let prompt r =
  let base =
    [ "Write a short invented sky myth of about 70 words.";
      "Use only the facts below. Add no numbers, dates or real legends.";
      "Shape: " ^ r.shape;
      "Stars: " ^ String.concat ", " r.stars ]
  in
  let extra = if r.neighbour = "" then [] else [ "Nearest constellation: " ^ r.neighbour ] in
  String.concat "\n" (base @ extra)

(**
   [json_escape s] is [s] quoted as a JSON string literal.
   Requires: nothing
   Returns: ["\"" ^ escaped ^ "\""]
   Raises: nothing
   Example: json_escape "a\"b" = "\"a\\\"b\""
   Complexity: O(n) time and space
   Pseudocode:
     for each char c:
       double quote -> backslash + quote ; backslash -> two backslashes
       newline, CR, tab -> backslash-n, backslash-r, backslash-t
       other control (< 0x20) -> backslash-u00XX
       else c
     wrap in double quotes
*)
let json_escape s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter
    (function
      | '"' -> Buffer.add_string b "\\\""
      | '\\' -> Buffer.add_string b "\\\\"
      | '\n' -> Buffer.add_string b "\\n"
      | '\r' -> Buffer.add_string b "\\r"
      | '\t' -> Buffer.add_string b "\\t"
      | c when Char.code c < 0x20 -> Buffer.add_string b (Printf.sprintf "\\u%04x" (Char.code c))
      | c -> Buffer.add_char b c)
    s;
  Buffer.add_char b '"';
  Buffer.contents b

(**
   [find_sub s sub from] is the first index [>= from] where [sub] occurs.
   Requires: [0 <= from]
   Returns: [Some i] or [None]
   Raises: nothing
   Example: find_sub "abcabc" "ca" 0 = Some 2
   Complexity: O(n * m) time, O(1) space
   Pseudocode:
     for i = from to |s| - |sub|: if s[i .. i+|sub|) = sub then return Some i
     return None
*)
let find_sub s sub from =
  let n = String.length s and m = String.length sub in
  let rec go i =
    if i + m > n then None else if String.sub s i m = sub then Some i else go (i + 1)
  in
  go from

(**
   [read_json_string s i] decodes the JSON string literal starting at the
   opening quote [s.[i]].
   Requires: [s.[i] = '"']
   Returns: [Some decoded] or [None] if the literal is unterminated
   Raises: nothing
   Example: read_json_string "\"a\\nb\"" 0 = Some "a\nb"
   Complexity: O(n) time and space
   Pseudocode:
     j <- i + 1
     loop: double quote -> done
           backslash -> decode the escape (n r t b f, slash, backslash,
                        quote, uXXXX encoded as UTF-8)
           other -> copy ; end of input -> None
*)
let read_json_string s i =
  let n = String.length s in
  let b = Buffer.create 256 in
  let rec go j =
    if j >= n then None
    else
      match s.[j] with
      | '"' -> Some (Buffer.contents b)
      | '\\' when j + 1 < n -> (
          match s.[j + 1] with
          | 'n' -> Buffer.add_char b '\n'; go (j + 2)
          | 'r' -> Buffer.add_char b '\r'; go (j + 2)
          | 't' -> Buffer.add_char b '\t'; go (j + 2)
          | 'b' -> Buffer.add_char b '\b'; go (j + 2)
          | 'f' -> Buffer.add_char b '\012'; go (j + 2)
          | 'u' when j + 5 < n -> (
              match int_of_string_opt ("0x" ^ String.sub s (j + 2) 4) with
              | Some code when Uchar.is_valid code ->
                  Buffer.add_utf_8_uchar b (Uchar.of_int code);
                  go (j + 6)
              | _ -> Buffer.add_char b '?'; go (j + 6))
          | c -> Buffer.add_char b c; go (j + 2))
      | c -> Buffer.add_char b c; go (j + 1)
  in
  go (i + 1)

(**
   [extract_text body] pulls the first ["text"] string out of a Messages
   API reply without a JSON library.
   Requires: nothing
   Returns: [Some text] or [None] when absent
   Raises: nothing
   Example: extract_text "{\"content\":[{\"type\":\"text\",\"text\":\"Hi\"}]}" = Some "Hi"
   Complexity: O(n) time and space
   Pseudocode:
     i <- index of "\"text\"" followed by optional spaces, ':' , spaces, '"'
     return read_json_string body (index of that quote)
*)
let extract_text body =
  let n = String.length body in
  let rec skip_ws j = if j < n && (body.[j] = ' ' || body.[j] = '\n' || body.[j] = '\r' || body.[j] = '\t') then skip_ws (j + 1) else j in
  let rec search from =
    match find_sub body "\"text\"" from with
    | None -> None
    | Some i ->
        let j = skip_ws (i + 6) in
        if j < n && body.[j] = ':' then
          let k = skip_ws (j + 1) in
          if k < n && body.[k] = '"' then read_json_string body k else search (i + 6)
        else search (i + 6)
  in
  search 0

(**
   [with_temp f] runs [f] with a fresh temporary file path and removes
   the file afterwards, even on exceptions.
   Requires: a writable temp directory
   Returns: [f path]
   Raises: whatever [f] raises (after cleanup)
   Example: with_temp (fun p -> Sys.file_exists p) = true
   Complexity: O(1) besides [f]
   Pseudocode:
     p <- Filename.temp_file ; result <- f p ; remove p ; return result
*)
let with_temp f =
  let p = Filename.temp_file "doodle" ".tmp" in
  Fun.protect ~finally:(fun () -> try Sys.remove p with Sys_error _ -> ()) (fun () -> f p)

(**
   [story_of r] makes the blocking request for a full request record.
   Requires: curl and ANTHROPIC_API_KEY for a result
   Returns: [Some text] or [None]
   Raises: nothing
   Example: story_of { shape = "Bolt"; stars = []; neighbour = "" } = None (offline)
   Complexity: one network round trip
   Pseudocode:
     key <- getenv ANTHROPIC_API_KEY, or return None
     write headers (x-api-key, anthropic-version, content-type) to temp file
     write JSON body { model; max_tokens = 300; messages = [user: prompt r] }
     run curl -s --max-time 20 -o out -H @headers -d @body endpoint
     if exit code <> 0 then None else extract_text (read out)
     any exception -> None
*)
let story_of r =
  match Sys.getenv_opt "ANTHROPIC_API_KEY" with
  | None | Some "" -> None
  | Some key -> (
      try
        with_temp (fun headers ->
            with_temp (fun body ->
                with_temp (fun out ->
                    Out_channel.with_open_text headers (fun oc ->
                        Printf.fprintf oc "x-api-key: %s\nanthropic-version: 2023-06-01\ncontent-type: application/json\n" key);
                    Out_channel.with_open_text body (fun oc ->
                        Printf.fprintf oc
                          "{\"model\":%s,\"max_tokens\":300,\"messages\":[{\"role\":\"user\",\"content\":%s}]}"
                          (json_escape model) (json_escape (prompt r)));
                    let cmd =
                      Filename.quote_command "curl"
                        [ "-s"; "--max-time"; "20"; "-o"; out; "-H"; "@" ^ headers;
                          "--data-binary"; "@" ^ body; endpoint ]
                    in
                    if Sys.command cmd <> 0 then None
                    else extract_text (In_channel.with_open_bin out In_channel.input_all))))
      with _ -> None)

(**
   [story ~shape ~stars] is the blocking call without a neighbour.
   Requires: see {!story_of}
   Returns: [Some text] or [None]
   Raises: nothing
   Example: story ~shape:"Bolt" ~stars:["Vega"] = None (when offline)
   Complexity: one network round trip
   Pseudocode:
     return story_of { shape; stars; neighbour = "" }
*)
let story ~shape ~stars = story_of { shape; stars; neighbour = "" }

(**
   [story_async r k] runs the request in a new domain.
   Requires: thread-safe [k]
   Returns: unit, immediately
   Raises: nothing
   Example: story_async r (fun s -> Atomic.set slot s)
   Complexity: O(1) for the caller
   Pseudocode:
     spawn domain: k (story_of r, or None on any exception)
     do not join; the domain ends after calling k
*)
let story_async r k =
  ignore (Domain.spawn (fun () -> k (try story_of r with _ -> None)) : unit Domain.t)
