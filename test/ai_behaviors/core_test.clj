(ns ai-behaviors.core-test
  (:require [ai-behaviors.core :as core]
            [babashka.fs :as fs]
            [clojure.string :as str]
            [clojure.test :refer [deftest is testing]]))

(defn- write-behavior!
  "Behavior `name` under `root`, with each of `files` (filename → contents)."
  [root name files]
  (let [dir (fs/path root name)]
    (fs/create-dirs dir)
    (doseq [[filename contents] files]
      (spit (fs/file dir filename) contents))))

(defn- with-roots
  "Calls `f` with a hand-built context over fresh `local` and `repo` roots."
  [f]
  (let [tmp (fs/create-temp-dir)
        local (str (fs/path tmp "local"))
        repo (str (fs/path tmp "repo"))]
    (try
      (fs/create-dirs local)
      (fs/create-dirs repo)
      (f {:roots [local repo]} local repo)
      (finally (fs/delete-tree tmp)))))

(deftest tagline-test
  (with-roots
    (fn [ctx _ repo]
      (write-behavior! repo "ct" {"prompt.md" "# #ct — Category Theory\n\n  Name the structure.  \nMore."})
      (write-behavior! repo "deep" {"prompt.md" "# #deep — Deep\nGo beneath."})
      (write-behavior! repo "bare" {"prompt.md" "# #bare — Bare Title"})
      (testing "title prefixed when it says more than the name"
        (is (= "Category Theory: Name the structure." (core/tagline ctx "ct"))))
      (testing "title dropped when it only restates the name"
        (is (= "Go beneath." (core/tagline ctx "deep"))))
      (testing "title alone when there is no body"
        (is (= "Bare Title" (core/tagline ctx "bare"))))
      (testing "CRLF line endings"
        (write-behavior! repo "crlf" {"prompt.md" "# #crlf — Carriage Return\r\n\r\nTagline.\r\n"})
        (is (= "Carriage Return: Tagline." (core/tagline ctx "crlf"))))
      (testing "nil without a prompt.md"
        (is (nil? (core/tagline ctx "missing")))))))

(deftest behavior-names-test
  (with-roots
    (fn [ctx local repo]
      (write-behavior! repo "deep" {"prompt.md" "# #deep — Deep\nRepo."})
      (write-behavior! local "deep" {"prompt.md" "# #deep — Deep\nLocal."})
      (write-behavior! repo "Code" {"compose" "#=code"})
      (write-behavior! repo ".hidden" {"prompt.md" "# #hidden"})
      (fs/create-dirs (fs/path repo "empty"))
      (is (= ["Code" "deep"] (core/behavior-names ctx))
          "sorted, shadowed names once, dot-dirs and dirs without behavior files skipped"))))

(deftest catalog-test
  (with-roots
    (fn [ctx _ repo]
      (write-behavior! repo "=code" {"prompt.md" "# #=code — Code\nShip it."})
      (write-behavior! repo "Code" {"compose" "#=code\n  #deep\n"})
      (write-behavior! repo "deep" {"prompt.md" "# #deep — Deep\nGo beneath."})
      (is (= (str "<behavior-catalog>\n"
                  core/catalog-intro "\n"
                  "## Modes\n#=code — Ship it.\n"
                  "## Composites\n#Code → #=code #deep\n"
                  "## Modifiers\n#deep — Go beneath.\n"
                  "</behavior-catalog>")
             (core/catalog ctx))))))

(defn- injection [ctx tags]
  (core/injection-context ctx (core/expand-tags ctx tags)))

(defn- block [text tag]
  (second (re-find (re-pattern (str "(?s)<" tag ">(.*?)</" tag ">")) text)))

