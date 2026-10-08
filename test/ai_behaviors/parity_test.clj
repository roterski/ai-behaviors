(ns ai-behaviors.parity-test
  "First-turn injection must be identical from the Claude Code hook, the ECA
  hook and ai-behaviors.core, for the shipped behaviors in this repo."
  (:require [ai-behaviors.core :as core]
            [babashka.fs :as fs]
            [babashka.process :as p]
            [cheshire.core :as json]
            [clojure.string :as str]
            [clojure.test :refer [deftest is testing]]))

(def ^:private repo-dir
  "This repo: two levels above this file's test/ai_behaviors/ dir, wherever the run starts."
  (str (fs/parent (fs/parent (fs/parent (fs/absolutize *file*))))))

(def ^:private prompts
  ["" "#nonexistent" "#Spike #nonexistent"
   "#=spike" "#Spike" "#Spike #challenge" "#Spike #falsifiable" "#Spike #Spike" "#=spike #=spike"
   "#Spike #=research" "#=research #Spike" "#Collate #Spike"
   "#=research" "#Research" "#Collate" "#=converge" "#Converge" "#Route"
   "#Frame" "#Design" "#Spec" "#Code" "#Debug" "#Test"
   "#=spike\n#stop" "text #Spike more" "https://x.com#Spike" "#EXPLAIN #Spike"
   "#Spike q → p, then `#Collate a into b`"
   "#=stepback" "#Stepback" "#Stepback #file x"
   "#assumptions" "#proceed" "#Code #proceed" "#Spike #proceed" "#EXPLAIN #proceed"])

(defn- hook-context
  "additionalContext from hook `script` fed `payload`, with a fresh HOME and XDG dir."
  [script payload]
  (let [home (fs/create-temp-dir)]
    (try
      (let [{:keys [out]} (p/shell {:in (json/generate-string payload)
                                    :out :string :err :string :continue true
                                    :extra-env {"HOME" (str home)
                                                "XDG_CONFIG_HOME" (str (fs/path home ".config"))}}
                                   "bash" (str (fs/path repo-dir "hooks" script)))]
        (when-not (str/blank? out)
          (let [json (json/parse-string out)]
            (or (get-in json ["hookSpecificOutput" "additionalContext"])
                (get json "additionalContext")))))
      (finally (fs/delete-tree home)))))

(defn- core-context [ctx prompt]
  (let [tags (core/parse-hashtags prompt)]
    (if (some #{"#EXPLAIN"} tags)
      (core/explain-context ctx (remove #{"#EXPLAIN"} tags))
      (core/injection-context ctx (core/expand-tags ctx tags)))))

(deftest first-turn-parity-test
  (is (and (fs/which "bash") (fs/which "jq")) "bash and jq are on PATH")
  (let [home (fs/create-temp-dir)
        ctx (core/context {:repo-dir repo-dir :cwd repo-dir :home (str home)
                           :xdg-config-home (str (fs/path home ".config"))})]
    (try
      (doseq [prompt prompts]
        (testing (pr-str prompt)
          (let [expected (core-context ctx prompt)]
            (is (= expected (hook-context "inject-behaviors.sh"
                                          {:prompt prompt :session_id "parity" :cwd repo-dir}))
                "Claude Code hook")
            (is (= expected (hook-context "eca-inject-behaviors.sh"
                                          {:prompt prompt :chat_id "parity" :workspaces [repo-dir]}))
                "ECA hook"))))
      (finally (fs/delete-tree home)))))
