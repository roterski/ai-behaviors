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