(deftest catalog-marker-test
  (with-roots
    (fn [ctx local repo]
      (write-behavior! repo "=route" {"prompt.md" "# #=route — Route\nRecommend." "catalog" ""})
      (write-behavior! repo "=code" {"prompt.md" "# #=code — Code\nShip it."})
      (write-behavior! repo "lens" {"prompt.md" "# #lens — Lens\nLook." "catalog" ""})
      (write-behavior! repo "deep" {"prompt.md" "# #deep — Deep\nGo beneath."})
      (testing "a marked mode carries the catalog inside <operating-mode>"
        (is (str/includes? (block (injection ctx ["#=route"]) "operating-mode")
                           "<behavior-catalog>")))
      (testing "a marked modifier carries it inside <behavior-modifiers>"
        (let [text (injection ctx ["#=code" "#lens"])]
          (is (not (str/includes? (block text "operating-mode") "<behavior-catalog>")))
          (is (str/includes? (block text "behavior-modifiers") "<behavior-catalog>"))))
      (testing "no marker, no catalog"
        (is (not (str/includes? (injection ctx ["#=code" "#deep"]) "<behavior-catalog>"))))
      (testing "several marked behaviors inject it once, on the mode first"
        (let [text (injection ctx ["#=route" "#lens"])]
          (is (= 1 (count (re-seq #"<behavior-catalog>\n" text))))
          (is (str/includes? (block text "operating-mode") "<behavior-catalog>\n"))))
      (testing "a shadow without the marker drops the catalog"
        (write-behavior! local "=route" {"prompt.md" "# #=route — Route\nRecommend."})
        (is (not (str/includes? (injection ctx ["#=route"]) "<behavior-catalog>")))))))

(deftest parse-subagents-test
  (testing "repeat and comma forms accumulate to the same tags"
    (is (= (core/parse-subagents "#:a:challenge #:a:deep")
           (core/parse-subagents "#:a:challenge,deep")
           {:agents [{:name "a" :tags ["#challenge" "#deep"]}]
            :combine {:agents ["a"] :tags ["#all"]}
            :ignored []
            :ungrouped []})))
  (testing "combinator: agents in written order, tags stacked over the same set"
    (is (= {:agents [{:name "a" :tags ["#challenge"]} {:name "b" :tags []}]
            :combine {:agents ["a" "b"] :tags ["#diff" "#deep"]}
            :ignored ["#::c:all"]
            :ungrouped []}
           (core/parse-subagents "#:a:challenge #::a+b:diff #::b+a:deep,diff #::c:all"))))
  (testing "only the combine group is spawned; tagged agents outside it are ungrouped"
    (is (= {:agents [{:name "a" :tags ["#challenge"]}]
            :combine {:agents ["a"] :tags ["#diff"]}
            :ignored []
            :ungrouped ["b"]}
           (core/parse-subagents "#:a:challenge #:b:steel-man #::a:diff"))))
  (testing "agents keep first-appearance order past eight names"
    (let [names (map #(str "n" %) (range 12))]
      (is (= names (map :name (:agents (core/parse-subagents
                                         (str/join " " (map #(str "#:" % ":deep") names)))))))))
  (testing "not hashtags, and inert after a non-space"
    (is (= [] (core/parse-hashtags "#:a:challenge #::a+b:diff")))
    (is (nil? (core/parse-subagents "https://x.com#:a:deep x#::a:diff plain #Code")))))

(deftest subagents-context-test
  (with-roots
    (fn [ctx _ repo]
      (write-behavior! repo "challenge" {"prompt.md" "# #challenge — Challenge\nAttack."})
      (write-behavior! repo "=code" {"prompt.md" "# #=code — Code\nShip."})
      (write-behavior! repo "diff" {"prompt.md" "# #diff — Diff\nDisagreements."})
      (let [{:keys [text missing]}
            (core/subagents-context ctx (core/parse-subagents "#:a:challenge,=code,nope #::a+b:diff,zz"))]
        (testing "agent text is the full injection; combine has blocks only"
          (is (str/includes? text (str "<agent name=\"a\">\n"
                                       (core/injection-context ctx (core/expand-tags ctx ["#challenge" "#=code"]))
                                       "\n</agent>")))
          (is (str/includes? text (str "<combine agents=\"a b\">\n"
                                       (str/join "\n" core/combine-instruction) "\n"
                                       "<behavior-modifiers>\n# #diff — Diff\nDisagreements.\n</behavior-modifiers>\n"
                                       "</combine>\n</subagents>"))))
        (testing "an untagged agent gets an empty block"
          (is (str/includes? text "<agent name=\"b\">\n</agent>")))
        (testing "unknown tags named by agent and combine"
          (is (= ["a:#nope" "combine:#zz"] missing))))
      (testing "prompt-injection: main injection, then the block"
        (let [main (core/injection-context ctx (core/expand-tags ctx ["#=code"]))
              block (:text (core/subagents-context ctx (core/parse-subagents "#:a:challenge")))]
          (is (= (str main "\n" block) (core/prompt-injection ctx "#=code #:a:challenge")))
          (is (= block (core/prompt-injection ctx "#:a:challenge")))
          (is (nil? (core/prompt-injection ctx "no tags"))))))))

(deftest parse-pipeline-test
  (testing "no #> token"
    (is (nil? (core/parse-pipeline "#Code #:a:challenge")))
    (is (nil? (core/parse-pipeline "x#>Test https://x.com#>Test"))))
  (testing "stages and cap"
    (let [p (core/parse-pipeline "#>Test>Review>Code*3 task")]
      (is (= "#>Test>Review>Code*3" (:token p)))
      (is (= [{:label "Test" :kind :tags :tags ["#Test"]}
              {:label "Review" :kind :tags :tags ["#Review"]}
              {:label "Code" :kind :tags :tags ["#Code"]}]
             (:stages p)))
      (is (= 3 (:cap p))))
    (is (= core/default-pipeline-cap (:cap (core/parse-pipeline "#>Test>Review*"))))
    (is (nil? (:cap (core/parse-pipeline "#>Test>Review"))))
    (is (= 0 (:cap (core/parse-pipeline "#>Test*0"))))
    (is (< core/max-pipeline-cap (:cap (core/parse-pipeline "#>Test*99999999999999999999")))))
  (testing "comma tags and blank stages"
    (is (= [{:label "Review,challenge" :kind :tags :tags ["#Review" "#challenge"]}
            {:label "Code" :kind :tags :tags ["#Code"]}]
           (:stages (core/parse-pipeline "#>Review,challenge>>Code")))))
  (testing "a #: name wins over a behavior of the same name"
    (is (= {:label "Review" :kind :agent :name "Review" :tags ["#Code"]}
           (second (:stages (core/parse-pipeline "#:Review:Code #>Test>Review")))))
    (is (= :tags (:kind (second (:stages (core/parse-pipeline "#>Test>Review")))))))
  (testing "a group merges by its #:: tokens over the same set, else #all"
    (let [g (second (:stages (core/parse-pipeline
                              "#:r1:challenge #::r2+r1:diff #::r1+r2:deep #>Test>r1+r2")))]
      (is (= :group (:kind g)))
      (is (= [{:name "r1" :tags ["#challenge"]} {:name "r2" :tags []}] (:agents g)))
      (is (= ["#diff" "#deep"] (:merge-tags g))))
    (is (= ["#all"] (:merge-tags (second (:stages (core/parse-pipeline "#>Test>a+b")))))))
  (testing "one pipeline per prompt; unused agents and groups reported"
    (let [p (core/parse-pipeline "#:r:Review #:x:deep #::q+r:all #>Test>r #>Code")]
      (is (= ["#>Code"] (:ignored p)))
      (is (= ["x"] (:unused-agents p)))
      (is (= ["#::q+r:all"] (:unused-groups p))))))

(def ^:private spike-instruction-lines
  "The first two <pipeline> lines exactly as the e2e spike rendered and measured
  them (ai/spike/pipeline-hook-e2e.finding.md, Method)."
  ["For this prompt only: run the stages below in order, each as a fresh subagent, one at a time: start a stage only after the previous one has returned. A later prompt runs a pipeline only through its own #> token."
   "Each spawn prompt starts with that stage's text between <stage> and </stage>, copied character for character, then this prompt's task, then the previous stage's full output under \"Previous stage output:\", copied character for character, never a summary. Wait for each subagent's full result before going on."])

(deftest pipeline-context-test
  (with-roots
    (fn [ctx _ repo]
      (write-behavior! repo "=test" {"prompt.md" "# #=test — Test\nBreak."})
      (write-behavior! repo "=code" {"prompt.md" "# #=code — Code\nShip."})
      (write-behavior! repo "triage" {"prompt.md" "# #triage — Triage\nBlocking or not."})
      (write-behavior! repo "challenge" {"prompt.md" "# #challenge — Challenge\nAttack."})
      (write-behavior! repo "diff" {"prompt.md" "# #diff — Diff\nDisagreements."})
      (let [render #(core/pipeline-context ctx (core/parse-pipeline %))
            lines #(set (str/split-lines (:text (render %))))]
        (testing "instruction lines keep the spike's measured wording"
          (is (= (into ["<pipeline>"] spike-instruction-lines)
                 (take 3 (str/split-lines (:text (render "#>=test>=code")))))))
        (testing "a single stage's text is its tags' full injection"
          (is (str/includes? (:text (render "#>=test>=code"))
                             (str "<stage n=\"1\" name=\"=test\">\n"
                                  (core/injection-context ctx (core/expand-tags ctx ["#=test"]))
                                  "\n</stage>"))))
        (testing "the checker counts loop runs and is the only stage that pauses"
          (let [ls (lines "#>=test>triage>=code*2")]
            (is (contains? ls "Loop: after the last stage, start again from the first. Stage 2 (triage) runs at most 2 times; its run number 2 is the last stage of the pipeline. Stop earlier when stage 2 (triage) reports no blocking findings. Before each round, write \"Round\" and its number."))
            (is (some #(str/includes? % "If a stage carrying #triage reports a blocking finding") ls))
            (is (some #(str/includes? % "Exception: when the pipeline's last stage reports blocking findings, do not ask") ls))))
        (testing "no checker: *N counts rounds and nothing pauses"
          (let [ls (lines "#>=code>=test*")]
            (is (contains? ls "Loop: after the last stage, start again from the first, for at most 3 rounds. Before each round, write \"Round\" and its number."))
            (is (contains? ls "Decisions: each stage's findings go to the next stage as accepted; do not pause for the user."))))
        (testing "one pass with a checker stops early on a clean checker"
          (is (contains? (lines "#>=test>triage") "Stop early when stage 2 (triage) reports no blocking findings.")))
        (testing "a group stage holds its agents and a blocks-only combine"
          (let [text (:text (render "#:r1:challenge #:r2:triage #::r1+r2:diff #>=test>r1+r2>=code"))]
            (is (str/includes? text core/pipeline-group-instruction))
            (is (str/includes? text (str "<stage n=\"2\" name=\"r1+r2\">\n<agent name=\"r1\">\n"
                                         (core/injection-context ctx (core/expand-tags ctx ["#challenge"]))
                                         "\n</agent>")))
            (is (str/includes? text (str "<combine agents=\"r1 r2\">\n" core/pipeline-combine-instruction "\n"
                                         "<behavior-modifiers>\n# #diff — Diff\nDisagreements.\n</behavior-modifiers>\n"
                                         "</combine>\n</stage>")))
            (is (str/includes? text "Stop early when stage 2 (r1+r2) reports no blocking findings.")
                "a group member carrying #triage makes the group the checker")))
        (testing "refusals: no :text, a :problem, unknown tags still listed"
          (is (= {:text nil :missing ["stage2:#nope"] :problem "stage 2 has no known behavior"}
                 (render "#>=test>nope")))
          (is (= "stage 2's agent a has no known behavior" (:problem (render "#>=test>a+b")))
              "an untagged group member is named")
          (is (= "stage 2's agent r2 has no known behavior"
                 (:problem (render "#:r1:challenge #>=test>r1+r2")))
              "one untagged member refuses the group")
          (is (= "*N needs N from 1 to 999" (:problem (render "#>=test*0"))))
          (is (= "it has no stages" (:problem (render "#>>"))))
          (is (= ["stage1:#zz" "r1:#nope" "stage2:combine:#qq"]
                 (:missing (render "#:r1:challenge,nope #:r2:diff #::r1+r2:qq #>=test,zz>r1+r2")))))
        (testing "prompt-injection: a #> token claims the prompt from #: tokens"
          (let [block (:text (render "#:a:challenge #>=test>a"))]
            (is (= block (core/prompt-injection ctx "#:a:challenge #:b:diff #>=test>a")))
            (is (= (str (core/injection-context ctx (core/expand-tags ctx ["#=code"])) "\n" block)
                   (core/prompt-injection ctx "#=code #:a:challenge #>=test>a")))
            (is (nil? (core/prompt-injection ctx "#:a:challenge #>=test>nope"))
                "a refused pipeline injects nothing, not the subagents")))))))
