(ns ai-behaviors.api
  "One-call use: a prompt string in, the same prompt with its behaviors in.

  Nothing to install, no context to build, no state to carry:

    (require '[ai-behaviors.api :as ab])
    (ab/augment \"fix the login bug #=code #deep\")

  A prompt with no hashtags comes back untouched."
  (:require [ai-behaviors.core :as core]
            [clojure.java.io :as io]))

(def ^:private api-resource "ai_behaviors/api.clj")

(defn- classpath-dir
  "Directory classpath entry `api-resource` was loaded from, or nil when it did
  not come from one — inside a jar the URL is `jar:` and there is no directory."
  [^java.net.URL url]
  (when (= "file" (.getProtocol url))
    (let [segments (inc (count (re-seq #"/" api-resource)))]
      (nth (iterate #(some-> ^java.io.File % .getParentFile) (io/file url))
           segments))))

(defn- dir-holding-behaviors
  "`dir` or its nearest ancestor holding a behaviors/ directory, or nil.
  `classpath-dir` counts parents to reach the classpath root; from there the
  repo root is found by looking for behaviors/ rather than counting again."
  [dir]
  (->> (iterate #(some-> ^java.io.File % .getParentFile) dir)
       (take-while some?)
       (take 3)
       (some #(when (.isDirectory (io/file % "behaviors")) (.getPath ^java.io.File %)))))

(def ^:private bundled-dir
  "Directory whose behaviors/ holds this repo's own behavior set.

  In precedence order: $AI_BEHAVIORS_DIR, the `ai-behaviors.dir` property, the
  classpath entry this namespace was loaded from, then the working directory.
  An explicit override is honoured as given — point it at a directory that
  contains behaviors/, or the set resolves to nothing.

  `classpath-dir` returns nil for a `jar:` URL, in which case the last resort
  answers; a caller running from outside the repo should pass `:repo-dir` or set
  the override to say where the behaviors live."
  (delay
    (or (System/getenv "AI_BEHAVIORS_DIR")
        (System/getProperty "ai-behaviors.dir")
        (some-> (io/resource api-resource) classpath-dir dir-holding-behaviors)
        (System/getProperty "user.dir"))))

(defn context
  "The lookup context used by default: this repo's behaviors, plus any
  user-local and project-local ones. Pass overrides (`:repo-dir`, `:cwd`,
  `:home`, `:xdg-config-home`) to point somewhere else."
  ([] (context {}))
  ([overrides]
   (core/context (merge {:repo-dir @bundled-dir
                         :cwd (System/getProperty "user.dir")}
                        overrides))))

(defn- ->context
  "A context, from either a context or a map of overrides for `context`.

  `:roots` is the only key lookup actually reads, so its presence is what marks
  an already-built context. Building one shells out to git and re-walks the
  behavior directories, so a caller in a loop should build one with `context`
  and pass it to every call.

  Requires a map or nil, and a `:roots` entry that is a sequence of directory
  paths. Both are checked here because this is the one boundary every public
  entry point crosses, and because an unchecked `:roots` is not caught by
  anything downstream — it surfaces much later as a type error from inside the
  file lookup, naming a class the caller never mentioned."
  [ctx-or-overrides]
  (when-not (or (nil? ctx-or-overrides) (map? ctx-or-overrides))
    (throw (ex-info (str "Expected a context or a map of overrides, got "
                         (.getSimpleName (class ctx-or-overrides)) ": "
                         (pr-str ctx-or-overrides))
                    {:got ctx-or-overrides})))
  (let [roots (:roots ctx-or-overrides)]
    (cond
      (nil? roots)
      (context ctx-or-overrides)

      (and (sequential? roots) (every? string? roots))
      ctx-or-overrides

      :else
      (throw (ex-info (str ":roots must be a sequence of directory paths, got "
                           (pr-str roots))
                      {:roots roots})))))

(defn behaviors
  "Just the behavior text for `prompt`'s hashtags — the operating mode,
  modifiers and framework blocks — or nil when it names none.

  Use this when you want the behaviors as a system message and the prompt as a
  user message. Unknown hashtags are ignored; check `report` to see them.

  The second argument is a context from `context`, or overrides to build one
  with — as it is for `augment`, `report` and `explain`."
  ([prompt] (behaviors prompt {}))
  ([prompt ctx-or-overrides]
   (let [ctx (->context ctx-or-overrides)
         tags (core/parse-hashtags prompt)]
     (when (seq tags)
       (core/injection-context ctx (core/expand-tags ctx tags))))))

(defn augment
  "`prompt` with its behaviors prepended, ready to send to a model.

  Returns the prompt unchanged when it carries no known hashtags."
  ([prompt] (augment prompt {}))
  ([prompt ctx-or-overrides]
   (if-let [text (behaviors prompt ctx-or-overrides)]
     (str text "\n\n" prompt)
     prompt)))

(defn report
  "What `prompt` resolves to, for tooling and debugging:
  {:tags [...] :leaves [...] :missing [...] :mode \"#=code\" :modifiers [...]
   :composites [...] :behaviors \"...\"}."
  ([prompt] (report prompt {}))
  ([prompt ctx-or-overrides]
   (let [ctx (->context ctx-or-overrides)
         tags (core/parse-hashtags prompt)
         expansion (core/expand-tags ctx tags)]
     {:tags tags
      :leaves (:leaves expansion)
      :missing (:missing expansion)
      :mode (core/mode-of expansion)
      :modifiers (core/modifiers-of expansion)
      :composites (vec (keys (:customs expansion)))
      :behaviors (when (seq tags) (core/injection-context ctx expansion))})))

(defn explain
  "What `prompt`'s hashtags would do, rather than the instruction to do it —
  a payload to hand a model when the user wants the combination explained.
  nil when the prompt names no behaviors."
  ([prompt] (explain prompt {}))
  ([prompt ctx-or-overrides]
   (let [tags (core/parse-hashtags prompt)]
     (when (seq tags)
       (core/explain-context (->context ctx-or-overrides) tags)))))

(comment
  (augment "fix the login bug #=code #deep")
  (behaviors "#Research")
  (report "ship it #Code #nope")
  (explain "#Frame #Code")
  ;; a behavior set from somewhere else entirely
  (augment "#house-style" {:repo-dir "/tmp/my-behaviors"})
  ;; build the context once when augmenting more than one prompt
  (let [ctx (context)]
    (mapv #(augment % ctx) ["#Code" "#Review #deep"])))
