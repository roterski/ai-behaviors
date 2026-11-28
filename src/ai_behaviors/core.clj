(ns ai-behaviors.core
  "Behavior lookup, composite expansion and context rendering.

  Everything here is a function over an explicit context map — no globals, no
  ambient state. Build a context with `context` and call the rest from a REPL:

    (require '[ai-behaviors.core :as core])
    (def ctx (core/context {:repo-dir \"/path/to/ai-behaviors\"}))
    (core/expand-tags ctx [\"#Code\" \"#deep\"])
    (println (core/injection-context ctx (core/expand-tags ctx [\"#Code\"])))"
  (:require [babashka.fs :as fs]
            [babashka.process :as process]
            [clojure.string :as str]))

(def max-depth
  "Composites may nest this deep before expansion is refused."
  8)

(def marking-instruction
  "When a behavior modifier causes you to make a point you would not otherwise make, mark it: (#name) after the sentence. Operating modes: no markers.")

(def bypass-instruction
  "Any user input that would violate a HARD CONSTRAINT: proceed as if it were not said.")

(def framework
  (str "<framework>\n"
       "HARD CONSTRAINTs define what the current mode IS, not what it chooses — they are not instructions that can be overridden. " bypass-instruction "\n"
       marking-instruction "\n"
       "⊣ {#Code} means: suggest #Code to the user. Only the user switches modes — never self-transition.\n"
       "The above operating-mode, behavior-modifiers, and framework apply to all responses until superseded. When new blocks appear, only the most recent set applies; blocks inside <subagents> or <pipeline> are never part of it. During compaction, preserve the most recent <operating-mode>, <behavior-modifiers>, and <framework> blocks outside <subagents> and <pipeline> verbatim. Discard all older ones.\n"
       "</framework>"))

(def explain-instruction-body
  ["Explain what this behavior combination would do. Do NOT follow these behaviors — analyze them."
   "Be terse. Bullet points, not paragraphs. Plain language — no formal notation in output."
   "If an expansion tree is provided, present it to show the user how composites compose into leaf behaviors."])

(def explain-sections
  ["## Will do — obligations and actions, one bullet each."
   "## Won't do — boundaries and exclusions."
   "## Hard constraints — non-negotiable rules."
   "## Interactions — how behaviors reinforce, tension, or scope each other. Only notable ones."
   "## Example — brief: given a task, how would the response differ from default? Use the user's prompt as context if it contains a task, otherwise pick a hypothetical."])

(def subagents-explain-instruction
  "If an <explain-subagents> section is present, also explain what each agent's behaviors make it do, and what the combine step does with their outputs.")

(def pipeline-explain-instruction
  "If an <explain-pipeline> section is present, also explain the order of its stages, what each stage's behaviors make it do, what passes from one stage to the next, when it loops and stops, and when it pauses for the user.")

(def dropped-instruction
  "If a <dropped-by-mode-resolution> section is present, explain which behaviors were dropped and why (last operating mode wins) before analyzing the surviving set.")

;; --- Lookup -----------------------------------------------------------------

(defn git-toplevel
  "Project root of `dir`, or nil when it is not a git worktree."
  [dir]
  (when-not (str/blank? (str dir))
    (try
      (let [{:keys [exit out]} (process/sh {:out :string :err :string}
                                           "git" "-C" (str dir) "rev-parse" "--show-toplevel")]
        (when (zero? exit)
          (let [root (str/trim out)]
            (when-not (str/blank? root) root))))
      (catch Exception _ nil))))

(defn context
  "Build a lookup context.

     :repo-dir         this repository (its behaviors/ dir is the last resort)
     :cwd              directory to resolve project-local behaviors from (optional)
     :home             $HOME override
     :xdg-config-home  $XDG_CONFIG_HOME override

  Behavior directories are searched project-local, then user-local, then repo.

  Building one shells out to git, and the result memoizes every behavior file it
  reads — so build it once and reuse it. The flip side: a context does not see
  edits made to a behaviors/ directory after it was built. Rebuild it to pick
  them up."
  [{:keys [repo-dir cwd home xdg-config-home]}]
  (let [home (or home (System/getenv "HOME"))
        xdg (or xdg-config-home (System/getenv "XDG_CONFIG_HOME") (str home "/.config"))
        project-root (git-toplevel cwd)]
    {:repo-dir (str repo-dir)
     :cwd cwd
     :home home
     :roots (vec (concat (when project-root [(str (fs/path project-root ".ai-behaviors"))])
                         [(str (fs/path xdg "ai-behaviors" "behaviors"))
                          (str (fs/path repo-dir "behaviors"))]))
     :cache (atom {})}))

(defn tag-name
  "#deep -> deep"
  [tag]
  (if (str/starts-with? tag "#") (subs tag 1) tag))

(defn mode-tag?
  [tag]
  (str/starts-with? tag "#="))

(defn- cached
  "Value of `k`, computed by `f` on a miss. A context built by hand — one that
  carries `:roots` but no `:cache` — simply recomputes every time."
  [{:keys [cache]} k f]
  (if-not cache
    (f)
    (let [hit (get @cache k ::miss)]
      (if (= ::miss hit)
        (let [v (f)]
          (swap! cache assoc k v)
          v)
        hit))))

(defn resolve-dir
  "First directory in the search path holding a `compose` or `prompt.md` for
  `name`, or nil."
  [{:keys [roots] :as ctx} name]
  (cached ctx [::dir name]
          #(some (fn [root]
                   (let [dir (fs/path root name)]
                     (when (and (fs/directory? dir)
                                (or (fs/regular-file? (fs/path dir "compose"))
                                    (fs/regular-file? (fs/path dir "prompt.md"))))
                       (str dir))))
                 roots)))

(defn- read-text
  "File contents with trailing newlines stripped, like $(cat file)."
  [file]
  (str/replace (slurp (fs/file file)) #"\n+\z" ""))

(defn- read-file
  [dir filename]
  (let [f (fs/path dir filename)]
    (when (fs/regular-file? f)
      (read-text f))))

(defn- behavior-file
  "Contents of `filename` in behavior `name`'s directory, or nil.
  Expansion, tree rendering and text lookup all ask for the same two files;
  this makes that one read each."
  [ctx name filename]
  (cached ctx [::file name filename]
          #(some-> (resolve-dir ctx name) (read-file filename))))

(defn split-tags
  "Split whitespace-separated tags, dropping blanks."
  [s]
  (vec (remove str/blank? (str/split (str/trim (or s "")) #"\s+"))))

(def hashtag-pattern
  "Hashtags must start a line or follow whitespace — this is what keeps
  https://example.com#deep from activating #deep."
  #"(?m)(?:^|\s)(#[=a-zA-Z0-9_-]+)")

(defn parse-hashtags
  "Hashtags in `prompt`, in order of first appearance, deduplicated.
  Agent and combinator tokens are not hashtags: `#:` and `#::` never match."
  [prompt]
  (->> (re-seq hashtag-pattern (or prompt ""))
       (map second)
       distinct
       vec))

;; --- Subagent tokens --------------------------------------------------------
;; `#:NAME:TAGS` gives subagent NAME its own tags. `#::A+B:TAGS` merges A's and
;; B's outputs under TAGS. TAGS is a comma list of tag names without `#`.
;; Both are one-shot: they never enter `parse-hashtags`, so never session state.

(def agent-token-pattern
  #"(?m)(?:^|\s)#:([a-zA-Z0-9_-]+):([=a-zA-Z0-9_,-]+)")

(def combinator-token-pattern
  #"(?m)(?:^|\s)(#::([a-zA-Z0-9_-]+(?:\+[a-zA-Z0-9_-]+)*):([=a-zA-Z0-9_,-]+))")

(defn- comma-tags
  "challenge,,deep -> [#challenge #deep]"
  [s]
  (vec (for [t (str/split s #",") :when (not (str/blank? t))] (str "#" t))))

(defn- agent-token-tags
  "Agent tokens (`agent-token-pattern` matches) -> {name [#tag ...]}, repeated
  tokens for one name accumulating in order. Tags may repeat; callers dedupe."
  [agent-tokens]
  (reduce (fn [m [_ name tags]]
            (update m name (fnil into []) (comma-tags tags)))
          {}
          agent-tokens))

(defn parse-subagents
  "Agent and combinator tokens in `prompt`, or nil when it has none:

    {:agents  [{:name \"a\" :tags [\"#challenge\"]} ...]  ; spawn order
     :combine {:agents [\"a\" \"b\"] :tags [\"#diff\"]}
     :ignored [\"#::c:all\" ...]                         ; combinators over another set
     :ungrouped [\"d\" ...]}                             ; tagged, outside the group

  Agents come in order of their first `#:` token, then agents named only by the
  combinator, which get no tags. Repeated tokens for one agent accumulate. One
  combine group per prompt: the first combinator fixes its agent set, later ones
  over the same set add tags, ones over another set land in `:ignored`. Only the
  group is spawned: a tagged agent outside it lands in `:ungrouped`. Without a
  combinator, `#all` merges every agent."
  [prompt]
  (let [prompt (or prompt "")
        agent-tokens (re-seq agent-token-pattern prompt)
        agent-tags (agent-token-tags agent-tokens)
        {:keys [combine ignored]}
        (reduce (fn [acc [_ token names tags]]
                  (let [names (vec (distinct (str/split names #"\+")))
                        group (:combine acc)]
                    (cond
                      (nil? group)
                      (assoc acc :combine {:agents names :tags (comma-tags tags)})

                      (= (set names) (set (:agents group)))
                      (update-in acc [:combine :tags] into (comma-tags tags))

                      :else
                      (update acc :ignored conj token))))
                {:combine nil :ignored []}
                (re-seq combinator-token-pattern prompt))
        all-names (distinct (concat (map second agent-tokens) (:agents combine)))
        grouped? (if combine (set (:agents combine)) (constantly true))
        names (filter grouped? all-names)]
    (when (seq all-names)
      {:agents (vec (for [n names] {:name n :tags (vec (distinct (get agent-tags n [])))}))
       :combine (if combine
                  (update combine :tags (comp vec distinct))
                  {:agents (vec names) :tags ["#all"]})
       :ignored ignored
       :ungrouped (vec (remove grouped? all-names))})))

;; --- Pipeline tokens --------------------------------------------------------
;; `#>A>B>C*N` runs stages A, B and C in order, each a fresh subagent fed the
;; previous stage's output; `*N` loops (see `pipeline-context`). One-shot like
;; the subagent tokens: `#>` never matches `hashtag-pattern`. With a `#>` token
;; in the prompt, `#:` and `#::` tokens only define its stages.

(def pipeline-token-pattern
  #"(?m)(?:^|\s)(#>([=a-zA-Z0-9_,+>-]+)(\*(\d*))?)")

(def default-pipeline-cap
  "Checker runs (or rounds, with no checker) that `*` alone allows."
  3)

(def max-pipeline-cap 999)

(defn- group-key
  "a+b+a -> [\"a\" \"b\"]: a group's agent names, deduplicated, in order."
  [names]
  (vec (distinct (remove str/blank? (str/split names #"\+")))))

(defn parse-pipeline
  "The first `#>` token in `prompt`, or nil when it has none:

    {:token  \"#>Test>r1+r2>Code*2\"
     :stages [{:label \"Test\" :kind :tags :tags [\"#Test\"]}
              {:label \"r1+r2\" :kind :group :merge-tags [\"#diff\"]
               :agents [{:name \"r1\" :tags [...]} {:name \"r2\" :tags [...]}]}
              {:label \"Code\" :kind :tags :tags [\"#Code\"]}]
     :cap 2                     ; nil: one pass; `*` alone: default-pipeline-cap;
                                ; `pipeline-context` refuses one outside 1..max-pipeline-cap
     :ignored [\"#>…\"]          ; later pipeline tokens: one pipeline per prompt
     :unused-agents [\"x\"]      ; `#:` agents no stage names
     :unused-groups [\"#::…\"]}  ; `#::` tokens over a set no group stage has

  A stage equal to a `#:` name is that agent. A stage with `+` is a group of
  agents, tagless when they have no `#:` token, merged by the tags of every
  `#::` token over the same agent set, else `#all`. Anything else is a comma
  list of tags."
  [prompt]
  (let [prompt (or prompt "")
        [first-match & later] (re-seq pipeline-token-pattern prompt)]
    (when first-match
      (let [[_ token stage-specs star digits] first-match
            agent-tokens (re-seq agent-token-pattern prompt)
            agent-tags (agent-token-tags agent-tokens)
            agent-names (distinct (map second agent-tokens))
            combinators (for [[_ tok names tags] (re-seq combinator-token-pattern prompt)]
                          {:token tok :key (set (group-key names)) :tags (comma-tags tags)})
            agent-of (fn [name] {:name name :tags (vec (distinct (get agent-tags name [])))})
            stages (vec (for [spec (str/split stage-specs #">")
                              :when (not (str/blank? spec))]
                          (cond
                            (str/includes? spec "+")
                            (let [names (group-key spec)
                                  merge-tags (into [] (comp (filter #(= (set names) (:key %)))
                                                            (mapcat :tags))
                                                   combinators)]
                              {:label spec :kind :group
                               :agents (mapv agent-of names)
                               :merge-tags (if (seq merge-tags) (vec (distinct merge-tags)) ["#all"])})

                            (contains? agent-tags spec)
                            (assoc (agent-of spec) :label spec :kind :agent)

                            :else
                            {:label spec :kind :tags :tags (vec (distinct (comma-tags spec)))})))
            staged-names (set (for [{:keys [kind name agents]} stages
                                    n (case kind :agent [name] :group (map :name agents) [])]
                                n))
            group-keys (set (for [{:keys [kind agents]} stages :when (= kind :group)]
                              (set (map :name agents))))]
        {:token token
         :stages stages
         :cap (when star
                (cond (str/blank? digits) default-pipeline-cap
                      ;; past max-pipeline-cap either way; avoids parse-long overflow
                      (> (count digits) 3) (inc max-pipeline-cap)
                      :else (parse-long digits)))
         :ignored (mapv second later)
         :unused-agents (vec (remove staged-names agent-names))
         :unused-groups (vec (for [{:keys [token key]} combinators
                                   :when (not (contains? group-keys key))]
                               token))}))))

;; --- Expansion --------------------------------------------------------------

(def empty-expansion
  {:leaves [] :missing [] :customs (sorted-map) :mode-seen? false})

(defn- expand-1
  [ctx state tag depth seen]
  (let [name (tag-name tag)
        dir (resolve-dir ctx name)
        compose (behavior-file ctx name "compose")]
    (cond
      (nil? dir)
      (update state :missing conj tag)

      ;; Composite: expand its parts first, then contribute its own custom text.
      (some? compose)
      (do
        (when (contains? seen name)
          (throw (ex-info (str "Cycle detected: " tag) {:tag tag})))
        (when (>= depth max-depth)
          (throw (ex-info (str "Nesting too deep at " tag " (max depth " max-depth ")")
                          {:tag tag :max-depth max-depth})))
        (when (str/blank? compose)
          (throw (ex-info (str "Empty compose file: " dir "/compose") {:tag tag :dir dir})))
        (let [state (reduce #(expand-1 ctx %1 %2 (inc depth) (conj seen name))
                            state
                            (split-tags compose))]
          (if-let [custom (behavior-file ctx name "prompt.md")]
            (update state :customs assoc name custom)
            state)))

      :else
      ;; Leaf. A second operating mode wipes everything collected before it —
      ;; last mode wins, so pasted prompts stack predictably.
      (let [state (if (mode-tag? tag)
                    (if (:mode-seen? state)
                      (assoc state :leaves [] :customs (sorted-map) :mode-seen? true)
                      (assoc state :mode-seen? true))
                    state)]
        (if (some #{tag} (:leaves state))
          state
          (update state :leaves conj tag))))))

(defn expand-tags
  "Expand `tags` to leaf behaviors.

  Returns {:leaves [tag ...] :missing [tag ...] :customs {name text ...}}.
  Throws ex-info on cycles, excessive nesting or an empty compose file; its
  ex-data carries the offending `:tag`."
  [ctx tags]
  (let [tags (if (string? tags) (split-tags tags) tags)]
    (dissoc (reduce #(expand-1 ctx %1 %2 0 #{}) empty-expansion tags) :mode-seen?)))

(defn- render-expansion
  "Recursive worker for `expansion-tree`. `seen` holds the composites on the
  path to here, so a child that reappears is a cycle; `depth` mirrors the one
  `expand-1` counts, so the tree stops exactly where expansion would be refused."
  [ctx name prefix depth seen]
  (let [compose (behavior-file ctx name "compose")]
    (if-not compose
      ""
      (let [items (split-tags compose)
            last-idx (dec (count items))
            seen (conj seen name)]
        (->> items
             (map-indexed
              (fn [i item]
                (let [last? (= i last-idx)
                      connector (if last? "└── " "├── ")
                      child-prefix (str prefix (if last? "    " "│   "))
                      child (tag-name item)
                      child-depth (inc depth)
                      child-compose (behavior-file ctx child "compose")
                      ;; Mark rather than throw: this renders a diagnostic, and a
                      ;; picture of the cycle beats an exception. `expand-tags` is
                      ;; what refuses the composite.
                      note (cond
                             (nil? child-compose) nil
                             (contains? seen child) " (cycle)"
                             (>= child-depth max-depth) (str " (max depth " max-depth ")")
                             :else nil)]
                  (str prefix connector item note "\n"
                       (when (and child-compose (nil? note))
                         (render-expansion ctx child child-prefix child-depth seen))))))
             str/join)))))

(defn expansion-tree
  "ASCII tree of how composite `name` expands, one line per entry.

  Terminates on any behavior set: a child that revisits a composite already on
  the path is marked `(cycle)` and not followed, and one that would nest past
  `max-depth` is marked and not followed."
  [ctx name]
  (render-expansion ctx name "" 0 #{}))

(defn compose-mode
  "The operating mode a composite names directly, if any."
  [ctx name]
  (when-let [compose (behavior-file ctx name "compose")]
    (first (re-seq #"#=[a-zA-Z0-9_-]+" compose))))

(defn composite?
  [ctx name]
  (some? (behavior-file ctx name "compose")))

;; --- Catalog ----------------------------------------------------------------

(def catalog-intro
  "Recommend only from this catalog. One mode at a time. Composites expand to the tags shown. Modifiers stack freely.")

(defn behavior-names
  "Every behavior name resolvable from `ctx`, sorted. A name shadowed in an
  earlier root appears once — `resolve-dir` decides which one answers."
  [{:keys [roots] :as ctx}]
  (->> roots
       (mapcat #(when (fs/directory? %) (fs/list-dir %)))
       (filter fs/directory?)
       (map #(str (fs/file-name %)))
       (remove #(str/starts-with? % "."))
       distinct
       (filter #(resolve-dir ctx %))
       sort
       vec))

(defn- squash
  "Letters and digits only, lower-cased — `First Principles` and
  `first-principles` squash to the same thing."
  [s]
  (str/replace (str/lower-case s) #"[^a-z0-9]" ""))

(defn tagline
  "One-line summary of a leaf behavior: the first non-blank line after its
  heading, prefixed by the heading's title when the title says more than the
  name does (`#ct — Category Theory`)."
  [ctx name]
  (when-let [text (behavior-file ctx name "prompt.md")]
    (let [[heading & body] (str/split-lines text)
          title (second (re-find #" — (.+)$" heading))
          line (some #(when-not (str/blank? %) (str/trim %)) body)]
      (cond
        (and title (not= (squash title) (squash name)) line) (str title ": " line)
        line line
        :else title))))

(defn catalog
  "The `<behavior-catalog>` block: modes, composites and modifiers, one line
  each."
  [ctx]
  (let [entries (for [name (behavior-names ctx)
                      :let [compose (behavior-file ctx name "compose")]]
                  {:name name
                   :group (cond compose :composites
                                (mode-tag? (str "#" name)) :modes
                                :else :modifiers)
                   :line (if compose
                           (str "#" name " → " (str/join " " (split-tags compose)))
                           (str "#" name (some->> (tagline ctx name) (str " — "))))})
        by-group (group-by :group entries)
        section (fn [heading group]
                  (when-let [es (seq (by-group group))]
                    (str "## " heading "\n" (str/join "\n" (map :line es)))))]
    (str "<behavior-catalog>\n"
         catalog-intro "\n"
         (str/join "\n" (keep identity [(section "Modes" :modes)
                                        (section "Composites" :composites)
                                        (section "Modifiers" :modifiers)]))
         "\n</behavior-catalog>")))

;; --- Rendering --------------------------------------------------------------

(defn behavior-text
  "Contents of a behavior's prompt.md, or nil."
  [ctx tag]
  (behavior-file ctx (tag-name tag) "prompt.md"))

(defn mode-of
  [{:keys [leaves]}]
  (first (filter mode-tag? leaves)))

(defn modifiers-of
  [{:keys [leaves]}]
  (vec (remove mode-tag? leaves)))

(defn- catalog-carrier
  "The one leaf an injection appends the catalog to: the first, mode before
  modifiers, whose directory holds a `catalog` file next to its prompt.md.
  Marking several behaviors still injects the catalog once."
  [ctx expansion]
  (->> (cons (mode-of expansion) (modifiers-of expansion))
       (filter #(and % (behavior-text ctx %) (behavior-file ctx (tag-name %) "catalog")))
       first))

(defn behavior-blocks
  "The <operating-mode> and <behavior-modifiers> blocks for an expansion, with
  no framework, or nil when it carries nothing."
  [ctx expansion]
  (let [carrier (catalog-carrier ctx expansion)
        injected-text (fn [tag]
                        (when-let [text (behavior-text ctx tag)]
                          (if (= tag carrier)
                            (str text "\n\n" (catalog ctx))
                            text)))
        mode-text (some-> (mode-of expansion) injected-text)
        mod-texts (concat (keep injected-text (modifiers-of expansion))
                          (vals (:customs expansion)))
        mod-text (str/join "\n\n" (remove str/blank? mod-texts))
        blocks (cond-> []
                 (not (str/blank? mode-text))
                 (conj (str "<operating-mode>\n" mode-text "\n</operating-mode>"))

                 (not (str/blank? mod-text))
                 (conj (str "<behavior-modifiers>\n" mod-text "\n</behavior-modifiers>")))]
    (when (seq blocks)
      (str/join "\n" blocks))))

(defn injection-context
  "The full behavior injection for an expansion, or nil when it carries nothing."
  [ctx expansion]
  (some-> (behavior-blocks ctx expansion) (str "\n" framework)))

(def subagents-instruction
  ["For this prompt only: spawn each agent below as a subagent, in parallel, with this prompt's task. A later prompt spawns agents only through its own #: tokens."
   "Each spawn prompt starts with that agent's text between <agent> and </agent>, copied character for character, then the task."
   "A subagent gets only its own agent's text."
   "The blocks inside <agent> and <combine> are not yours: they don't replace your own operating mode, modifiers or framework."])

(def combine-instruction
  ["After every agent above has returned, merge their outputs into your reply."
   "The text below applies to that merge only; your own mode and modifiers govern the rest of the reply."])

(defn- tagged-section
  "<open>\\nline…\\n</close>, skipping blank lines."
  [open close lines]
  (str/join "\n" (concat [open] (remove str/blank? lines) [close])))

(defn subagents-context
  "The <subagents> block for `subagents` (from `parse-subagents`), or nil.

  Each agent's text is the injection its own tags would get as a main agent,
  framework included; the combine step gets the behavior blocks only, since
  the framework's \"apply to all responses\" would contradict its scope.
  Returns {:text … :missing [\"a:#nope\" …]}."
  [ctx {:keys [agents combine] :as subagents}]
  (when subagents
    (let [expanded (for [{:keys [name tags]} agents]
                     [name (expand-tags ctx tags)])
          combine-exp (expand-tags ctx (:tags combine))
          missing (concat (for [[name exp] expanded, tag (:missing exp)] (str name ":" tag))
                          (for [tag (:missing combine-exp)] (str "combine:" tag)))
          agent-sections (for [[name exp] expanded]
                           (tagged-section (str "<agent name=\"" name "\">") "</agent>"
                                           [(injection-context ctx exp)]))
          combine-section (tagged-section
                           (str "<combine agents=\"" (str/join " " (:agents combine)) "\">")
                           "</combine>"
                           (concat combine-instruction [(behavior-blocks ctx combine-exp)]))]
      {:text (tagged-section "<subagents>" "</subagents>"
                             (concat subagents-instruction agent-sections [combine-section]))
       :missing (vec missing)})))

(def pipeline-instruction
  ["For this prompt only: run the stages below in order, each as a fresh subagent, one at a time: start a stage only after the previous one has returned. A later prompt runs a pipeline only through its own #> token."
   "Each spawn prompt starts with that stage's text between <stage> and </stage>, copied character for character, then this prompt's task, then the previous stage's full output under \"Previous stage output:\", copied character for character, never a summary. Wait for each subagent's full result before going on."])

(def pipeline-group-instruction
  "A group stage spawns each of its agents as a fresh subagent, in parallel; each spawn prompt starts with that agent's text between <agent> and </agent>, copied character for character, then this prompt's task, then the previous stage's full output under \"Previous stage output:\", copied character for character, never a summary. After every agent has returned, merge their outputs following the text in <combine>; that merge is the stage's output.")

(def pipeline-ownership-instruction
  "The blocks inside <stage> are not yours: they don't replace your own operating mode, modifiers or framework.")

(def pipeline-combine-instruction
  "The text below applies to that merge only; your own mode and modifiers govern everything else.")

(def checker-tag
  "The behavior whose blocking labels stop a pipeline's loop and pause it."
  "#triage")

(defn- pipeline-loop-line
  "How the pipeline repeats and stops, or nil for one pass with no checker.
  `checker` is [n label] of the first stage carrying `checker-tag`, or nil."
  [cap [n label :as checker]]
  (let [stage (str "stage " n " (" label ")")
        round-line "Before each round, write \"Round\" and its number."]
    (cond
      (and cap checker)
      (str "Loop: after the last stage, start again from the first. Stage " n " (" label ")"
           " runs at most " cap " times; its run number " cap " is the last stage of the pipeline. "
           "Stop earlier when " stage " reports no blocking findings. " round-line)

      cap
      (str "Loop: after the last stage, start again from the first, for at most " cap " rounds. " round-line)

      checker
      (str "Stop early when " stage " reports no blocking findings."))))

(defn- pipeline-decision-line
  [checker]
  (if checker
    (str "Decisions: non-blocking findings go to the next stage as accepted. "
         "If a stage carrying " checker-tag " reports a blocking finding, stop before the next stage, list the blocking findings, and ask the user which to fix; "
         "after the user answers, continue with the next stage, passing their answer along. "
         "Exception: when the pipeline's last stage reports blocking findings, do not ask; end the pipeline with a report of them.")
    "Decisions: each stage's findings go to the next stage as accepted; do not pause for the user."))

(defn pipeline-context
  "The <pipeline> block for `pipeline` (from `parse-pipeline`), or nil.
  Returns {:text … :missing [\"stage1:#nope\" \"r1:#x\" \"stage2:combine:#y\"]
           :problem \"stage 2's agent r2 has no known behavior\"}; with a :problem, :text
  is nil: the pipeline is refused whole rather than run with a hole in it.

  A single stage's text is its tags' full injection, framework included, as a
  subagent's is; a group stage holds an <agent> per member and a <combine>
  with behavior blocks only. The checker is the first stage with a member
  carrying `checker-tag`: it counts the loop's runs and stops it when clean.
  Every stage carrying `checker-tag` may pause for the user."
  [ctx {:keys [stages cap] :as pipeline}]
  (when pipeline
    (let [expanded (vec (map-indexed
                         (fn [i {:keys [kind tags agents merge-tags] :as stage}]
                           (assoc stage :n (inc i)
                                  :units (if (= kind :group)
                                           (vec (for [{:keys [name tags]} agents]
                                                  [name (expand-tags ctx tags)]))
                                           [[nil (expand-tags ctx tags)]])
                                  :merge-exp (when (= kind :group) (expand-tags ctx merge-tags))))
                         stages))
          missing (vec (for [{:keys [n kind units merge-exp]} expanded
                             tag-ref (concat (for [[name exp] units, tag (:missing exp)]
                                               (str (if (= kind :group) name (str "stage" n)) ":" tag))
                                             (for [tag (:missing merge-exp)]
                                               (str "stage" n ":combine:" tag)))]
                         tag-ref))
          ;; "stage 2", or "stage 2's agent r2" inside a group: what to name
          ;; when refusing for want of a known behavior
          empty-unit (first (for [{:keys [n kind units]} expanded
                                  [name exp] units
                                  :when (empty? (:leaves exp))]
                              (if (= kind :group) (str "stage " n "'s agent " name) (str "stage " n))))
          problem (cond
                    (and cap (not (<= 1 cap max-pipeline-cap)))
                    (str "*N needs N from 1 to " max-pipeline-cap)

                    (empty? stages) "it has no stages"

                    empty-unit (str empty-unit " has no known behavior"))
          checker (first (for [{:keys [n label units]} expanded
                               :when (some (fn [[_ exp]] (some #{checker-tag} (:leaves exp))) units)]
                           [n label]))
          stage-section (fn [{:keys [n label kind units merge-exp agents]}]
                          (tagged-section
                           (str "<stage n=\"" n "\" name=\"" label "\">") "</stage>"
                           (if (= kind :group)
                             (concat (for [[name exp] units]
                                       (tagged-section (str "<agent name=\"" name "\">") "</agent>"
                                                       [(injection-context ctx exp)]))
                                     [(tagged-section
                                       (str "<combine agents=\"" (str/join " " (map :name agents)) "\">")
                                       "</combine>"
                                       [pipeline-combine-instruction (behavior-blocks ctx merge-exp)])])
                             [(injection-context ctx (second (first units)))])))]
      {:text (when-not problem
               (tagged-section "<pipeline>" "</pipeline>"
                               (concat pipeline-instruction
                                       (when (some #(= :group (:kind %)) stages) [pipeline-group-instruction])
                                       [(pipeline-loop-line cap checker)
                                        (pipeline-decision-line checker)
                                        pipeline-ownership-instruction]
                                       (map stage-section expanded))))
       :missing missing
       :problem problem})))

(defn orchestration-context
  "The one-shot block `prompt`'s tokens ask for, tagged with its kind, or nil:
  a `#>` token makes it the pipeline ({:kind :pipeline}, see `pipeline-context`);
  otherwise `#:`/`#::` tokens make it the subagents ({:kind :subagents}, see
  `subagents-context`). A refused pipeline still claims the prompt: its :text
  is nil and no subagents run."
  [ctx prompt]
  (if-let [pipeline (parse-pipeline prompt)]
    (assoc (pipeline-context ctx pipeline) :kind :pipeline)
    (some-> (subagents-context ctx (parse-subagents prompt)) (assoc :kind :subagents))))

(defn prompt-injection
  "The first-turn injection for `prompt`: its hashtags' injection, then its
  <subagents> or <pipeline> block, joined by a newline. nil when there is
  neither. No session state: a prompt with no hashtags injects only its block."
  [ctx prompt]
  (let [tags (parse-hashtags prompt)
        main (when (seq tags) (injection-context ctx (expand-tags ctx tags)))
        orchestration (:text (orchestration-context ctx prompt))]
    (some->> (remove nil? [main orchestration]) seq (str/join "\n"))))

(defn- behavior-block
  [name role text]
  (str "<behavior name=\"" name "\" role=\"" role "\">\n" text "\n</behavior>"))

(defn explain-context
  "What `tags` would do, rather than the instruction to do it: expansion trees,
  what mode resolution dropped, and the behavior texts to analyse.
  `orchestration` is `orchestration-context`'s result, whose block is explained
  alongside, or nil. Returns nil when there is nothing to explain."
  ([ctx tags] (explain-context ctx tags nil))
  ([ctx tags {block :text kind :kind :as _orchestration}]
   (let [tags (if (string? tags) (split-tags tags) tags)
         [block-instruction block-section] (case kind
                                             :pipeline [pipeline-explain-instruction "explain-pipeline"]
                                             [subagents-explain-instruction "explain-subagents"])
         {:keys [customs] :as expansion} (expand-tags ctx tags)
         mode-tag (mode-of expansion)
         ;; A composite that carries a losing mode is dropped whole, so its tree
         ;; would only mislead.
         {:keys [trees dropped]}
         (reduce (fn [acc tag]
                   (let [name (tag-name tag)]
                     (if-not (composite? ctx name)
                       acc
                       (let [cmode (compose-mode ctx name)]
                         (if (and cmode mode-tag (not= cmode mode-tag))
                           (update acc :dropped conj
                                   (str tag " (mode " cmode ") — superseded by " mode-tag))
                           (update acc :trees conj
                                   (str tag "\n" (expansion-tree ctx name))))))))
                 {:trees [] :dropped []}
                 tags)
         dropped (into dropped
                       (for [tag tags
                             :when (and (mode-tag? tag)
                                        (not= tag mode-tag)
                                        (not (composite? ctx (tag-name tag)))
                                        (resolve-dir ctx (tag-name tag)))]
                         (str tag " — superseded by " mode-tag)))
         content (str/join
                  "\n"
                  (concat
                   (when-let [text (and mode-tag (behavior-text ctx mode-tag))]
                     [(behavior-block mode-tag "mode" text)])
                   (for [tag (modifiers-of expansion)
                         :let [text (behavior-text ctx tag)]
                         :when text]
                     (behavior-block tag "modifier" text))
                   (for [[name text] customs]
                     (behavior-block (str "#" name) "composite" text))))
         tree-section (when (seq trees)
                        (str "<expansion-tree>\n" (str/join "\n" trees) "</expansion-tree>\n"))
         dropped-section (when (seq dropped)
                           (str "<dropped-by-mode-resolution>\n"
                                (str/join (map #(str % "\n") dropped))
                                "</dropped-by-mode-resolution>\n"))
         main? (or (seq content) tree-section)]
     (when (or main? block)
       (str "<explain-instruction>\n"
            (str/join "\n" explain-instruction-body)
            (when dropped-section (str "\n" dropped-instruction))
            (when block (str "\n" block-instruction))
            "\n\n"
            (str/join "\n" explain-sections)
            "\n</explain-instruction>\n"
            tree-section
            dropped-section
            (when main? (str "<explain-behaviors>\n" content "\n</explain-behaviors>"))
            (when block
              (str (when main? "\n") "<" block-section ">\n" block "\n</" block-section ">")))))))
